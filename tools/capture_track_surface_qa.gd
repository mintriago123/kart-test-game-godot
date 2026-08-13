extends SceneTree

const CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for definition in CATALOG.tracks:
		var packed_main := load("res://scenes/main.tscn") as PackedScene
		var main := packed_main.instantiate()
		root.add_child(main)
		await process_frame
		main.settings.is_persistence_enabled = false
		main.start_game(definition.id, false)
		for _frame in 6:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var error := image.save_png(
			"/tmp/track_surface_%s.png" % definition.id
		)
		if error != OK:
			push_error("No se pudo capturar %s" % definition.display_name)
			quit(1)
			return
		print("CAPTURA: %s" % definition.display_name)
		main.queue_free()
		await process_frame
	quit()
