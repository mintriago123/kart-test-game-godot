class_name CoastalTrack
extends Node3D

const ROAD_WIDTH := 16.0
const ROUTE_SUBDIVISIONS := 8
const CURB_WIDTH := 0.7

var route_points: Array[Vector3] = []
var item_spawn_points: Array[Vector3] = []

var _road_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _sand_material: StandardMaterial3D


func _ready() -> void:
	_prepare_materials()
	_build_route()
	_build_environment()
	_build_road()
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


func _build_route() -> void:
	var controls: Array[Vector3] = [
		Vector3(0.0, 0.25, 29.0),
		Vector3(24.0, 0.25, 28.0),
		Vector3(42.0, 0.25, 15.0),
		Vector3(49.0, 0.25, -7.0),
		Vector3(39.0, 0.25, -29.0),
		Vector3(16.0, 0.25, -41.0),
		Vector3(-9.0, 0.25, -40.0),
		Vector3(-31.0, 0.65, -28.0),
		Vector3(-44.0, 2.1, -8.0),
		Vector3(-40.0, 0.65, 16.0),
		Vector3(-24.0, 0.25, 31.0),
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


func _build_environment() -> void:
	var ocean := MeshInstance3D.new()
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(180.0, 150.0)
	ocean.mesh = ocean_mesh
	ocean.position.y = -0.8
	var ocean_material := _material(Color("#167f93"), 0.36)
	ocean_material.metallic = 0.08
	ocean.material_override = ocean_material
	add_child(ocean)

	for island_data in [
		[Vector3(0.0, -0.45, 0.0), Vector3(110.0, 0.5, 92.0)],
		[Vector3(-44.0, 0.0, -8.0), Vector3(23.0, 1.5, 33.0)],
	]:
		_create_island(island_data[0], island_data[1])


func _build_road() -> void:
	var road_mesh := _create_ribbon_mesh(-ROAD_WIDTH * 0.5, ROAD_WIDTH * 0.5, 0.0)
	var road := MeshInstance3D.new()
	road.name = "ContinuousRoad"
	road.mesh = road_mesh
	road.material_override = _road_material
	add_child(road)

	var road_body := StaticBody3D.new()
	road_body.name = "RoadCollision"
	road_body.collision_layer = 1
	road_body.collision_mask = 2
	add_child(road_body)
	var road_collision := CollisionShape3D.new()
	var road_shape := road_mesh.create_trimesh_shape()
	if road_shape is ConcavePolygonShape3D:
		(road_shape as ConcavePolygonShape3D).backface_collision = true
	road_collision.shape = road_shape
	road_body.add_child(road_collision)

	_create_curb(-ROAD_WIDTH * 0.5, -ROAD_WIDTH * 0.5 + CURB_WIDTH)
	_create_curb(ROAD_WIDTH * 0.5 - CURB_WIDTH, ROAD_WIDTH * 0.5)
	for route_index in range(0, route_points.size(), 6):
		_create_road_marker(route_index)


func _create_ribbon_mesh(offset_a: float, offset_b: float, height_offset: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cumulative_distance := 0.0
	for route_index in route_points.size():
		var next_index := (route_index + 1) % route_points.size()
		var current_left := _offset_route_point(route_index, offset_a, height_offset)
		var current_right := _offset_route_point(route_index, offset_b, height_offset)
		var next_left := _offset_route_point(next_index, offset_a, height_offset)
		var next_right := _offset_route_point(next_index, offset_b, height_offset)
		var next_distance := cumulative_distance + route_points[route_index].distance_to(route_points[next_index])
		_add_surface_vertex(surface, current_left, Vector2(0.0, cumulative_distance * 0.08))
		_add_surface_vertex(surface, next_right, Vector2(1.0, next_distance * 0.08))
		_add_surface_vertex(surface, current_right, Vector2(1.0, cumulative_distance * 0.08))
		_add_surface_vertex(surface, current_left, Vector2(0.0, cumulative_distance * 0.08))
		_add_surface_vertex(surface, next_left, Vector2(0.0, next_distance * 0.08))
		_add_surface_vertex(surface, next_right, Vector2(1.0, next_distance * 0.08))
		cumulative_distance = next_distance
	surface.generate_normals()
	return surface.commit()


func _offset_route_point(route_index: int, lateral_offset: float, height_offset: float) -> Vector3:
	var previous := route_points[(route_index - 1 + route_points.size()) % route_points.size()]
	var next := route_points[(route_index + 1) % route_points.size()]
	var tangent := next - previous
	tangent.y = 0.0
	tangent = tangent.normalized()
	var right := Vector3.UP.cross(tangent).normalized()
	return route_points[route_index] + right * lateral_offset + Vector3.UP * height_offset


func _add_surface_vertex(surface: SurfaceTool, vertex: Vector3, uv: Vector2) -> void:
	surface.set_uv(uv)
	surface.add_vertex(vertex)


func _create_curb(inner_offset: float, outer_offset: float) -> void:
	var curb := MeshInstance3D.new()
	curb.mesh = _create_ribbon_mesh(inner_offset, outer_offset, 0.055)
	curb.material_override = _edge_material
	add_child(curb)


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
		post.position = start + right * side * 5.4 + Vector3.UP * 2.6
		post.material_override = _material(Color("#f15d4b"), 0.75)
		add_child(post)
	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(11.5, 1.0, 0.55)
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
		Vector3(15, 0, 42), Vector3(35, 0, 34), Vector3(55, 0, 9),
		Vector3(51, 0, -28), Vector3(25, 0, -51), Vector3(-5, 0, -51),
		Vector3(-27, 0, -42), Vector3(-56, 0, -15), Vector3(-51, 0, 24),
		Vector3(-27, 0, 43), Vector3(3, 0, 44), Vector3(13, 0, -27),
	]
	for palm_position in palm_positions:
		_create_palm(palm_position)

	for rock_position in [
		Vector3(29, 0, 4), Vector3(31, 0, -11), Vector3(-15, 0, 18),
		Vector3(-16, 0, -17), Vector3(6, 0, -21),
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
	for route_index in [16, 36, 58, 78]:
		item_spawn_points.append(route_points[route_index] + Vector3.UP * 1.2)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
