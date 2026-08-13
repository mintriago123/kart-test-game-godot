extends SceneTree

const CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/minimaps"))
	for definition in CATALOG.tracks:
		var track := definition.scene.instantiate() as TrackLevel
		if track == null:
			push_error("Cannot instantiate %s" % definition.id); quit(1); return
		var minimap := TrackMinimapBuilder.build(track)
		track.free()
		if minimap == null:
			push_error("Cannot generate %s" % definition.id); quit(1); return
		var map_path := "res://levels/minimaps/%s.tres" % definition.id
		if ResourceSaver.save(minimap, map_path) != OK:
			push_error("Cannot save %s" % map_path); quit(1); return
		definition.preview_map = load(map_path) as TrackMinimapData
		definition.length_km = snappedf(minimap.length_meters / 1000.0, 0.1)
		definition.shortcut_count = minimap.shortcut_count
		if ResourceSaver.save(definition, definition.resource_path) != OK:
			push_error("Cannot update %s" % definition.resource_path); quit(1); return
		print("Generated %s: %.1f km, %d shortcuts" % [definition.id, definition.length_km, definition.shortcut_count])
	quit()
