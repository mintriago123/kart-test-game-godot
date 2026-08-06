@tool
class_name TrackShortcut
extends Path3D

@export var shortcut_id := 0
@export var display_name := "Nuevo atajo"
@export var route_anchor_enabled := false
@export_range(0.0, 1.0, 0.0001) var entry_progress := 0.0
@export_range(0.0, 1.0, 0.0001) var exit_progress := 0.0
@export var midpoint_lateral_offset := 0.0
@export var midpoint_longitudinal_offset := 0.0
@export var midpoint_height_offset := 0.0
@export_range(0.0, 100.0, 0.01, "or_greater") var entry_handle_length := 10.0
@export_range(0.0, 100.0, 0.01, "or_greater") var exit_handle_length := 10.0
@export_range(0.0, 100.0, 0.01, "or_greater") var midpoint_in_handle_length := 6.0
@export_range(0.0, 100.0, 0.01, "or_greater") var midpoint_out_handle_length := 6.0


func ensure_curve() -> Curve3D:
	if curve == null:
		curve = Curve3D.new()
	curve.closed = false
	return curve


func rebuild_from_route(
	entry_position: Vector3,
	entry_forward: Vector3,
	exit_position: Vector3,
	exit_forward: Vector3
) -> bool:
	if not route_anchor_enabled:
		return false
	var direct := exit_position - entry_position
	var horizontal_direct := Vector3(direct.x, 0.0, direct.z)
	if horizontal_direct.length_squared() <= 0.0001:
		return false
	horizontal_direct = horizontal_direct.normalized()
	var lateral := Vector3(
		-horizontal_direct.z,
		0.0,
		horizontal_direct.x
	)
	var midpoint := entry_position.lerp(exit_position, 0.5)
	midpoint += horizontal_direct * midpoint_longitudinal_offset
	midpoint += lateral * midpoint_lateral_offset
	midpoint.y += midpoint_height_offset

	var safe_entry_forward := _flattened_direction(entry_forward, horizontal_direct)
	var safe_exit_forward := _flattened_direction(exit_forward, horizontal_direct)
	var middle_forward := direct.normalized()
	var rebuilt_curve := Curve3D.new()
	rebuilt_curve.add_point(
		entry_position,
		Vector3.ZERO,
		safe_entry_forward * entry_handle_length
	)
	rebuilt_curve.add_point(
		midpoint,
		-middle_forward * midpoint_in_handle_length,
		middle_forward * midpoint_out_handle_length
	)
	rebuilt_curve.add_point(
		exit_position,
		-safe_exit_forward * exit_handle_length,
		Vector3.ZERO
	)
	rebuilt_curve.closed = false
	curve = rebuilt_curve
	return true


func clear_route_anchor() -> void:
	route_anchor_enabled = false


func _flattened_direction(direction: Vector3, fallback: Vector3) -> Vector3:
	var flattened := Vector3(direction.x, 0.0, direction.z)
	if flattened.length_squared() <= 0.0001:
		return fallback
	return flattened.normalized()
