@tool
class_name CoastalTrack
extends Node3D

signal shortcut_completed(kart: Node, entry_index: int, exit_index: int)

const ROAD_WIDTH := 17.5
const ROUTE_SUBDIVISIONS := 8
const CURB_WIDTH := 0.7
const SHORTCUT_WIDTH := 10.0
const BARRIER_HEIGHT := 1.0
const SHORTCUT_PATH_SEGMENTS := 24
const SHORTCUT_CURB_TRIM_SEGMENTS := 6
const SHORTCUT_GATE_OFFSET_SEGMENTS := 3
const SHORTCUT_ENDPOINT_HANDLE_RATIO := 0.32
const SHORTCUT_ENDPOINT_HANDLE_MAX_LENGTH := 20.0
const SHORTCUT_MIDPOINT_HANDLE_RATIO := 0.18
const BARRIER_PATH_INSET := 0.12
const BARRIER_MITER_LIMIT := 2.0
const BARRIER_THICKNESS := 0.24
const PORTAL_MIN_WIDTH := 6.0
const PORTAL_MAX_WIDTH := 14.0
const SHORTCUT_HEIGHT_ALIGNMENT_BLEND_DISTANCE := 4.0
const MAIN_COLLISION_LAYER := 1
const SHORTCUT_COLLISION_LAYER := 8
const MAIN_BARRIER_COLLISION_LAYER := 16
const SHORTCUT_BARRIER_COLLISION_LAYER := 32

var route_points: Array[Vector3] = []
var item_spawn_points: Array[Vector3] = []
var shortcut_definitions: Array[Dictionary] = []

var _road_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _sand_material: StandardMaterial3D
var _barrier_material: StandardMaterial3D
var _shortcut_material: StandardMaterial3D
var _active_shortcuts: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_prepare_materials()
	_build_route()
	_define_shortcuts()
	_build_environment()
	_build_road()
	_build_shortcuts()
	_build_main_barriers()
	_build_start_arch()
	_build_decorations()
	_define_item_spawns()


func get_spawn_transform(slot: int) -> Transform3D:
	var forward := (route_points[2] - route_points[0]).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var row := slot / 2
	var column := slot % 2
	var offset := right * (-2.0 if column == 0 else 2.0) - forward * (2.8 + row * 3.2)
	var spawn_position := route_points[0] + offset + Vector3.UP * 1.0
	var transform := Transform3D(Basis.IDENTITY, spawn_position)
	return transform.looking_at(spawn_position + forward, Vector3.UP)


func get_route_length() -> float:
	var total_length := 0.0
	for route_index in route_points.size():
		total_length += route_points[route_index].distance_to(
			route_points[(route_index + 1) % route_points.size()]
		)
	return total_length


func _prepare_materials() -> void:
	_road_material = _material(Color("#33474a"), 0.9)
	_edge_material = _material(Color("#f6d66f"), 0.72)
	_sand_material = _material(Color("#e7ba68"), 1.0)
	_barrier_material = _material(Color("#ef684e"), 0.68)
	_shortcut_material = _material(Color("#2f7774"), 0.86)


func _build_route() -> void:
	var controls: Array[Vector3] = [
		Vector3(0.0, 0.25, 60.0),
		Vector3(30.0, 0.25, 64.0),
		Vector3(63.0, 0.25, 52.0),
		Vector3(82.0, 0.25, 28.0),
		Vector3(89.0, 0.25, -2.0),
		Vector3(80.0, 0.25, -35.0),
		Vector3(52.0, 0.25, -60.0),
		Vector3(18.0, 0.25, -73.0),
		Vector3(-19.0, 0.25, -72.0),
		Vector3(-52.0, 0.8, -58.0),
		Vector3(-78.0, 2.8, -34.0),
		Vector3(-89.0, 3.6, -2.0),
		Vector3(-80.0, 1.2, 31.0),
		Vector3(-55.0, 0.25, 57.0),
		Vector3(-25.0, 0.25, 70.0),
	]
	for index in controls.size():
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var current := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var following := controls[(index + 2) % controls.size()]
		for step in ROUTE_SUBDIVISIONS:
			var weight := float(step) / ROUTE_SUBDIVISIONS
			var route_point := _catmull_rom(previous, current, next, following, weight)
			route_point.y = maxf(route_point.y, 0.25)
			route_points.append(route_point)


func _define_shortcuts() -> void:
	var lagoon_entry := 18
	var lagoon_exit := 38
	var lagoon_points := _create_waypoint_shortcut_path(
		lagoon_entry,
		lagoon_exit,
		Vector3(55.0, 0.42, 16.0)
	)
	shortcut_definitions.append({
		"id": 0,
		"name": "Paso Laguna",
		"entry_index": lagoon_entry,
		"exit_index": lagoon_exit,
		"points": lagoon_points,
	})

	var canyon_entry := 66
	var canyon_exit := 90
	var canyon_points := _create_waypoint_shortcut_path(
		canyon_entry,
		canyon_exit,
		Vector3(-52.0, 1.3, -33.0)
	)
	shortcut_definitions.append({
		"id": 1,
		"name": "Corte del Cañón",
		"entry_index": canyon_entry,
		"exit_index": canyon_exit,
		"points": canyon_points,
	})


func _build_environment() -> void:
	var ocean := MeshInstance3D.new()
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(310.0, 260.0)
	ocean.mesh = ocean_mesh
	ocean.position.y = -0.8
	var ocean_material := _material(Color("#167f93"), 0.36)
	ocean_material.metallic = 0.08
	ocean.material_override = ocean_material
	add_child(ocean)

	for island_data in [
		[Vector3(0.0, -0.45, 0.0), Vector3(215.0, 0.5, 180.0)],
		[Vector3(-101.0, -0.1, -5.0), Vector3(22.0, 1.2, 46.0)],
	]:
		_create_island(island_data[0], island_data[1])


func _build_road() -> void:
	_create_drivable_surface(
		route_points,
		ROAD_WIDTH,
		_road_material,
		"MainRoad",
		true,
		MAIN_COLLISION_LAYER
	)

	_create_curb(route_points, -ROAD_WIDTH * 0.5, -ROAD_WIDTH * 0.5 + CURB_WIDTH, true)
	_create_curb(route_points, ROAD_WIDTH * 0.5 - CURB_WIDTH, ROAD_WIDTH * 0.5, true)
	for route_index in range(0, route_points.size(), 6):
		_create_road_marker(route_index)


func _create_drivable_surface(
	path_points: Array[Vector3],
	width: float,
	material: StandardMaterial3D,
	node_name: String,
	is_closed: bool,
	collision_layer: int
) -> void:
	var path_mesh := _create_ribbon_mesh(
		path_points,
		-width * 0.5,
		width * 0.5,
		0.0,
		is_closed
	)
	var path_visual := MeshInstance3D.new()
	path_visual.name = node_name
	path_visual.mesh = path_mesh
	path_visual.material_override = material
	add_child(path_visual)

	var path_body := StaticBody3D.new()
	path_body.name = node_name + "Collision"
	path_body.collision_layer = collision_layer
	path_body.collision_mask = 2
	add_child(path_body)
	var path_collision := CollisionShape3D.new()
	var path_shape := path_mesh.create_trimesh_shape()
	if path_shape is ConcavePolygonShape3D:
		(path_shape as ConcavePolygonShape3D).backface_collision = true
	path_collision.shape = path_shape
	path_body.add_child(path_collision)


func _create_shortcut_drivable_surface(
	path_points: Array[Vector3],
	node_name: String
) -> void:
	var visual_mesh := _create_ribbon_mesh(
		path_points,
		-SHORTCUT_WIDTH * 0.5,
		SHORTCUT_WIDTH * 0.5,
		0.0,
		false
	)
	var path_visual := MeshInstance3D.new()
	path_visual.name = node_name
	path_visual.mesh = visual_mesh
	path_visual.material_override = _shortcut_material
	add_child(path_visual)

	var collision_mesh := _create_shortcut_collision_mesh(path_points)
	var path_body := StaticBody3D.new()
	path_body.name = node_name + "Collision"
	path_body.collision_layer = SHORTCUT_COLLISION_LAYER
	path_body.collision_mask = 2
	add_child(path_body)
	var path_collision := CollisionShape3D.new()
	var path_shape := collision_mesh.create_trimesh_shape()
	if path_shape is ConcavePolygonShape3D:
		(path_shape as ConcavePolygonShape3D).backface_collision = false
	path_collision.shape = path_shape
	path_body.add_child(path_collision)


func _create_shortcut_collision_mesh(path_points: Array[Vector3]) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index in path_points.size() - 1:
		var next_index := point_index + 1
		var current_left := _offset_path_point(
			path_points,
			point_index,
			-SHORTCUT_WIDTH * 0.5,
			0.0,
			false
		)
		var current_right := _offset_path_point(
			path_points,
			point_index,
			SHORTCUT_WIDTH * 0.5,
			0.0,
			false
		)
		var next_left := _offset_path_point(
			path_points,
			next_index,
			-SHORTCUT_WIDTH * 0.5,
			0.0,
			false
		)
		var next_right := _offset_path_point(
			path_points,
			next_index,
			SHORTCUT_WIDTH * 0.5,
			0.0,
			false
		)
		_add_surface_vertex(surface, current_left, Vector2.ZERO)
		_add_surface_vertex(surface, current_right, Vector2(1.0, 0.0))
		_add_surface_vertex(surface, next_right, Vector2.ONE)
		_add_surface_vertex(surface, current_left, Vector2.ZERO)
		_add_surface_vertex(surface, next_right, Vector2.ONE)
		_add_surface_vertex(surface, next_left, Vector2(0.0, 1.0))
	surface.generate_normals()
	return surface.commit()


func _create_ribbon_mesh(
	path_points: Array[Vector3],
	offset_a: float,
	offset_b: float,
	height_offset: float,
	is_closed: bool
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cumulative_distance := 0.0
	var segment_count := path_points.size() if is_closed else path_points.size() - 1
	for point_index in segment_count:
		var next_index := (point_index + 1) % path_points.size()
		var current_left := _offset_path_point(path_points, point_index, offset_a, height_offset, is_closed)
		var current_right := _offset_path_point(path_points, point_index, offset_b, height_offset, is_closed)
		var next_left := _offset_path_point(path_points, next_index, offset_a, height_offset, is_closed)
		var next_right := _offset_path_point(path_points, next_index, offset_b, height_offset, is_closed)
		var next_distance := cumulative_distance + path_points[point_index].distance_to(path_points[next_index])
		_add_surface_vertex(surface, current_left, Vector2(0.0, cumulative_distance * 0.08))
		_add_surface_vertex(surface, next_right, Vector2(1.0, next_distance * 0.08))
		_add_surface_vertex(surface, current_right, Vector2(1.0, cumulative_distance * 0.08))
		_add_surface_vertex(surface, current_left, Vector2(0.0, cumulative_distance * 0.08))
		_add_surface_vertex(surface, next_left, Vector2(0.0, next_distance * 0.08))
		_add_surface_vertex(surface, next_right, Vector2(1.0, next_distance * 0.08))
		cumulative_distance = next_distance
	surface.generate_normals()
	return surface.commit()


func _offset_path_point(
	path_points: Array[Vector3],
	point_index: int,
	lateral_offset: float,
	height_offset: float,
	is_closed: bool
) -> Vector3:
	var previous_index := point_index - 1
	var next_index := point_index + 1
	if is_closed:
		previous_index = (previous_index + path_points.size()) % path_points.size()
		next_index %= path_points.size()
	else:
		previous_index = maxi(previous_index, 0)
		next_index = mini(next_index, path_points.size() - 1)
	var previous := path_points[previous_index]
	var next := path_points[next_index]
	var tangent := next - previous
	tangent.y = 0.0
	tangent = tangent.normalized()
	var right := Vector3.UP.cross(tangent).normalized()
	return path_points[point_index] + right * lateral_offset + Vector3.UP * height_offset


func _add_surface_vertex(surface: SurfaceTool, vertex: Vector3, uv: Vector2) -> void:
	surface.set_uv(uv)
	surface.add_vertex(vertex)


func _create_curb(
	path_points: Array[Vector3],
	inner_offset: float,
	outer_offset: float,
	is_closed: bool
) -> void:
	var curb := MeshInstance3D.new()
	curb.mesh = _create_ribbon_mesh(path_points, inner_offset, outer_offset, 0.055, is_closed)
	curb.material_override = _edge_material
	add_child(curb)


func _build_shortcuts() -> void:
	for shortcut in shortcut_definitions:
		var shortcut_id: int = shortcut.id
		var shortcut_name: String = shortcut.name
		var shortcut_points: Array[Vector3] = shortcut.points
		_create_shortcut_drivable_surface(
			shortcut_points,
			"Shortcut%d" % shortcut_id
		)
		var trimmed_shortcut_points: Array[Vector3] = []
		for point_index in range(
			SHORTCUT_CURB_TRIM_SEGMENTS,
			shortcut_points.size() - SHORTCUT_CURB_TRIM_SEGMENTS
		):
			trimmed_shortcut_points.append(shortcut_points[point_index])
		_create_curb(
			trimmed_shortcut_points,
			-SHORTCUT_WIDTH * 0.5,
			-SHORTCUT_WIDTH * 0.5 + CURB_WIDTH,
			false
		)
		_create_curb(
			trimmed_shortcut_points,
			SHORTCUT_WIDTH * 0.5 - CURB_WIDTH,
			SHORTCUT_WIDTH * 0.5,
			false
		)
		_create_shortcut_barriers(
			shortcut_points,
			"Shortcut%d" % shortcut_id,
			SHORTCUT_BARRIER_COLLISION_LAYER
		)
		_create_shortcut_gate(
			shortcut_points[SHORTCUT_GATE_OFFSET_SEGMENTS],
			shortcut_points[SHORTCUT_GATE_OFFSET_SEGMENTS + 1],
			SHORTCUT_WIDTH,
			shortcut_id,
			int(shortcut.entry_index),
			int(shortcut.exit_index),
			true
		)
		var exit_gate_index := (
			shortcut_points.size() - 1 - SHORTCUT_GATE_OFFSET_SEGMENTS
		)
		_create_shortcut_gate(
			shortcut_points[exit_gate_index],
			shortcut_points[exit_gate_index - 1],
			SHORTCUT_WIDTH,
			shortcut_id,
			int(shortcut.entry_index),
			int(shortcut.exit_index),
			false
		)
		_create_shortcut_sign(shortcut_name, shortcut_points[2], shortcut_points[3])


func _build_main_barriers() -> void:
	_create_main_barrier_side(
		-ROAD_WIDTH * 0.5 + BARRIER_PATH_INSET,
		"MainBarrierLeft",
		MAIN_BARRIER_COLLISION_LAYER
	)
	_create_main_barrier_side(
		ROAD_WIDTH * 0.5 - BARRIER_PATH_INSET,
		"MainBarrierRight",
		MAIN_BARRIER_COLLISION_LAYER
	)


func _create_main_barrier_side(
	lateral_offset: float,
	barrier_name: String,
	collision_layer: int
) -> void:
	var barrier_ring := _build_miter_barrier_ring(route_points, lateral_offset)
	if barrier_ring.size() < 3:
		return
	var portal_intervals := _build_main_barrier_portals(lateral_offset)
	var barrier_mesh: ArrayMesh
	if portal_intervals.is_empty():
		var closed_ring := PackedVector3Array()
		for ring_point in barrier_ring:
			closed_ring.append(ring_point.point)
		barrier_mesh = _create_indexed_barrier_mesh([closed_ring], true)
	else:
		var open_chains := _split_barrier_ring(barrier_ring, portal_intervals)
		barrier_mesh = _create_indexed_barrier_mesh(open_chains, false)
	_commit_barrier_mesh(barrier_mesh, barrier_name, collision_layer)


func _build_miter_barrier_ring(
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
		var next_normal := Vector2(next_direction.y, -next_direction.x)
		var current_2d := Vector2(current.x, current.z)
		var previous_offset_point := (
			current_2d + previous_normal * lateral_offset
		)
		var next_offset_point := current_2d + next_normal * lateral_offset
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


func _intersect_lines_2d(
	first_point: Vector2,
	first_direction: Vector2,
	second_point: Vector2,
	second_direction: Vector2
) -> Dictionary:
	var denominator := first_direction.cross(second_direction)
	if absf(denominator) <= 0.00001:
		return {
			"valid": true,
			"point": first_point.lerp(second_point, 0.5),
		}
	var distance := (
		second_point - first_point
	).cross(second_direction) / denominator
	return {
		"valid": true,
		"point": first_point + first_direction * distance,
	}


func _build_main_barrier_portals(lateral_offset: float) -> Array[Vector2]:
	var intervals: Array[Vector2] = []
	var route_length := get_route_length()
	if route_length <= 0.001:
		return intervals
	var requested_side := signf(lateral_offset)
	for shortcut in shortcut_definitions:
		var shortcut_points: Array[Vector3] = shortcut.points
		if shortcut_points.size() < 3:
			continue
		for is_entry in [true, false]:
			var portal := _find_shortcut_portal(shortcut_points, is_entry, 0.0)
			if portal.is_empty() or float(portal.side) != requested_side:
				continue
			var edge_progresses: Array[float] = []
			for corridor_offset in [-3.75, 3.75]:
				var edge_portal := _find_shortcut_portal(
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
							_get_closest_route_location(
								edge_portal.point
							).progress
						)
					)
			var center_progress := float(
				_get_closest_route_location(portal.point).progress
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
			_append_portal_interval(
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


func _append_portal_interval(
	intervals: Array[Vector2],
	barrier_crossing_point: Vector3,
	corridor_direction: Vector3,
	route_length: float,
	center_progress_override := -1.0
) -> void:
	var route_location := _get_closest_route_location(barrier_crossing_point)
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
		(SHORTCUT_WIDTH + BARRIER_THICKNESS * 2.0 + 1.5)
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


func _find_shortcut_portal(
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
	var previous_point := _offset_path_point(
		shortcut_points,
		point_index,
		corridor_offset,
		0.0,
		false
	)
	var previous_location := _get_closest_route_location(previous_point)
	var previous_right := Vector3.UP.cross(
		previous_location.forward
	).normalized()
	var previous_lateral := (
		previous_point - (previous_location.point as Vector3)
	).dot(previous_right)
	var target_lateral := (
		target_lateral_override
		if target_lateral_override >= 0.0
		else ROAD_WIDTH * 0.5 - BARRIER_PATH_INSET
	)
	while point_index + step >= 0 and point_index + step < point_count:
		point_index += step
		var current_point := _offset_path_point(
			shortcut_points,
			point_index,
			corridor_offset,
			0.0,
			false
		)
		var current_location := _get_closest_route_location(current_point)
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


func _get_closest_route_location(point: Vector3) -> Dictionary:
	var flattened_point := Vector2(point.x, point.z)
	var minimum_distance := INF
	var cumulative_distance := 0.0
	var best_distance := 0.0
	var best_forward := Vector3.FORWARD
	var best_point := route_points[0]
	var route_length := get_route_length()
	for route_index in route_points.size():
		var next_index := (route_index + 1) % route_points.size()
		var start := route_points[route_index]
		var finish := route_points[next_index]
		var segment_2d := Vector2(finish.x - start.x, finish.z - start.z)
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
		"progress": best_distance / route_length if route_length > 0.001 else 0.0,
		"forward": best_forward,
		"point": best_point,
	}


func _split_barrier_ring(
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
			var allowed_start := segment_start.lerp(segment_end, allowed_range.x)
			var allowed_end := segment_start.lerp(segment_end, allowed_range.y)
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


func _get_allowed_barrier_ranges(
	start_progress: float,
	end_progress: float,
	portal_intervals: Array[Vector2]
) -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	if end_progress - start_progress <= 0.000001:
		if not _is_progress_inside_portal(start_progress, portal_intervals):
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


func _is_progress_inside_portal(
	progress: float,
	portal_intervals: Array[Vector2]
) -> bool:
	for interval in portal_intervals:
		if progress >= interval.x and progress <= interval.y:
			return true
	return false


func _create_indexed_barrier_mesh(chains: Array, is_closed: bool) -> ArrayMesh:
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
			var left_bottom := chain[point_index] + side * BARRIER_THICKNESS * 0.5
			var right_bottom := chain[point_index] - side * BARRIER_THICKNESS * 0.5
			vertices.append(left_bottom)
			vertices.append(left_bottom + Vector3.UP * BARRIER_HEIGHT)
			vertices.append(right_bottom)
			vertices.append(right_bottom + Vector3.UP * BARRIER_HEIGHT)
			normals.append(side)
			normals.append((side + Vector3.UP * 0.2).normalized())
			normals.append(-side)
			normals.append((-side + Vector3.UP * 0.2).normalized())
		var segment_count := chain.size() if is_closed else chain.size() - 1
		for point_index in segment_count:
			var next_index := (point_index + 1) % chain.size()
			var current_base := base_vertex + point_index * 4
			var next_base := base_vertex + next_index * 4
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
				current_base + 1,
				current_base + 3,
				next_base + 3,
				next_base + 1
			)
		if not is_closed:
			var final_base := base_vertex + (chain.size() - 1) * 4
			_append_quad_indices(
				indices,
				base_vertex,
				base_vertex + 2,
				base_vertex + 3,
				base_vertex + 1
			)
			_append_quad_indices(
				indices,
				final_base,
				final_base + 1,
				final_base + 3,
				final_base + 2
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


func _append_quad_indices(
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
	add_child(barrier_visual)

	var barrier_body := StaticBody3D.new()
	barrier_body.name = barrier_name + "Collision"
	barrier_body.collision_layer = collision_layer
	barrier_body.collision_mask = 2
	add_child(barrier_body)
	var collision := CollisionShape3D.new()
	var shape := barrier_mesh.create_trimesh_shape()
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true
	collision.shape = shape
	barrier_body.add_child(collision)


func _create_shortcut_barriers(
	shortcut_points: Array[Vector3],
	name_prefix: String,
	collision_layer: int
) -> void:
	for side_data in [
		[-SHORTCUT_WIDTH * 0.5 + BARRIER_PATH_INSET, name_prefix + "BarrierLeft"],
		[SHORTCUT_WIDTH * 0.5 - BARRIER_PATH_INSET, name_prefix + "BarrierRight"],
	]:
		var lateral_offset: float = side_data[0]
		var barrier_name: String = side_data[1]
		var join_clearance := _get_shortcut_barrier_join_clearance()
		var entry_portal := _find_shortcut_portal(
			shortcut_points,
			true,
			lateral_offset,
			join_clearance
		)
		var exit_portal := _find_shortcut_portal(
			shortcut_points,
			false,
			lateral_offset,
			join_clearance
		)
		if entry_portal.is_empty() or exit_portal.is_empty():
			continue
		var entry_index := int(entry_portal.point_index)
		var exit_index := int(exit_portal.point_index)
		if entry_index > exit_index:
			continue
		var barrier_chain := PackedVector3Array([
			(entry_portal.point as Vector3) + Vector3.UP * 0.08,
		])
		for point_index in range(entry_index, exit_index + 1):
			var barrier_point := _offset_path_point(
				shortcut_points,
				point_index,
				lateral_offset,
				0.08,
				false
			)
			if barrier_chain[-1].distance_to(barrier_point) > 0.0001:
				barrier_chain.append(barrier_point)
		var exit_point := (exit_portal.point as Vector3) + Vector3.UP * 0.08
		if barrier_chain[-1].distance_to(exit_point) > 0.0001:
			barrier_chain.append(exit_point)
		var barrier_mesh := _create_indexed_barrier_mesh(
			[barrier_chain],
			false
		)
		_commit_barrier_mesh(barrier_mesh, barrier_name, collision_layer)


func _get_shortcut_barrier_join_clearance() -> float:
	return ROAD_WIDTH * 0.5 - BARRIER_PATH_INSET


func _get_closest_main_route_point(point: Vector3) -> Vector3:
	var flattened_point := Vector2(point.x, point.z)
	var minimum_distance := INF
	var closest_route_point := route_points[0]
	for route_index in route_points.size():
		var next_index := (route_index + 1) % route_points.size()
		var segment_start := Vector2(route_points[route_index].x, route_points[route_index].z)
		var segment_end := Vector2(route_points[next_index].x, route_points[next_index].z)
		var segment := segment_end - segment_start
		var segment_length_squared := segment.length_squared()
		var weight := 0.0
		if segment_length_squared > 0.0001:
			weight = clampf(
				(flattened_point - segment_start).dot(segment) / segment_length_squared,
				0.0,
				1.0
			)
		var closest_flattened_point := segment_start + segment * weight
		var distance := flattened_point.distance_to(closest_flattened_point)
		if distance < minimum_distance:
			minimum_distance = distance
			closest_route_point = route_points[route_index].lerp(
				route_points[next_index],
				weight
			)
	return closest_route_point


func _align_shortcut_junction_heights(points: Array[Vector3]) -> void:
	var full_alignment_clearance := ROAD_WIDTH * 0.5 + SHORTCUT_WIDTH * 0.5
	for point_index in points.size():
		var shortcut_point := points[point_index]
		var closest_route_point := _get_closest_main_route_point(shortcut_point)
		var clearance := Vector2(shortcut_point.x, shortcut_point.z).distance_to(
			Vector2(closest_route_point.x, closest_route_point.z)
		)
		var alignment_weight := clampf(
			(
				full_alignment_clearance
				+ SHORTCUT_HEIGHT_ALIGNMENT_BLEND_DISTANCE
				- clearance
			) / SHORTCUT_HEIGHT_ALIGNMENT_BLEND_DISTANCE,
			0.0,
			1.0
		)
		alignment_weight = smoothstep(0.0, 1.0, alignment_weight)
		shortcut_point.y = lerpf(
			shortcut_point.y,
			closest_route_point.y + 0.018,
			alignment_weight
		)
		points[point_index] = shortcut_point


func _point_to_segment_distance_2d(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var weight := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_to(segment_start + segment * weight)


func _get_route_forward(route_index: int) -> Vector3:
	var previous_index := (route_index - 1 + route_points.size()) % route_points.size()
	var next_index := (route_index + 1) % route_points.size()
	return (route_points[next_index] - route_points[previous_index]).normalized()


func _create_shortcut_gate(
	gate_position: Vector3,
	look_position: Vector3,
	gate_width: float,
	shortcut_id: int,
	entry_index: int,
	exit_index: int,
	is_entry: bool
) -> void:
	var gate := Area3D.new()
	gate.name = "Shortcut%d%sGate" % [shortcut_id, "Entry" if is_entry else "Exit"]
	gate.collision_layer = 0
	gate.collision_mask = 2
	gate.monitoring = true
	add_child(gate)
	gate.position = gate_position + Vector3.UP * 0.7
	gate.look_at(look_position + Vector3.UP * 0.7, Vector3.UP)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(gate_width * 1.3, 2.6, 4.5)
	collision.shape = shape
	gate.add_child(collision)
	if is_entry:
		gate.body_entered.connect(
			func(body: Node3D) -> void: _handle_shortcut_entry(body, shortcut_id)
		)
	else:
		gate.body_entered.connect(
			func(body: Node3D) -> void:
				_handle_shortcut_exit(body, shortcut_id, entry_index, exit_index)
		)


func _handle_shortcut_entry(body: Node3D, shortcut_id: int) -> void:
	if not body is Kart:
		return
	body.set_shortcut_surface_enabled(true)
	_active_shortcuts[body.get_instance_id()] = shortcut_id


func _handle_shortcut_exit(
	body: Node3D,
	shortcut_id: int,
	entry_index: int,
	exit_index: int
) -> void:
	if not body is Kart:
		return
	var kart_id := body.get_instance_id()
	if int(_active_shortcuts.get(kart_id, -1)) != shortcut_id:
		return
	_active_shortcuts.erase(kart_id)
	body.set_shortcut_surface_enabled(false)
	shortcut_completed.emit(body, entry_index, exit_index)


func _create_shortcut_sign(label_text: String, sign_position: Vector3, look_position: Vector3) -> void:
	var sign := Label3D.new()
	sign.text = "ATAJO\n" + label_text.to_upper()
	sign.font_size = 44
	sign.outline_size = 10
	sign.modulate = Color("#fff0a8")
	add_child(sign)
	sign.position = sign_position + Vector3.UP * 3.2
	sign.look_at(look_position + Vector3.UP * 2.0, Vector3.UP)


func _append_bezier_segment(
	points: Array[Vector3],
	start: Vector3,
	control_a: Vector3,
	control_b: Vector3,
	end: Vector3,
	segment_count: int,
	include_start: bool
) -> void:
	var first_step := 0 if include_start else 1
	for step in range(first_step, segment_count + 1):
		var weight := float(step) / segment_count
		var inverse_weight := 1.0 - weight
		var point := (
			inverse_weight * inverse_weight * inverse_weight * start
			+ 3.0 * inverse_weight * inverse_weight * weight * control_a
			+ 3.0 * inverse_weight * weight * weight * control_b
			+ weight * weight * weight * end
		)
		var center_lift := sin(PI * weight) * 0.035
		points.append(point + Vector3.UP * center_lift)


func _create_waypoint_shortcut_path(
	entry_index: int,
	exit_index: int,
	waypoint: Vector3
) -> Array[Vector3]:
	var start := route_points[entry_index]
	var end := route_points[exit_index]
	var entry_to_waypoint := (waypoint - start).normalized()
	var waypoint_to_exit := (end - waypoint).normalized()
	var waypoint_forward := (entry_to_waypoint + waypoint_to_exit).normalized()
	var entry_handle_length := minf(
		start.distance_to(waypoint) * SHORTCUT_ENDPOINT_HANDLE_RATIO,
		SHORTCUT_ENDPOINT_HANDLE_MAX_LENGTH
	)
	var exit_handle_length := minf(
		waypoint.distance_to(end) * SHORTCUT_ENDPOINT_HANDLE_RATIO,
		SHORTCUT_ENDPOINT_HANDLE_MAX_LENGTH
	)
	var midpoint_handle_length := minf(
		minf(start.distance_to(waypoint), waypoint.distance_to(end))
		* SHORTCUT_MIDPOINT_HANDLE_RATIO,
		10.0
	)
	var half_segment_count := SHORTCUT_PATH_SEGMENTS / 2
	var points: Array[Vector3] = []
	_append_bezier_segment(
		points,
		start,
		start + _get_route_forward(entry_index) * entry_handle_length,
		waypoint - waypoint_forward * midpoint_handle_length,
		waypoint,
		half_segment_count,
		true
	)
	_append_bezier_segment(
		points,
		waypoint,
		waypoint + waypoint_forward * midpoint_handle_length,
		end - _get_route_forward(exit_index) * exit_handle_length,
		end,
		half_segment_count,
		false
	)
	_align_shortcut_junction_heights(points)
	return points


func _create_road_marker(route_index: int) -> void:
	var next_index := (route_index + 1) % route_points.size()
	var start := route_points[route_index]
	var end := route_points[next_index]
	var marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.22, 0.045, minf(start.distance_to(end) * 0.72, 2.2))
	marker.mesh = marker_mesh
	marker.material_override = _material(Color("#f7f2d0"), 0.9)
	add_child(marker)
	marker.position = start.lerp(end, 0.5) + Vector3.UP * 0.055
	marker.look_at(end, Vector3.UP)


func _create_island(island_position: Vector3, island_size: Vector3) -> void:
	var island_body := StaticBody3D.new()
	island_body.collision_layer = 1
	island_body.collision_mask = 2
	island_body.position = island_position
	add_child(island_body)
	var island := MeshInstance3D.new()
	var island_mesh := BoxMesh.new()
	island_mesh.size = island_size
	island.mesh = island_mesh
	island.material_override = _sand_material
	island_body.add_child(island)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = island_size
	collision.shape = shape
	island_body.add_child(collision)


func _catmull_rom(
	previous: Vector3,
	current: Vector3,
	next: Vector3,
	following: Vector3,
	weight: float
) -> Vector3:
	var squared_weight := weight * weight
	var cubed_weight := squared_weight * weight
	return 0.5 * (
		2.0 * current
		+ (-previous + next) * weight
		+ (2.0 * previous - 5.0 * current + 4.0 * next - following) * squared_weight
		+ (-previous + 3.0 * current - 3.0 * next + following) * cubed_weight
	)


func _build_start_arch() -> void:
	var start := route_points[0]
	var forward := (route_points[2] - start).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.7, 5.2, 0.7)
		post.mesh = post_mesh
		post.position = start + right * side * 7.3 + Vector3.UP * 2.6
		post.material_override = _material(Color("#f15d4b"), 0.75)
		add_child(post)
	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(15.4, 1.0, 0.55)
	banner.mesh = banner_mesh
	add_child(banner)
	banner.position = start + Vector3.UP * 5.0
	banner.look_at(start + forward, Vector3.UP)
	banner.material_override = _material(Color("#f5d66f"), 0.7)

	var sign := Label3D.new()
	sign.text = _get_start_banner_text()
	sign.font_size = 72
	sign.outline_size = 12
	sign.modulate = Color("#15363a")
	add_child(sign)
	sign.position = start + Vector3.UP * 5.05 - forward * 0.31
	sign.look_at(start - forward, Vector3.UP)


func _get_start_banner_text() -> String:
	return "COSTA TURBO"


func _build_decorations() -> void:
	var palm_positions: Array[Vector3] = [
		Vector3(12, 0, 47), Vector3(42, 0, 50), Vector3(70, 0, 35),
		Vector3(72, 0, 3), Vector3(67, 0, -34), Vector3(41, 0, -53),
		Vector3(10, 0, -60), Vector3(-22, 0, -57), Vector3(-51, 0, -42),
		Vector3(-69, 0, -12), Vector3(-66, 0, 24), Vector3(-45, 0, 48),
		Vector3(-15, 0, 52), Vector3(18, 0, 12), Vector3(-8, 0, -18),
	]
	for palm_position in palm_positions:
		_create_palm(palm_position)

	for rock_position in [
		Vector3(37, 0, 12), Vector3(46, 0, -18), Vector3(-25, 0, 23),
		Vector3(-34, 0, -18), Vector3(8, 0, -38), Vector3(-60, 0, 7),
	]:
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 2.0
		rock_mesh.height = 3.2
		rock.mesh = rock_mesh
		rock.scale = Vector3(1.0, 0.65, 0.8)
		rock.position = rock_position
		rock.material_override = _material(Color("#9b775e"), 1.0)
		add_child(rock)


func _create_palm(palm_position: Vector3) -> void:
	var palm := Node3D.new()
	palm.position = palm_position
	add_child(palm)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.24
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = 4.7
	trunk.mesh = trunk_mesh
	trunk.position.y = 2.35
	trunk.material_override = _material(Color("#8a5b3b"), 0.9)
	palm.add_child(trunk)

	for leaf_index in 5:
		var leaf := MeshInstance3D.new()
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = Vector3(0.35, 0.12, 3.1)
		leaf.mesh = leaf_mesh
		leaf.position = Vector3(0.0, 4.78, 0.0)
		leaf.rotation.y = leaf_index * TAU / 5.0
		leaf.rotation.x = -0.26
		leaf.material_override = _material(Color("#3d9b61"), 0.82)
		palm.add_child(leaf)


func _define_item_spawns() -> void:
	for route_index in [14, 45, 76, 108]:
		item_spawn_points.append(route_points[route_index] + Vector3.UP * 1.2)
	for shortcut in shortcut_definitions:
		var shortcut_points: Array[Vector3] = shortcut.points
		item_spawn_points.append(
			shortcut_points[shortcut_points.size() / 2] + Vector3.UP * 1.2
		)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
