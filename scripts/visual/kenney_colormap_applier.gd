class_name KenneyColormapApplier
extends Node3D

@export var colormap: Texture2D

func _ready() -> void:
	if colormap == null:
		return
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
			var material := source.duplicate() as BaseMaterial3D if source != null else StandardMaterial3D.new()
			material.albedo_texture = colormap
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			material.roughness = 0.78
			mesh_instance.set_surface_override_material(surface_index, material)
