extends SceneTree

const CATALOG: ProgressionCatalog = preload("res://progression/progression_catalog.tres")
const OUTPUT_DIR := "res://assets/racers/portraits"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("No hay renderer 3D disponible. Ejecuta esta herramienta en Godot con una sesión gráfica.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for racer in CATALOG.racers.racers:
		var path := "%s/%s.png" % [OUTPUT_DIR, racer.id]
		if FileAccess.file_exists(path) and not OS.get_cmdline_args().has("--force"): continue
		var showroom := VehicleViewport.new()
		showroom.name = "PortraitShowroom"
		showroom.size = Vector2(256, 256)
		showroom.reduced_motion = true
		showroom.show_driver = true
		showroom.driver_color = racer.body_color
		root.add_child(showroom)
		showroom.show_variant(racer.default_kart_visual)
		for _frame in 5: await process_frame
		RenderingServer.force_draw()
		await process_frame
		if showroom.viewport == null or showroom.viewport.get_texture() == null:
			push_error("No hay renderer 3D disponible. Ejecuta esta herramienta en Godot con una sesión gráfica.")
			showroom.queue_free()
			quit(2)
			return
		var image := showroom.viewport.get_texture().get_image()
		if image.save_png(path) != OK:
			push_error("No se pudo generar " + path)
			quit(1)
			return
		showroom.queue_free()
		await process_frame
	quit()
