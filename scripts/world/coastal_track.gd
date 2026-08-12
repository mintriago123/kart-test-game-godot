@tool
class_name CoastalTrack
extends Node3D

const JunctionBuilder = preload("res://scripts/world/track_junction_builder.gd")

signal shortcut_completed(kart: Node, entry_index: int, exit_index: int)

const ROAD_WIDTH := 17.5
const ROUTE_SUBDIVISIONS := 8
const CURB_WIDTH := 0.7
const SHORTCUT_WIDTH := 10.0
const BARRIER_HEIGHT := TrackBarrierBuilder.BARRIER_HEIGHT
const SHORTCUT_PATH_SEGMENTS := 24
const SHORTCUT_CURB_TRIM_SEGMENTS := 6
const SHORTCUT_GATE_OFFSET_SEGMENTS := 3
const SHORTCUT_ENDPOINT_HANDLE_RATIO := 0.32
const SHORTCUT_ENDPOINT_HANDLE_MAX_LENGTH := 20.0
const SHORTCUT_MIDPOINT_HANDLE_RATIO := 0.18
const BARRIER_PATH_INSET := TrackBarrierBuilder.BARRIER_PATH_INSET
const BARRIER_MITER_LIMIT := TrackBarrierBuilder.BARRIER_MITER_LIMIT
const BARRIER_THICKNESS := TrackBarrierBuilder.BARRIER_THICKNESS
const BARRIER_VERTICES_PER_POINT := TrackBarrierBuilder.BARRIER_VERTICES_PER_POINT
const PORTAL_MIN_WIDTH := TrackBarrierBuilder.PORTAL_MIN_WIDTH
const PORTAL_MAX_WIDTH := TrackBarrierBuilder.PORTAL_MAX_WIDTH
const SHORTCUT_HEIGHT_ALIGNMENT_BLEND_DISTANCE := 4.0
const SHORTCUT_JUNCTION_SURFACE_OVERLAP := 1.5
const MAIN_COLLISION_LAYER := PhysicsLayers.WORLD
const SHORTCUT_COLLISION_LAYER := PhysicsLayers.SHORTCUTS
const MAIN_BARRIER_COLLISION_LAYER := PhysicsLayers.MAIN_BARRIERS
const SHORTCUT_BARRIER_COLLISION_LAYER := PhysicsLayers.SHORTCUT_BARRIERS

var route_points: Array[Vector3] = []
var item_spawn_points: Array[Vector3] = []
var shortcut_definitions: Array[Dictionary] = []
var _shortcut_junctions: Dictionary = {}

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
	_build_shortcut_junctions()
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
	_barrier_material = _create_barrier_material(Color("#ef684e"))
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


func _build_shortcut_junctions() -> void:
	_shortcut_junctions.clear()
	var junction_builder := JunctionBuilder.new(
		route_points,
		ROAD_WIDTH,
		SHORTCUT_WIDTH
	)
	for shortcut in shortcut_definitions:
		var shortcut_points: Array[Vector3] = shortcut.points
		_shortcut_junctions[int(shortcut.id)] = {
			"entry": junction_builder.build(shortcut_points, true),
			"exit": junction_builder.build(shortcut_points, false),
		}


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
	TrackSurfaceBuilder.create_drivable_surface(
		self,
		route_points,
		ROAD_WIDTH,
		_road_material,
		"MainRoad",
		true,
		MAIN_COLLISION_LAYER
	)

	TrackSurfaceBuilder.create_curb(
		self,
		route_points,
		-ROAD_WIDTH * 0.5,
		-ROAD_WIDTH * 0.5 + CURB_WIDTH,
		true,
		_edge_material
	)
	TrackSurfaceBuilder.create_curb(
		self,
		route_points,
		ROAD_WIDTH * 0.5 - CURB_WIDTH,
		ROAD_WIDTH * 0.5,
		true,
		_edge_material
	)
	for route_index in range(0, route_points.size(), 6):
		_create_road_marker(route_index)


func _build_shortcuts() -> void:
	var barrier_builder := _create_barrier_builder()
	for shortcut in shortcut_definitions:
		var shortcut_id: int = shortcut.id
		var shortcut_name: String = shortcut.name
		var shortcut_points: Array[Vector3] = shortcut.points
		var junctions: Dictionary = _shortcut_junctions.get(shortcut_id, {})
		var entry_junction = junctions.get("entry")
		var exit_junction = junctions.get("exit")
		var trimmed_shortcut_points := _get_trimmed_shortcut_points(
			shortcut_points,
			entry_junction,
			exit_junction
		)
		var collision_shortcut_points := _get_shortcut_collision_points(
			shortcut_points,
			entry_junction,
			exit_junction
		)
		TrackSurfaceBuilder.create_shortcut_drivable_surface(
			self,
			trimmed_shortcut_points,
			SHORTCUT_WIDTH,
			_shortcut_material,
			"Shortcut%d" % shortcut_id,
			SHORTCUT_COLLISION_LAYER,
			collision_shortcut_points
		)
		for junction_data in [
			[entry_junction, "Entry"],
			[exit_junction, "Exit"],
		]:
			var junction = junction_data[0]
			if junction == null or not junction.is_valid:
				continue
			var junction_name := "Shortcut%d%sJunction" % [
				shortcut_id,
				junction_data[1],
			]
			TrackSurfaceBuilder.create_junction_surface(
				self,
				junction.left_boundary,
				junction.right_boundary,
				_shortcut_material,
				junction_name,
				MAIN_COLLISION_LAYER
			)
			TrackSurfaceBuilder.create_boundary_curb(
				self,
				junction.left_boundary,
				junction.right_boundary,
				CURB_WIDTH,
				_edge_material,
				junction_name + "CurbLeft"
			)
			TrackSurfaceBuilder.create_boundary_curb(
				self,
				junction.right_boundary,
				junction.left_boundary,
				CURB_WIDTH,
				_edge_material,
				junction_name + "CurbRight"
			)
		TrackSurfaceBuilder.create_curb(
			self,
			trimmed_shortcut_points,
			-SHORTCUT_WIDTH * 0.5,
			-SHORTCUT_WIDTH * 0.5 + CURB_WIDTH,
			false,
			_edge_material
		)
		TrackSurfaceBuilder.create_curb(
			self,
			trimmed_shortcut_points,
			SHORTCUT_WIDTH * 0.5 - CURB_WIDTH,
			SHORTCUT_WIDTH * 0.5,
			false,
			_edge_material
		)
		barrier_builder.create_shortcut_barriers(
			shortcut_points,
			"Shortcut%d" % shortcut_id,
			SHORTCUT_BARRIER_COLLISION_LAYER,
			entry_junction,
			exit_junction
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


func _get_trimmed_shortcut_points(
	shortcut_points: Array[Vector3],
	entry_junction,
	exit_junction
) -> Array[Vector3]:
	var trimmed_points: Array[Vector3] = []
	var trim_start := SHORTCUT_CURB_TRIM_SEGMENTS
	var trim_finish := shortcut_points.size() - SHORTCUT_CURB_TRIM_SEGMENTS
	if entry_junction != null and entry_junction.is_valid:
		trim_start = entry_junction.shortcut_transition_index
		trimmed_points.append(entry_junction.shortcut_transition_center)
	if exit_junction != null and exit_junction.is_valid:
		trim_finish = exit_junction.shortcut_transition_index + 1
	for point_index in range(trim_start, trim_finish):
		if (
			trimmed_points.is_empty()
			or trimmed_points[-1].distance_to(shortcut_points[point_index]) > 0.001
		):
			trimmed_points.append(shortcut_points[point_index])
	if exit_junction != null and exit_junction.is_valid:
		if (
			trimmed_points.is_empty()
			or trimmed_points[-1].distance_to(
				exit_junction.shortcut_transition_center
			) > 0.001
		):
			trimmed_points.append(exit_junction.shortcut_transition_center)
	# Keep the collision ribbons slightly interleaved at their hand-off. The
	# overlap stays well inside the junction transition, so it cannot restore
	# the old invisible shortcut triangles over the main road.
	if trimmed_points.size() >= 2:
		if entry_junction != null and entry_junction.is_valid:
			var entry_direction := (trimmed_points[0] - trimmed_points[1]).normalized()
			trimmed_points[0] += entry_direction * SHORTCUT_JUNCTION_SURFACE_OVERLAP
		if exit_junction != null and exit_junction.is_valid:
			var last_index := trimmed_points.size() - 1
			var exit_direction := (
				trimmed_points[last_index] - trimmed_points[last_index - 1]
			).normalized()
			trimmed_points[last_index] += (
				exit_direction * SHORTCUT_JUNCTION_SURFACE_OVERLAP
			)
	return trimmed_points


func _get_shortcut_collision_points(
	shortcut_points: Array[Vector3],
	entry_junction,
	exit_junction
) -> Array[Vector3]:
	if (
		entry_junction == null
		or not entry_junction.is_valid
		or exit_junction == null
		or not exit_junction.is_valid
	):
		return _get_trimmed_shortcut_points(
			shortcut_points,
			entry_junction,
			exit_junction
		)
	var collision_points: Array[Vector3] = [entry_junction.world_position]
	var first_index := clampi(
		entry_junction.shortcut_join_index,
		0,
		shortcut_points.size() - 1
	)
	var last_index := clampi(
		exit_junction.shortcut_join_index,
		first_index,
		shortcut_points.size() - 1
	)
	for point_index in range(first_index, last_index + 1):
		if collision_points[-1].distance_to(shortcut_points[point_index]) > 0.001:
			collision_points.append(shortcut_points[point_index])
	if collision_points[-1].distance_to(exit_junction.world_position) > 0.001:
		collision_points.append(exit_junction.world_position)
	return collision_points


func get_navigation_shortcut_definitions() -> Array[Dictionary]:
	var navigation_definitions: Array[Dictionary] = []
	for shortcut in shortcut_definitions:
		var result := shortcut.duplicate(true)
		var shortcut_id := int(shortcut.get("id", -1))
		var junctions: Dictionary = _shortcut_junctions.get(shortcut_id, {})
		var entry = junctions.get("entry")
		var exit = junctions.get("exit")
		var source_points: Array[Vector3] = shortcut.points
		var points := _get_trimmed_shortcut_points(source_points, entry, exit)
		if entry != null and entry.is_valid:
			var entry_centers := _get_junction_centers(entry)
			for center_index in range(entry_centers.size() - 2, -1, -1):
				points.push_front(entry_centers[center_index])
		if exit != null and exit.is_valid:
			var exit_centers := _get_junction_centers(exit)
			for center_index in range(exit_centers.size() - 2, -1, -1):
				if points[-1].distance_to(exit_centers[center_index]) > 0.001:
					points.append(exit_centers[center_index])
		result.points = points
		navigation_definitions.append(result)
	return navigation_definitions


func _get_junction_centers(junction) -> Array[Vector3]:
	var centers: Array[Vector3] = []
	if junction == null or junction.left_boundary.size() != junction.right_boundary.size():
		return centers
	for point_index in junction.left_boundary.size():
		centers.append(junction.left_boundary[point_index].lerp(junction.right_boundary[point_index], 0.5))
	return centers


func _create_barrier_builder() -> TrackBarrierBuilder:
	return TrackBarrierBuilder.new(
		self,
		route_points,
		shortcut_definitions,
		ROAD_WIDTH,
		SHORTCUT_WIDTH,
		_barrier_material,
		_get_shortcut_barrier_join_clearance(),
		_shortcut_junctions
	)


func _build_main_barriers() -> void:
	_create_barrier_builder().build_main_barriers(
		MAIN_BARRIER_COLLISION_LAYER
	)


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
	gate.collision_mask = PhysicsLayers.KARTS
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
		start
		+ TrackBarrierBuilder.get_route_forward(
			route_points,
			entry_index
		) * entry_handle_length,
		waypoint - waypoint_forward * midpoint_handle_length,
		waypoint,
		half_segment_count,
		true
	)
	_append_bezier_segment(
		points,
		waypoint,
		waypoint + waypoint_forward * midpoint_handle_length,
		end
		- TrackBarrierBuilder.get_route_forward(
			route_points,
			exit_index
		) * exit_handle_length,
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
	island_body.collision_layer = PhysicsLayers.WORLD
	island_body.collision_mask = PhysicsLayers.KARTS
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


func _create_barrier_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.68)
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material
