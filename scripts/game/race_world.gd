class_name RaceWorld
extends Node3D

const DEFAULT_ITEM_CATALOG: ItemCatalog = preload(
	"res://items/item_catalog.tres"
)

signal retry_requested
signal menu_requested
signal race_completed(result: RaceResult)
signal settings_requested
signal controls_requested

var graphics_profile := "medium"
var vibration_enabled := true
var vibration_intensity := 1.0
var camera_motion := "reduced"
var speed_lines_enabled := true
var threat_indicators_enabled := true
var play_intro := true
var track_definition: TrackDefinition
var race_class: RaceClassDefinition = RaceClassDefinition.get_default()
var game_mode := GameModeDefinition.RACE
var ghost_enabled := true
var ghost_recording: GhostRecording
var track_fingerprint := ""
var race_manager: RaceManager
var player_kart: Kart
var human_karts: Array[Kart] = []
var local_player_karts: Array[Kart] = []
var local_huds: Array[RaceHud] = []
var local_cameras: Array[FollowCamera] = []
var item_catalog: ItemCatalog = DEFAULT_ITEM_CATALOG
var previous_best_time := -1.0
var previous_best_lap_time := -1.0
var race_seed := 2025
var racing_line: RacingLine
var session: RaceSessionConfig


func _init() -> void:
	# Main stays active to receive the unpause shortcut, so the race must opt
	# back into pausable processing instead of inheriting Main's ALWAYS mode.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(value: RaceSessionConfig) -> void:
	session = value
	track_definition = value.track
	race_class = value.race_class
	game_mode = value.game_mode
	race_seed = value.race_seed

var _track: CoastalTrack
var _hud: RaceHud
var _sound: SoundManager
var _follow_camera: FollowCamera
var _intro_camera: RaceIntroCamera
var _active_items: Node3D
var _projectiles: Node3D
var _traps: Node3D
var _effects: Node3D
var _item_executor: ItemExecutor
var _item_boxes: Array[ItemBox] = []
var _ai_drivers: Array[AiDriver] = []
var _has_begun_race := false
var _item_rng := RandomNumberGenerator.new()
var _ghost_recorder: GhostRecorder
var _ghost_playback: GhostPlayback
var _interaction_manager: KartInteractionManager
var _threat_indicators: ThreatIndicatorController
var _split_screen_layer: CanvasLayer
var _split_viewports: Array[SubViewport] = []
var _hud_by_kart: Dictionary = {}
var _camera_by_kart: Dictionary = {}
var _lan_synchronizer: LanRaceSynchronizer


func _ready() -> void:
	if session == null:
		session = RaceSessionConfig.create_default(game_mode)
		session.track = track_definition
		session.race_class = race_class
	var catalog_errors := item_catalog.validate() if item_catalog != null else [
		"RaceWorld requires an item catalog."
	]
	if not catalog_errors.is_empty():
		push_error("Invalid RaceWorld item catalog: %s" % "; ".join(catalog_errors))
	_item_rng.randomize()
	_build_track()
	_build_environment()
	if _items_enabled():
		_build_active_item_container()
	_build_race()


func _build_environment() -> void:
	# Split-screen applies a temporary render budget without changing the saved
	# graphics profile. Two 3D views are substantially more expensive than one.
	var effective_profile := "low" if game_mode == GameModeDefinition.LOCAL_MULTIPLAYER else graphics_profile
	var quality := PresentationQuality.get_budget(effective_profile)
	match int(quality.msaa):
		4: get_viewport().msaa_3d = Viewport.MSAA_4X
		2: get_viewport().msaa_3d = Viewport.MSAA_2X
		_: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	_sound = SoundManager.new()
	add_child(_sound)
	_sound.play_track_music(session.track.id, session.track.music)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	var theme := _get_track_theme()
	environment.background_color = (
		theme.sky_color if theme != null else Color("#58bfd0")
	)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = (
		theme.ambient_color if theme != null else Color("#d9f4df")
	)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = int(quality.glow) > 0
	environment.glow_intensity = [0.0, 0.55, 0.85, 1.15][clampi(int(quality.glow), 0, 3)]
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("#fff1c4")
	sun.light_energy = 1.25
	sun.shadow_enabled = bool(quality.shadows)
	sun.directional_shadow_max_distance = float(quality.shadow_distance)
	add_child(sun)


func _build_track() -> void:
	if track_definition != null and track_definition.scene != null:
		_track = track_definition.scene.instantiate() as CoastalTrack
	if _track == null:
		_track = CoastalTrack.new()
	add_child(_track)


func _build_active_item_container() -> void:
	_active_items = Node3D.new()
	_active_items.name = "ActiveItems"
	add_child(_active_items)

	_projectiles = Node3D.new()
	_projectiles.name = "Projectiles"
	_active_items.add_child(_projectiles)

	_traps = Node3D.new()
	_traps.name = "Traps"
	_active_items.add_child(_traps)

	_effects = Node3D.new()
	_effects.name = "Effects"
	_active_items.add_child(_effects)


func _build_race() -> void:
	if race_class == null:
		race_class = RaceClassDefinition.get_default()
	race_manager = RaceManager.new()
	race_manager.game_mode = game_mode
	add_child(race_manager)
	if track_definition != null:
		race_manager.total_laps = track_definition.laps
		race_manager.track_id = track_definition.id
	race_manager.cc_id = race_class.id
	race_manager.previous_best_time = previous_best_time
	race_manager.previous_best_lap_time = previous_best_lap_time
	race_manager.configure(_track.route_points)
	track_fingerprint = TrackFingerprint.calculate(_track, track_definition)
	racing_line = RacingLineBuilder.build(
		_track.route_points,
		_track.get_navigation_shortcut_definitions(),
		track_fingerprint
	)
	if not racing_line.is_valid():
		push_warning("No se pudo generar la trazada; los rivales usarán navegación segura de respaldo.")
	_track.shortcut_completed.connect(race_manager.complete_shortcut)
	race_manager.shortcut_accepted.connect(_handle_shortcut_accepted)

	if _items_enabled():
		_item_executor = ItemExecutor.new()
		_item_executor.name = "ItemExecutor"
		add_child(_item_executor)
		_item_executor.setup(race_manager, _projectiles, _traps, _effects)
		_item_executor.item_activated.connect(_handle_item_activated)
		_item_executor.kart_hit.connect(_handle_item_hit)
		_item_executor.item_entity_spawned.connect(_handle_item_entity_spawned)
		_item_executor.item_entity_destroyed.connect(_handle_item_entity_destroyed)
		_item_executor.projectile_bounced.connect(_sound.play_projectile_bounce)

	var configured_racers: Array[RacerDefinition] = []
	if session != null:
		session.ensure_participants()
		configured_racers.assign(session.racers)
	if configured_racers.is_empty():
		push_error("RaceWorld.setup(session) requires configured racers.")
		return
	var configured_participants: Array[RaceParticipantConfig] = []
	configured_participants.assign(session.participants)
	var kart_count := mini(configured_participants.size(), session.grid_size) if GameModeDefinition.has_rivals(game_mode) else 1
	var local_count := 0
	for participant in configured_participants.slice(0, kart_count):
		if participant != null and participant.is_local():
			local_count += 1
	if local_count > 1:
		_prepare_split_screen(local_count)
	var next_local_index := 0
	for slot in kart_count:
		var kart := Kart.new()
		var participant := configured_participants[slot]
		var racer := participant.racer
		kart.racer_id = racer.id
		kart.racer_name = racer.display_name
		kart.body_color = racer.body_color
		kart.participant_slot = participant.slot_id
		kart.network_peer_id = participant.peer_id
		kart.is_player = participant.is_human()
		if participant.is_local():
			kart.local_player_index = next_local_index
			next_local_index += 1
		kart.input_source = RacerInputSource.for_participant(participant)
		kart.visual_variant = participant.vehicle if participant.vehicle != null else racer.default_kart_visual
		var effective_stats := racer.kart_stats.copy()
		if kart.visual_variant != null:
			effective_stats.max_speed *= kart.visual_variant.speed
			effective_stats.acceleration *= kart.visual_variant.acceleration
			effective_stats.steering_speed *= kart.visual_variant.handling
			effective_stats.grip *= kart.visual_variant.handling
			effective_stats.weight = kart.visual_variant.weight
			effective_stats.mini_turbo_duration_multiplier = kart.visual_variant.mini_turbo_duration_multiplier
		kart.configure_for_race(effective_stats, race_class, session.driving_tuning)
		kart.item_catalog = item_catalog if _items_enabled() else null
		kart.item_rng = _item_rng
		add_child(kart)
		var sparks := DriftSparkController.new()
		kart.add_child(sparks)
		sparks.setup(kart, graphics_profile)
		var kart_audio := KartAudioController.new()
		kart.add_child(kart_audio)
		kart_audio.setup(kart, &"player" if kart.is_player else &"rival")
		var visual_feedback := KartVisualFeedback.new()
		kart.add_child(visual_feedback)
		visual_feedback.setup(kart, graphics_profile, speed_lines_enabled)
		var grid_slot := participant.slot_id if GameModeDefinition.has_rivals(game_mode) else 0
		kart.global_transform = _track.get_spawn_transform(grid_slot)
		kart.set_respawn_transform(kart.global_transform)
		race_manager.register_kart(
			kart,
			participant.is_local() and kart.local_player_index == 0,
			grid_slot + 1,
			kart.local_player_index,
			participant.is_human()
		)
		if _items_enabled():
			kart.item_use_requested.connect(_handle_item_use_requested.bind(kart))
		kart.hit_blocked.connect(_handle_shield_blocked.bind(kart))
		kart.recovered.connect(race_manager.record_recovery.bind(kart))
		if participant.is_human():
			human_karts.append(kart)
		if participant.is_local():
			local_player_karts.append(kart)
			if player_kart == null:
				player_kart = kart
			var camera := _add_camera(kart, kart.local_player_index)
			visual_feedback.attach_to_camera(camera.get_camera())
			kart.hit_received.connect(_handle_local_player_hit.bind(kart))
		elif participant.control_type == RaceParticipantConfig.ControlType.AI:
			var ai := AiDriver.new()
			kart.add_child(ai)
			ai.setup(kart, race_manager, racing_line, racer, race_seed, session.difficulty)
			var launch_rng := RandomNumberGenerator.new()
			launch_rng.seed = ("%d|%s|launch" % [race_seed, racer.id]).hash()
			var precision := racer.ai_profile.precision
			var reaction := racer.ai_profile.reaction_time
			var launch_time := -0.32 - reaction * 0.35 + launch_rng.randf_range(-0.28, 0.22) * (1.15 - precision * 0.55)
			kart.register_launch_crossing(launch_time)
			ai.set_physics_process(false)
			_ai_drivers.append(ai)

	if GameModeDefinition.has_rivals(game_mode):
		_interaction_manager = KartInteractionManager.new()
		_interaction_manager.setup(race_manager, session.driving_tuning)
		add_child(_interaction_manager)

	if _items_enabled():
		for item_position in _track.item_spawn_points:
			var item_box := ItemBox.new()
			item_box.position = item_position
			item_box.collected.connect(_handle_item_collected)
			add_child(item_box)
			item_box.set_collection_enabled(false)
			_item_boxes.append(item_box)
	else:
		_setup_ghosts()

	_build_local_huds(kart_count)
	_hud = local_huds.front() if not local_huds.is_empty() else null
	race_manager.countdown_changed.connect(_sound.play_countdown)
	race_manager.lap_completed.connect(_handle_lap_completed)
	race_manager.race_completed.connect(_handle_race_completed)
	race_manager.player_finished.connect(_handle_player_finished)
	race_manager.human_finished.connect(_handle_human_finished)
	race_manager.racer_finished.connect(_handle_racer_finished)
	race_manager.race_started.connect(_handle_race_started)
	if session.lan_session != null:
		_lan_synchronizer = LanRaceSynchronizer.new()
		_lan_synchronizer.name = "LanRaceSynchronizer"
		add_child(_lan_synchronizer)
		_lan_synchronizer.setup(session.lan_session, self)
	_start_pre_race.call_deferred()


func _get_track_theme() -> TrackTheme:
	if _track is TrackLevel:
		return (_track as TrackLevel).track_theme
	return null


func _prepare_split_screen(player_count: int) -> void:
	_split_screen_layer = CanvasLayer.new()
	_split_screen_layer.name = "SplitScreen"
	_split_screen_layer.layer = 1
	add_child(_split_screen_layer)
	var rows := VBoxContainer.new()
	rows.name = "Viewports"
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.add_theme_constant_override("separation", 2)
	_split_screen_layer.add_child(rows)
	for index in player_count:
		var container := SubViewportContainer.new()
		container.name = "Player%dView" % (index + 1)
		container.stretch = true
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(container)
		var viewport := SubViewport.new()
		viewport.name = "Viewport"
		viewport.world_3d = get_viewport().world_3d
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.handle_input_locally = false
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		container.add_child(viewport)
		_split_viewports.append(viewport)


func _add_camera(kart: Kart, local_index: int = 0) -> FollowCamera:
	var camera := FollowCamera.new()
	camera.name = "CameraRigP%d" % (local_index + 1)
	if local_index >= 0 and local_index < _split_viewports.size():
		_split_viewports[local_index].add_child(camera)
	else:
		add_child(camera)
	camera.setup(kart)
	camera.motion_mode = camera_motion
	local_cameras.append(camera)
	_camera_by_kart[kart] = camera
	if _follow_camera == null:
		_follow_camera = camera
	return camera


func _build_local_huds(kart_count: int) -> void:
	for local_index in local_player_karts.size():
		var kart := local_player_karts[local_index]
		var hud := RaceHud.new()
		hud.name = "RaceHudP%d" % (local_index + 1)
		hud.vibration_enabled = vibration_enabled
		hud.vibration_intensity = vibration_intensity
		hud.mobile_controls_enabled = local_player_karts.size() == 1 and (
			OS.has_feature("android")
			or OS.has_feature("ios")
			or DisplayServer.is_touchscreen_available()
			or "--mobile-controls" in OS.get_cmdline_user_args()
		)
		if local_index < _split_viewports.size():
			_split_viewports[local_index].add_child(hud)
		else:
			add_child(hud)
		hud.bind_player(kart)
		hud.configure_minimap(_track, race_manager.racers)
		hud.set_game_mode(game_mode)
		hud.set_compact_mode(local_player_karts.size() > 1, local_index == 0)
		hud.update_race_info(1, race_manager.total_laps, race_manager.get_race_position(kart), kart_count, 0.0)
		_bind_hud_actions(hud)
		local_huds.append(hud)
		_hud_by_kart[kart] = hud
		race_manager.countdown_changed.connect(hud.show_countdown)
		race_manager.provisional_standings_changed.connect(hud.update_provisional_standings)
		race_manager.results_countdown_changed.connect(hud.update_results_countdown)
	if threat_indicators_enabled and _active_items != null and player_kart != null and not local_huds.is_empty():
		_threat_indicators = ThreatIndicatorController.new()
		local_huds[0].add_child(_threat_indicators)
		_threat_indicators.setup(player_kart, _active_items, (_camera_by_kart[player_kart] as FollowCamera).get_camera())
	for kart in local_player_karts:
		race_manager.race_info_changed_for.connect(func(changed_kart: Node, lap: int, laps: int, position: int, racers: int, time: float) -> void:
			if changed_kart == kart and _hud_by_kart.has(kart):
				(_hud_by_kart[kart] as RaceHud).update_race_info(lap, laps, position, racers, time)
		)


func _bind_hud_actions(hud: RaceHud) -> void:
	hud.retry_requested.connect(_handle_retry_requested)
	hud.menu_requested.connect(_handle_menu_requested)
	hud.restart_requested.connect(_handle_retry_requested)
	hud.quit_requested.connect(_handle_menu_requested)
	hud.settings_requested.connect(func() -> void: settings_requested.emit())
	hud.controls_requested.connect(func() -> void: controls_requested.emit())
	hud.intro_skip_requested.connect(_handle_intro_skip_requested)


func _start_pre_race() -> void:
	if not play_intro or local_player_karts.size() > 1:
		_begin_race()
		return

	_intro_camera = RaceIntroCamera.new()
	_intro_camera.name = "RaceIntroCamera"
	add_child(_intro_camera)
	_intro_camera.progress_changed.connect(_hud.update_intro_progress)
	_intro_camera.skip_available.connect(
		func() -> void: _hud.set_intro_skip_enabled(true)
	)
	_intro_camera.skip_started.connect(_handle_intro_skip_started)
	_intro_camera.finished.connect(_handle_intro_finished)
	if not _intro_camera.start_intro(
		race_manager.route_points,
		_follow_camera
	):
		_cleanup_intro()
		_begin_race()
		return
	var track_name := (
		track_definition.display_name
		if track_definition != null
		else "Circuito"
	)
	_hud.show_intro(track_name, race_manager.total_laps)


func _begin_race() -> void:
	if _has_begun_race:
		return
	_has_begun_race = true
	if _follow_camera != null:
		_follow_camera.activate()
	for hud in local_huds:
		hud.hide_intro()
	race_manager.begin()


func _handle_intro_skip_requested() -> void:
	if _intro_camera == null or not is_instance_valid(_intro_camera):
		return
	_intro_camera.request_skip()


func _handle_intro_skip_started() -> void:
	_hud.set_intro_skip_enabled(false)
	_hud.update_intro_progress(RaceIntroCamera.FLIGHT_DURATION)


func _handle_intro_finished() -> void:
	_cleanup_intro()
	_begin_race()


func _cleanup_intro() -> void:
	if _intro_camera != null and is_instance_valid(_intro_camera):
		_intro_camera.queue_free()
	_intro_camera = null
	if _hud != null:
		_hud.hide_intro()
	if _follow_camera != null:
		_follow_camera.activate()


func _handle_race_started() -> void:
	for ai_driver in _ai_drivers:
		ai_driver.set_physics_process(true)
	var client_is_replica := (
		session != null
		and session.lan_session != null
		and not session.lan_session.is_host
	)
	if not client_is_replica:
		for item_box in _item_boxes:
			item_box.set_collection_enabled(true)


func _handle_item_collected(kart: Node) -> void:
	race_manager.record_item_collected(kart)
	_sound.play_pickup()
	if kart in local_player_karts and vibration_enabled:
		_vibrate_local_kart(kart as Kart, 35, 0.35)


func _handle_player_hit() -> void:
	_handle_local_player_hit(player_kart)


func _handle_local_player_hit(kart: Kart) -> void:
	if vibration_enabled and vibration_intensity > 0.0:
		_vibrate_local_kart(kart, roundi(120.0 * vibration_intensity), 0.55 * vibration_intensity)
	var camera := _camera_by_kart.get(kart) as FollowCamera
	if camera != null:
		camera.add_impact(1.0)


func _handle_item_use_requested(
	item: ItemDefinition,
	direction: Vector3,
	source_kart: Kart
) -> void:
	if _item_executor == null:
		return
	_item_executor.execute(
		item,
		source_kart,
		direction,
		not source_kart.consume_straight_launch_request()
	)


func _handle_item_activated(
	item: ItemDefinition,
	source_kart: Kart
) -> void:
	race_manager.record_item_used(source_kart)
	if _is_lan_host():
		session.lan_session.broadcast_reliable_event(&"item_activated", {
			"item_id": item.id,
			"source_slot": source_kart.participant_slot,
		})
	match item.category:
		ItemDefinition.ItemCategory.PROJECTILE:
			_sound.play_item_launch()
		ItemDefinition.ItemCategory.TRAP:
			_sound.play_item_deploy()
		_:
			_sound.play_item_activation()


func _handle_item_hit(
	item: ItemDefinition,
	source_kart: Kart,
	kart: Node3D,
	result: int
) -> void:
	race_manager.record_item_hit(source_kart, kart, result)
	if _is_lan_host():
		session.lan_session.broadcast_reliable_event(&"item_hit", {
			"item_id": item.id,
			"source_slot": source_kart.participant_slot,
			"target_slot": int(kart.get("participant_slot")),
			"result": result,
		})
	if result != Kart.HitResult.BLOCKED:
		_sound.play_item_impact()


func _handle_item_entity_spawned(
	entity_id: int,
	entity_kind: StringName,
	item: ItemDefinition,
	source_kart: Kart,
	entity: Node3D
) -> void:
	if not _is_lan_host():
		return
	var velocity := Vector3.ZERO
	if entity is CharacterBody3D:
		velocity = (entity as CharacterBody3D).velocity
	session.lan_session.broadcast_reliable_event(&"item_spawned", {
		"entity_id": entity_id,
		"entity_kind": entity_kind,
		"item_id": item.id,
		"source_slot": source_kart.participant_slot,
		"position": entity.global_position,
		"rotation": entity.global_basis.get_rotation_quaternion(),
		"velocity": velocity,
	})


func _handle_item_entity_destroyed(entity_id: int) -> void:
	if _is_lan_host():
		session.lan_session.broadcast_reliable_event(&"item_destroyed", {
			"entity_id": entity_id,
		})


func _is_lan_host() -> bool:
	return (
		session != null
		and session.lan_session != null
		and session.lan_session.is_host
		and session.lan_session.race_active
	)


func _items_enabled() -> bool:
	return (
		GameModeDefinition.has_items(game_mode)
		and (session == null or session.items_enabled)
	)


func _handle_shield_blocked(threat: Node, source_kart: Kart) -> void:
	_sound.play_shield_block()
	if source_kart in local_player_karts and vibration_enabled:
		_vibrate_local_kart(source_kart, roundi(85.0 * vibration_intensity), 0.46 * vibration_intensity)
		var camera := _camera_by_kart.get(source_kart) as FollowCamera
		if camera != null:
			camera.add_impact(0.3)
		if source_kart == player_kart and _threat_indicators != null:
			_threat_indicators.remove_threat(threat)


func _vibrate_local_kart(kart: Kart, duration_ms: int, strength: float) -> void:
	if kart != null and kart.input_source != null and kart.input_source.device_type == RaceParticipantConfig.DEVICE_GAMEPAD:
		Input.start_joy_vibration(kart.input_source.device_id, strength, strength, float(duration_ms) / 1000.0)
	elif kart == player_kart:
		Input.vibrate_handheld(duration_ms, strength)


func _handle_retry_requested() -> void:
	shutdown()
	retry_requested.emit()


func _handle_menu_requested() -> void:
	shutdown()
	menu_requested.emit()


func _clear_projectiles() -> void:
	_clear_container(_projectiles)


func _clear_active_items() -> void:
	_clear_container(_projectiles)
	_clear_container(_traps)
	_clear_container(_effects)
	if race_manager != null:
		for racer in race_manager.racers:
			if is_instance_valid(racer) and racer.has_method("clear_item_effects"):
				racer.clear_item_effects()


func _clear_container(container: Node3D) -> void:
	if container == null:
		return
	for active_item in container.get_children():
		container.remove_child(active_item)
		active_item.queue_free()


func _handle_shortcut_accepted(kart: Node) -> void:
	if kart not in local_player_karts:
		return
	_sound.play_pickup()
	if vibration_enabled:
		_vibrate_local_kart(kart as Kart, 70, 0.42)


func _handle_lap_completed(racer: Node, lap_number: int, lap_time: float) -> void:
	var hud := _hud_by_kart.get(racer) as RaceHud
	if hud != null:
		hud.show_lap_split(lap_number, lap_time, previous_best_lap_time)


func _handle_player_finished(_position: int, _time: float) -> void:
	pass # Compatibility signal; per-human handling lives in _handle_human_finished.


func _handle_human_finished(racer: Node, _position: int, _time: float) -> void:
	if race_manager.state != RaceManager.RaceState.WAITING_FOR_RIVALS:
		return
	for hud in local_huds:
		hud.show_provisional(
			race_manager.get_provisional_standings(),
			race_manager.get_results_wait_remaining()
		)
	var camera := _camera_by_kart.get(racer) as FollowCamera
	var active_racer := race_manager.get_best_active_racer() as Kart
	if camera != null and active_racer != null:
		camera.set_target(active_racer)


func _handle_racer_finished(_racer: Node, _position: int, _time: float) -> void:
	if race_manager.state == RaceManager.RaceState.WAITING_FOR_RIVALS:
		_follow_best_active_racer.call_deferred()


func _follow_best_active_racer() -> void:
	var racer := race_manager.get_best_active_racer() as Kart
	if racer != null and _follow_camera != null:
		_follow_camera.set_target(racer)


func _handle_race_completed(result: RaceResult) -> void:
	if session != null:
		result.run_id = session.run_id
		result.cup_id = session.cup_id
		result.cup_race_index = session.cup_race_index
	if _ghost_recorder != null:
		result.set_meta("ghost_recording", _ghost_recorder.finish(result))
	_clear_active_items()
	_sound.play_finish()
	if vibration_enabled and player_kart != null:
		_vibrate_local_kart(player_kart, 220, 0.6)
	race_completed.emit(result)
	if result.cup_summary != null and result.cup_summary.completed:
		_sound.play_cup_victory()
	for index in local_huds.size():
		local_huds[index].show_results(result.for_local_player(index))


func receive_network_result(result: RaceResult) -> void:
	if session == null or session.lan_session == null or session.lan_session.is_host:
		return
	_handle_race_completed(result)


func take_over_with_ai(slot_id: int) -> void:
	for kart in race_manager.racers:
		if int(kart.get("participant_slot")) != slot_id:
			continue
		if kart.get_node_or_null("DisconnectAi") != null:
			return
		var racer := session.participants[slot_id].racer
		var ai := AiDriver.new()
		ai.name = "DisconnectAi"
		kart.add_child(ai)
		ai.setup(kart, race_manager, racing_line, racer, race_seed, session.difficulty)
		ai.set_physics_process(true)
		kart.input_source = null
		return


func restore_network_control(slot_id: int) -> void:
	for kart in race_manager.racers:
		if int(kart.get("participant_slot")) != slot_id:
			continue
		var ai := kart.get_node_or_null("DisconnectAi")
		if ai != null:
			ai.queue_free()
		kart.input_source = RacerInputSource.for_participant(session.participants[slot_id])
		return


func shutdown() -> void:
	if _ghost_recorder != null:
		_ghost_recorder.cancel()
	_clear_active_items()
	if _sound != null:
		_sound.shutdown()


func _exit_tree() -> void:
	shutdown()


func _setup_ghosts() -> void:
	track_fingerprint = TrackFingerprint.calculate(_track, track_definition)
	_ghost_recorder = GhostRecorder.new()
	_ghost_recorder.name = "GhostRecorder"
	add_child(_ghost_recorder)
	_ghost_recorder.setup(race_manager, player_kart, track_definition.id, track_fingerprint, race_class.id, race_manager.total_laps)
	if ghost_enabled and ghost_recording != null:
		_ghost_playback = GhostPlayback.new()
		_ghost_playback.name = "GhostPlayback"
		add_child(_ghost_playback)
		_ghost_playback.setup(ghost_recording)


func _process(_delta: float) -> void:
	if _ghost_playback == null or race_manager == null:
		return
	_ghost_playback.update_for_time(race_manager.race_time)
	var reference_time := _ghost_playback.get_reference_time(race_manager.get_racer_progress(player_kart))
	_hud.update_ghost_delta(race_manager.race_time - reference_time if reference_time >= 0.0 else NAN)
