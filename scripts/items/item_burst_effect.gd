class_name ItemBurstEffect
extends Node3D

const BOOST_TEXTURE: Texture2D = preload(
	"res://assets/vendor/kenney/particle-pack/flame_05.png"
)
const WAVE_TEXTURE: Texture2D = preload(
	"res://assets/vendor/kenney/particle-pack/circle_01.png"
)

var item_definition: ItemDefinition
var source_kart: Node3D

var _duration := 0.35
var _elapsed := 0.0
var _follow_source := false
var _wave_root: Node3D
var _wave_materials: Array[StandardMaterial3D] = []


func setup(
	definition: ItemDefinition,
	source: Node3D,
	follow_source: bool
) -> void:
	item_definition = definition
	source_kart = source
	_follow_source = follow_source
	_duration = maxf(definition.effect_visual_duration, 0.01)


func _ready() -> void:
	if item_definition == null or not is_instance_valid(source_kart):
		queue_free()
		return
	_update_source_transform()
	if item_definition.type == ItemDefinition.ItemType.TROPICAL_WAVE:
		_build_wave()
	else:
		_build_boost_particles()


func _process(delta: float) -> void:
	_elapsed += delta
	if _follow_source:
		if not is_instance_valid(source_kart):
			queue_free()
			return
		_update_source_transform()
	if _wave_root != null:
		var progress := clampf(_elapsed / _duration, 0.0, 1.0)
		var radius_scale := lerpf(0.12, item_definition.area_radius, progress)
		_wave_root.scale = Vector3(radius_scale, 1.0, radius_scale)
		for material in _wave_materials:
			material.albedo_color.a = 0.72 * (1.0 - progress)
	if _elapsed >= _duration:
		queue_free()


func get_remaining_life() -> float:
	return maxf(_duration - _elapsed, 0.0)


func _update_source_transform() -> void:
	global_transform = source_kart.global_transform
	global_position += Vector3.UP * 0.35


func _build_boost_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 22
	particles.lifetime = 0.42
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.42
	particles.direction = Vector3(0.0, 0.12, 1.0)
	particles.spread = 24.0
	particles.initial_velocity_min = 2.6
	particles.initial_velocity_max = 5.2
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 0.95
	particles.gravity = Vector3.ZERO
	particles.color = item_definition.hud_color
	particles.mesh = _particle_quad(BOOST_TEXTURE, Vector2(0.42, 0.42))
	particles.position = Vector3(0.0, 0.35, 1.15)
	add_child(particles)


func _build_wave() -> void:
	_wave_root = Node3D.new()
	add_child(_wave_root)
	for ring_index in 3:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.74 + ring_index * 0.05
		mesh.outer_radius = 0.9 + ring_index * 0.05
		mesh.rings = 24
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.position.y = 0.06 + ring_index * 0.08
		var material := _glowing_material(
			item_definition.hud_color.lightened(float(ring_index) * 0.12)
		)
		_wave_materials.append(material)
		ring.material_override = material
		_wave_root.add_child(ring)
	var particles := CPUParticles3D.new()
	particles.amount = 18
	particles.lifetime = _duration
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.7
	particles.direction = Vector3.UP
	particles.spread = 82.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.2
	particles.gravity = Vector3(0.0, -2.0, 0.0)
	particles.color = Color("#77d9df")
	particles.mesh = _particle_quad(WAVE_TEXTURE, Vector2(0.48, 0.48))
	particles.position.y = 0.3
	add_child(particles)


func _particle_quad(texture: Texture2D, size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	return mesh


func _glowing_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.7
	return material
