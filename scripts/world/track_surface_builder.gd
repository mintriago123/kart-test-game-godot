class_name TrackSurfaceBuilder
extends RefCounted

const CURB_HEIGHT_OFFSET := 0.055
const UV_DISTANCE_SCALE := 0.08


static func create_drivable_surface(
	parent: Node3D,
	path_points: Array[Vector3],
	width: float,
	material: StandardMaterial3D,
	node_name: String,
	is_closed: bool,
	collision_layer: int
) -> void:
	var path_mesh := create_ribbon_mesh(
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
	parent.add_child(path_visual)

	var path_body := StaticBody3D.new()
	path_body.name = node_name + "Collision"
	path_body.collision_layer = collision_layer
	path_body.collision_mask = PhysicsLayers.KARTS
	parent.add_child(path_body)
	var path_collision := CollisionShape3D.new()
	var path_shape := path_mesh.create_trimesh_shape()
	if path_shape is ConcavePolygonShape3D:
		(path_shape as ConcavePolygonShape3D).backface_collision = true
	path_collision.shape = path_shape
	path_body.add_child(path_collision)


static func create_shortcut_drivable_surface(
	parent: Node3D,
	path_points: Array[Vector3],
	width: float,
	material: StandardMaterial3D,
	node_name: String,
	collision_layer: int
) -> void:
	var visual_mesh := create_ribbon_mesh(
		path_points,
		-width * 0.5,
		width * 0.5,
		0.0,
		false
	)
	var path_visual := MeshInstance3D.new()
	path_visual.name = node_name
	path_visual.mesh = visual_mesh
	path_visual.material_override = material
	parent.add_child(path_visual)

	var collision_mesh := create_shortcut_collision_mesh(path_points, width)
	var path_body := StaticBody3D.new()
	path_body.name = node_name + "Collision"
	path_body.collision_layer = collision_layer
	path_body.collision_mask = PhysicsLayers.KARTS
	parent.add_child(path_body)
	var path_collision := CollisionShape3D.new()
	var path_shape := collision_mesh.create_trimesh_shape()
	if path_shape is ConcavePolygonShape3D:
		(path_shape as ConcavePolygonShape3D).backface_collision = false
	path_collision.shape = path_shape
	path_body.add_child(path_collision)


static func create_junction_surface(
	parent: Node3D,
	left_boundary: PackedVector3Array,
	right_boundary: PackedVector3Array,
	material: StandardMaterial3D,
	node_name: String,
	collision_layer: int
) -> void:
	var junction_mesh := create_boundary_ribbon_mesh(
		left_boundary,
		right_boundary,
		0.012
	)
	if junction_mesh.get_surface_count() == 0:
		return
	var junction_visual := MeshInstance3D.new()
	junction_visual.name = node_name
	junction_visual.mesh = junction_mesh
	junction_visual.material_override = material
	parent.add_child(junction_visual)

	var junction_body := StaticBody3D.new()
	junction_body.name = node_name + "Collision"
	junction_body.collision_layer = collision_layer
	junction_body.collision_mask = PhysicsLayers.KARTS
	parent.add_child(junction_body)
	var junction_collision := CollisionShape3D.new()
	var junction_shape := junction_mesh.create_trimesh_shape()
	if junction_shape is ConcavePolygonShape3D:
		(junction_shape as ConcavePolygonShape3D).backface_collision = true
	junction_collision.shape = junction_shape
	junction_body.add_child(junction_collision)


static func create_boundary_curb(
	parent: Node3D,
	boundary: PackedVector3Array,
	opposite_boundary: PackedVector3Array,
	width: float,
	material: StandardMaterial3D,
	node_name: String
) -> void:
	if boundary.size() < 2 or boundary.size() != opposite_boundary.size():
		return
	var inner_boundary := PackedVector3Array()
	for point_index in boundary.size():
		var direction := opposite_boundary[point_index] - boundary[point_index]
		direction.y = 0.0
		if direction.length_squared() <= 0.0001:
			inner_boundary.append(boundary[point_index])
		else:
			inner_boundary.append(
				boundary[point_index] + direction.normalized() * width
			)
	var curb := MeshInstance3D.new()
	curb.name = node_name
	curb.mesh = create_boundary_ribbon_mesh(
		boundary,
		inner_boundary,
		CURB_HEIGHT_OFFSET
	)
	curb.material_override = material
	parent.add_child(curb)


static func create_shortcut_collision_mesh(
	path_points: Array[Vector3],
	width: float
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index in path_points.size() - 1:
		var next_index := point_index + 1
		var current_left := offset_path_point(
			path_points,
			point_index,
			-width * 0.5,
			0.0,
			false
		)
		var current_right := offset_path_point(
			path_points,
			point_index,
			width * 0.5,
			0.0,
			false
		)
		var next_left := offset_path_point(
			path_points,
			next_index,
			-width * 0.5,
			0.0,
			false
		)
		var next_right := offset_path_point(
			path_points,
			next_index,
			width * 0.5,
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


static func create_ribbon_mesh(
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
		var current_left := offset_path_point(
			path_points,
			point_index,
			offset_a,
			height_offset,
			is_closed
		)
		var current_right := offset_path_point(
			path_points,
			point_index,
			offset_b,
			height_offset,
			is_closed
		)
		var next_left := offset_path_point(
			path_points,
			next_index,
			offset_a,
			height_offset,
			is_closed
		)
		var next_right := offset_path_point(
			path_points,
			next_index,
			offset_b,
			height_offset,
			is_closed
		)
		var next_distance := (
			cumulative_distance
			+ path_points[point_index].distance_to(path_points[next_index])
		)
		_add_surface_vertex(
			surface,
			current_left,
			Vector2(0.0, cumulative_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			next_right,
			Vector2(1.0, next_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			current_right,
			Vector2(1.0, cumulative_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			current_left,
			Vector2(0.0, cumulative_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			next_left,
			Vector2(0.0, next_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			next_right,
			Vector2(1.0, next_distance * UV_DISTANCE_SCALE)
		)
		cumulative_distance = next_distance
	surface.generate_normals()
	return surface.commit()


static func create_boundary_ribbon_mesh(
	left_boundary: PackedVector3Array,
	right_boundary: PackedVector3Array,
	height_offset: float
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if left_boundary.size() < 2 or left_boundary.size() != right_boundary.size():
		return surface.commit()
	var cumulative_distance := 0.0
	for point_index in left_boundary.size() - 1:
		var next_index := point_index + 1
		var current_left := left_boundary[point_index] + Vector3.UP * height_offset
		var current_right := right_boundary[point_index] + Vector3.UP * height_offset
		var next_left := left_boundary[next_index] + Vector3.UP * height_offset
		var next_right := right_boundary[next_index] + Vector3.UP * height_offset
		var next_distance := cumulative_distance + (
			left_boundary[point_index].lerp(right_boundary[point_index], 0.5)
			.distance_to(
				left_boundary[next_index].lerp(right_boundary[next_index], 0.5)
			)
		)
		_add_surface_vertex(
			surface,
			current_left,
			Vector2(0.0, cumulative_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			next_right,
			Vector2(1.0, next_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			current_right,
			Vector2(1.0, cumulative_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			current_left,
			Vector2(0.0, cumulative_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			next_left,
			Vector2(0.0, next_distance * UV_DISTANCE_SCALE)
		)
		_add_surface_vertex(
			surface,
			next_right,
			Vector2(1.0, next_distance * UV_DISTANCE_SCALE)
		)
		cumulative_distance = next_distance
	surface.generate_normals()
	return surface.commit()


static func offset_path_point(
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
	return (
		path_points[point_index]
		+ right * lateral_offset
		+ Vector3.UP * height_offset
	)


static func create_curb(
	parent: Node3D,
	path_points: Array[Vector3],
	inner_offset: float,
	outer_offset: float,
	is_closed: bool,
	material: StandardMaterial3D
) -> void:
	var curb := MeshInstance3D.new()
	curb.mesh = create_ribbon_mesh(
		path_points,
		inner_offset,
		outer_offset,
		CURB_HEIGHT_OFFSET,
		is_closed
	)
	curb.material_override = material
	parent.add_child(curb)


static func _add_surface_vertex(
	surface: SurfaceTool,
	vertex: Vector3,
	uv: Vector2
) -> void:
	surface.set_uv(uv)
	surface.add_vertex(vertex)
