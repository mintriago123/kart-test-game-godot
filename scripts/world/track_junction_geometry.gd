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
var left_boundary := PackedVector3Array()
var right_boundary := PackedVector3Array()


func get_boundary_for_offset(lateral_offset: float) -> PackedVector3Array:
	return left_boundary if lateral_offset < 0.0 else right_boundary

