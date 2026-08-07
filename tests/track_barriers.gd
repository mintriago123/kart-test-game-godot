extends SceneTree

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_surface_geometry()
	_test_surface_edge_cases()
	_test_closed_barrier_geometry()
	_test_barrier_edge_cases()
	await _test_explicit_portals()
	quit(1 if _has_failed else 0)


func _test_surface_geometry() -> void:
	var path_points: Array[Vector3] = [
		Vector3(-10.0, 0.25, -6.0),
		Vector3(10.0, 0.25, -6.0),
		Vector3(10.0, 1.25, 6.0),
		Vector3(-10.0, 1.25, 6.0),
	]
	var closed_mesh := TrackSurfaceBuilder.create_ribbon_mesh(
		path_points,
		-4.0,
		4.0,
		0.0,
		true
	)
	var open_mesh := TrackSurfaceBuilder.create_ribbon_mesh(
		path_points,
		-4.0,
		4.0,
		0.0,
		false
	)
	var shortcut_mesh := TrackSurfaceBuilder.create_shortcut_collision_mesh(
		path_points,
		CoastalTrack.SHORTCUT_WIDTH
	)
	var closed_vertices := (
		closed_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		as PackedVector3Array
	)
	var open_vertices := (
		open_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		as PackedVector3Array
	)
	var shortcut_vertices := (
		shortcut_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		as PackedVector3Array
	)
	_check(
		closed_vertices.size() == path_points.size() * 6
		and open_vertices.size() == (path_points.size() - 1) * 6
		and shortcut_vertices.size() == (path_points.size() - 1) * 6,
		"Road and shortcut ribbons preserve their six-vertices-per-segment signature."
	)
	var endpoint_left := TrackSurfaceBuilder.offset_path_point(
		path_points,
		0,
		-4.0,
		0.5,
		false
	)
	var endpoint_right := TrackSurfaceBuilder.offset_path_point(
		path_points,
		0,
		4.0,
		0.5,
		false
	)
	_check(
		is_equal_approx(endpoint_left.distance_to(endpoint_right), 8.0)
		and is_equal_approx(endpoint_left.y, path_points[0].y + 0.5)
		and is_equal_approx(endpoint_right.y, path_points[0].y + 0.5),
		"Open-path offsets preserve width and height at endpoints."
	)


func _test_surface_edge_cases() -> void:
	var minimal_open: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(8.0, 1.0, 0.0),
	]
	var minimal_closed: Array[Vector3] = [
		Vector3(-5.0, 0.0, -4.0),
		Vector3(5.0, 0.0, -4.0),
		Vector3(0.0, 0.0, 5.0),
	]
	var repeated_points: Array[Vector3] = [
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(8.0, 0.0, 0.0),
	]
	var collinear_points: Array[Vector3] = [
		Vector3(-8.0, 0.0, 0.0),
		Vector3.ZERO,
		Vector3(8.0, 0.0, 0.0),
	]
	var cases := [
		{
			"name": "minimal open",
			"points": minimal_open,
			"closed": false,
			"vertices": 6,
		},
		{
			"name": "minimal closed",
			"points": minimal_closed,
			"closed": true,
			"vertices": 18,
		},
		{
			"name": "repeated-point",
			"points": repeated_points,
			"closed": false,
			"vertices": 12,
		},
		{
			"name": "collinear",
			"points": collinear_points,
			"closed": false,
			"vertices": 12,
		},
	]
	for case_data in cases:
		var points: Array[Vector3] = case_data.points
		var mesh := TrackSurfaceBuilder.create_ribbon_mesh(
			points,
			-2.0,
			2.0,
			0.1,
			case_data.closed
		)
		var arrays := mesh.surface_get_arrays(0)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		_check(
			vertices.size() == case_data.vertices
			and normals.size() == vertices.size()
			and _vectors_are_finite(vertices)
			and _vectors_are_finite(normals),
			"%s ribbon preserves finite vertices and normals."
			% case_data.name
		)
	var repeated_collision := (
		TrackSurfaceBuilder.create_shortcut_collision_mesh(
			repeated_points,
			CoastalTrack.SHORTCUT_WIDTH
		)
	)
	var repeated_collision_vertices := (
		repeated_collision.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		as PackedVector3Array
	)
	_check(
		repeated_collision_vertices.size() == 12
		and _vectors_are_finite(repeated_collision_vertices),
		"Shortcut collision tolerates a repeated path point."
	)


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
		var ring := TrackBarrierBuilder.build_miter_barrier_ring(
			track.route_points,
			offset
		)
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
		var mesh := TrackBarrierBuilder.create_indexed_barrier_mesh(
			[closed_points],
			true
		)
		var arrays := mesh.surface_get_arrays(0)
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var final_vertex := (
			(closed_points.size() - 1)
			* CoastalTrack.BARRIER_VERTICES_PER_POINT
		)
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
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var normals_match_faces := true
		for point_index in closed_points.size():
			var point_base := (
				point_index * CoastalTrack.BARRIER_VERTICES_PER_POINT
			)
			normals_match_faces = (
				normals_match_faces
				and normals[point_base].dot(
					normals[point_base + 1]
				) > 0.9999
				and normals[point_base + 2].dot(
					normals[point_base + 3]
				) > 0.9999
				and normals[point_base + 4].dot(Vector3.UP) > 0.9999
				and normals[point_base + 5].dot(Vector3.UP) > 0.9999
			)
		_check(
			normals_match_faces,
			"Closed barrier shape %d separates side and top normals."
			% (shape_index + 1)
		)
		track.free()


func _test_barrier_edge_cases() -> void:
	var too_short: Array[Vector3] = [Vector3.ZERO, Vector3.RIGHT]
	_check(
		TrackBarrierBuilder.build_miter_barrier_ring(
			too_short,
			4.0
		).is_empty(),
		"Barrier rings reject paths with fewer than three points."
	)
	var repeated_path: Array[Vector3] = [
		Vector3(-10.0, 0.0, -10.0),
		Vector3(10.0, 0.0, -10.0),
		Vector3(10.0, 0.0, -10.0),
		Vector3(10.0, 0.0, 10.0),
		Vector3(-10.0, 0.0, 10.0),
	]
	var repeated_ring := TrackBarrierBuilder.build_miter_barrier_ring(
		repeated_path,
		4.0
	)
	var repeated_ring_is_finite := repeated_ring.size() >= 3
	for ring_point in repeated_ring:
		repeated_ring_is_finite = (
			repeated_ring_is_finite
			and (ring_point.point as Vector3).is_finite()
			and is_finite(float(ring_point.progress))
		)
	_check(
		repeated_ring_is_finite,
		"Barrier mitering skips repeated points without producing invalid geometry."
	)

	var overlapping_portals: Array[Vector2] = [
		Vector2(0.1, 0.3),
		Vector2(0.2, 0.4),
	]
	var allowed_ranges := TrackBarrierBuilder._get_allowed_barrier_ranges(
		0.0,
		1.0,
		overlapping_portals
	)
	_check(
		allowed_ranges == [
			Vector2(0.0, 0.1),
			Vector2(0.4, 1.0),
		],
		"Overlapping portal intervals behave as one opening."
	)
	var wrapped_portals: Array[Vector2] = [
		Vector2(0.0, 0.1),
		Vector2(0.9, 1.0),
	]
	var wrapped_allowed := TrackBarrierBuilder._get_allowed_barrier_ranges(
		0.0,
		1.0,
		wrapped_portals
	)
	_check(
		wrapped_allowed == [Vector2(0.1, 0.9)],
		"Wrapped portal halves leave only the middle barrier range."
	)

	var open_chain := PackedVector3Array([
		Vector3.ZERO,
		Vector3(5.0, 0.0, 0.0),
	])
	var open_mesh := TrackBarrierBuilder.create_indexed_barrier_mesh(
		[open_chain],
		false
	)
	var open_arrays := open_mesh.surface_get_arrays(0)
	var open_vertices := (
		open_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	)
	var open_normals := (
		open_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	)
	var open_indices := (
		open_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	)
	var caps_have_expected_normals := true
	for vertex_index in range(12, 16):
		caps_have_expected_normals = (
			caps_have_expected_normals
			and open_normals[vertex_index].dot(Vector3.LEFT) > 0.9999
		)
	for vertex_index in range(16, 20):
		caps_have_expected_normals = (
			caps_have_expected_normals
			and open_normals[vertex_index].dot(Vector3.RIGHT) > 0.9999
		)
	_check(
		open_vertices.size() == 20
		and open_normals.size() == 20
		and open_indices.size() == 30
		and caps_have_expected_normals,
		"Minimal open barriers include indexed caps with outward normals."
	)

	var closed_triangle := PackedVector3Array([
		Vector3(-4.0, 0.0, -3.0),
		Vector3(4.0, 0.0, -3.0),
		Vector3(0.0, 0.0, 4.0),
	])
	var closed_mesh := TrackBarrierBuilder.create_indexed_barrier_mesh(
		[closed_triangle],
		true
	)
	var closed_arrays := closed_mesh.surface_get_arrays(0)
	_check(
		(closed_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		== 18
		and (
			closed_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		).size() == 54,
		"Minimal closed barriers connect three points without end caps."
	)


func _test_explicit_portals() -> void:
	var packed_scene := load("res://levels/coastal_track.tscn") as PackedScene
	var track := packed_scene.instantiate() as TrackLevel
	root.add_child(track)
	await process_frame
	var builder := TrackBarrierBuilder.new(
		track,
		track.route_points,
		track.shortcut_definitions,
		CoastalTrack.ROAD_WIDTH,
		CoastalTrack.SHORTCUT_WIDTH,
		track._barrier_material,
		track._get_shortcut_barrier_join_clearance()
	)
	_check(
		track._barrier_material.cull_mode == BaseMaterial3D.CULL_BACK,
		"Barrier material avoids double-sided self-shadowing."
	)
	var left_offset := -CoastalTrack.ROAD_WIDTH * 0.5 + CoastalTrack.BARRIER_PATH_INSET
	var right_offset := CoastalTrack.ROAD_WIDTH * 0.5 - CoastalTrack.BARRIER_PATH_INSET
	var left_portals := builder.build_main_barrier_portals(left_offset)
	var right_portals := builder.build_main_barrier_portals(right_offset)
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

	var barrier_ring := TrackBarrierBuilder.build_miter_barrier_ring(
		track.route_points,
		right_offset
	)
	var open_chains := TrackBarrierBuilder.split_barrier_ring(
		barrier_ring,
		right_portals
	)
	var open_mesh := TrackBarrierBuilder.create_indexed_barrier_mesh(
		open_chains,
		false
	)
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
	var route_forward := TrackBarrierBuilder.get_route_forward(
		track.route_points,
		0
	)
	var route_right := Vector3.UP.cross(route_forward).normalized()
	builder.append_portal_interval(
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
	var collision_contracts := [
		{
			"visual": "MainRoad",
			"body": "MainRoadCollision",
			"layer": CoastalTrack.MAIN_COLLISION_LAYER,
			"mask": PhysicsLayers.KARTS,
			"backface": true,
		},
		{
			"visual": "Shortcut0",
			"body": "Shortcut0Collision",
			"layer": CoastalTrack.SHORTCUT_COLLISION_LAYER,
			"mask": PhysicsLayers.KARTS,
			"backface": false,
		},
		{
			"visual": "MainBarrierRight",
			"body": "MainBarrierRightCollision",
			"layer": CoastalTrack.MAIN_BARRIER_COLLISION_LAYER,
			"mask": PhysicsLayers.KARTS | PhysicsLayers.PROJECTILES,
			"backface": true,
		},
		{
			"visual": "Shortcut0BarrierRight",
			"body": "Shortcut0BarrierRightCollision",
			"layer": CoastalTrack.SHORTCUT_BARRIER_COLLISION_LAYER,
			"mask": PhysicsLayers.KARTS | PhysicsLayers.PROJECTILES,
			"backface": true,
		},
	]
	for contract in collision_contracts:
		var visual := track.get_node_or_null(contract.visual) as MeshInstance3D
		var body := track.get_node_or_null(contract.body) as StaticBody3D
		var collision := (
			body.get_child(0) as CollisionShape3D
			if body != null and body.get_child_count() > 0
			else null
		)
		var shape := (
			collision.shape as ConcavePolygonShape3D
			if collision != null
			else null
		)
		_check(
			visual != null
			and body != null
			and body.collision_layer == contract.layer
			and body.collision_mask == contract.mask
			and shape != null
			and shape.backface_collision == contract.backface,
			"%s preserves its visual name, collision name, layer, mask, and normals."
			% contract.visual
		)
	track.queue_free()
	await process_frame


func _create_circle_points(point_count: int, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point_index in point_count:
		var angle := TAU * float(point_index) / point_count
		points.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	return points


func _vectors_are_finite(vectors: PackedVector3Array) -> bool:
	for vector in vectors:
		if not vector.is_finite():
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
