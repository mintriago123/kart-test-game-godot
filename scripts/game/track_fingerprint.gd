class_name TrackFingerprint
extends RefCounted

const FORMAT_VERSION := 2
const QUANTIZATION := 1000.0


static func calculate(track: CoastalTrack, definition: TrackDefinition) -> String:
	if track == null or definition == null or track.route_points.size() < 3:
		return ""
	var payload := PackedByteArray()
	_append_text(payload, "track-fingerprint:%d\n" % FORMAT_VERSION)
	_append_text(payload, "%s\n%d\n" % [definition.id, definition.laps])
	for point in track.route_points:
		_append_vector(payload, point)
	var spawn := track.get_spawn_transform(3)
	_append_vector(payload, spawn.origin)
	_append_basis(payload, spawn.basis)
	_append_text(payload, "road:%d\n" % roundi(CoastalTrack.ROAD_WIDTH * QUANTIZATION))
	if track is TrackLevel:
		var authored := track as TrackLevel
		_append_text(payload, "authored:%d:%d:%d\n" % [
			authored.start_point_index,
			authored.route_subdivisions,
			roundi(authored.shortcut_barrier_overlap * QUANTIZATION),
		])
	for shortcut in track.shortcut_definitions:
		_append_text(payload, "shortcut:%d:%d\n" % [
			int(shortcut.get("entry_index", -1)), int(shortcut.get("exit_index", -1))
		])
		for point in shortcut.get("points", []):
			_append_vector(payload, point)
	for child in track.find_children("*", "TrackSurfaceZone", true, false):
		var zone := child as TrackSurfaceZone
		_append_text(payload, "surface:%s:%s:%d:%d:%d:%d:%d:%d:%d\n" % [
			zone.id, zone.surface.id if zone.surface != null else &"", zone.path_kind,
			zone.shortcut_id, roundi(zone.start_progress * QUANTIZATION),
			roundi(zone.end_progress * QUANTIZATION), roundi(zone.lateral_offset * QUANTIZATION),
			roundi(zone.width * QUANTIZATION), roundi(zone.priority * QUANTIZATION),
		])
		_append_vector(payload, zone.position)
		_append_basis(payload, zone.basis)
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(payload) != OK:
		return ""
	return hashing.finish().hex_encode()


static func _append_vector(payload: PackedByteArray, value: Vector3) -> void:
	_append_text(payload, "%d,%d,%d\n" % [
		roundi(value.x * QUANTIZATION), roundi(value.y * QUANTIZATION),
		roundi(value.z * QUANTIZATION),
	])


static func _append_basis(payload: PackedByteArray, basis: Basis) -> void:
	_append_vector(payload, basis.x)
	_append_vector(payload, basis.y)
	_append_vector(payload, basis.z)


static func _append_text(payload: PackedByteArray, value: String) -> void:
	payload.append_array(value.to_utf8_buffer())
