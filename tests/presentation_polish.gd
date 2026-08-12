extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_profiles()
	_test_surfaces()
	await _test_track_assets()
	await _test_particles_and_audio()
	quit(1 if failed else 0)

func _test_profiles() -> void:
	var expected := {
		"low": [0.35, 12, false, 0, 0],
		"medium": [0.65, 20, true, 2, 1],
		"high": [1.0, 32, true, 2, 2],
		"ultra": [1.5, 48, true, 4, 3],
	}
	for profile in expected:
		var budget := PresentationQuality.get_budget(profile)
		var values: Array = expected[profile]
		_check(is_equal_approx(budget.particle_scale, values[0]) and budget.speed_lines == values[1] and budget.shadows == values[2] and budget.msaa == values[3] and budget.glow == values[4], "%s has its exact presentation budget." % profile)
	_check(PresentationQuality.sanitize("future") == "medium", "Unknown profiles migrate safely to medium.")

func _test_surfaces() -> void:
	for path in ["res://levels/surfaces/asphalt.tres", "res://levels/surfaces/dirt.tres", "res://levels/surfaces/sand.tres", "res://levels/surfaces/grass.tres"]:
		var surface := load(path) as SurfaceDefinition
		_check(surface != null and surface.audio_pitch > 0.0 and surface.audio_volume > 0.0 and surface.particle_color.a > 0.0, "%s declares audio and particle identity." % path.get_file())

func _test_track_assets() -> void:
	var tents := load("res://assets/track/racing_tents.tscn").instantiate() as Node3D
	root.add_child(tents)
	await process_frame
	var textured := false
	for child in tents.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var material := mesh_instance.get_surface_override_material(0) as BaseMaterial3D
		if material != null and material.albedo_texture != null:
			textured = true
	_check(textured, "Racing scenery receives the Kenney colormap explicitly.")
	tents.queue_free()
	await process_frame

func _test_particles_and_audio() -> void:
	var kart := Kart.new()
	kart.visual_variant = load("res://progression/variants/kart_oobi.tres") as KartVariantDefinition
	root.add_child(kart)
	await process_frame
	var colored_meshes := 0
	for child in kart._visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.get_surface_override_material(0) is BaseMaterial3D:
			var material := mesh_instance.get_surface_override_material(0) as BaseMaterial3D
			if material.albedo_texture != null: colored_meshes += 1
	_check(colored_meshes > 0, "Imported kart geometry receives the Kenney colormap explicitly.")
	_check(is_equal_approx(Kart.COLLISION_SIZE.x, 1.5) and is_equal_approx(Kart.COLLISION_SIZE.z, 2.5), "Kart collision footprint matches the normalized arcade vehicle scale.")
	var feedback := KartVisualFeedback.new()
	kart.add_child(feedback)
	feedback.setup(kart, "ultra", true)
	var camera := Camera3D.new()
	root.add_child(camera)
	feedback.attach_to_camera(camera)
	_check(is_equal_approx(feedback.position.z, -7.0), "Speed lines spawn far enough ahead of the camera to form visible streaks.")
	_check(feedback.speed_line_overlay.line_count == PresentationQuality.get_budget("ultra").speed_lines and not feedback.speed_lines.visible, "Speed lines use the radial screen-space renderer instead of vertical particle billboards.")
	var sparks := DriftSparkController.new()
	kart.add_child(sparks)
	sparks.setup(kart, "high")
	for particle in [feedback.speed_lines, feedback.flash_particles] + sparks._emitters:
		_check(particle.draw_pass_1 != null and particle.process_material != null and particle.visibility_aabb.size.length() > 0.0, "Every driving particle has geometry, material, and visibility bounds.")
	var player_audio := KartAudioController.new()
	kart.add_child(player_audio)
	player_audio.setup(kart, &"player")
	var rival_audio := KartAudioController.new()
	kart.add_child(rival_audio)
	rival_audio.setup(kart, &"rival")
	_check(player_audio.tires_player != null and player_audio.boost_player != null and rival_audio.tires_player == null and rival_audio.event_player != null, "Only the player receives the full persistent kart mix.")
	kart.queue_free()
	camera.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)
