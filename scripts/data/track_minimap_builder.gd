@tool
class_name TrackMinimapBuilder
extends RefCounted

const SAMPLE_STEP_METERS := 2.5
const SIMPLIFY_TOLERANCE_METERS := 0.9
const MINIMUM_ROUTE_SAMPLES := 16


static func build(track: TrackLevel) -> TrackMinimapData:
	if track == null:
		return null
	var main_route := track.get_main_route()
	if (
		main_route == null
		or main_route.curve == null
		or main_route.curve.point_count < 4
		or not main_route.curve.closed
		or main_route.curve.get_baked_length() <= 0.0
	):
		return null

	var start_index := clampi(
		track.start_point_index,
		0,
		main_route.curve.point_count - 1
	)
	var start_offset := main_route.curve.get_closest_offset(
		main_route.curve.get_point_position(start_index)
	)
	var sampled_route := _sample_path(
		track,
		main_route,
		true,
		start_offset
	)
	if sampled_route.size() < 3:
		return null

	var data := TrackMinimapData.new()
	var route_points := _flatten_points(sampled_route)
	route_points.append(route_points[0])
	route_points = _simplify_polyline(
		route_points,
		SIMPLIFY_TOLERANCE_METERS
	)
	if (
		route_points.size() > 1
		and route_points[0].is_equal_approx(route_points[-1])
	):
		route_points.remove_at(route_points.size() - 1)
	if route_points.size() < 3:
		return null

	data.route_points = route_points
	data.start_position = route_points[0]
	data.start_direction = _find_start_direction(route_points)
	data.length_meters = _measure_loop(sampled_route)

	for shortcut in track.get_shortcuts():
		if (
			shortcut == null
			or shortcut.curve == null
			or shortcut.curve.closed
			or shortcut.curve.point_count < 2
			or shortcut.curve.get_baked_length() <= 0.0
		):
			continue
		var sampled_shortcut := _sample_path(track, shortcut, false)
		var simplified_shortcut := _simplify_polyline(
			_flatten_points(sampled_shortcut),
			SIMPLIFY_TOLERANCE_METERS
		)
		if simplified_shortcut.size() < 2:
			continue
		data.shortcut_ranges.append(data.shortcut_points.size())
		data.shortcut_ranges.append(simplified_shortcut.size())
		data.shortcut_points.append_array(simplified_shortcut)
		data.shortcut_count += 1

	return data if data.is_valid() else null


static func _sample_path(
	track: TrackLevel,
	path: Path3D,
	is_closed: bool,
	start_offset := 0.0
) -> PackedVector3Array:
	var points := PackedVector3Array()
	var curve := path.curve
	var baked_length := curve.get_baked_length()
	if baked_length <= 0.0:
		return points
	var minimum_samples := (
		maxi(MINIMUM_ROUTE_SAMPLES, curve.point_count * 2)
		if is_closed
		else maxi(2, curve.point_count - 1)
	)
	var segment_count := maxi(
		ceili(baked_length / SAMPLE_STEP_METERS),
		minimum_samples
	)
	var path_to_track := _get_transform_to_track(path, track)
	var sample_count := segment_count if is_closed else segment_count + 1
	for sample_index in sample_count:
		var progress := float(sample_index) / float(segment_count)
		var sample_offset := start_offset + baked_length * progress
		if is_closed:
			sample_offset = fmod(sample_offset, baked_length)
		else:
			sample_offset = minf(sample_offset, baked_length)
		var point := path_to_track * curve.sample_baked(sample_offset, true)
		if track is TrackLevel:
			point.y = maxf(point.y, TrackLevel.MINIMUM_DRIVABLE_HEIGHT)
		points.append(point)
	return points


static func _get_transform_to_track(
	path: Node3D,
	track: TrackLevel
) -> Transform3D:
	var path_to_track := Transform3D.IDENTITY
	var current: Node = path
	while current != null and current != track:
		if not current is Node3D:
			return Transform3D.IDENTITY
		path_to_track = (current as Node3D).transform * path_to_track
		current = current.get_parent()
	return path_to_track


static func _flatten_points(points: PackedVector3Array) -> PackedVector2Array:
	var flattened := PackedVector2Array()
	for point in points:
		flattened.append(Vector2(point.x, point.z))
	return flattened


static func _find_start_direction(points: PackedVector2Array) -> Vector2:
	for point_index in range(1, points.size()):
		var direction := points[point_index] - points[0]
		if direction.length_squared() >= 0.0001:
			return direction.normalized()
	return Vector2.ZERO


static func _measure_loop(points: PackedVector3Array) -> float:
	var length := 0.0
	for point_index in points.size():
		length += points[point_index].distance_to(
			points[(point_index + 1) % points.size()]
		)
	return length


static func _simplify_polyline(
	points: PackedVector2Array,
	tolerance: float
) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var keep := PackedByteArray()
	keep.resize(points.size())
	keep[0] = 1
	keep[points.size() - 1] = 1
	var segments: Array[Vector2i] = [
		Vector2i(0, points.size() - 1),
	]
	while not segments.is_empty():
		var segment: Vector2i = segments.pop_back()
		var furthest_index := -1
		var furthest_distance := tolerance
		for point_index in range(segment.x + 1, segment.y):
			var distance := _distance_to_segment(
				points[point_index],
				points[segment.x],
				points[segment.y]
			)
			if distance > furthest_distance:
				furthest_distance = distance
				furthest_index = point_index
		if furthest_index < 0:
			continue
		keep[furthest_index] = 1
		segments.append(Vector2i(segment.x, furthest_index))
		segments.append(Vector2i(furthest_index, segment.y))

	var simplified := PackedVector2Array()
	for point_index in points.size():
		if keep[point_index] == 1:
			simplified.append(points[point_index])
	return simplified


static func _distance_to_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var progress := clampf(
		(point - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return point.distance_to(segment_start + segment * progress)
