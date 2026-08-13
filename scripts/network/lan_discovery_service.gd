class_name LanDiscoveryService
extends Node

signal rooms_changed(rooms: Array)
signal discovery_error(message: String)

var _socket: PacketPeerUDP
var _advertisement: Dictionary = {}
var _rooms: Dictionary = {}
var _announce_elapsed := 0.0
var _browsing := false
var _advertising := false


func start_advertising(advertisement: Dictionary) -> Error:
	stop()
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	var error := _socket.bind(0)
	if error != OK:
		discovery_error.emit("No se pudo abrir el anuncio LAN: %s" % error_string(error))
		return error
	_socket.set_dest_address("255.255.255.255", LanProtocol.DISCOVERY_PORT)
	_advertisement = advertisement.duplicate(true)
	_advertising = true
	_announce_elapsed = LanProtocol.ANNOUNCE_INTERVAL
	set_process(true)
	return OK


func start_browsing() -> Error:
	stop()
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	var error := _socket.bind(LanProtocol.DISCOVERY_PORT, "*")
	if error != OK:
		discovery_error.emit("No se pudo escuchar el descubrimiento LAN: %s" % error_string(error))
		return error
	_browsing = true
	set_process(true)
	return OK


func stop() -> void:
	set_process(false)
	_browsing = false
	_advertising = false
	_advertisement.clear()
	_rooms.clear()
	if _socket != null:
		_socket.close()
	_socket = null


func get_rooms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for room in _rooms.values():
		result.append((room as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")) < str(b.get("name", "")))
	return result


func update_advertisement(values: Dictionary) -> void:
	if not _advertising:
		return
	for key in values:
		_advertisement[key] = values[key]


func ingest_announcement(data: Dictionary, address: String, now_ms: int) -> bool:
	if int(data.get("protocol", -1)) != LanProtocol.LAN_PROTOCOL_VERSION:
		return false
	var room_id := str(data.get("room_id", ""))
	if room_id.is_empty():
		return false
	var room := data.duplicate(true)
	room["address"] = address
	room["last_seen_ms"] = now_ms
	_rooms[room_id] = room
	return true


func prune_stale(now_ms: int) -> bool:
	var changed := false
	for room_id in _rooms.keys():
		var room: Dictionary = _rooms[room_id]
		if now_ms - int(room.get("last_seen_ms", 0)) > int(LanProtocol.ROOM_TIMEOUT * 1000.0):
			_rooms.erase(room_id)
			changed = true
	return changed


func _process(delta: float) -> void:
	if _socket == null:
		return
	if _advertising:
		_announce_elapsed += delta
		if _announce_elapsed >= LanProtocol.ANNOUNCE_INTERVAL:
			_announce_elapsed = 0.0
			_socket.put_packet(LanProtocol.encode_discovery(_advertisement))
	if _browsing:
		var changed := false
		while _socket.get_available_packet_count() > 0:
			var packet := LanProtocol.decode_discovery(_socket.get_packet())
			if not packet.is_empty():
				changed = ingest_announcement(packet, _socket.get_packet_ip(), Time.get_ticks_msec()) or changed
		changed = prune_stale(Time.get_ticks_msec()) or changed
		if changed:
			rooms_changed.emit(get_rooms())


func _exit_tree() -> void:
	stop()
