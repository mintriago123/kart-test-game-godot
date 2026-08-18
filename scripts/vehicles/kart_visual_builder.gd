class_name KartVisualBuilder
extends RefCounted

const VEHICLE_COLORMAP: Texture2D = preload("res://assets/vendor/kenney/car-kit/Textures/colormap.png")


func build_collision(kart: Kart) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Kart.COLLISION_SIZE
	collision.shape = shape
	collision.position.y = 0.57
	kart.add_child(collision)


func build_visual(kart: Kart) -> Node3D:
	var root := Node3D.new()
	kart.add_child(root)
	if kart.visual_variant != null and kart.visual_variant.visual_scene != null:
		var custom_visual := kart.visual_variant.visual_scene.instantiate() as Node3D
		if custom_visual != null:
			root.add_child(custom_visual)
			_apply_vehicle_colormap(custom_visual)
			return root
	_add_box(root, Vector3(1.55, 0.52, 2.2), Vector3(0.0, 0.62, 0.0), kart.body_color)
	_add_box(root, Vector3(1.25, 0.48, 0.95), Vector3(0.0, 1.0, 0.28), kart.body_color.lightened(0.12))
	_add_box(root, Vector3(1.15, 0.12, 0.45), Vector3(0.0, 0.88, -1.14), Color("#f5d66f"))
	var driver := MeshInstance3D.new()
	var driver_mesh := SphereMesh.new()
	driver_mesh.radius = 0.34
	driver_mesh.height = 0.68
	driver.mesh = driver_mesh
	driver.position = Vector3(0.0, 1.47, 0.25)
	driver.material_override = _material(Color("#fff0d0"))
	root.add_child(driver)
	for wheel_x in [-0.87, 0.87]:
		for wheel_z in [-0.68, 0.72]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.34
			wheel_mesh.bottom_radius = 0.34
			wheel_mesh.height = 0.28
			wheel.mesh = wheel_mesh
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(wheel_x, 0.48, wheel_z)
			wheel.material_override = _material(Color("#15282b"))
			root.add_child(wheel)
	return root


func _apply_vehicle_colormap(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
			var material := source.duplicate() as BaseMaterial3D if source != null else StandardMaterial3D.new()
			material.albedo_texture = VEHICLE_COLORMAP
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			material.roughness = 0.72
			mesh_instance.set_surface_override_material(surface_index, material)


func _add_box(parent: Node, size: Vector3, box_position: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = box_position
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
