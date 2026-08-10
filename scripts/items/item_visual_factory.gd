class_name ItemVisualFactory
extends RefCounted

const Bounds := preload("res://scripts/visual/node_3d_bounds.gd")
const SHADOW_ALPHA := 0.28
const SHADOW_HEIGHT := 0.012


static func attach_presentation(
	parent: Node3D,
	definition: ItemDefinition,
	physical_radius: float,
	shadow_local_y: float,
	fallback_factory: Callable = Callable()
) -> Dictionary:
	var result := {
		"visual": null,
		"shadow": null,
		"trail": null,
		"was_normalized": false,
	}
	if parent == null or definition == null:
		return result
	var visual := _create_visual(definition, fallback_factory)
	if visual != null:
		visual.name = "ItemVisual"
		parent.add_child(visual)
		result.visual = visual
		result.was_normalized = _normalize_visual(visual, definition)
	if definition.show_ground_shadow:
		var shadow := _create_shadow(
			maxf(definition.world_visual_diameter, physical_radius * 2.0),
			shadow_local_y
		)
		parent.add_child(shadow)
		result.shadow = shadow
	if definition.show_motion_trail:
		var trail := _create_motion_trail(
			definition.hud_color,
			maxf(definition.world_visual_diameter, physical_radius * 2.0)
		)
		parent.add_child(trail)
		result.trail = trail
	return result


static func _create_visual(
	definition: ItemDefinition,
	fallback_factory: Callable
) -> Node3D:
	if definition.visual_scene != null:
		var scene_visual := definition.visual_scene.instantiate() as Node3D
		if scene_visual != null:
			return scene_visual
	if fallback_factory.is_valid():
		return fallback_factory.call() as Node3D
	return null


static func _normalize_visual(
	visual: Node3D,
	definition: ItemDefinition
) -> bool:
	if definition.world_visual_diameter <= 0.0:
		return false
	var bounds_result := Bounds.get_node_aabb(visual)
	if not bool(bounds_result.valid):
		push_warning(
			"No se pudo medir el visual de %s; se conservó su escala authored."
			% definition.display_name
		)
		return false
	var bounds: AABB = bounds_result.aabb
	var largest_dimension := maxf(
		bounds.size.x,
		maxf(bounds.size.y, bounds.size.z)
	)
	if not is_finite(largest_dimension) or largest_dimension <= 0.0001:
		push_warning(
			"El visual de %s no tiene dimensiones medibles; se conservó su escala authored."
			% definition.display_name
		)
		return false
	visual.scale *= definition.world_visual_diameter / largest_dimension
	return true


static func _create_shadow(diameter: float, local_y: float) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "GroundShadow"
	shadow.position.y = local_y
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = diameter * 0.38
	mesh.bottom_radius = diameter * 0.38
	mesh.height = SHADOW_HEIGHT
	mesh.radial_segments = 32
	shadow.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.025, 0.03, SHADOW_ALPHA)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	shadow.material_override = material
	return shadow


static func _create_motion_trail(color: Color, diameter: float) -> GPUParticles3D:
	var trail := GPUParticles3D.new()
	trail.name = "MotionTrail"
	trail.amount = 18
	trail.lifetime = 0.28
	trail.local_coords = false
	trail.emitting = true
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visibility_aabb = AABB(
		Vector3.ONE * -diameter * 4.0,
		Vector3.ONE * diameter * 8.0
	)
	var particles := ParticleProcessMaterial.new()
	particles.direction = Vector3.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = diameter * 0.05
	particles.initial_velocity_max = diameter * 0.15
	particles.gravity = Vector3.ZERO
	particles.scale_min = 0.55
	particles.scale_max = 1.0
	particles.color = Color(color.r, color.g, color.b, 0.58)
	trail.process_material = particles
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * diameter * 0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	quad.material = material
	trail.draw_pass_1 = quad
	return trail
