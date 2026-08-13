class_name LanRaceSynchronizer
extends Node

var lan_session: LanSession
var world: RaceWorld
var snapshot_buffer := LanSnapshotBuffer.new()
var _kart_by_slot: Dictionary = {}
var _server_clock_offset_ms := 0
var _has_clock_offset := false
var _network_item_replicas: Dictionary = {}


func setup(value_session: LanSession, value_world: RaceWorld) -> void:
	lan_session = value_session
	world = value_world
	for kart in world.race_manager.racers:
		_kart_by_slot[int(kart.get("participant_slot"))] = kart
	lan_session.input_received.connect(_handle_input_received)
	lan_session.snapshot_received.connect(_handle_snapshot_received)
	lan_session.reliable_event_received.connect(_handle_reliable_event)
	lan_session.ai_takeover_requested.connect(_handle_ai_takeover)
	lan_session.control_restored.connect(_handle_control_restored)
	if lan_session.is_host:
		world.race_manager.lap_completed.connect(_broadcast_lap)
		world.race_manager.race_completed.connect(_broadcast_result)
	else:
		_configure_client_prediction()


func _physics_process(_delta: float) -> void:
	if lan_session == null or world == null or not lan_session.race_active:
		return
	if lan_session.is_host:
		var local_kart := world.player_kart
		if local_kart != null:
			lan_session.set_local_input(local_kart.get_drive_input_frame())
		lan_session.broadcast_snapshot(_build_snapshot())
	else:
		var local_kart := world.player_kart
		if local_kart != null:
			lan_session.set_local_input(local_kart.get_drive_input_frame())
		_apply_buffered_snapshot()


func _build_snapshot() -> Dictionary:
	var racers: Array[Dictionary] = []
	for kart in world.race_manager.racers:
		var state := {
			"slot_id": int(kart.get("participant_slot")),
			"position": kart.global_position,
			"rotation": kart.global_transform.basis.get_rotation_quaternion(),
			"velocity": kart.velocity,
			"lap": world.race_manager.get_completed_checkpoint_count(kart),
			"finished": not kart.is_control_enabled and world.race_manager.state in [RaceManager.RaceState.WAITING_FOR_RIVALS, RaceManager.RaceState.FINISHED],
			"held_item_id": kart.held_item.id if kart.held_item != null else &"",
		}
		racers.append(state)
	var items: Array[Dictionary] = []
	for container in [world._projectiles, world._traps]:
		if container == null:
			continue
		for entity_value in container.get_children():
			var entity := entity_value as Node3D
			if entity == null or not entity.has_meta(&"lan_entity_id"):
				continue
			var velocity := Vector3.ZERO
			if entity is CharacterBody3D:
				velocity = (entity as CharacterBody3D).velocity
			items.append({
				"entity_id": int(entity.get_meta(&"lan_entity_id")),
				"position": entity.global_position,
				"rotation": entity.global_basis.get_rotation_quaternion(),
				"velocity": velocity,
			})
	return {"racers": racers, "items": items, "race_time": world.race_manager.race_time}


func _configure_client_prediction() -> void:
	world.race_manager.race_started.connect(_disable_client_authority)
	for kart in world.race_manager.racers:
		if kart != world.player_kart:
			kart.set_physics_process(false)
		else:
			kart.item_catalog = null
			kart.allow_item_execution = false
	for item_box in world._item_boxes:
		item_box.set_collection_enabled(false)


func _disable_client_authority() -> void:
	# The local countdown may animate, but clients stop lap/result simulation the
	# instant control begins. Only host snapshots and reliable events advance it.
	world.race_manager.set_process(false)


func _handle_input_received(slot_id: int, sequence: int, frame: Dictionary) -> void:
	if not lan_session.is_host:
		return
	var kart := _kart_by_slot.get(slot_id) as Kart
	if kart == null or kart.input_source == null or not kart.input_source.has_method("push_frame"):
		return
	kart.input_source.push_frame(sequence, frame)


func _handle_snapshot_received(snapshot: Dictionary) -> void:
	if lan_session.is_host:
		return
	var server_time := int(snapshot.get("server_time_ms", 0))
	if not _has_clock_offset:
		_server_clock_offset_ms = Time.get_ticks_msec() - server_time
		_has_clock_offset = true
	snapshot_buffer.push_snapshot(snapshot)
	_apply_item_snapshot(snapshot.get("items", []))


func _apply_buffered_snapshot() -> void:
	if not _has_clock_offset:
		return
	var server_now := Time.get_ticks_msec() - _server_clock_offset_ms
	for slot_id in _kart_by_slot:
		var kart := _kart_by_slot[slot_id] as Kart
		var state := snapshot_buffer.sample_racer(int(slot_id), server_now)
		if state.is_empty():
			continue
		if kart == world.player_kart:
			var current := {
				"position": kart.global_position,
				"rotation": kart.global_transform.basis.get_rotation_quaternion(),
				"velocity": kart.velocity,
			}
			state = snapshot_buffer.reconcile_local(current, state)
		kart.global_position = state.get("position", kart.global_position)
		kart.global_transform.basis = Basis(state.get("rotation", kart.global_transform.basis.get_rotation_quaternion()))
		kart.velocity = state.get("velocity", kart.velocity)
		_apply_held_item(kart, StringName(state.get("held_item_id", &"")))


func _broadcast_lap(kart: Node, lap: int, lap_time: float) -> void:
	lan_session.broadcast_reliable_event(&"lap", {
		"slot_id": int(kart.get("participant_slot")),
		"lap": lap,
		"lap_time": lap_time,
	})


func _broadcast_result(result: RaceResult) -> void:
	lan_session.broadcast_reliable_event(&"race_result", _serialize_result(result))


func _handle_reliable_event(kind: StringName, payload: Dictionary) -> void:
	if lan_session.is_host:
		return
	match kind:
		&"race_result":
			world.receive_network_result(_deserialize_result_for_local(payload))
		&"lap":
			var kart := _kart_by_slot.get(int(payload.get("slot_id", -1))) as Kart
			if kart == world.player_kart:
				world._handle_lap_completed(kart, int(payload.get("lap", 0)), float(payload.get("lap_time", 0.0)))
		&"item_activated":
			_present_item_activation(StringName(payload.get("item_id", &"")))
		&"item_hit":
			_present_item_hit(payload)
		&"item_spawned":
			_spawn_item_replica(payload)
		&"item_destroyed":
			_destroy_item_replica(int(payload.get("entity_id", -1)))


func _apply_held_item(kart: Kart, item_id: StringName) -> void:
	var item := world.item_catalog.get_item(item_id) if not item_id.is_empty() else null
	if kart.held_item == item:
		return
	kart.held_item = item
	kart.item_changed.emit(item)


func _apply_item_snapshot(values: Array) -> void:
	for value in values:
		if not value is Dictionary:
			continue
		var entity_id := int(value.get("entity_id", -1))
		var entity := _network_item_replicas.get(entity_id) as Node3D
		if entity == null or not is_instance_valid(entity):
			continue
		var position: Vector3 = value.get("position", entity.global_position)
		var rotation: Quaternion = value.get("rotation", entity.global_basis.get_rotation_quaternion())
		entity.global_position = entity.global_position.lerp(position, 0.65)
		entity.global_basis = Basis(entity.global_basis.get_rotation_quaternion().slerp(rotation, 0.65))
		if entity is CharacterBody3D:
			(entity as CharacterBody3D).velocity = value.get("velocity", Vector3.ZERO)


func _spawn_item_replica(payload: Dictionary) -> void:
	var entity_id := int(payload.get("entity_id", -1))
	if entity_id < 0 or _network_item_replicas.has(entity_id):
		return
	var item := world.item_catalog.get_item(StringName(payload.get("item_id", &"")))
	var source := _kart_by_slot.get(int(payload.get("source_slot", -1))) as Kart
	if item == null:
		return
	var entity: Node3D
	if StringName(payload.get("entity_kind", &"")) == &"projectile":
		var projectile := KartProjectile.new()
		var velocity: Vector3 = payload.get("velocity", Vector3.FORWARD)
		projectile.setup(source, item, velocity.normalized() if not velocity.is_zero_approx() else Vector3.FORWARD)
		world._projectiles.add_child(projectile)
		projectile.set_physics_process(false)
		projectile.collision_layer = 0
		projectile.collision_mask = 0
		projectile.velocity = velocity
		entity = projectile
	else:
		var trap := ItemTrap.new()
		trap.setup(source, item)
		world._traps.add_child(trap)
		trap.set_physics_process(false)
		trap.collision_layer = 0
		trap.collision_mask = 0
		entity = trap
	entity.global_position = payload.get("position", Vector3.ZERO)
	entity.global_basis = Basis(payload.get("rotation", Quaternion.IDENTITY))
	_network_item_replicas[entity_id] = entity


func _destroy_item_replica(entity_id: int) -> void:
	var entity := _network_item_replicas.get(entity_id) as Node3D
	if entity != null and is_instance_valid(entity):
		entity.queue_free()
	_network_item_replicas.erase(entity_id)


func _present_item_activation(item_id: StringName) -> void:
	var item := world.item_catalog.get_item(item_id)
	if item == null:
		return
	match item.category:
		ItemDefinition.ItemCategory.PROJECTILE:
			world._sound.play_item_launch()
		ItemDefinition.ItemCategory.TRAP:
			world._sound.play_item_deploy()
		_:
			world._sound.play_item_activation()


func _present_item_hit(payload: Dictionary) -> void:
	var result := int(payload.get("result", Kart.HitResult.IGNORED))
	if result == Kart.HitResult.BLOCKED:
		world._sound.play_shield_block()
		return
	world._sound.play_item_impact()
	var target := _kart_by_slot.get(int(payload.get("target_slot", -1))) as Kart
	if target == world.player_kart:
		world._handle_local_player_hit(target)


func _handle_ai_takeover(slot_id: int) -> void:
	if lan_session.is_host:
		world.take_over_with_ai(slot_id)


func _handle_control_restored(slot_id: int, _peer_id: int) -> void:
	if lan_session.is_host:
		world.restore_network_control(slot_id)


func _serialize_result(result: RaceResult) -> Dictionary:
	var standings: Array[Dictionary] = []
	for row in result.standings:
		standings.append({
			"racer_id": row.racer_id,
			"racer_name": row.racer_name,
			"participant_slot": row.participant_slot,
			"start_position": row.start_position,
			"finish_position": row.finish_position,
			"laps_completed": row.laps_completed,
			"lap_times": row.lap_times,
			"finish_time": row.finish_time,
			"best_lap_time": row.best_lap_time,
			"is_dnf": row.is_dnf,
			"items_collected": row.items_collected,
			"items_used": row.items_used,
			"hits_landed": row.hits_landed,
			"hits_blocked": row.hits_blocked,
			"shortcuts_used": row.shortcuts_used,
			"recoveries": row.recoveries,
		})
	return {
		"track_id": result.track_id,
		"cc_id": result.cc_id,
		"game_mode": GameModeDefinition.LAN_MULTIPLAYER,
		"run_id": result.run_id,
		"standings": standings,
	}


func _deserialize_result_for_local(payload: Dictionary) -> RaceResult:
	var result := RaceResult.new()
	result.track_id = StringName(payload.get("track_id", &""))
	result.cc_id = StringName(payload.get("cc_id", &""))
	result.game_mode = GameModeDefinition.LAN_MULTIPLAYER
	result.run_id = StringName(payload.get("run_id", &""))
	var local_slot := lan_session.get_local_slot_id()
	for value in payload.get("standings", []):
		if not value is Dictionary:
			continue
		var row := RacerRaceResult.new()
		row.racer_id = StringName(value.get("racer_id", &""))
		row.racer_name = str(value.get("racer_name", ""))
		row.participant_slot = int(value.get("participant_slot", -1))
		row.is_player = row.participant_slot == local_slot
		row.local_player_index = 0 if row.is_player else -1
		row.start_position = int(value.get("start_position", 0))
		row.finish_position = int(value.get("finish_position", 0))
		row.laps_completed = int(value.get("laps_completed", 0))
		for lap_time in value.get("lap_times", []):
			row.lap_times.append(float(lap_time))
		row.finish_time = float(value.get("finish_time", -1.0))
		row.best_lap_time = float(value.get("best_lap_time", -1.0))
		row.is_dnf = bool(value.get("is_dnf", false))
		row.items_collected = int(value.get("items_collected", 0))
		row.items_used = int(value.get("items_used", 0))
		row.hits_landed = int(value.get("hits_landed", 0))
		row.hits_blocked = int(value.get("hits_blocked", 0))
		row.shortcuts_used = int(value.get("shortcuts_used", 0))
		row.recoveries = int(value.get("recoveries", 0))
		result.standings.append(row)
		if row.is_player:
			result.player_result = row
			result.player_results.append(row)
	result.finalize_records()
	return result
