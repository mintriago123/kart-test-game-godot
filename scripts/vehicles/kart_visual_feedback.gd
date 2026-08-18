class_name KartVisualFeedback
extends Node3D

var kart: Kart
var profile := "medium"
var speed_lines_enabled := true
var speed_lines: GPUParticles3D
var flash_particles: GPUParticles3D
var speed_line_layer: CanvasLayer
var speed_line_overlay: SpeedLineOverlay
var _flash_energy := 0.0

class SpeedLineOverlay:
	extends Control
	var line_count := 20
	var intensity := 0.0
	var glow_strength := 0.0
	var visibility_gain := 1.0
	var phase := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		phase = fmod(phase + delta * lerpf(0.7, 2.8, intensity), 1.0)
		queue_redraw()

	func _draw() -> void:
		if intensity <= 0.01 or size.x <= 1.0 or size.y <= 1.0:
			return
		var center := Vector2(size.x * 0.5, size.y * 0.46)
		var radius_scale := Vector2(size.x * 0.66, size.y * 0.72)
		var visible_count := maxi(4, roundi(float(line_count) * 0.58))
		for index in visible_count:
			var seed := fmod(float(index) * 0.61803398875, 1.0)
			var jitter := fmod(absf(sin(float(index) * 91.73)) * 19.19, 1.0)
			# Favor the side and lower periphery. Avoid a uniform 360-degree spinner.
			var side := 0.0 if index % 2 == 0 else PI
			var angle := side + lerpf(-0.48, 0.48, seed) + lerpf(-0.05, 0.05, jitter)
			var individual_speed := lerpf(0.58, 1.62, jitter)
			var travel := fmod(phase * individual_speed + seed * 2.37 + jitter, 1.0)
			# Keep the center and the road immediately around the kart unobstructed.
			var radius := lerpf(0.48, 1.0, travel * travel)
			var radial := Vector2(cos(angle), sin(angle))
			var position := center + radial * radius_scale * radius
			var direction := (position - center).normalized()
			var length := lerpf(38.0, 156.0, travel) * lerpf(0.72, 1.0, intensity)
			var flicker := smoothstep(0.04, 0.2, travel) * (1.0 - smoothstep(0.72, 1.0, travel))
			var alpha := clampf((0.22 + flicker * 0.78) * intensity * visibility_gain, 0.0, 0.95)
			var start := position - direction * length
			var perpendicular := Vector2(-direction.y, direction.x)
			var head_width := lerpf(1.8, 4.8, travel) * lerpf(0.75, 1.0, intensity)
			if glow_strength > 0.0:
				draw_line(start, position, Color(0.62, 0.88, 1.0, alpha * 0.22 * glow_strength), head_width * 2.4, true)
			# A tapered wedge reads as forward motion instead of rain.
			draw_colored_polygon(PackedVector2Array([
				start,
				position + perpendicular * head_width,
				position + direction * head_width * 1.8,
				position - perpendicular * head_width,
			]), Color(0.94, 0.97, 0.93, alpha * 0.88))
			draw_line(position - perpendicular * head_width * 0.45, position + perpendicular * head_width * 0.45, Color(1.0, 1.0, 0.98, alpha * 0.9), 1.35, true)

func setup(value: Kart, quality_profile: String, lines_enabled := true) -> void:
	kart = value
	profile = PresentationQuality.sanitize(quality_profile)
	speed_lines_enabled = lines_enabled
	var budget := PresentationQuality.get_budget(profile)
	speed_lines = _make_particles(int(budget.speed_lines), Vector2(0.025, 1.4), Color(0.45, 0.95, 1.0, 0.72), Vector3(8, 5, 12))
	speed_lines.lifetime = 0.42
	speed_lines.emitting = false
	speed_lines.visible = false # Compatibility node; screen-space overlay renders the streaks.
	var process := speed_lines.process_material as ParticleProcessMaterial
	process.direction = Vector3(0, 0, 1)
	process.spread = 4.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 22.0
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(4.8, 2.7, 0.6)
	process.scale_min = 0.65
	process.scale_max = 1.25
	add_child(speed_lines)
	speed_line_layer = CanvasLayer.new()
	speed_line_layer.layer = 2
	add_child(speed_line_layer)
	speed_line_overlay = SpeedLineOverlay.new()
	speed_line_overlay.line_count = int(budget.speed_lines)
	speed_line_overlay.glow_strength = float(budget.glow) / 3.0
	speed_line_overlay.visibility_gain = {"low": 0.48, "medium": 0.9, "high": 1.12, "ultra": 1.3}[profile]
	speed_line_layer.add_child(speed_line_overlay)
	flash_particles = _make_particles(maxi(4, roundi(18.0 * float(budget.particle_scale))), Vector2(0.14, 0.5), Color("#65f6ff"), Vector3(4, 3, 4))
	flash_particles.one_shot = true
	flash_particles.explosiveness = 0.92
	flash_particles.lifetime = 0.3
	flash_particles.emitting = false
	add_child(flash_particles)
	kart.presentation_boost_started.connect(func(power: float) -> void: _burst(Color("#65f6ff"), power))
	kart.mini_turbo_released.connect(func(level: int) -> void: _burst([Color("#48ddff"), Color("#ff9a35"), Color("#ff48c8")][clampi(level - 1, 0, 2)], 0.55 + level * 0.15))
	kart.presentation_landed.connect(func(intensity: float) -> void: _burst(kart.get_surface_particle_color(), intensity))
	kart.presentation_launch_bogged.connect(func() -> void: _burst(Color("#77706c"), 0.7))
	kart.hit_blocked.connect(func(_threat: Node) -> void: _burst(Color("#b58cff"), 1.0))

func attach_to_camera(view_camera: Camera3D) -> void:
	if view_camera == null: return
	reparent(view_camera)
	# Spawn well in front of the near plane, then stream toward the camera.
	position = Vector3(0, 0, -7.0)

func _process(_delta: float) -> void:
	if kart == null: return
	var speed_ratio := kart.get_horizontal_speed() / maxf(kart.stats.max_speed, 0.1)
	var strength := maxf(inverse_lerp(0.92, 1.18, speed_ratio), kart.get_boost_power_ratio())
	var active := speed_lines_enabled and (kart.is_boost_active() or speed_ratio >= 0.92)
	speed_lines.emitting = false
	speed_lines.amount_ratio = clampf(strength, 0.12 if profile == "low" and active else 0.0, 1.0)
	speed_line_overlay.intensity = clampf(strength, 0.12 if profile == "low" and active else 0.0, 1.0) if active else 0.0


func animate_vehicle(root: Node3D, delta: float, steer: float, drifting: bool, landing_ratio: float, stunned: bool) -> void:
	if root == null:
		return
	var target_roll := -steer * (0.12 if drifting else 0.06)
	root.rotation.z = lerpf(root.rotation.z, target_roll, delta * 8.0)
	root.position.y = sin(Time.get_ticks_msec() * 0.012) * 0.015 - landing_ratio * 0.08
	root.scale = Vector3(
		1.0 + landing_ratio * 0.025,
		1.0 - landing_ratio * 0.08,
		1.0 + landing_ratio * 0.025
	)
	if stunned:
		root.rotation.y += delta * 8.0
	else:
		root.rotation.y = lerp_angle(root.rotation.y, 0.0, delta * 10.0)

func _burst(color: Color, intensity: float) -> void:
	var material := flash_particles.draw_pass_1.surface_get_material(0) as StandardMaterial3D
	material.albedo_color = color
	material.emission = color
	flash_particles.amount_ratio = clampf(intensity, 0.25, 1.0)
	flash_particles.restart()

func _make_particles(amount: int, dimensions: Vector2, color: Color, bounds: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.visibility_aabb = AABB(-bounds, bounds * 2.0)
	var process := ParticleProcessMaterial.new()
	process.gravity = Vector3.ZERO
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = dimensions
	quad.orientation = PlaneMesh.FACE_Z
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.emission_enabled = profile != "low"
	material.emission = color
	material.emission_energy_multiplier = 0.65 if profile == "medium" else (1.5 if profile == "ultra" else 1.0)
	quad.material = material
	particles.draw_pass_1 = quad
	return particles
