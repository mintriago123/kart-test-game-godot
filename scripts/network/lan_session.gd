class_name LanSession
extends Node

static var reconnect_token_cache := ""

signal connection_state_changed(state: StringName, message: String)
signal room_changed(slots: Array, settings: Dictionary)
signal join_rejected(message: String)
signal race_start_received(payload: Dictionary)
signal input_received(slot_id: int, sequence: int, frame: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal reliable_event_received(kind: StringName, payload: Dictionary)
signal ai_takeover_requested(slot_id: int)
signal control_restored(slot_id: int, peer_id: int)
signal host_lost(message: String)

var progression: ProgressionCatalog
var tracks: TrackCatalog
var catalog_fingerprint := ""
var peer: ENetMultiplayerPeer
var is_host := false
var race_active := false
var room_settings: Dictionary = {}
var slots: Dictionary = {}
var local_token := ""
var local_profile: Dictionary = {}
var local_input_frame := RacerInputSource.empty_frame()
var active_race_payload: Dictionary = {}

var _input_sequence := 0
var _input_elapsed := 0.0
var _last_snapshot_ms := -1


func configure(value_progression: ProgressionCatalog, value_tracks: TrackCatalog) -> void:
	progression = value_progression
	tracks = value_tracks
	catalog_fingerprint = LanProtocol.calculate_catalog_fingerprint(progression, tracks)


func host_room(profile: Dictionary, settings: Dictionary, port := LanProtocol.RACE_PORT) -> Error:
	close()
	if not _is_valid_local_profile(profile):
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, LanProtocol.MAX_HUMANS - 1, 3)
	if error != OK:
		peer = null
		connection_state_changed.emit(&"error", "No se pudo crear la sala LAN: %s" % error_string(error))
		return error
	is_host = true
	local_profile = profile.duplicate(true)
	local_token = _new_token()
	room_settings = _sanitize_room_settings(settings)
	slots[0] = _make_slot(0, 1, local_token, local_profile, true)
	_attach_peer()
	connection_state_changed.emit(&"hosting", "Sala LAN abierta en UDP %d." % port)
	_emit_room_state()
	return OK


func join_room(address: String, profile: Dictionary, port := LanProtocol.RACE_PORT, reconnect_token := "") -> Error:
	close()
	if address.strip_edges().is_empty() or not _is_valid_local_profile(profile):
		return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port, 3)
	if error != OK:
		peer = null
		connection_state_changed.emit(&"error", "No se pudo conectar a %s:%d: %s" % [address, port, error_string(error)])
		return error
	is_host = false
	local_profile = profile.duplicate(true)
	local_token = reconnect_token if not reconnect_token.is_empty() else reconnect_token_cache
	_attach_peer()
	connection_state_changed.emit(&"connecting", "Conectando con %s:%d…" % [address, port])
	return OK


func close() -> void:
	var active_peer := peer
	peer = null
	is_host = false
	race_active = false
	if active_peer != null:
		active_peer.close()
	if is_inside_tree():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	slots.clear()
	_input_sequence = 0
	_input_elapsed = 0.0
	_last_snapshot_ms = -1
	active_race_payload.clear()


func set_local_selection(racer_id: StringName, vehicle_id: StringName, ready: bool) -> bool:
	var update := {"racer_id": racer_id, "vehicle_id": vehicle_id, "ready": ready}
	if is_host:
		return _apply_slot_update(1, update)
	if peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return false
	_request_slot_update.rpc_id(1, update)
	return true


func host_update_room_settings(settings: Dictionary) -> bool:
	if not is_host or race_active:
		return false
	room_settings = _sanitize_room_settings(settings)
	_emit_room_state()
	return true


func can_host_start() -> bool:
	if not is_host or race_active or slots.is_empty():
		return false
	for slot in slots.values():
		if bool(slot.get("connected", false)) and not bool(slot.get("ready", false)):
			return false
	return true


func host_start_race() -> bool:
	if not can_host_start():
		return false
	race_active = true
	var payload := {
		"settings": room_settings.duplicate(true),
		"slots": get_slots(),
		"race_seed": randi(),
		"server_time_ms": Time.get_ticks_msec(),
	}
	active_race_payload = payload.duplicate(true)
	_receive_race_start.rpc(payload)
	_receive_race_start(payload)
	return true


func set_local_input(frame: Dictionary) -> void:
	local_input_frame = LanProtocol.sanitize_input_frame(frame)


func broadcast_snapshot(snapshot: Dictionary) -> bool:
	if not is_host or not race_active:
		return false
	var now := Time.get_ticks_msec()
	if _last_snapshot_ms >= 0 and now - _last_snapshot_ms < int(1000.0 / LanProtocol.SNAPSHOT_RATE_HZ):
		return false
	_last_snapshot_ms = now
	var value := snapshot.duplicate(true)
	value["server_time_ms"] = now
	_receive_snapshot.rpc(value)
	return true


func broadcast_reliable_event(kind: StringName, payload: Dictionary) -> bool:
	if not is_host:
		return false
	_receive_reliable_event(kind, payload)
	_receive_reliable_event.rpc(kind, payload)
	return true


func get_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in slots.values():
		result.append((value as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.slot_id) < int(b.slot_id))
	return result


func get_local_slot_id() -> int:
	var unique_id := multiplayer.get_unique_id() if is_inside_tree() else (1 if is_host else 0)
	for slot in slots.values():
		if int(slot.get("peer_id", 0)) == unique_id:
			return int(slot.get("slot_id", -1))
	return -1


func build_participants() -> Array[RaceParticipantConfig]:
	var participants: Array[RaceParticipantConfig] = []
	var selected := {}
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null else 1
	for slot in get_slots():
		var racer := progression.racers.get_racer(StringName(slot.racer_id))
		var vehicle := progression.unlocks.get_variant(StringName(slot.vehicle_id))
		var slot_peer := int(slot.peer_id)
		var control := RaceParticipantConfig.ControlType.LOCAL if slot_peer == local_peer_id else RaceParticipantConfig.ControlType.REMOTE
		var participant := RaceParticipantConfig.create(
			int(slot.slot_id), racer, vehicle, control,
			RaceParticipantConfig.DEVICE_KEYBOARD if control == RaceParticipantConfig.ControlType.LOCAL else RaceParticipantConfig.DEVICE_NETWORK,
			-1, slot_peer
		)
		participant.session_token = str(slot.token)
		participants.append(participant)
		selected[racer.id] = true
	for racer in progression.racers.racers:
		if participants.size() >= LanProtocol.GRID_SIZE:
			break
		if selected.has(racer.id):
			continue
		participants.append(RaceParticipantConfig.create(
			participants.size(), racer, racer.default_kart_visual,
			RaceParticipantConfig.ControlType.AI if is_host else RaceParticipantConfig.ControlType.REMOTE,
			RaceParticipantConfig.DEVICE_NONE if is_host else RaceParticipantConfig.DEVICE_NETWORK,
			-1, 1
		))
	return participants


func _physics_process(delta: float) -> void:
	if peer == null or not race_active:
		return
	_input_elapsed += delta
	var interval := 1.0 / LanProtocol.INPUT_RATE_HZ
	while _input_elapsed >= interval:
		_input_elapsed -= interval
		_input_sequence += 1
		var slot_id := get_local_slot_id()
		if slot_id < 0:
			continue
		if is_host:
			input_received.emit(slot_id, _input_sequence, local_input_frame)
		else:
			_submit_input.rpc_id(1, local_token, _input_sequence, local_input_frame)


func _attach_peer() -> void:
	if not is_inside_tree():
		connection_state_changed.emit(&"error", "La sesión LAN debe estar dentro del árbol de escenas.")
		return
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.multiplayer_peer = peer


func _on_connected_to_server() -> void:
	connection_state_changed.emit(&"connected", "Conectado; validando versión y catálogo…")
	_request_join.rpc_id(1, {
		"protocol": LanProtocol.LAN_PROTOCOL_VERSION,
		"catalog_fingerprint": catalog_fingerprint,
		"racer_id": local_profile.get("racer_id", &""),
		"vehicle_id": local_profile.get("vehicle_id", &""),
		"track_id": &"",
		"name": str(local_profile.get("name", "Invitado")),
		"token": local_token,
	})


func _on_peer_connected(_peer_id: int) -> void:
	pass


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host:
		return
	for slot_id in slots:
		var slot: Dictionary = slots[slot_id]
		if int(slot.peer_id) != peer_id:
			continue
		slot.connected = false
		slot.ready = false
		slot.peer_id = 0
		slots[slot_id] = slot
		ai_takeover_requested.emit(int(slot_id))
		if race_active:
			room_changed.emit(get_slots(), room_settings)
		else:
			_emit_room_state()
		return


func _on_connection_failed() -> void:
	connection_state_changed.emit(&"error", "No se pudo conectar con el anfitrión LAN.")


func _on_server_disconnected() -> void:
	var message := "El anfitrión abandonó la partida. No hay migración de host."
	host_lost.emit(message)
	connection_state_changed.emit(&"host_lost", message)
	close()


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_join(payload: Dictionary) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	var validation_payload := payload.duplicate(true)
	validation_payload["track_id"] = room_settings.get("track_id", &"")
	var error := LanProtocol.validate_handshake(validation_payload, catalog_fingerprint, progression, tracks)
	var token := str(payload.get("token", ""))
	var reserved_slot := _find_slot_by_token(token) if not token.is_empty() else -1
	if error.is_empty() and race_active and reserved_slot < 0:
		error = (
			"La carrera ya comenzó; hace falta el token del slot reservado."
			if token.is_empty()
			else "El token de reconexión no pertenece a esta carrera."
		)
	if not error.is_empty():
		_join_denied.rpc_id(sender, error)
		return
	if reserved_slot >= 0:
		var reconnecting: Dictionary = slots[reserved_slot]
		reconnecting.peer_id = sender
		reconnecting.connected = true
		slots[reserved_slot] = reconnecting
		var resume_payload := active_race_payload.duplicate(true)
		resume_payload["slots"] = get_slots()
		resume_payload["server_time_ms"] = Time.get_ticks_msec()
		_join_accepted.rpc_id(
			sender, reserved_slot, token, get_slots(), room_settings,
			race_active, resume_payload
		)
		control_restored.emit(reserved_slot, sender)
		_emit_room_state()
		return
	if _connected_human_count() >= LanProtocol.MAX_HUMANS:
		_join_denied.rpc_id(sender, "La sala está llena (máximo cuatro humanos).")
		return
	if _is_racer_taken(StringName(payload.racer_id), -1):
		_join_denied.rpc_id(sender, "Ese piloto ya está ocupado en la sala.")
		return
	var slot_id := _first_free_slot()
	token = _new_token()
	slots[slot_id] = _make_slot(slot_id, sender, token, payload, true)
	_join_accepted.rpc_id(sender, slot_id, token, get_slots(), room_settings, false, {})
	_emit_room_state()


@rpc("authority", "call_remote", "reliable", 0)
func _join_accepted(
	slot_id: int,
	token: String,
	server_slots: Array,
	settings: Dictionary,
	started: bool,
	race_payload: Dictionary
) -> void:
	local_token = token
	reconnect_token_cache = token
	race_active = started
	_replace_slots(server_slots)
	room_settings = settings.duplicate(true)
	connection_state_changed.emit(&"joined", "Entraste en el slot %d." % (slot_id + 1))
	room_changed.emit(get_slots(), room_settings)
	if started and not race_payload.is_empty():
		_receive_race_start(race_payload)


@rpc("authority", "call_remote", "reliable", 0)
func _join_denied(message: String) -> void:
	join_rejected.emit(message)
	connection_state_changed.emit(&"rejected", message)
	if peer != null:
		peer.close()


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_slot_update(update: Dictionary) -> void:
	if is_host:
		_apply_slot_update(multiplayer.get_remote_sender_id(), update)


func _apply_slot_update(peer_id: int, update: Dictionary) -> bool:
	var slot_id := _find_slot_by_peer(peer_id)
	if slot_id < 0:
		return false
	var racer_id := StringName(update.get("racer_id", &""))
	var vehicle_id := StringName(update.get("vehicle_id", &""))
	if progression.racers.get_racer(racer_id) == null or progression.unlocks.get_variant(vehicle_id) == null:
		return false
	if _is_racer_taken(racer_id, slot_id):
		return false
	var slot: Dictionary = slots[slot_id]
	slot.racer_id = racer_id
	slot.vehicle_id = vehicle_id
	slot.ready = bool(update.get("ready", false))
	slots[slot_id] = slot
	_emit_room_state()
	return true


@rpc("authority", "call_remote", "reliable", 0)
func _receive_room_state(server_slots: Array, settings: Dictionary) -> void:
	_replace_slots(server_slots)
	room_settings = settings.duplicate(true)
	room_changed.emit(get_slots(), room_settings)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_race_start(payload: Dictionary) -> void:
	race_active = true
	if payload.has("slots"):
		_replace_slots(payload.slots)
	race_start_received.emit(payload)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(token: String, sequence: int, frame: Dictionary) -> void:
	if not is_host or not race_active:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var slot_id := _find_slot_by_peer(peer_id)
	if slot_id < 0 or str((slots[slot_id] as Dictionary).token) != token:
		return
	var slot: Dictionary = slots[slot_id]
	if sequence <= int(slot.get("last_input_sequence", -1)):
		return
	slot.last_input_sequence = sequence
	slots[slot_id] = slot
	input_received.emit(slot_id, sequence, LanProtocol.sanitize_input_frame(frame))


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _receive_snapshot(snapshot: Dictionary) -> void:
	snapshot_received.emit(snapshot)


@rpc("authority", "call_remote", "reliable", 0)
func _receive_reliable_event(kind: StringName, payload: Dictionary) -> void:
	reliable_event_received.emit(kind, payload)


func _emit_room_state() -> void:
	var values := get_slots()
	room_changed.emit(values, room_settings)
	if is_host:
		_receive_room_state.rpc(values, room_settings)


func _replace_slots(values: Array) -> void:
	slots.clear()
	for value in values:
		if value is Dictionary:
			slots[int(value.get("slot_id", slots.size()))] = (value as Dictionary).duplicate(true)


func _make_slot(slot_id: int, peer_id: int, token: String, profile: Dictionary, connected: bool) -> Dictionary:
	return {
		"slot_id": slot_id,
		"peer_id": peer_id,
		"token": token,
		"name": str(profile.get("name", "Piloto %d" % (slot_id + 1))).left(24),
		"racer_id": StringName(profile.get("racer_id", &"marea")),
		"vehicle_id": StringName(profile.get("vehicle_id", &"sedan")),
		"ready": false,
		"connected": connected,
		"last_input_sequence": -1,
	}


func _sanitize_room_settings(settings: Dictionary) -> Dictionary:
	var track_id := StringName(settings.get("track_id", tracks.get_default_track().id if tracks != null and tracks.get_default_track() != null else &""))
	if tracks == null or tracks.get_track(track_id) == null:
		track_id = tracks.get_default_track().id if tracks != null and tracks.get_default_track() != null else &""
	return {
		"track_id": track_id,
		"cc_id": RaceClassDefinition.get_by_id(StringName(settings.get("cc_id", &"150"))).id,
		"items_enabled": bool(settings.get("items_enabled", true)),
		"port": clampi(int(settings.get("port", LanProtocol.RACE_PORT)), 1, 65535),
		"room_name": str(settings.get("room_name", "Sala MichiKart")).left(32),
	}


func _is_valid_local_profile(profile: Dictionary) -> bool:
	if progression == null or tracks == null:
		return false
	return (
		progression.racers.get_racer(StringName(profile.get("racer_id", &""))) != null
		and progression.unlocks.get_variant(StringName(profile.get("vehicle_id", &""))) != null
	)


func _find_slot_by_peer(peer_id: int) -> int:
	for slot_id in slots:
		if int((slots[slot_id] as Dictionary).peer_id) == peer_id:
			return int(slot_id)
	return -1


func _find_slot_by_token(token: String) -> int:
	for slot_id in slots:
		if str((slots[slot_id] as Dictionary).token) == token:
			return int(slot_id)
	return -1


func _is_racer_taken(racer_id: StringName, except_slot: int) -> bool:
	for slot_id in slots:
		if int(slot_id) != except_slot and StringName((slots[slot_id] as Dictionary).racer_id) == racer_id:
			return true
	return false


func _connected_human_count() -> int:
	var count := 0
	for slot in slots.values():
		count += int(bool(slot.get("connected", false)))
	return count


func _first_free_slot() -> int:
	for slot_id in LanProtocol.MAX_HUMANS:
		if not slots.has(slot_id):
			return slot_id
	return slots.size()


func _new_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _exit_tree() -> void:
	close()
