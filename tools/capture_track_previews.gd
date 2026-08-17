extends SceneTree

const OUTPUT_DIR := "res://assets/track/previews"
const CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("No hay renderer 3D disponible. Ejecuta esta herramienta en Godot con una sesión gráfica.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for definition in CATALOG.tracks:
		var path := "%s/%s.webp" % [OUTPUT_DIR, definition.id]
		if FileAccess.file_exists(path) and not OS.get_cmdline_args().has("--force"):
			print("SKIP EXISTING: ", path)
			continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(960, 540)
		viewport.own_world_3d = true
		viewport.world_3d = World3D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var environment := WorldEnvironment.new()
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = definition.preview_color.darkened(0.42)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#d8f4e8")
		env.ambient_light_energy = 0.7
		environment.environment = env
		viewport.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55.0, -28.0, 0.0)
		light.light_energy = 1.8
		viewport.add_child(light)
		var track := definition.scene.instantiate() as Node3D
		viewport.add_child(track)
		for _frame in 6: await process_frame
		var route := track.get("route_points") as Array[Vector3]
		var bounds := AABB(Vector3.ZERO, Vector3.ONE)
		if route != null and not route.is_empty():
			bounds = AABB(route[0], Vector3.ZERO)
			for point in route: bounds = bounds.expand(point)
		var center := bounds.get_center()
		var extent := maxf(bounds.size.x, bounds.size.z)
		var camera := Camera3D.new()
		camera.fov = definition.preview_camera_fov
		camera.position = center + Vector3(0.0, maxf(55.0, extent * 0.72), maxf(30.0, extent * 0.38))
		camera.look_at(center, Vector3.UP)
		viewport.add_child(camera)
		for _frame in 3: await process_frame
		RenderingServer.force_draw()
		await process_frame
		if viewport.get_texture() == null:
			push_error("No hay renderer 3D disponible. Ejecuta esta herramienta en Godot con una sesión gráfica.")
			viewport.queue_free()
			quit(2)
			return
		var image := viewport.get_texture().get_image()
		var error := image.save_webp(path, true)
		if error != OK:
			push_error("No se pudo generar %s" % path)
			quit(1)
			return
		print("CAPTURED: ", path)
		viewport.queue_free()
		await process_frame
	quit()
