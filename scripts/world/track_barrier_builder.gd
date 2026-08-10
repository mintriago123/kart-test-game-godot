class_name TrackBarrierBuilder
extends RefCounted

const BARRIER_HEIGHT := 1.0
const BARRIER_PATH_INSET := 0.12
const BARRIER_MITER_LIMIT := 2.0
const BARRIER_THICKNESS := 0.24
const BARRIER_VERTICES_PER_POINT := 6
const PORTAL_MIN_WIDTH := 6.0
const PORTAL_MAX_WIDTH := 14.0

var _parent: Node3D
var _route_points: Array[Vector3]
var _shortcut_definitions: Array[Dictionary]
var _road_width: float
var _shortcut_width: float
var _barrier_material: StandardMaterial3D
var _shortcut_join_clearance: float
var _junctions: Dictionary


func _init(
	parent: Node3D,
	route_points: Array[Vector3],
	shortcut_definitions: Array[Dictionary],
	road_width: float,
	shortcut_width: float,
	barrier_material: StandardMaterial3D,
	shortcut_join_clearance: float,
	junctions := {}
) -> void:
	_parent = parent
	_route_points = route_points
	_shortcut_definitions = shortcut_definitions
	_road_width = road_width
	_shortcut_width = shortcut_width
	_barrier_material = barrier_material
	_shortcut_join_clearance = shortcut_join_clearance
	_junctions = junctions


func build_main_barriers(collision_layer: int) -> void:
	_create_main_barrier_side(
		-_road_width * 0.5 + BARRIER_PATH_INSET,
		"MainBarrierLeft",
		collision_layer
	)
	_create_main_barrier_side(
		_road_width * 0.5 - BARRIER_PATH_INSET,
		"MainBarrierRight",
		collision_layer
	)


func create_shortcut_barriers(
	shortcut_points: Array[Vector3],
	name_prefix: String,
	collision_layer: int,
	entry_junction = null,
	exit_junction = null
) -> void:
	for side_data in [
		[
			-_shortcut_width * 0.5 + BARRIER_PATH_INSET,
			name_prefix + "BarrierLeft",
		],
		[
			_shortcut_width * 0.5 - BARRIER_PATH_INSET,
			name_prefix + "BarrierRight",
		],
	]:
		var lateral_offset: float = side_data[0]
		var barrier_name: String = side_data[1]
		var entry_portal := find_shortcut_portal(
			shortcut_points,
			true,
			lateral_offset,
			_shortcut_join_clearance
		)
		var exit_portal := find_shortcut_portal(
			shortcut_points,
			false,
			lateral_offset,
			_shortcut_join_clearance
		)
		if entry_portal.is_empty() or exit_portal.is_empty():
			continue
		var entry_index := int(entry_portal.point_index)
		var exit_index := int(exit_portal.point_index)
		if entry_junction != null and entry_junction.is_valid:
			entry_index = entry_junction.shortcut_transition_index
		if exit_junction != null and exit_junction.is_valid:
			exit_index = exit_junction.shortcut_transition_index
		if entry_index > exit_index:
			continue
		var barrier_chain := PackedVector3Array()
		if entry_junction != null and entry_junction.is_valid:
			for junction_point in entry_junction.get_barrier_boundary(
				lateral_offset,
				BARRIER_PATH_INSET
			):
				barrier_chain.append(junction_point + Vector3.UP * 0.08)
		else:
			barrier_chain.append(
				(entry_portal.point as Vector3) + Vector3.UP * 0.08
			)
		for point_index in range(entry_index, exit_index + 1):
			var barrier_point := TrackSurfaceBuilder.offset_path_point(
				shortcut_points,
				point_index,
				lateral_offset,
				0.08,
				false
			)
			if barrier_chain[-1].distance_to(barrier_point) > 0.0001:
				barrier_chain.append(barrier_point)
		if exit_junction != null and exit_junction.is_valid:
			var exit_boundary: PackedVector3Array = exit_junction.get_barrier_boundary(
				lateral_offset,
				BARRIER_PATH_INSET
			)
			for boundary_index in range(exit_boundary.size() - 1, -1, -1):
				var exit_curve_point: Vector3 = (
					exit_boundary[boundary_index] + Vector3.UP * 0.08
				)
				if barrier_chain[-1].distance_to(exit_curve_point) > 0.0001:
					barrier_chain.append(exit_curve_point)
		else:
			var exit_point := (
				(exit_portal.point as Vector3) + Vector3.UP * 0.08
			)
			if barrier_chain[-1].distance_to(exit_point) > 0.0001:
				barrier_chain.append(exit_point)
		var barrier_mesh := create_indexed_barrier_mesh(
			[barrier_chain],
			false,
			entry_junction == null or not entry_junction.is_valid,
			exit_junction == null or not exit_junction.is_valid
		)
		_commit_barrier_mesh(barrier_mesh, barrier_name, collision_layer)


func build_main_barrier_portals(lateral_offset: float) -> Array[Vector2]:
	var intervals: Array[Vector2] = []
	var route_length := _get_route_length()
	if route_length <= 0.001:
		return intervals
	var requested_side := signf(lateral_offset)
	for shortcut in _shortcut_definitions:
		var shortcut_points: Array[Vector3] = shortcut.points
		if shortcut_points.size() < 3:
			continue
		for is_entry in [true, false]:
			var junction = _get_junction(shortcut, is_entry)
			if junction != null and junction.is_valid:
				if junction.side == requested_side:
					intervals.append_array(junction.portal_intervals)
				continue
			var portal := find_shortcut_portal(
				shortcut_points,
				is_entry,
				0.0
			)
			if portal.is_empty() or float(portal.side) != requested_side:
				continue
			var edge_progresses: Array[float] = []
			for corridor_offset in [-3.75, 3.75]:
				var edge_portal := find_shortcut_portal(
					shortcut_points,
					is_entry,
					corridor_offset
				)
				if (
					not edge_portal.is_empty()
					and float(edge_portal.side) == requested_side
				):
					edge_progresses.append(
						float(
							get_closest_route_location(
								edge_portal.point
							).progress
						)
					)
			var center_progress := float(
				get_closest_route_location(portal.point).progress
			)
			if edge_progresses.size() == 2:
				var first_delta := wrapf(
					edge_progresses[0] - center_progress + 0.5,
					0.0,
					1.0
				) - 0.5
				var second_delta := wrapf(
					edge_progresses[1] - center_progress + 0.5,
					0.0,
					1.0
				) - 0.5
				center_progress = wrapf(
					center_progress + (first_delta + second_delta) * 0.5,
					0.0,
					1.0
				)
			append_portal_interval(
				intervals,
				portal.point,
				portal.direction,
				route_length,
				center_progress
			)
	intervals.sort_custom(
		func(first: Vector2, second: Vector2) -> bool:
			return first.x < second.x
	)
	var merged: Array[Vector2] = []
	for interval in intervals:
		if merged.is_empty() or interval.x > merged[-1].y + 0.00001:
			merged.append(interval)
		else:
			var merged_interval := merged[-1]
			merged_interval.y = maxf(merged_interval.y, interval.y)
			merged[-1] = merged_interval
	return merged


func append_portal_interval(
	intervals: Array[Vector2],
	barrier_crossing_point: Vector3,
	corridor_direction: Vector3,
	route_length: float,
	center_progress_override := -1.0
) -> void:
	var route_location := get_closest_route_location(barrier_crossing_point)
	var route_forward: Vector3 = route_location.forward
	var flattened_corridor := Vector3(
		corridor_direction.x,
		0.0,
		corridor_direction.z
	)
	if flattened_corridor.length_squared() <= 0.0001:
		return
	flattened_corridor = flattened_corridor.normalized()
	var crossing_factor := absf(
		Vector2(route_forward.x, route_forward.z).normalized().cross(
			Vector2(flattened_corridor.x, flattened_corridor.z)
		)
	)
	var portal_width := clampf(
		(_shortcut_width + BARRIER_THICKNESS * 2.0 + 1.5)
		/ maxf(crossing_factor, 0.15),
		PORTAL_MIN_WIDTH,
		PORTAL_MAX_WIDTH
	)
	var half_progress := portal_width * 0.5 / route_length
	var center_progress := (
		center_progress_override
		if center_progress_override >= 0.0
		else float(route_location.progress)
	)
	var interval_start := center_progress - half_progress
	var interval_end := center_progress + half_progress
	if interval_start < 0.0:
		intervals.append(Vector2(0.0, interval_end))
		intervals.append(Vector2(1.0 + interval_start, 1.0))
	elif interval_end > 1.0:
		intervals.append(Vector2(interval_start, 1.0))
		intervals.append(Vector2(0.0, interval_end - 1.0))
	else:
		intervals.append(Vector2(interval_start, interval_end))


func find_shortcut_portal(
	shortcut_points: Array[Vector3],
	is_entry: bool,
	corridor_offset: float,
	target_lateral_override := -1.0
) -> Dictionary:
	var point_count := shortcut_points.size()
	if point_count < 2:
		return {}
	var step := 1 if is_entry else -1
	var point_index := 0 if is_entry else point_count - 1
	var previous_point := TrackSurfaceBuilder.offset_path_point(
		shortcut_points,
		point_index,
		corridor_offset,
		0.0,
		false
	)
	var previous_location := get_closest_route_location(previous_point)
	var previous_right := Vector3.UP.cross(
		previous_location.forward
	).normalized()
	var previous_lateral := (
		previous_point - (previous_location.point as Vector3)
	).dot(previous_right)
	var target_lateral := (
		target_lateral_override
		if target_lateral_override >= 0.0
		else _road_width * 0.5 - BARRIER_PATH_INSET
	)
	while point_index + step >= 0 and point_index + step < point_count:
		point_index += step
		var current_point := TrackSurfaceBuilder.offset_path_point(
			shortcut_points,
			point_index,
			corridor_offset,
			0.0,
			false
		)
		var current_location := get_closest_route_location(current_point)
		var current_right := Vector3.UP.cross(
			current_location.forward
		).normalized()
		var current_lateral := (
			current_point - (current_location.point as Vector3)
		).dot(current_right)
		var side := signf(current_lateral)
		if side != 0.0 and absf(current_lateral) >= target_lateral:
			var previous_absolute := absf(previous_lateral)
			var current_absolute := absf(current_lateral)
			var weight := 1.0
			if current_absolute - previous_absolute > 0.0001:
				weight = clampf(
					(target_lateral - previous_absolute)
					/ (current_absolute - previous_absolute),
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


func get_closest_route_location(point: Vector3) -> Dictionary:
	var flattened_point := Vector2(point.x, point.z)
	var minimum_distance := INF
	var cumulative_distance := 0.0
	var best_distance := 0.0
	var best_forward := Vector3.FORWARD
	var best_point := _route_points[0]
	var route_length := _get_route_length()
	for route_index in _route_points.size():
		var next_index := (route_index + 1) % _route_points.size()
		var start := _route_points[route_index]
		var finish := _route_points[next_index]
		var segment_2d := Vector2(
			finish.x - start.x,
			finish.z - start.z
		)
		var segment_length_squared := segment_2d.length_squared()
		var weight := 0.0
		if segment_length_squared > 0.0001:
			weight = clampf(
				(
					flattened_point - Vector2(start.x, start.z)
				).dot(segment_2d) / segment_length_squared,
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
		"progress": (
			best_distance / route_length
			if route_length > 0.001
			else 0.0
		),
		"forward": best_forward,
		"point": best_point,
	}


static func build_miter_barrier_ring(
	path_points: Array[Vector3],
	lateral_offset: float
) -> Array[Dictionary]:
	var ring: Array[Dictionary] = []
	if path_points.size() < 3:
		return ring
	var cumulative_distances := PackedFloat32Array()
	cumulative_distances.resize(path_points.size() + 1)
	for point_index in path_points.size():
		cumulative_distances[point_index + 1] = (
			cumulative_distances[point_index]
			+ path_points[point_index].distance_to(
				path_points[(point_index + 1) % path_points.size()]
			)
		)
	var route_length := cumulative_distances[-1]
	if route_length <= 0.001:
		return ring

	for point_index in path_points.size():
		var previous := path_points[
			(point_index - 1 + path_points.size()) % path_points.size()
		]
		var current := path_points[point_index]
		var next := path_points[(point_index + 1) % path_points.size()]
		var previous_direction := Vector2(
			current.x - previous.x,
			current.z - previous.z
		).normalized()
		var next_direction := Vector2(
			next.x - current.x,
			next.z - current.z
		).normalized()
		if (
			previous_direction.length_squared() <= 0.0001
			or next_direction.length_squared() <= 0.0001
		):
			continue
		var previous_normal := Vector2(
			previous_direction.y,
			-previous_direction.x
		)
		var next_normal := Vector2(
			next_direction.y,
			-next_direction.x
		)
		var current_2d := Vector2(current.x, current.z)
		var previous_offset_point := (
			current_2d + previous_normal * lateral_offset
		)
		var next_offset_point := (
			current_2d + next_normal * lateral_offset
		)
		var intersection := _intersect_lines_2d(
			previous_offset_point,
			previous_direction,
			next_offset_point,
			next_direction
		)
		var progress := cumulative_distances[point_index] / route_length
		var uses_miter := bool(intersection.valid)
		if uses_miter and absf(lateral_offset) > 0.001:
			uses_miter = (
				current_2d.distance_to(intersection.point)
				<= absf(lateral_offset) * BARRIER_MITER_LIMIT
			)
		if uses_miter:
			ring.append({
				"point": Vector3(
					intersection.point.x,
					current.y + 0.08,
					intersection.point.y
				),
				"progress": progress,
			})
		else:
			ring.append({
				"point": Vector3(
					previous_offset_point.x,
					current.y + 0.08,
					previous_offset_point.y
				),
				"progress": progress,
			})
			ring.append({
				"point": Vector3(
					next_offset_point.x,
					current.y + 0.08,
					next_offset_point.y
				),
				"progress": progress,
			})
	return ring


static func split_barrier_ring(
	barrier_ring: Array[Dictionary],
	portal_intervals: Array[Vector2]
) -> Array:
	var chains: Array = []
	var current_chain := PackedVector3Array()
	for point_index in barrier_ring.size():
		var next_index := (point_index + 1) % barrier_ring.size()
		var segment_start: Vector3 = barrier_ring[point_index].point
		var segment_end: Vector3 = barrier_ring[next_index].point
		var start_progress := float(barrier_ring[point_index].progress)
		var end_progress := (
			1.0
			if next_index == 0
			else float(barrier_ring[next_index].progress)
		)
		var allowed_ranges := _get_allowed_barrier_ranges(
			start_progress,
			end_progress,
			portal_intervals
		)
		for allowed_range in allowed_ranges:
			var allowed_start := segment_start.lerp(
				segment_end,
				allowed_range.x
			)
			var allowed_end := segment_start.lerp(
				segment_end,
				allowed_range.y
			)
			if (
				current_chain.is_empty()
				or current_chain[-1].distance_to(allowed_start) > 0.001
			):
				if current_chain.size() >= 2:
					chains.append(current_chain)
				current_chain = PackedVector3Array([allowed_start])
			elif current_chain[-1].distance_to(allowed_start) > 0.00001:
				current_chain.append(allowed_start)
			if current_chain[-1].distance_to(allowed_end) > 0.00001:
				current_chain.append(allowed_end)
	if current_chain.size() >= 2:
		chains.append(current_chain)
	if (
		chains.size() >= 2
		and (chains[-1] as PackedVector3Array)[-1].distance_to(
			(chains[0] as PackedVector3Array)[0]
		) <= 0.001
	):
		var joined := chains[-1] as PackedVector3Array
		var first_chain := chains[0] as PackedVector3Array
		for first_index in range(1, first_chain.size()):
			joined.append(first_chain[first_index])
		chains[0] = joined
		chains.pop_back()
	return chains


static func create_indexed_barrier_mesh(
	chains: Array,
	is_closed: bool,
	cap_start := true,
	cap_end := true
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for chain_value in chains:
		var chain := chain_value as PackedVector3Array
		if chain.size() < 2:
			continue
		var base_vertex := vertices.size()
		for point_index in chain.size():
			var previous_index := (
				(point_index - 1 + chain.size()) % chain.size()
				if is_closed
				else maxi(point_index - 1, 0)
			)
			var next_index := (
				(point_index + 1) % chain.size()
				if is_closed
				else mini(point_index + 1, chain.size() - 1)
			)
			var tangent := chain[next_index] - chain[previous_index]
			tangent.y = 0.0
			if tangent.length_squared() <= 0.0001:
				tangent = Vector3.FORWARD
			else:
				tangent = tangent.normalized()
			var side := Vector3.UP.cross(tangent).normalized()
			var left_bottom := (
				chain[point_index] + side * BARRIER_THICKNESS * 0.5
			)
			var right_bottom := (
				chain[point_index] - side * BARRIER_THICKNESS * 0.5
			)
			vertices.append(left_bottom)
			vertices.append(left_bottom + Vector3.UP * BARRIER_HEIGHT)
			vertices.append(right_bottom)
			vertices.append(right_bottom + Vector3.UP * BARRIER_HEIGHT)
			vertices.append(left_bottom + Vector3.UP * BARRIER_HEIGHT)
			vertices.append(right_bottom + Vector3.UP * BARRIER_HEIGHT)
			normals.append(side)
			normals.append(side)
			normals.append(-side)
			normals.append(-side)
			normals.append(Vector3.UP)
			normals.append(Vector3.UP)
		var segment_count := chain.size() if is_closed else chain.size() - 1
		for point_index in segment_count:
			var next_index := (point_index + 1) % chain.size()
			var current_base := (
				base_vertex + point_index * BARRIER_VERTICES_PER_POINT
			)
			var next_base := (
				base_vertex + next_index * BARRIER_VERTICES_PER_POINT
			)
			_append_quad_indices(
				indices,
				current_base,
				current_base + 1,
				next_base + 1,
				next_base
			)
			_append_quad_indices(
				indices,
				current_base + 2,
				next_base + 2,
				next_base + 3,
				current_base + 3
			)
			_append_quad_indices(
				indices,
				current_base + 4,
				current_base + 5,
				next_base + 5,
				next_base + 4
			)
		if not is_closed:
			var final_base := (
				base_vertex
				+ (chain.size() - 1) * BARRIER_VERTICES_PER_POINT
			)
			var start_tangent := chain[1] - chain[0]
			start_tangent.y = 0.0
			if start_tangent.length_squared() <= 0.0001:
				start_tangent = Vector3.FORWARD
			else:
				start_tangent = start_tangent.normalized()
			var end_tangent := chain[-1] - chain[-2]
			end_tangent.y = 0.0
			if end_tangent.length_squared() <= 0.0001:
				end_tangent = Vector3.FORWARD
			else:
				end_tangent = end_tangent.normalized()
			if cap_start:
				var start_cap_base := vertices.size()
				_append_barrier_cap_vertices(
					vertices,
					normals,
					[
						vertices[base_vertex],
						vertices[base_vertex + 2],
						vertices[base_vertex + 3],
						vertices[base_vertex + 1],
					],
					-start_tangent
				)
				_append_quad_indices(
					indices,
					start_cap_base,
					start_cap_base + 1,
					start_cap_base + 2,
					start_cap_base + 3
				)
			if cap_end:
				var end_cap_base := vertices.size()
				_append_barrier_cap_vertices(
					vertices,
					normals,
					[
						vertices[final_base],
						vertices[final_base + 1],
						vertices[final_base + 3],
						vertices[final_base + 2],
					],
					end_tangent
				)
				_append_quad_indices(
					indices,
					end_cap_base,
					end_cap_base + 1,
					end_cap_base + 2,
					end_cap_base + 3
				)
	var mesh := ArrayMesh.new()
	if vertices.is_empty() or indices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func get_route_forward(
	route_points: Array[Vector3],
	route_index: int
) -> Vector3:
	return (
		route_points[(route_index + 1) % route_points.size()]
		- route_points[
			(route_index - 1 + route_points.size()) % route_points.size()
		]
	).normalized()


func _create_main_barrier_side(
	lateral_offset: float,
	barrier_name: String,
	collision_layer: int
) -> void:
	var barrier_ring := build_miter_barrier_ring(
		_route_points,
		lateral_offset
	)
	if barrier_ring.size() < 3:
		return
	var portal_intervals := build_main_barrier_portals(lateral_offset)
	var barrier_mesh: ArrayMesh
	if portal_intervals.is_empty():
		var closed_ring := PackedVector3Array()
		for ring_point in barrier_ring:
			closed_ring.append(ring_point.point)
		barrier_mesh = create_indexed_barrier_mesh([closed_ring], true)
	else:
		var open_chains := split_barrier_ring(
			barrier_ring,
			portal_intervals
		)
		barrier_mesh = create_indexed_barrier_mesh(open_chains, false)
	_commit_barrier_mesh(barrier_mesh, barrier_name, collision_layer)


func _commit_barrier_mesh(
	barrier_mesh: ArrayMesh,
	barrier_name: String,
	collision_layer: int
) -> void:
	if barrier_mesh == null or barrier_mesh.get_surface_count() == 0:
		return
	var barrier_visual := MeshInstance3D.new()
	barrier_visual.name = barrier_name
	barrier_visual.mesh = barrier_mesh
	barrier_visual.material_override = _barrier_material
	_parent.add_child(barrier_visual)

	var barrier_body := StaticBody3D.new()
	barrier_body.name = barrier_name + "Collision"
	barrier_body.collision_layer = collision_layer
	barrier_body.collision_mask = (
		PhysicsLayers.KARTS | PhysicsLayers.PROJECTILES
	)
	_parent.add_child(barrier_body)
	var collision := CollisionShape3D.new()
	var shape := barrier_mesh.create_trimesh_shape()
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true
	collision.shape = shape
	barrier_body.add_child(collision)


func _get_route_length() -> float:
	var total_length := 0.0
	for route_index in _route_points.size():
		total_length += _route_points[route_index].distance_to(
			_route_points[(route_index + 1) % _route_points.size()]
		)
	return total_length


func _get_junction(shortcut: Dictionary, is_entry: bool):
	var shortcut_junctions: Dictionary = _junctions.get(int(shortcut.id), {})
	return shortcut_junctions.get("entry" if is_entry else "exit")


static func _intersect_lines_2d(
	first_point: Vector2,
	first_direction: Vector2,
	second_point: Vector2,
	second_direction: Vector2
) -> Dictionary:
	var denominator := first_direction.cross(second_direction)
	if absf(denominator) <= 0.00001:
		return {
			"valid": first_direction.dot(second_direction) > 0.0,
			"point": first_point.lerp(second_point, 0.5),
		}
	var distance := (
		second_point - first_point
	).cross(second_direction) / denominator
	return {
		"valid": true,
		"point": first_point + first_direction * distance,
	}


static func _get_allowed_barrier_ranges(
	start_progress: float,
	end_progress: float,
	portal_intervals: Array[Vector2]
) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	if end_progress - start_progress <= 0.000001:
		if not _is_progress_inside_portal(
			start_progress,
			portal_intervals
		):
			ranges.append(Vector2(0.0, 1.0))
		return ranges
	var cuts := PackedFloat32Array([start_progress, end_progress])
	for interval in portal_intervals:
		if interval.x > start_progress and interval.x < end_progress:
			cuts.append(interval.x)
		if interval.y > start_progress and interval.y < end_progress:
			cuts.append(interval.y)
	cuts.sort()
	var progress_length := end_progress - start_progress
	for cut_index in cuts.size() - 1:
		var range_start := cuts[cut_index]
		var range_end := cuts[cut_index + 1]
		if _is_progress_inside_portal(
			(range_start + range_end) * 0.5,
			portal_intervals
		):
			continue
		ranges.append(
			Vector2(
				(range_start - start_progress) / progress_length,
				(range_end - start_progress) / progress_length
			)
		)
	return ranges


static func _is_progress_inside_portal(
	progress: float,
	portal_intervals: Array[Vector2]
) -> bool:
	for interval in portal_intervals:
		if progress >= interval.x and progress <= interval.y:
			return true
	return false


static func _append_barrier_cap_vertices(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	cap_vertices: Array[Vector3],
	normal: Vector3
) -> void:
	for cap_vertex in cap_vertices:
		vertices.append(cap_vertex)
		normals.append(normal)


static func _append_quad_indices(
	indices: PackedInt32Array,
	first: int,
	second: int,
	third: int,
	fourth: int
) -> void:
	indices.append_array(PackedInt32Array([
		first, second, third,
		first, third, fourth,
	]))
