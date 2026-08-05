class_name CoastalTrack
extends Node3D

const ROAD_WIDTH := 13.5
const SUBDIVISIONS := 4

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
		var start := controls[index]
		var end := controls[(index + 1) % controls.size()]
		for step in SUBDIVISIONS:
			route_points.append(start.lerp(end, float(step) / SUBDIVISIONS))


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
		var island := MeshInstance3D.new()
		var island_mesh := BoxMesh.new()
		island_mesh.size = island_data[1]
		island.mesh = island_mesh
		island.position = island_data[0]
		island.material_override = _sand_material
		add_child(island)


func _build_road() -> void:
	for index in route_points.size():
		var start := route_points[index]
		var end := route_points[(index + 1) % route_points.size()]
		_create_road_segment(start, end, index % 2 == 0)


func _create_road_segment(start: Vector3, end: Vector3, add_marker: bool) -> void:
	var length := start.distance_to(end) + 1.3
	var midpoint := start.lerp(end, 0.5)
	var segment := StaticBody3D.new()
	segment.collision_layer = 1
	segment.collision_mask = 2
	add_child(segment)
	segment.position = midpoint
	segment.look_at(end, Vector3.UP)

	var road := MeshInstance3D.new()
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(ROAD_WIDTH, 0.42, length)
	road.mesh = road_mesh
	road.material_override = _road_material
	segment.add_child(road)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = road_mesh.size
	collision.shape = shape
	segment.add_child(collision)

	for side in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var edge_mesh := BoxMesh.new()
		edge_mesh.size = Vector3(0.55, 0.18, length)
		edge.mesh = edge_mesh
		edge.position = Vector3(side * (ROAD_WIDTH * 0.5 - 0.3), 0.28, 0.0)
		edge.material_override = _edge_material
		segment.add_child(edge)

	if add_marker:
		var marker := MeshInstance3D.new()
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(0.22, 0.06, minf(length * 0.42, 2.1))
		marker.mesh = marker_mesh
		marker.position.y = 0.24
		marker.material_override = _material(Color("#f7f2d0"), 0.9)
		segment.add_child(marker)


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
	for route_index in [8, 18, 29, 39]:
		item_spawn_points.append(route_points[route_index] + Vector3.UP * 1.2)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
