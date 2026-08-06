@tool
class_name TrackMinimapData
extends Resource

@export var route_points := PackedVector2Array()
@export var shortcut_points := PackedVector2Array()
@export var shortcut_ranges := PackedInt32Array()
@export var start_position := Vector2.ZERO
@export var start_direction := Vector2.ZERO
@export_range(0.0, 100000.0, 0.1, "or_greater") var length_meters := 0.0
@export_range(0, 128, 1, "or_greater") var shortcut_count := 0


func is_valid() -> bool:
	if (
		route_points.size() < 3
		or length_meters <= 0.0
		or start_direction.length_squared() < 0.0001
		or shortcut_ranges.size() != shortcut_count * 2
	):
		return false
	for shortcut_index in shortcut_count:
		var range_offset := shortcut_index * 2
		var point_offset := shortcut_ranges[range_offset]
		var point_count := shortcut_ranges[range_offset + 1]
		if (
			point_offset < 0
			or point_count < 2
			or point_offset + point_count > shortcut_points.size()
		):
			return false
	return true


func get_shortcut_points(shortcut_index: int) -> PackedVector2Array:
	if shortcut_index < 0 or shortcut_index >= shortcut_count:
		return PackedVector2Array()
	var range_offset := shortcut_index * 2
	var point_offset := shortcut_ranges[range_offset]
	var point_count := shortcut_ranges[range_offset + 1]
	var points := PackedVector2Array()
	for point_index in range(point_offset, point_offset + point_count):
		points.append(shortcut_points[point_index])
	return points
