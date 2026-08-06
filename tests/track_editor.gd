extends SceneTree

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_guided_screen()
	await _test_template_and_history()
	await _test_migration_and_partial_preview()
	await _test_track_runner()
	quit(1 if _has_failed else 0)


func _test_guided_screen() -> void:
	var screen := TrackEditorScreen.new()
	root.add_child(screen)
	await process_frame
	await process_frame
	_check(screen.session.track != null, "Guided editor opens the first catalog track.")
	_check(screen.find_child("TrackMap", true, false) != null, "Guided editor exposes the aerial map.")
	_check(
		screen.find_child("TrackPreview3D", true, false) != null,
		"Guided editor exposes the 3D preview."
	)
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
	screen.queue_free()
	await process_frame
	await process_frame


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
