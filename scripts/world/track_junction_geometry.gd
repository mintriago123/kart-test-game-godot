class_name TrackJunctionGeometry
extends RefCounted

var is_valid := false
var fallback_reason := ""
var is_entry := true
var side := 0.0
var mouth_width := 0.0
var transition_length := 0.0
var angle_degrees := 0.0
var world_position := Vector3.ZERO
var portal_intervals: Array[Vector2] = []
var shortcut_join_index := -1
var shortcut_transition_index := -1
var shortcut_transition_center := Vector3.ZERO
var left_boundary := PackedVector3Array()
var right_boundary := PackedVector3Array()


func get_boundary_for_offset(lateral_offset: float) -> PackedVector3Array:
	return left_boundary if lateral_offset < 0.0 else right_boundary


func get_barrier_boundary(
	lateral_offset: float,
	inset: float
) -> PackedVector3Array:
	var boundary := get_boundary_for_offset(lateral_offset)
	var opposite := right_boundary if lateral_offset < 0.0 else left_boundary
	var barrier_boundary := PackedVector3Array()
	for point_index in boundary.size():
		var inward := opposite[point_index] - boundary[point_index]
		inward.y = 0.0
		var transition_weight := (
			float(point_index) / float(boundary.size() - 1)
			if boundary.size() > 1
			else 1.0
		)
		barrier_boundary.append(
			boundary[point_index]
			+ inward.normalized() * inset * transition_weight
		)
	return barrier_boundary
