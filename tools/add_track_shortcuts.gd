extends SceneTree

const IDS := [&"dunas_doradas", &"pantano_brumoso", &"can_carmes", &"valle_de_otoo", &"baha_pirata", &"caldera_furiosa", &"cumbre_glacial", &"ruinas_esmeralda", &"nen_medianoche"]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var catalog := load("res://levels/track_catalog.tres") as TrackCatalog
	for id in IDS:
		var definition := catalog.get_track(id)
		var session := TrackEditorSession.new()
		if session.load_track(definition.scene.resource_path) != OK: quit(1); return
		var desired := 2 if session.track.difficulty == "Difícil" else 1
		var helper := TrackEditorScreen.new()
		helper.session = session
		var curve := session.track.get_main_route().curve
		var pairs := [[0, 3], [4, 7], [7, 10], [1, 4], [5, 8]]
		for pair in pairs:
			if session.track.get_shortcuts().size() >= desired: break
			var start := curve.get_point_position(pair[0])
			var finish := curve.get_point_position(pair[1])
			var shortcut_curve: Curve3D = helper._find_clear_shortcut_curve(
				start, finish,
				helper._get_route_forward_at_position(curve, start),
				helper._get_route_forward_at_position(curve, finish)
			)
			if shortcut_curve == null: continue
			var shortcut := TrackShortcut.new()
			shortcut.name = "Shortcut%d" % session.track.get_shortcuts().size()
			shortcut.shortcut_id = session.track.get_shortcuts().size()
			shortcut.display_name = "Ruta arriesgada %d" % (shortcut.shortcut_id + 1)
			shortcut.curve = shortcut_curve
			session.track.get_node("Shortcuts").add_child(shortcut)
			shortcut.owner = session.track
			session.configure_shortcut_anchor(shortcut, true)
		helper.free()
		if session.track.get_shortcuts().size() != desired or not session.track.validate_track().is_empty():
			push_error("No se pudieron crear los atajos de %s" % definition.display_name); quit(1); return
		if session.publish(3, definition.description) != OK: quit(1); return
		print("ATAJOS: %s (%d)" % [definition.display_name, desired])
	quit()
