extends SceneTree

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_closed_barrier_geometry()
	await _test_explicit_portals()
	quit(1 if _has_failed else 0)


func _test_closed_barrier_geometry() -> void:
	var shapes: Array[Array] = [
		[
			Vector3(-30.0, 0.0, -20.0),
			Vector3(30.0, 0.0, -20.0),
			Vector3(30.0, 0.0, 20.0),
			Vector3(-30.0, 0.0, 20.0),
		],
		[
			Vector3(-8.0, 0.0, -6.0),
			Vector3(8.0, 0.0, -6.0),
			Vector3(8.0, 0.0, 6.0),
			Vector3(-8.0, 0.0, 6.0),
		],
		[
			Vector3(-35.0, 0.0, -2.0),
			Vector3(35.0, 0.0, 0.0),
			Vector3(-30.0, 0.0, 3.0),
		],
		_create_circle_points(24, 32.0),
	]
	for shape_index in shapes.size():
		var track := CoastalTrack.new()
		track.route_points.assign(shapes[shape_index])
		var offset := 4.0
		var ring := track._build_miter_barrier_ring(track.route_points, offset)
		var ring_has_no_spikes := ring.size() >= track.route_points.size()
		for ring_point in ring:
			var closest_control_distance := INF
			for control_point in track.route_points:
				closest_control_distance = minf(
					closest_control_distance,
					(ring_point.point as Vector3).distance_to(
						control_point + Vector3.UP * 0.08
					)
				)
			ring_has_no_spikes = (
				ring_has_no_spikes
				and closest_control_distance
				<= offset * CoastalTrack.BARRIER_MITER_LIMIT + 0.001
			)
		_check(
			ring_has_no_spikes,
			"Closed barrier shape %d respects the 2.0 miter limit."
			% (shape_index + 1)
		)

		var closed_points := PackedVector3Array()
		for ring_point in ring:
			closed_points.append(ring_point.point)
		var mesh := track._create_indexed_barrier_mesh([closed_points], true)
		var arrays := mesh.surface_get_arrays(0)
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var final_vertex := (closed_points.size() - 1) * 4
		_check(
			not indices.is_empty()
			and indices.has(0)
			and indices.has(final_vertex),
			"Closed barrier shape %d indexes the final segment back to the first."
			% (shape_index + 1)
		)
		_check(
			indices.size() == closed_points.size() * 18,
			"Closed barrier shape %d has no visual or physical seam."
			% (shape_index + 1)
		)
		track.free()


func _test_explicit_portals() -> void:
	var packed_scene := load("res://levels/coastal_track.tscn") as PackedScene
	var track := packed_scene.instantiate() as TrackLevel
	root.add_child(track)
	await process_frame
	var left_offset := -CoastalTrack.ROAD_WIDTH * 0.5 + CoastalTrack.BARRIER_PATH_INSET
	var right_offset := CoastalTrack.ROAD_WIDTH * 0.5 - CoastalTrack.BARRIER_PATH_INSET
	var left_portals := track._build_main_barrier_portals(left_offset)
	var right_portals := track._build_main_barrier_portals(right_offset)
	_check(
		left_portals.is_empty() and right_portals.size() == 4,
		"Only the real entry and exit sides open four main-route portals."
	)
	var portal_widths_are_bounded := true
	for interval in right_portals:
		var width := (interval.y - interval.x) * track.get_route_length()
		portal_widths_are_bounded = (
			portal_widths_are_bounded
			and width >= CoastalTrack.PORTAL_MIN_WIDTH - 0.01
			and width <= CoastalTrack.PORTAL_MAX_WIDTH + 0.01
		)
	_check(
		portal_widths_are_bounded,
		"Shortcut portal openings stay within the 6–14 meter bounds."
	)

	var barrier_ring := track._build_miter_barrier_ring(
		track.route_points,
		right_offset
	)
	var open_chains := track._split_barrier_ring(barrier_ring, right_portals)
	var open_mesh := track._create_indexed_barrier_mesh(open_chains, false)
	var open_arrays := open_mesh.surface_get_arrays(0)
	var open_indices := open_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var expected_index_count := 0
	for chain_value in open_chains:
		var chain := chain_value as PackedVector3Array
		expected_index_count += (chain.size() - 1) * 18 + 12
	_check(
		not open_chains.is_empty()
		and open_indices.size() == expected_index_count,
		"Every explicit portal has indexed end caps in visual and collision geometry."
	)

	var wrapping_intervals: Array[Vector2] = []
	var route_forward := track._get_route_forward(0)
	var route_right := Vector3.UP.cross(route_forward).normalized()
	track._append_portal_interval(
		wrapping_intervals,
		track.route_points[0],
		route_forward.lerp(route_right, 0.75).normalized(),
		track.get_route_length(),
		0.998
	)
	_check(
		wrapping_intervals.size() == 2
		and is_zero_approx(wrapping_intervals[1].x)
		and is_equal_approx(wrapping_intervals[0].y, 1.0),
		"Portal intervals wrap safely across normalized progress 0.0/1.0."
	)
	track.queue_free()
	await process_frame


func _create_circle_points(point_count: int, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point_index in point_count:
		var angle := TAU * float(point_index) / point_count
		points.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return points


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
