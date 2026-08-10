class_name TrackJunctionBuilder
extends RefCounted

const JunctionGeometry = preload("res://scripts/world/track_junction_geometry.gd")

const BARRIER_PATH_INSET := 0.12
const PORTAL_MIN_WIDTH := 6.0
const PORTAL_MAX_WIDTH := 14.0
const ENTRY_MOUTH_PADDING := 3.0
const EXIT_MOUTH_PADDING := 1.5
const TRANSITION_MIN_LENGTH := 6.0
const TRANSITION_MAX_LENGTH := 10.0
const SAMPLE_SPACING := 0.75
const MINIMUM_ANGLE_DEGREES := 20.0

var _route_points: Array[Vector3]
var _road_width: float
var _shortcut_width: float
var _route_length := 0.0


func _init(
	route_points: Array[Vector3],
	road_width: float,
	shortcut_width: float
) -> void:
	_route_points = route_points
	_road_width = road_width
	_shortcut_width = shortcut_width
	for route_index in _route_points.size():
		_route_length += _route_points[route_index].distance_to(
			_route_points[(route_index + 1) % _route_points.size()]
		)


func build(
	shortcut_points: Array[Vector3],
	is_entry: bool
) -> JunctionGeometry:
	var geometry := JunctionGeometry.new()
	geometry.is_entry = is_entry
	if _route_points.size() < 3 or shortcut_points.size() < 3 or _route_length <= 0.001:
		geometry.fallback_reason = "La unión no tiene suficientes puntos."
		return geometry
	var crossing := _find_crossing(shortcut_points, is_entry, 0.0)
	if crossing.is_empty():
		geometry.fallback_reason = "El atajo no cruza el borde de la carretera."
		return geometry
	geometry.side = float(crossing.side)
	geometry.world_position = crossing.point
	geometry.shortcut_join_index = int(crossing.point_index)
	var inward_direction := crossing.direction as Vector3
	inward_direction.y = 0.0
	if inward_direction.length_squared() <= 0.0001:
		geometry.fallback_reason = "La dirección de la unión es inválida."
		return geometry
	inward_direction = inward_direction.normalized()
	var drive_forward := inward_direction if is_entry else -inward_direction
	var route_location := _get_closest_route_location(crossing.point)
	var route_forward := route_location.forward as Vector3
	var alignment := clampf(route_forward.dot(drive_forward), -1.0, 1.0)
	geometry.angle_degrees = rad_to_deg(acos(alignment))
	if geometry.angle_degrees < MINIMUM_ANGLE_DEGREES:
		geometry.fallback_reason = (
			"La unión tiene un ángulo menor a %d°." % int(MINIMUM_ANGLE_DEGREES)
		)
		return geometry
	geometry.mouth_width = clampf(
		_shortcut_width + (ENTRY_MOUTH_PADDING if is_entry else EXIT_MOUTH_PADDING),
		PORTAL_MIN_WIDTH,
		PORTAL_MAX_WIDTH
	)
	var angle_sine := sin(deg_to_rad(geometry.angle_degrees))
	geometry.transition_length = clampf(
		_shortcut_width * 0.8 / maxf(angle_sine, 0.35),
		TRANSITION_MIN_LENGTH,
		TRANSITION_MAX_LENGTH
	)
	var center_progress := float(route_location.progress)
	var half_progress := geometry.mouth_width * 0.5 / _route_length
	geometry.portal_intervals = _make_wrapped_intervals(
		center_progress - half_progress,
		center_progress + half_progress
	)
	var mouth_a := _get_route_edge_at_progress(
		wrapf(center_progress - half_progress, 0.0, 1.0),
		geometry.side
	)
	var mouth_b := _get_route_edge_at_progress(
		wrapf(center_progress + half_progress, 0.0, 1.0),
		geometry.side
	)
	var join_sample := _sample_shortcut_inward(
		shortcut_points,
		crossing.point,
		geometry.shortcut_join_index,
		is_entry,
		geometry.transition_length
	)
	if join_sample.is_empty():
		geometry.fallback_reason = "El atajo es demasiado corto para suavizar la unión."
		return geometry
	var join_center := join_sample.point as Vector3
	var join_inward := join_sample.direction as Vector3
	var join_drive_forward := join_inward if is_entry else -join_inward
	var join_right := Vector3.UP.cross(join_drive_forward).normalized()
	var shortcut_left := join_center - join_right * _shortcut_width * 0.5
	var shortcut_right := join_center + join_right * _shortcut_width * 0.5
	var direct_pairing: bool = (
		mouth_a.point.distance_to(shortcut_left)
		+ mouth_b.point.distance_to(shortcut_right)
		<= mouth_a.point.distance_to(shortcut_right)
		+ mouth_b.point.distance_to(shortcut_left)
	)
	var left_mouth: Dictionary = mouth_a if direct_pairing else mouth_b
	var right_mouth: Dictionary = mouth_b if direct_pairing else mouth_a
	geometry.left_boundary = _sample_bezier(
		left_mouth.point,
		left_mouth.direction,
		shortcut_left,
		join_inward,
		geometry.transition_length
	)
	geometry.right_boundary = _sample_bezier(
		right_mouth.point,
		right_mouth.direction,
		shortcut_right,
		join_inward,
		geometry.transition_length
	)
	if (
		not _boundaries_are_finite(geometry)
		or _boundaries_cross(geometry.left_boundary, geometry.right_boundary)
	):
		geometry.left_boundary.clear()
		geometry.right_boundary.clear()
		geometry.fallback_reason = "Las curvas de la unión se cruzan."
		return geometry
	geometry.is_valid = true
	return geometry


func _find_crossing(
	shortcut_points: Array[Vector3],
	is_entry: bool,
	corridor_offset: float
) -> Dictionary:
	var step := 1 if is_entry else -1
	var point_index := 0 if is_entry else shortcut_points.size() - 1
	var previous_point := TrackSurfaceBuilder.offset_path_point(
		shortcut_points,
		point_index,
		corridor_offset,
		0.0,
		false
	)
	var previous_location := _get_closest_route_location(previous_point)
	var previous_right := Vector3.UP.cross(
		previous_location.forward as Vector3
	).normalized()
	var previous_lateral := (
		previous_point - (previous_location.point as Vector3)
	).dot(previous_right)
	var target_lateral := _road_width * 0.5 - BARRIER_PATH_INSET
	while point_index + step >= 0 and point_index + step < shortcut_points.size():
		point_index += step
		var current_point := TrackSurfaceBuilder.offset_path_point(
			shortcut_points,
			point_index,
			corridor_offset,
			0.0,
			false
		)
		var current_location := _get_closest_route_location(current_point)
		var current_right := Vector3.UP.cross(
			current_location.forward as Vector3
		).normalized()
		var current_lateral := (
			current_point - (current_location.point as Vector3)
		).dot(current_right)
		var side := signf(current_lateral)
		if side != 0.0 and absf(current_lateral) >= target_lateral:
			var denominator := absf(current_lateral) - absf(previous_lateral)
			var weight := 1.0
			if denominator > 0.0001:
				weight = clampf(
					(target_lateral - absf(previous_lateral)) / denominator,
					0.0,
					1.0
				)
			return {
				"point": previous_point.lerp(current_point, weight),
				"direction": current_point - previous_point,
				"side": side,
				"point_index": point_index,
			}
		previous_point = current_point
		previous_lateral = current_lateral
	return {}


func _get_closest_route_location(point: Vector3) -> Dictionary:
	var flattened_point := Vector2(point.x, point.z)
	var minimum_distance := INF
	var cumulative_distance := 0.0
	var best_distance := 0.0
	var best_forward := Vector3.FORWARD
	var best_point := _route_points[0]
	for route_index in _route_points.size():
		var start := _route_points[route_index]
		var finish := _route_points[(route_index + 1) % _route_points.size()]
		var segment_2d := Vector2(finish.x - start.x, finish.z - start.z)
		var segment_length_squared := segment_2d.length_squared()
		var weight := 0.0
		if segment_length_squared > 0.0001:
			weight = clampf(
				(flattened_point - Vector2(start.x, start.z)).dot(segment_2d)
				/ segment_length_squared,
				0.0,
				1.0
			)
		var closest_2d := Vector2(start.x, start.z) + segment_2d * weight
		var distance := flattened_point.distance_squared_to(closest_2d)
		var segment_length := start.distance_to(finish)
		if distance < minimum_distance:
			minimum_distance = distance
			best_distance = cumulative_distance + segment_length * weight
			best_forward = finish - start
			best_forward.y = 0.0
			best_forward = best_forward.normalized()
			best_point = start.lerp(finish, weight)
		cumulative_distance += segment_length
	return {
		"progress": best_distance / _route_length,
		"forward": best_forward,
		"point": best_point,
	}


func _get_route_edge_at_progress(progress: float, side: float) -> Dictionary:
	var target_distance := progress * _route_length
	var cumulative_distance := 0.0
	for route_index in _route_points.size():
		var start := _route_points[route_index]
		var finish := _route_points[(route_index + 1) % _route_points.size()]
		var segment_length := start.distance_to(finish)
		if cumulative_distance + segment_length >= target_distance:
			var weight := (
				(target_distance - cumulative_distance) / maxf(segment_length, 0.001)
			)
			var forward := finish - start
			forward.y = 0.0
			forward = forward.normalized()
			var right := Vector3.UP.cross(forward).normalized()
			return {
				"point": start.lerp(finish, weight)
					+ right * side * (_road_width * 0.5 - BARRIER_PATH_INSET),
				"direction": forward,
			}
		cumulative_distance += segment_length
	return {}


func _sample_shortcut_inward(
	shortcut_points: Array[Vector3],
	crossing_point: Vector3,
	crossing_index: int,
	is_entry: bool,
	target_distance: float
) -> Dictionary:
	var step := 1 if is_entry else -1
	var previous := crossing_point
	var traveled := 0.0
	var point_index := crossing_index
	while point_index >= 0 and point_index < shortcut_points.size():
		var current := shortcut_points[point_index]
		var segment := current - previous
		var segment_length := segment.length()
		if segment_length > 0.0001:
			if traveled + segment_length >= target_distance:
				var weight := (target_distance - traveled) / segment_length
				return {
					"point": previous.lerp(current, weight),
					"direction": segment.normalized(),
				}
			traveled += segment_length
		previous = current
		point_index += step
	return {}


func _sample_bezier(
	start: Vector3,
	start_direction: Vector3,
	finish: Vector3,
	finish_direction: Vector3,
	transition_length: float
) -> PackedVector3Array:
	var handle_length := minf(transition_length / 3.0, start.distance_to(finish) * 0.45)
	var control_a := start + start_direction.normalized() * handle_length
	var control_b := finish - finish_direction.normalized() * handle_length
	var sample_count := maxi(2, ceili(transition_length / SAMPLE_SPACING))
	var points := PackedVector3Array()
	for sample_index in range(sample_count + 1):
		var weight := float(sample_index) / float(sample_count)
		var inverse := 1.0 - weight
		points.append(
			start * inverse * inverse * inverse
			+ control_a * 3.0 * inverse * inverse * weight
			+ control_b * 3.0 * inverse * weight * weight
			+ finish * weight * weight * weight
		)
	return points


func _make_wrapped_intervals(start: float, finish: float) -> Array[Vector2]:
	var intervals: Array[Vector2] = []
	if start < 0.0:
		intervals.append(Vector2(0.0, finish))
		intervals.append(Vector2(1.0 + start, 1.0))
	elif finish > 1.0:
		intervals.append(Vector2(start, 1.0))
		intervals.append(Vector2(0.0, finish - 1.0))
	else:
		intervals.append(Vector2(start, finish))
	return intervals


func _boundaries_are_finite(geometry: JunctionGeometry) -> bool:
	for boundary in [geometry.left_boundary, geometry.right_boundary]:
		for point in boundary:
			if not point.is_finite():
				return false
	return true


func _boundaries_cross(
	left_boundary: PackedVector3Array,
	right_boundary: PackedVector3Array
) -> bool:
	for segment_index in left_boundary.size() - 1:
		var left_start := Vector2(left_boundary[segment_index].x, left_boundary[segment_index].z)
		var left_end := Vector2(left_boundary[segment_index + 1].x, left_boundary[segment_index + 1].z)
		for right_index in right_boundary.size() - 1:
			var right_start := Vector2(right_boundary[right_index].x, right_boundary[right_index].z)
			var right_end := Vector2(right_boundary[right_index + 1].x, right_boundary[right_index + 1].z)
			if Geometry2D.segment_intersects_segment(
				left_start,
				left_end,
				right_start,
				right_end
			) != null:
				return true
	return false
