class_name DriftSparkController
extends Node3D

var _emitters: Array[GPUParticles3D] = []

func setup(kart: Kart, profile := "medium") -> void:
	var particle_scale := float(PresentationQuality.get_budget(profile).particle_scale)
	for x in [-0.62, 0.62]:
		var particles := GPUParticles3D.new()
		particles.position = Vector3(x, 0.18, 0.72)
		particles.amount = maxi(1, roundi(18.0 * particle_scale))
		particles.lifetime = 0.32
		particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 5))
		particles.emitting = false
		var material := ParticleProcessMaterial.new()
		material.direction = Vector3(0, 0.4, 1)
		material.initial_velocity_min = 1.5
		material.initial_velocity_max = 3.0
		particles.process_material = material
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.09, 0.28)
		var visual_material := StandardMaterial3D.new()
		visual_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		visual_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		visual_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		visual_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		visual_material.emission_enabled = profile != "low"
		mesh.material = visual_material
		particles.draw_pass_1 = mesh
		add_child(particles)
		_emitters.append(particles)
	kart.drift_charge_changed.connect(_update_sparks)

func _update_sparks(level: int, ratio: float, quality: float) -> void:
	var colors := [Color("#39e8ff"), Color("#ff982e"), Color("#ff48c8")]
	for emitter in _emitters:
		emitter.emitting = level > 0 or ratio > 0.15
		emitter.amount_ratio = clampf((0.25 + ratio * 0.75) * (0.35 if quality < 0.25 else 1.0), 0.0, 1.0)
		var material := emitter.process_material as ParticleProcessMaterial
		material.color = colors[clampi(level, 0, 2)]
		var visual_material := emitter.draw_pass_1.surface_get_material(0) as StandardMaterial3D
		visual_material.albedo_color = material.color
		visual_material.emission = material.color
