extends SceneTree

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_validation_contract()
	_test_all_validation_contracts()
	await _test_guided_screen()
	await _test_template_and_history()
	await _test_migration_and_partial_preview()
	await _test_track_runner()
	quit(1 if _has_failed else 0)


func _test_validation_contract() -> void:
	var track := TrackLevel.new()
	track.track_id = &""
	track.display_name = "   "
	var issue_signatures := PackedStringArray()
	for issue in track.inspect_track():
		issue_signatures.append(
			"%s|%s|%s" % [issue.code, issue.target_path, issue.message]
		)
	var expected_signatures := PackedStringArray([
		"track_id_missing|.|La pista necesita un identificador.",
		"display_name_missing|.|La pista necesita un nombre visible.",
		"route_missing|MainRoute|Falta el nodo MainRoute de tipo Path3D.",
		"props_missing|Props|Falta el nodo Props.",
		"items_missing|ItemSpawns|Falta el nodo ItemSpawns.",
	])
	_check(
		issue_signatures == expected_signatures,
		"Structured validation preserves issue codes, paths, messages, and order."
	)
	_check(
		track.validate_track() == PackedStringArray([
			"La pista necesita un identificador.",
			"La pista necesita un nombre visible.",
			"Falta el nodo MainRoute de tipo Path3D.",
			"Falta el nodo Props.",
			"Falta el nodo ItemSpawns.",
		]),
		"Legacy validation preserves the structured issue messages and order."
	)
	track.free()


func _test_all_validation_contracts() -> void:
	var cases := [
		{
			"code": &"track_id_missing",
			"message": "La pista necesita un identificador.",
			"path": NodePath("."),
		},
		{
			"code": &"display_name_missing",
			"message": "La pista necesita un nombre visible.",
			"path": NodePath("."),
		},
		{
			"code": &"route_missing",
			"message": "Falta el nodo MainRoute de tipo Path3D.",
			"path": NodePath("MainRoute"),
		},
		{
			"code": &"route_point_count",
			"message": "MainRoute necesita al menos cuatro puntos.",
			"path": NodePath("MainRoute"),
		},
		{
			"code": &"route_not_closed",
			"message": "MainRoute debe ser una curva cerrada.",
			"path": NodePath("MainRoute"),
		},
		{
			"code": &"route_too_short",
			"message": "La ruta principal debe medir al menos 120 metros.",
			"path": NodePath("MainRoute"),
		},
		{
			"code": &"start_point_invalid",
			"message": "La salida apunta a un punto que ya no existe.",
			"path": NodePath("MainRoute"),
		},
		{
			"code": &"shortcut_name_missing",
			"message": "El atajo 0 necesita un nombre.",
			"path": NodePath("Shortcuts/PasoLaguna"),
		},
		{
			"code": &"shortcut_id_duplicate",
			"message": "El identificador de atajo 0 está repetido.",
			"path": NodePath("Shortcuts/CorteCanon"),
		},
		{
			"code": &"shortcut_point_count",
			"message": "Paso Laguna necesita al menos tres puntos.",
			"path": NodePath("Shortcuts/PasoLaguna"),
		},
		{
			"code": &"shortcut_not_open",
			"message": "Paso Laguna debe ser una curva abierta.",
			"path": NodePath("Shortcuts/PasoLaguna"),
		},
		{
			"code": &"shortcut_connection",
			"message": "Paso Laguna debe comenzar y terminar sobre MainRoute.",
			"path": NodePath("Shortcuts/PasoLaguna"),
		},
		{
			"code": &"shortcut_order",
			"message": "Paso Laguna cruza la línea de meta o sale antes de entrar.",
			"path": NodePath("Shortcuts/PasoLaguna"),
		},
		{
			"code": &"shortcut_direction",
			"message": "Paso Laguna entra o sale a contravía.",
			"path": NodePath("Shortcuts/PasoLaguna"),
		},
		{
			"code": &"props_missing",
			"message": "Falta el nodo Props.",
			"path": NodePath("Props"),
		},
		{
			"code": &"items_missing",
			"message": "Falta el nodo ItemSpawns.",
			"path": NodePath("ItemSpawns"),
		},
		{
			"code": &"item_count",
			"message": "ItemSpawns necesita al menos cuatro marcadores.",
			"path": NodePath("ItemSpawns"),
		},
		{
			"code": &"item_type",
			"message": "BrokenItem debe ser Marker3D.",
			"path": NodePath("ItemSpawns/BrokenItem"),
		},
		{
			"code": &"item_off_route",
			"message": "Norte está fuera de la carretera.",
			"path": NodePath("ItemSpawns/Norte"),
		},
	]
	var observed_codes: Dictionary = {}
	for case_data in cases:
		var expected_code: StringName = case_data.code
		var track := _create_validation_case_track(expected_code)
		var issues := track.inspect_track()
		var matching_issue_count := 0
		var signatures: Dictionary = {}
		var ordered_messages := PackedStringArray()
		for issue in issues:
			var signature := "%s|%s" % [issue.code, issue.target_path]
			_check(
				not signatures.has(signature),
				"Validation case %s deduplicates code and target."
				% expected_code
			)
			signatures[signature] = true
			ordered_messages.append(issue.message)
			if issue.code == expected_code:
				matching_issue_count += 1
				_check(
					issue.message == case_data.message
					and issue.target_path == case_data.path,
					"Validation code %s preserves message and target."
					% expected_code
				)
		_check(
			matching_issue_count == 1,
			"Validation case %s emits its code exactly once."
			% expected_code
		)
		_check(
			track.validate_track() == ordered_messages,
			"Validation case %s preserves issue order in validate_track()."
			% expected_code
		)
		observed_codes[expected_code] = true
		track.free()
	_check(
		observed_codes.size() == 19,
		"Parameterized validation covers all 19 issue codes."
	)


func _create_validation_case_track(code: StringName) -> TrackLevel:
	var packed_scene := load("res://levels/coastal_track.tscn") as PackedScene
	var track := packed_scene.instantiate() as TrackLevel
	var route := track.get_main_route()
	route.curve = route.curve.duplicate(true) as Curve3D
	for shortcut in track.get_shortcuts():
		shortcut.curve = shortcut.curve.duplicate(true) as Curve3D
	var primary_shortcut := track.get_shortcuts()[0]
	match code:
		&"track_id_missing":
			track.track_id = &""
		&"display_name_missing":
			track.display_name = "   "
		&"route_missing":
			route.free()
		&"route_point_count":
			while route.curve.point_count > 3:
				route.curve.remove_point(route.curve.point_count - 1)
		&"route_not_closed":
			route.curve.closed = false
		&"route_too_short":
			var short_curve := Curve3D.new()
			for point in [
				Vector3(-10.0, 0.0, -10.0),
				Vector3(10.0, 0.0, -10.0),
				Vector3(10.0, 0.0, 10.0),
				Vector3(-10.0, 0.0, 10.0),
			]:
				short_curve.add_point(point)
			short_curve.closed = true
			route.curve = short_curve
		&"start_point_invalid":
			track.start_point_index = route.curve.point_count
		&"shortcut_name_missing":
			primary_shortcut.display_name = " "
		&"shortcut_id_duplicate":
			track.get_shortcuts()[1].shortcut_id = primary_shortcut.shortcut_id
		&"shortcut_point_count":
			while primary_shortcut.curve.point_count > 2:
				primary_shortcut.curve.remove_point(1)
		&"shortcut_not_open":
			primary_shortcut.curve.closed = true
		&"shortcut_connection":
			for point_index in primary_shortcut.curve.point_count:
				primary_shortcut.curve.set_point_position(
					point_index,
					primary_shortcut.curve.get_point_position(point_index)
					+ Vector3(500.0, 0.0, 500.0)
				)
		&"shortcut_order":
			var final_index := primary_shortcut.curve.point_count - 1
			var entry := primary_shortcut.curve.get_point_position(0)
			var exit := primary_shortcut.curve.get_point_position(final_index)
			primary_shortcut.curve.set_point_position(0, exit)
			primary_shortcut.curve.set_point_position(final_index, entry)
		&"shortcut_direction":
			var sampled_points := track._sample_path(primary_shortcut, false)
			var valid_forward := (sampled_points[2] - sampled_points[0]).normalized()
			primary_shortcut.curve.set_point_out(0, -valid_forward * 80.0)
		&"props_missing":
			track.get_node("Props").free()
		&"items_missing":
			track.get_node("ItemSpawns").free()
		&"item_count":
			track.get_node("ItemSpawns").get_child(-1).free()
		&"item_type":
			var broken_item := Node3D.new()
			broken_item.name = "BrokenItem"
			track.get_node("ItemSpawns").add_child(broken_item)
		&"item_off_route":
			var marker := track.get_node("ItemSpawns/Norte") as Marker3D
			marker.position = Vector3(1000.0, 0.0, 1000.0)
	return track


func _test_guided_screen() -> void:
	var screen := TrackEditorScreen.new()
	root.add_child(screen)
	await process_frame
	await process_frame
	_check(screen.session.track != null, "Guided editor opens the first catalog track.")
	var map_view := screen.find_child("TrackMap", true, false) as TrackMapView
	var preview_container := (
		screen.find_child("TrackPreview3D", true, false) as SubViewportContainer
	)
	_check(map_view != null, "Guided editor exposes the aerial map.")
	_check(
		preview_container != null,
		"Guided editor exposes the 3D preview."
	)
	_check(
		screen.find_child("PitLaneToolbar", true, false) != null
		and screen.find_child("TrackPicker", true, false) != null
		and screen.find_child("EditorStatus", true, false) != null,
		"Guided editor preserves the control names used by the plugin and tests."
	)
	var step_texts := PackedStringArray()
	for step_button in screen._step_buttons:
		step_texts.append(step_button.text)
	_check(
		step_texts == PackedStringArray([
			"1  CONFIGURACIÓN",
			"2  CARRETERA",
			"3  ATAJOS",
			"4  OBJETOS",
			"5  REVISAR",
		]),
		"Guided editor preserves the five workflow steps and their order."
	)
	_check(
		screen._preview_viewport.own_world_3d
		and screen._preview_viewport.find_child("*", true, false) != null
		and screen._preview_camera != null
		and screen._preview_camera.get_parent() == screen._preview_viewport,
		"3D preview owns its world and keeps its camera inside the viewport."
	)
	screen._toggle_view()
	_check(
		not map_view.visible
		and preview_container.visible
		and screen._view_toggle.text == "MAPA AÉREO",
		"View toggle replaces the aerial map with the 3D preview."
	)
	screen._toggle_view()
	_check(
		map_view.visible
		and not preview_container.visible
		and screen._view_toggle.text == "VISTA 3D",
		"View toggle restores the aerial map."
	)
	_check(
		screen._new_dialog.ok_button_text == "Crear pista"
		and screen._open_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE
		and screen._unsaved_dialog.ok_button_text == "Guardar"
		and screen._guide_dialog.dialog_text.begins_with("1. CONFIGURACIÓN"),
		"Editor dialogs preserve their actions and purposes."
	)
	screen._show_unsaved_dialog("load", "user://pending-track.tscn")
	_check(
		screen._pending_action == "load"
		and screen._pending_path == "user://pending-track.tscn",
		"Unsaved changes retain the pending action and target path."
	)
	screen._unsaved_dialog.hide()
	screen._pending_action = ""
	screen._pending_path = ""
	var interactive_controls_are_accessible := true
	var button_count := 0
	for node in _collect_descendants(screen):
		if node is Button:
			button_count += 1
			interactive_controls_are_accessible = (
				interactive_controls_are_accessible
				and (node as Button).custom_minimum_size.y >= 44.0
				and (node as Button).focus_mode == Control.FOCUS_ALL
			)
	_check(button_count >= 14, "Guided editor exposes the complete five-step workflow.")
	_check(
		interactive_controls_are_accessible,
		"Guided editor buttons are touch-friendly and keyboard focusable."
	)
	for step_index in 5:
		screen._show_step(step_index)
		await process_frame
	_check(
		screen.session.track != null and is_instance_valid(screen.session.track),
		"All five guided steps render without losing the edited track."
	)
	var screen_route := screen.session.track.get_main_route()
	var screen_original := screen_route.curve.get_point_position(0)
	screen.session.snapshot_route_for_undo()
	screen_route.curve.set_point_position(0, screen_original + Vector3.RIGHT)
	screen.session.undo_route()
	await process_frame
	_check(
		is_instance_valid(screen.session.track)
		and screen.session.track.is_inside_tree()
		and screen.session.track.get_main_route().curve.get_point_position(0).is_equal_approx(
			screen_original
		),
		"Undo refreshes the guided preview without deleting the track."
	)
	screen.session.create_track(&"medium", "Atajo guiado")
	await process_frame
	screen._create_shortcut(0, 3)
	await process_frame
	_check(
		screen.session.track.get_shortcuts().size() == 1,
		"The shortcut step creates a physical shortcut without editing nodes."
	)
	_check(
		screen.session.track.validate_track().is_empty(),
		"The automatically connected shortcut passes track validation."
	)
	var asset_library := load(
		"res://assets/track/track_asset_library.tres"
	) as TrackAssetLibrary
	var asset_entry := asset_library.get_valid_entries()[0]
	screen._add_asset(asset_entry, 0, 1.0, 15.0, 30.0)
	screen._add_item_spawn(0)
	var anchored_shortcut := screen.session.track.get_shortcuts()[0]
	var anchored_prop := screen.session.track.get_node("Props").get_child(-1) as Node3D
	var anchored_item := (
		screen.session.track.get_node("ItemSpawns").get_child(-1) as Marker3D
	)
	var original_shortcut_entry := anchored_shortcut.curve.get_point_position(0)
	var original_prop_position := anchored_prop.position
	var original_item_position := anchored_item.position
	var anchored_route := screen.session.track.get_main_route()
	screen.session.snapshot_route_for_undo()
	anchored_route.curve.set_point_position(
		0,
		anchored_route.curve.get_point_position(0) + Vector3(12.0, 1.0, -4.0)
	)
	screen.session.recalculate_route_dependents()
	screen.session.mark_dirty()
	var edited_shortcut_entry := anchored_shortcut.curve.get_point_position(0)
	var edited_prop_position := anchored_prop.position
	var edited_item_position := anchored_item.position
	_check(
		not edited_shortcut_entry.is_equal_approx(original_shortcut_entry)
		and not edited_prop_position.is_equal_approx(original_prop_position)
		and not edited_item_position.is_equal_approx(original_item_position),
		"Shortcuts, item boxes, and editor props follow a route edit."
	)
	screen.session.undo_route()
	_check(
		anchored_shortcut.curve.get_point_position(0).is_equal_approx(
			original_shortcut_entry
		)
		and anchored_prop.position.is_equal_approx(original_prop_position)
		and anchored_item.position.is_equal_approx(original_item_position),
		"Undo restores the route and all anchored dependents as one operation."
	)
	screen.session.redo_route()
	_check(
		anchored_shortcut.curve.get_point_position(0).is_equal_approx(
			edited_shortcut_entry
		)
		and anchored_prop.position.is_equal_approx(edited_prop_position)
		and anchored_item.position.is_equal_approx(edited_item_position),
		"Redo restores the recalculated dependents with the route."
	)
	var test_scene_path := "user://coastal_karts_editor_screen_test.tscn"
	screen.session.scene_path = test_scene_path
	var play_request := {}
	screen.play_requested.connect(
		func(scene_path: String, track_id: StringName, laps: int) -> void:
			play_request.scene_path = scene_path
			play_request.track_id = track_id
			play_request.laps = laps
	)
	screen._handle_test_pressed()
	_check(
		play_request.get("scene_path", "") == test_scene_path
		and play_request.get("track_id", &"") == screen.session.track.track_id
		and play_request.get("laps", 0) == 3,
		"Test action preserves the play_requested signal contract."
	)
	screen.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_scene_path))


func _test_template_and_history() -> void:
	var session := TrackEditorSession.new()
	session.create_track(&"medium", "Pista de prueba")
	var track := session.track
	root.add_child(track)
	await process_frame
	_check(track.get_main_route().curve.closed, "New templates create a closed editable route.")
	_check(track.get_main_route().curve.point_count == 8, "New templates start with eight clear control points.")
	_check(track.get_node("ItemSpawns").get_child_count() == 4, "New templates include four item boxes.")
	_check(track.inspect_track().is_empty(), "New medium template passes structured validation.")

	var route := track.get_main_route()
	var original_position := route.curve.get_point_position(0)
	session.snapshot_route_for_undo()
	route.curve.set_point_position(0, original_position + Vector3(8.0, 0.0, 0.0))
	session.mark_dirty()
	session.undo_route()
	_check(
		route.curve.get_point_position(0).is_equal_approx(original_position),
		"Route edits can be undone."
	)
	session.redo_route()
	_check(
		route.curve.get_point_position(0).is_equal_approx(
			original_position + Vector3(8.0, 0.0, 0.0)
		),
		"Undone route edits can be redone."
	)

	track.start_point_index = 2
	track.rebuild_preview()
	_check(
		track.route_points[0].distance_to(route.curve.get_point_position(2)) < 0.1,
		"Start selection rotates the generated race route."
	)
	var draft_path := "user://coastal_karts_editor_test_draft.tscn"
	session.scene_path = draft_path
	_check(session.save() == OK, "Guided editor saves an incomplete or complete draft.")
	var reloaded_session := TrackEditorSession.new()
	_check(
		reloaded_session.load_track(draft_path) == OK
		and reloaded_session.track.track_id == track.track_id
		and reloaded_session.track.start_point_index == 2,
		"Saved drafts reload with their editable data intact."
	)
	var catalog_path := "user://coastal_karts_editor_test_catalog.tres"
	ResourceSaver.save(TrackCatalog.new(), catalog_path)
	reloaded_session.catalog_path = catalog_path
	root.add_child(reloaded_session.track)
	await process_frame
	_check(
		reloaded_session.publish(3, "Pista temporal") == OK,
		"A valid draft can be published through the guided editor."
	)
	var published_catalog := ResourceLoader.load(
		catalog_path,
		"TrackCatalog",
		ResourceLoader.CACHE_MODE_REPLACE
	) as TrackCatalog
	var published_definition := (
		published_catalog.get_track(track.track_id)
		if published_catalog != null
		else null
	)
	_check(
		published_definition != null,
		"Publishing registers the track in its catalog."
	)
	_check(
		published_definition != null
		and published_definition.preview_map != null
		and published_definition.preview_map.is_valid()
		and published_definition.preview_map.length_meters > 0.0,
		"Publishing persists the generated minimap and its metadata."
	)
	if reloaded_session.track != null:
		reloaded_session.track.queue_free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(draft_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(catalog_path))
	session.clear_recovery()
	track.queue_free()
	await process_frame


func _test_migration_and_partial_preview() -> void:
	var legacy_path := "res://levels/tracks/bahia_relampago.tscn"
	var scene_before := FileAccess.get_file_as_string(legacy_path)
	var session := TrackEditorSession.new()
	_check(session.load_track(legacy_path) == OK, "Legacy drafts open through the editor session.")
	_check(
		session.last_repair_summary == "2 atajos y 4 cajas reparados"
		and session.is_dirty
		and session.can_undo(),
		"Opening Bahía Relámpago repairs two shortcuts and four boxes as an undoable edit."
	)
	var all_anchors_were_created := true
	for shortcut in session.track.get_shortcuts():
		all_anchors_were_created = (
			all_anchors_were_created and shortcut.route_anchor_enabled
		)
	for marker in session.track.get_node("ItemSpawns").get_children():
		all_anchors_were_created = (
			all_anchors_were_created
			and marker.has_meta(TrackEditorSession.META_ANCHOR_PROGRESS)
		)
	_check(all_anchors_were_created, "Legacy repair creates normalized route anchors.")
	_check(
		FileAccess.get_file_as_string(legacy_path) == scene_before,
		"Automatic repair does not overwrite the source scene."
	)
	session.undo_route()
	_check(
		not session.track.get_shortcuts()[0].route_anchor_enabled
		and not session.is_dirty,
		"Undo removes the in-memory migration and restores the clean draft state."
	)
	session.redo_route()
	_check(
		session.track.get_shortcuts()[0].route_anchor_enabled and session.is_dirty,
		"Redo reapplies the legacy migration."
	)

	root.add_child(session.track)
	await process_frame
	var invalid_shortcut := session.track.get_shortcuts()[0]
	invalid_shortcut.curve.remove_point(1)
	var preview_errors := session.track.rebuild_preview()
	_check(
		not preview_errors.is_empty()
		and session.track.get_node_or_null("MainRoadCollision") != null
		and session.track.get_node_or_null("MainBarrierLeftCollision") != null
		and session.track.get_node_or_null("MainBarrierRightCollision") != null,
		"An invalid draft keeps its usable road and barriers in the preview."
	)
	_check(
		session.track.shortcut_definitions.size() == 1,
		"Partial preview omits only the invalid shortcut."
	)
	var observed_issues: Dictionary = {}
	var issues_are_unique := true
	for issue in session.track.inspect_track():
		var issue_key := "%s|%s" % [issue.code, issue.target_path]
		issues_are_unique = issues_are_unique and not observed_issues.has(issue_key)
		observed_issues[issue_key] = true
	_check(issues_are_unique, "Structured validation deduplicates issues by code and node.")
	session.track.queue_free()
	await process_frame

	var official_session := TrackEditorSession.new()
	_check(
		official_session.load_track("res://levels/coastal_track.tscn") == OK
		and official_session.last_repair_summary.is_empty()
		and not official_session.is_dirty,
		"Official tracks already contain anchors and open without migration edits."
	)
	official_session.track.free()


func _test_track_runner() -> void:
	var config_path := "user://coastal_karts_track_test.cfg"
	var config := ConfigFile.new()
	config.set_value("track", "scene_path", "res://levels/coastal_track.tscn")
	config.set_value("track", "id", &"coastal")
	config.set_value("track", "laps", 3)
	config.save(config_path)
	var runner_scene := load(
		"res://addons/track_editor/track_test_runner.tscn"
	) as PackedScene
	var runner := runner_scene.instantiate()
	root.add_child(runner)
	await process_frame
	await process_frame
	var test_world := runner.get("_world") as RaceWorld
	_check(
		test_world != null and test_world.player_kart != null,
		"The Test button runner starts the selected draft with the real player kart."
	)
	runner.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))


func _collect_descendants(node: Node) -> Array[Node]:
	var descendants: Array[Node] = []
	for child in node.get_children():
		descendants.append(child)
		descendants.append_array(_collect_descendants(child))
	return descendants


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
