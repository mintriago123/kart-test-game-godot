extends SceneTree

const PROGRESSION: ProgressionCatalog = preload("res://progression/progression_catalog.tres")
const TRACKS: TrackCatalog = preload("res://levels/track_catalog.tres")
const RACERS := [&"marea", &"lima", &"coral", &"brisa"]

var _role := "client"
var _client_index := 1
var _port := 17777
var _expected_humans := 4
var _session: LanSession
var _deadline_ms := 0
var _finishing := false
var _input_slots := {}
var _received_snapshot := false
var _received_event := false
var _network_probe_sent := false
var _discovery: LanDiscoveryService
var _room_discovered := false
var _reconnect_started := false
var _reconnected := false
var _host_restored_slot := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
		elif argument.begins_with("--client-index="):
			_client_index = int(argument.trim_prefix("--client-index="))
		elif argument.begins_with("--port="):
			_port = int(argument.trim_prefix("--port="))
	call_deferred("_run")


func _run() -> void:
	var holder := Node.new()
	holder.name = "LanLoopback"
	root.add_child(holder)
	_session = LanSession.new()
	_session.name = "Session"
	holder.add_child(_session)
	_session.configure(PROGRESSION, TRACKS)
	_session.connection_state_changed.connect(_on_connection_state)
	_session.join_rejected.connect(_fail)
	_session.race_start_received.connect(_on_race_start)
	_session.host_lost.connect(_fail)
	_session.room_changed.connect(_on_room_changed)
	_session.input_received.connect(_on_input_received)
	_session.snapshot_received.connect(_on_snapshot_received)
	_session.reliable_event_received.connect(_on_reliable_event)
	_session.control_restored.connect(func(_slot_id: int, _peer_id: int) -> void:
		_host_restored_slot = true
	)
	_deadline_ms = Time.get_ticks_msec() + 15000
	var profile := _profile(0 if _role == "host" else _client_index)
	_discovery = LanDiscoveryService.new()
	holder.add_child(_discovery)
	_discovery.discovery_error.connect(_fail)
	if _role == "client" and _client_index == 1:
		_discovery.rooms_changed.connect(_on_rooms_changed)
		if _discovery.start_browsing() != OK:
			return
	var error := OK
	if _role == "host":
		error = _session.host_room(profile, {
			"track_id": &"coastal",
			"cc_id": &"150",
			"items_enabled": false,
			"port": _port,
			"room_name": "Loopback",
		}, _port)
		if error == OK:
			_session.set_local_selection(profile.racer_id, profile.vehicle_id, true)
			_discovery.start_advertising({
				"room_id": _session.local_token,
				"name": "Loopback",
				"port": _port,
				"humans": 1,
				"max_humans": LanProtocol.MAX_HUMANS,
				"catalog_fingerprint": _session.catalog_fingerprint,
				"track_id": &"coastal",
			})
	else:
		error = _session.join_room("127.0.0.1", profile, _port)
	if error != OK:
		_fail("No se pudo iniciar %s: %s" % [_role, error_string(error)])


func _process(_delta: float) -> bool:
	if not _finishing and _deadline_ms > 0 and Time.get_ticks_msec() > _deadline_ms:
		_fail("Timeout esperando la carrera LAN (%s)." % _role)
	return false


func _profile(index: int) -> Dictionary:
	return {
		"name": "Peer %d" % index,
		"racer_id": RACERS[clampi(index, 0, RACERS.size() - 1)],
		"vehicle_id": &"sedan",
	}


func _on_connection_state(state: StringName, _message: String) -> void:
	if _role != "host" and state == &"joined":
		var profile := _profile(_client_index)
		if not _session.set_local_selection(profile.racer_id, profile.vehicle_id, true):
			_fail("El cliente no pudo marcarse listo.")


func _on_room_changed(values: Array, _settings: Dictionary) -> void:
	if _role != "host" or _session.race_active or values.size() != _expected_humans:
		return
	for slot in values:
		if not bool(slot.get("connected", false)) or not bool(slot.get("ready", false)):
			return
	_session.host_start_race.call_deferred()


func _on_race_start(payload: Dictionary) -> void:
	var participants := _session.build_participants()
	var local_count := 0
	for participant in participants:
		local_count += int(participant.is_local())
	if participants.size() != LanProtocol.GRID_SIZE or local_count != 1:
		_fail("La parrilla sincronizada no contiene ocho corredores y un jugador local.")
		return
	if bool((payload.get("settings", {}) as Dictionary).get("items_enabled", true)):
		_fail("La preferencia sin objetos del anfitrión no llegó a todos los peers.")
		return
	if _role == "client" and _client_index == 3 and _reconnect_started:
		_reconnected = true
		_begin_client_success.call_deferred()
		return
	_session.set_local_input({
		"throttle": 0.25 + float(_client_index) * 0.1,
		"brake": 0.0,
		"steer": 0.1,
		"drift": false,
		"use_item": false,
	})


func _on_input_received(slot_id: int, _sequence: int, frame: Dictionary) -> void:
	if _role != "host" or _network_probe_sent:
		return
	if float(frame.get("throttle", 0.0)) > 0.0:
		_input_slots[slot_id] = true
	if _input_slots.size() != _expected_humans:
		return
	_network_probe_sent = true
	if not _session.broadcast_snapshot({
		"racers": [{"slot_id": 0, "position": Vector3(4, 0, 2)}],
	}):
		_fail("El host no pudo enviar el snapshot de prueba.")
		return
	_session.broadcast_reliable_event(&"loopback_probe", {"humans": _expected_humans})
	create_timer(5.0).timeout.connect(_finish_host_probe)


func _on_snapshot_received(snapshot: Dictionary) -> void:
	if _role == "host":
		return
	_received_snapshot = not snapshot.get("racers", []).is_empty()
	_try_client_success()


func _on_reliable_event(kind: StringName, payload: Dictionary) -> void:
	if _role == "host" or kind != &"loopback_probe":
		return
	_received_event = int(payload.get("humans", 0)) == _expected_humans
	_try_client_success()


func _try_client_success() -> void:
	var discovery_ready := _client_index != 1 or _room_discovered
	if _received_snapshot and _received_event and discovery_ready:
		if _client_index == 3 and not _reconnect_started:
			_begin_reconnect.call_deferred()
		else:
			_begin_client_success.call_deferred()


func _begin_reconnect() -> void:
	if _reconnect_started or _finishing:
		return
	_reconnect_started = true
	var token := _session.local_token
	_session.close()
	await create_timer(0.25).timeout
	var error := _session.join_room("127.0.0.1", _profile(_client_index), _port, token)
	if error != OK:
		_fail("El cliente no pudo iniciar su reconexión: %s" % error_string(error))


func _finish_host_probe() -> void:
	if not _host_restored_slot:
		_fail("El host no restauró el control del slot reservado tras la reconexión.")
		return
	_succeed()


func _on_rooms_changed(rooms: Array) -> void:
	for room in rooms:
		if str(room.get("name", "")) == "Loopback" and int(room.get("port", 0)) == _port:
			_room_discovered = true
			_try_client_success()
			return


func _succeed() -> void:
	if _finishing:
		return
	_finishing = true
	_report_pass()
	_close_success()


func _begin_client_success() -> void:
	if _finishing:
		return
	_finishing = true
	_report_pass()
	# Keep the ENet peers alive until the host closes its healthy connections.
	# The host-lost callback is ignored once this probe has already passed.
	create_timer(6.0).timeout.connect(_close_success)


func _report_pass() -> void:
	print("LAN_LOOPBACK_PASS role=%s humans=%d grid=%d snapshot=%s reliable=%s discovery=%s reconnect=%s" % [
		_role,
		_session.get_slots().size(),
		LanProtocol.GRID_SIZE,
		str(_network_probe_sent if _role == "host" else _received_snapshot),
		str(_network_probe_sent if _role == "host" else _received_event),
		str(true if _role == "host" or _client_index != 1 else _room_discovered),
		str(_host_restored_slot if _role == "host" else (_reconnected if _client_index == 3 else true)),
	])


func _close_success() -> void:
	if _discovery != null:
		_discovery.stop()
	_session.close()
	quit(0)


func _fail(message: String) -> void:
	if _finishing:
		return
	_finishing = true
	push_error(message)
	if _session != null:
		_session.close()
	if _discovery != null:
		_discovery.stop()
	quit(1)
