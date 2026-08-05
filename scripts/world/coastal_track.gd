class_name CoastalTrack
extends Node3D

signal shortcut_completed(kart: Node, entry_index: int, exit_index: int)

const ROAD_WIDTH := 17.5
const ROUTE_SUBDIVISIONS := 8
const CURB_WIDTH := 0.7
const SHORTCUT_WIDTH := 8.0
const BARRIER_HEIGHT := 1.0
const SHORTCUT_PATH_SEGMENTS := 24
const MAIN_COLLISION_LAYER := 1
const SHORTCUT_COLLISION_LAYER := 8

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
	var lagoon_points := _create_bezier_path(
		route_points[lagoon_entry],
		Vector3(47.0, 0.42, 33.0),
		Vector3(54.0, 0.42, 4.0),
		route_points[lagoon_exit]
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
	var canyon_points := _create_bezier_path(
		route_points[canyon_entry],
		Vector3(-38.0, 0.65, -48.0),
		Vector3(-62.0, 1.9, -20.0),
		route_points[canyon_exit]
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
		_create_drivable_surface(
			shortcut_points,
			SHORTCUT_WIDTH,
			_shortcut_material,
			"Shortcut%d" % shortcut_id,
			false,
			SHORTCUT_COLLISION_LAYER
		)
		var trimmed_shortcut_points: Array[Vector3] = []
		for point_index in range(4, shortcut_points.size() - 4):
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
		var shortcut_openings: Dictionary = {}
		for opening_index in range(0, 5):
			shortcut_openings[opening_index] = true
		for opening_index in range(shortcut_points.size() - 6, shortcut_points.size() - 1):
			shortcut_openings[opening_index] = true
		_create_barrier_path(
			shortcut_points,
			SHORTCUT_WIDTH,
			false,
			shortcut_openings,
			shortcut_openings,
			"Shortcut%d" % shortcut_id,
			SHORTCUT_COLLISION_LAYER
		)
		_create_shortcut_gate(
			shortcut_points[0],
			shortcut_points[1],
			SHORTCUT_WIDTH,
			shortcut_id,
			int(shortcut.entry_index),
			int(shortcut.exit_index),
			true
		)
		_create_shortcut_gate(
			shortcut_points.back(),
			shortcut_points[shortcut_points.size() - 2],
			SHORTCUT_WIDTH,
			shortcut_id,
			int(shortcut.entry_index),
			int(shortcut.exit_index),
			false
		)
		_create_shortcut_sign(shortcut_name, shortcut_points[2], shortcut_points[3])


func _build_main_barriers() -> void:
	var left_openings: Dictionary = {}
	var right_openings: Dictionary = {}
	for shortcut in shortcut_definitions:
		var shortcut_points: Array[Vector3] = shortcut.points
		var gate_data := [
			[int(shortcut.entry_index), true],
			[int(shortcut.exit_index), false],
		]
		for gate in gate_data:
			var gate_index: int = gate[0]
			var is_entry: bool = gate[1]
			var opens_right := _shortcut_opens_to_right(
				shortcut_points,
				gate_index,
				is_entry
			)
			var target_openings := right_openings if opens_right else left_openings
			for offset in range(-1, 2):
				var segment_index: int = (
					gate_index + offset + route_points.size()
				) % route_points.size()
				target_openings[segment_index] = true
	_create_barrier_path(
		route_points,
		ROAD_WIDTH,
		true,
		left_openings,
		right_openings,
		"Main",
		MAIN_COLLISION_LAYER
	)


func _create_barrier_path(
	path_points: Array[Vector3],
	path_width: float,
	is_closed: bool,
	left_skipped_segments: Dictionary,
	right_skipped_segments: Dictionary,
	name_prefix: String,
	collision_layer: int
) -> void:
	_create_barrier_side(
		path_points,
		-path_width * 0.5 + 0.12,
		is_closed,
		left_skipped_segments,
		name_prefix + "BarrierLeft",
		collision_layer
	)
	_create_barrier_side(
		path_points,
		path_width * 0.5 - 0.12,
		is_closed,
		right_skipped_segments,
		name_prefix + "BarrierRight",
		collision_layer
	)


func _shortcut_opens_to_right(
	shortcut_points: Array[Vector3],
	route_index: int,
	is_entry: bool
) -> bool:
	var previous := route_points[(route_index - 1 + route_points.size()) % route_points.size()]
	var next := route_points[(route_index + 1) % route_points.size()]
	var route_direction := next - previous
	route_direction.y = 0.0
	route_direction = route_direction.normalized()
	var route_right := Vector3.UP.cross(route_direction).normalized()
	var connection_direction: Vector3
	if is_entry:
		connection_direction = shortcut_points[3] - shortcut_points[0]
	else:
		connection_direction = (
			shortcut_points[shortcut_points.size() - 4]
			- shortcut_points.back()
		)
	connection_direction.y = 0.0
	return connection_direction.normalized().dot(route_right) > 0.0


func _create_barrier_side(
	path_points: Array[Vector3],
	lateral_offset: float,
	is_closed: bool,
	skipped_segments: Dictionary,
	barrier_name: String,
	collision_layer: int
) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := path_points.size() if is_closed else path_points.size() - 1
	for point_index in segment_count:
		if skipped_segments.has(point_index):
			continue
		var next_index := (point_index + 1) % path_points.size()
		var current_bottom := _offset_path_point(
			path_points,
			point_index,
			lateral_offset,
			0.08,
			is_closed
		)
		var next_bottom := _offset_path_point(
			path_points,
			next_index,
			lateral_offset,
			0.08,
			is_closed
		)
		var current_top := current_bottom + Vector3.UP * BARRIER_HEIGHT
		var next_top := next_bottom + Vector3.UP * BARRIER_HEIGHT
		_add_surface_vertex(surface, current_bottom, Vector2.ZERO)
		_add_surface_vertex(surface, next_top, Vector2.ONE)
		_add_surface_vertex(surface, next_bottom, Vector2(1.0, 0.0))
		_add_surface_vertex(surface, current_bottom, Vector2.ZERO)
		_add_surface_vertex(surface, current_top, Vector2(0.0, 1.0))
		_add_surface_vertex(surface, next_top, Vector2.ONE)
	surface.generate_normals()
	var barrier_mesh := surface.commit()

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


func _create_bezier_path(
	start: Vector3,
	control_a: Vector3,
	control_b: Vector3,
	end: Vector3
) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for step in range(SHORTCUT_PATH_SEGMENTS + 1):
		var weight := float(step) / SHORTCUT_PATH_SEGMENTS
		var inverse_weight := 1.0 - weight
		var point := (
			inverse_weight * inverse_weight * inverse_weight * start
			+ 3.0 * inverse_weight * inverse_weight * weight * control_a
			+ 3.0 * inverse_weight * weight * weight * control_b
			+ weight * weight * weight * end
		)
		var center_lift := sin(PI * weight) * 0.035
		points.append(point + Vector3.UP * center_lift)
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
	sign.text = "COSTA TURBO"
	sign.font_size = 72
	sign.outline_size = 12
	sign.modulate = Color("#15363a")
	add_child(sign)
	sign.position = start + Vector3.UP * 5.05 - forward * 0.31
	sign.look_at(start - forward, Vector3.UP)


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
