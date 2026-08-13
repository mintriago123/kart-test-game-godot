class_name LanProtocol
extends RefCounted

const LAN_PROTOCOL_VERSION := 1
const RACE_PORT := 7777
const DISCOVERY_PORT := 7778
const MAX_HUMANS := 4
const GRID_SIZE := 8
const INPUT_RATE_HZ := 30.0
const SNAPSHOT_RATE_HZ := 20.0
const INTERPOLATION_DELAY_MS := 100
const ANNOUNCE_INTERVAL := 1.0
const ROOM_TIMEOUT := 3.0

const CHANNEL_RELIABLE := 0
const CHANNEL_INPUT := 1
const CHANNEL_SNAPSHOT := 2


static func calculate_catalog_fingerprint(
	progression: ProgressionCatalog,
	tracks: TrackCatalog
) -> String:
	var rows := PackedStringArray(["lan-protocol:%d" % LAN_PROTOCOL_VERSION])
	if progression != null and progression.racers != null:
		var racer_rows := PackedStringArray()
		for racer in progression.racers.racers:
			if racer != null:
				racer_rows.append("r:%s:%s:%s" % [racer.id, racer.display_name, racer.body_color.to_html()])
		racer_rows.sort()
		rows.append_array(racer_rows)
	if progression != null and progression.unlocks != null:
		var vehicle_rows := PackedStringArray()
		for vehicle in progression.unlocks.variants:
			if vehicle != null:
				vehicle_rows.append("v:%s:%.3f:%.3f:%.3f:%.3f:%.3f" % [vehicle.id, vehicle.speed, vehicle.acceleration, vehicle.handling, vehicle.weight, vehicle.mini_turbo_duration_multiplier])
		vehicle_rows.sort()
		rows.append_array(vehicle_rows)
	if tracks != null:
		var track_rows := PackedStringArray()
		for track in tracks.tracks:
			if track != null:
				track_rows.append("t:%s:%d:%.3f" % [track.id, track.laps, track.length_km])
		track_rows.sort()
		rows.append_array(track_rows)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update("\n".join(rows).to_utf8_buffer())
	return context.finish().hex_encode()


static func validate_handshake(
	payload: Dictionary,
	expected_fingerprint: String,
	progression: ProgressionCatalog,
	tracks: TrackCatalog
) -> String:
	if int(payload.get("protocol", -1)) != LAN_PROTOCOL_VERSION:
		return "Versión LAN incompatible (se requiere protocolo %d)." % LAN_PROTOCOL_VERSION
	if str(payload.get("catalog_fingerprint", "")) != expected_fingerprint:
		return "Catálogo incompatible: ambos equipos deben usar la misma versión del juego."
	var racer_id := StringName(payload.get("racer_id", &""))
	if progression == null or progression.racers == null or progression.racers.get_racer(racer_id) == null:
		return "Piloto incompatible o inexistente: %s." % racer_id
	var vehicle_id := StringName(payload.get("vehicle_id", &""))
	if progression.unlocks == null or progression.unlocks.get_variant(vehicle_id) == null:
		return "Vehículo incompatible o inexistente: %s." % vehicle_id
	var track_id := StringName(payload.get("track_id", &""))
	if not track_id.is_empty() and (tracks == null or tracks.get_track(track_id) == null):
		return "Circuito incompatible o inexistente: %s." % track_id
	return ""


static func sanitize_input_frame(frame: Dictionary) -> Dictionary:
	return {
		"throttle": clampf(float(frame.get("throttle", 0.0)), 0.0, 1.0),
		"brake": clampf(float(frame.get("brake", 0.0)), 0.0, 1.0),
		"steer": clampf(float(frame.get("steer", 0.0)), -1.0, 1.0),
		"drift": bool(frame.get("drift", false)),
		"use_item": bool(frame.get("use_item", false)),
	}


static func encode_discovery(payload: Dictionary) -> PackedByteArray:
	var safe := payload.duplicate(true)
	safe["protocol"] = LAN_PROTOCOL_VERSION
	return JSON.stringify(safe).to_utf8_buffer()


static func decode_discovery(packet: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var data := parsed as Dictionary
	if int(data.get("protocol", -1)) != LAN_PROTOCOL_VERSION:
		return {}
	return data
