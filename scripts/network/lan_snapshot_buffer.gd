class_name LanSnapshotBuffer
extends RefCounted

const MAX_SNAPSHOTS := 32

var interpolation_delay_ms := LanProtocol.INTERPOLATION_DELAY_MS
var _snapshots: Array[Dictionary] = []


func push_snapshot(snapshot: Dictionary) -> bool:
	var server_time := int(snapshot.get("server_time_ms", -1))
	if server_time < 0:
		return false
	if not _snapshots.is_empty() and server_time <= int(_snapshots.back().get("server_time_ms", -1)):
		return false
	_snapshots.append(snapshot.duplicate(true))
	while _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()
	return true


func sample_racer(slot_id: int, local_time_ms: int) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var target_time := local_time_ms - interpolation_delay_ms
	var before: Dictionary = _snapshots.front()
	var after: Dictionary = _snapshots.back()
	for index in range(1, _snapshots.size()):
		if int(_snapshots[index].server_time_ms) >= target_time:
			before = _snapshots[index - 1]
			after = _snapshots[index]
			break
	var first := _find_racer(before, slot_id)
	var second := _find_racer(after, slot_id)
	if first.is_empty():
		return second
	if second.is_empty() or before == after:
		return first
	var duration := maxf(float(int(after.server_time_ms) - int(before.server_time_ms)), 1.0)
	var weight := clampf(float(target_time - int(before.server_time_ms)) / duration, 0.0, 1.0)
	return interpolate_state(first, second, weight)


func reconcile_local(
	current: Dictionary,
	authoritative: Dictionary,
	position_threshold := 0.35,
	rotation_threshold := 0.08
) -> Dictionary:
	if current.is_empty() or authoritative.is_empty():
		return authoritative.duplicate(true)
	var current_position: Vector3 = current.get("position", Vector3.ZERO)
	var target_position: Vector3 = authoritative.get("position", current_position)
	var current_rotation: Quaternion = current.get("rotation", Quaternion.IDENTITY)
	var target_rotation: Quaternion = authoritative.get("rotation", current_rotation)
	var position_error := current_position.distance_to(target_position)
	var rotation_error := current_rotation.angle_to(target_rotation)
	var weight := 1.0 if position_error > 4.0 else clampf(position_error / maxf(position_threshold * 6.0, 0.01), 0.08, 0.42)
	var rotation_weight := 1.0 if rotation_error > 1.0 else clampf(rotation_error / maxf(rotation_threshold * 8.0, 0.01), 0.08, 0.4)
	var result := authoritative.duplicate(true)
	result["position"] = current_position.lerp(target_position, weight)
	result["rotation"] = current_rotation.slerp(target_rotation, rotation_weight)
	return result


static func interpolate_state(first: Dictionary, second: Dictionary, weight: float) -> Dictionary:
	var result := second.duplicate(true)
	result["position"] = (first.get("position", Vector3.ZERO) as Vector3).lerp(second.get("position", Vector3.ZERO), weight)
	result["velocity"] = (first.get("velocity", Vector3.ZERO) as Vector3).lerp(second.get("velocity", Vector3.ZERO), weight)
	result["rotation"] = (first.get("rotation", Quaternion.IDENTITY) as Quaternion).slerp(second.get("rotation", Quaternion.IDENTITY), weight)
	return result


func clear() -> void:
	_snapshots.clear()


func _find_racer(snapshot: Dictionary, slot_id: int) -> Dictionary:
	for value in snapshot.get("racers", []):
		if value is Dictionary and int(value.get("slot_id", -1)) == slot_id:
			return value
	return {}
