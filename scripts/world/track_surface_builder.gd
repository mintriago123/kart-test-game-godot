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
	collision_layer: int,
	collision_width: float = -1.0
) -> void:
	var path_mesh := create_ribbon_mesh(
		path_points,
		-width * 0.5,
		width * 0.5,
		0.0,
		is_closed
	)
	var collision_points := _densify_path(path_points, is_closed, 4)
	# Keep a generous visual shoulder while keeping the physical ribbon clear of
	# the self-intersecting inner edge at very tight turns.
	var physical_width := collision_width if collision_width > 0.0 else width
	var collision_mesh := create_ribbon_mesh(
		collision_points,
		-physical_width * 0.5,
		physical_width * 0.5,
		0.0,
		is_closed,
		true
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
	var path_shape := collision_mesh.create_trimesh_shape()
	if path_shape is ConcavePolygonShape3D:
		(path_shape as ConcavePolygonShape3D).backface_collision = true
	# Use one surface shape for the whole road. Splitting the ribbon into many
	# convex cells exposes their shared end faces to CharacterBody3D and creates
	# artificial horizontal impacts at tight bends.
	path_collision.disabled = false
	path_collision.shape = path_shape
	path_body.add_child(path_collision)


static func _densify_path(
	path_points: Array[Vector3],
	is_closed: bool,
	subdivisions: int
) -> Array[Vector3]:
	if not is_closed or path_points.size() < 4 or subdivisions <= 1:
		return path_points
	var dense_points: Array[Vector3] = []
	for point_index in path_points.size():
		var previous := path_points[(point_index - 1 + path_points.size()) % path_points.size()]
		var current := path_points[point_index]
		var next := path_points[(point_index + 1) % path_points.size()]
		var following := path_points[(point_index + 2) % path_points.size()]
		for subdivision in subdivisions:
			var weight := float(subdivision) / float(subdivisions)
			dense_points.append(_catmull_rom(previous, current, next, following, weight))
	return dense_points


static func _catmull_rom(
	previous: Vector3,
	current: Vector3,
	next: Vector3,
	following: Vector3,
	weight: float
) -> Vector3:
	var weight_squared := weight * weight
	var weight_cubed := weight_squared * weight
	return 0.5 * (
		2.0 * current
		+ (-previous + next) * weight
		+ (2.0 * previous - 5.0 * current + 4.0 * next - following) * weight_squared
		+ (-previous + 3.0 * current - 3.0 * next + following) * weight_cubed
	)


static func create_shortcut_drivable_surface(
	parent: Node3D,
	path_points: Array[Vector3],
	width: float,
	material: StandardMaterial3D,
	node_name: String,
	collision_layer: int,
	collision_path_points: Array[Vector3] = []
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

	# Collision may overlap the junction up to its road-edge crossings. Callers
	# must keep those points clipped so no invisible triangles cross MainRoad.
	var collision_points := (
		collision_path_points
		if not collision_path_points.is_empty()
		else path_points
	)
	var collision_mesh := create_shortcut_collision_mesh(collision_points, width)
	var path_body := StaticBody3D.new()
	path_body.name = node_name + "Collision"
	path_body.collision_layer = collision_layer
	path_body.collision_mask = PhysicsLayers.KARTS
	parent.add_child(path_body)
	var path_collision := CollisionShape3D.new()
	var path_shape := collision_mesh.create_trimesh_shape()
	if path_shape is ConcavePolygonShape3D:
		(path_shape as ConcavePolygonShape3D).backface_collision = true
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
	is_closed: bool,
	use_indexed_geometry: bool = false
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
		_add_ribbon_quad(
			surface,
			current_left,
			next_right,
			current_right,
			next_left,
			Vector2(0.0, cumulative_distance * UV_DISTANCE_SCALE),
			Vector2(1.0, next_distance * UV_DISTANCE_SCALE),
			Vector2(1.0, cumulative_distance * UV_DISTANCE_SCALE),
			Vector2(0.0, next_distance * UV_DISTANCE_SCALE)
		)
		cumulative_distance = next_distance
	if use_indexed_geometry:
		surface.index()
	surface.generate_normals()
	return surface.commit()


static func _add_ribbon_quad(
	surface: SurfaceTool,
	current_left: Vector3,
	next_right: Vector3,
	current_right: Vector3,
	next_left: Vector3,
	current_left_uv: Vector2,
	next_right_uv: Vector2,
	current_right_uv: Vector2,
	next_left_uv: Vector2
) -> void:
	# The usual diagonal creates a near-vertical triangle when the inner edge
	# folds at a tight, banked corner. Pick the diagonal whose two triangles
	# retain the strongest upward-facing normals.
	var triangle_sets := [
		[
			[current_left, next_right, current_right],
			[current_left, next_left, next_right],
		],
		[
			[current_left, next_left, current_right],
			[next_left, next_right, current_right],
		],
	]
	var uv_sets := [
		[
			[current_left_uv, next_right_uv, current_right_uv],
			[current_left_uv, next_left_uv, next_right_uv],
		],
		[
			[current_left_uv, next_left_uv, current_right_uv],
			[next_left_uv, next_right_uv, current_right_uv],
		],
	]
	var best_set := 0
	var best_score := -INF
	for set_index in triangle_sets.size():
		var first: Array = triangle_sets[set_index][0]
		var second: Array = triangle_sets[set_index][1]
		var first_normal: Vector3 = (first[1] - first[0]).cross(first[2] - first[0]).normalized()
		var second_normal: Vector3 = (second[1] - second[0]).cross(second[2] - second[0]).normalized()
		var score := minf(absf(first_normal.y), absf(second_normal.y))
		if score > best_score:
			best_score = score
			best_set = set_index
	for triangle_index in 2:
		var triangle: Array = triangle_sets[best_set][triangle_index].duplicate()
		var triangle_uv: Array = uv_sets[best_set][triangle_index].duplicate()
		var normal: Vector3 = (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])
		if normal.y < 0.0:
			var swapped_vertex = triangle[1]
			triangle[1] = triangle[2]
			triangle[2] = swapped_vertex
			var swapped_uv = triangle_uv[1]
			triangle_uv[1] = triangle_uv[2]
			triangle_uv[2] = swapped_uv
		for vertex_index in 3:
			_add_surface_vertex(surface, triangle[vertex_index], triangle_uv[vertex_index])


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
