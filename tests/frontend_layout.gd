extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2340, 1080)]:
		await _check_size(viewport_size)
	quit(1 if failed else 0)

func _check_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	root.add_child(viewport)
	var menu := MainMenu.new()
	menu.track_catalog = load("res://levels/track_catalog.tres") as TrackCatalog
	menu.progression_catalog = load("res://progression/progression_catalog.tres") as ProgressionCatalog
	menu.player_progress = PlayerProgress.new()
	viewport.add_child(menu)
	await process_frame
	menu._title_screen.hide()
	menu._router.replace(MenuRoute.Id.MAIN)
	menu._cup_selector.configure(menu.progression_catalog, menu.player_progress, {"source": "play", "mode": GameModeDefinition.CUP})
	for route in [MenuRoute.Id.PLAY_MODE, MenuRoute.Id.PLAY_CUP, MenuRoute.Id.PLAY_READY, MenuRoute.Id.PLAY_LOCAL_LOBBY, MenuRoute.Id.GARAGE, MenuRoute.Id.PROFILE, MenuRoute.Id.SETTINGS, MenuRoute.Id.CONTROLS]:
		menu._router.navigate(route)
		await process_frame
		var screen := menu._router._screens[route] as Control
		var bounds := Rect2(Vector2.ZERO, viewport_size)
		var valid := screen.visible
		for candidate in screen.find_children("*", "Button", true, false):
			var button := candidate as Button
			if not button.is_visible_in_tree(): continue
			if route == MenuRoute.Id.GARAGE and menu._vehicle_gallery.cards.is_ancestor_of(button): continue
			var rect := button.get_global_rect()
			if not bounds.has_point(rect.get_center()): continue
			if rect.position.x < 0.0 or rect.end.x > bounds.end.x or button.custom_minimum_size.y < 48.0:
				print("LAYOUT: %s/%s rect=%s minimum=%s" % [MenuRoute.route_name(route), button.name, rect, button.custom_minimum_size])
			valid = valid and rect.position.x >= 0.0 and rect.end.x <= bounds.end.x and button.custom_minimum_size.y >= 48.0
		_check(valid, "%s fits %dx%d with accessible actions." % [MenuRoute.route_name(route), viewport_size.x, viewport_size.y])
	_check((menu._cup_selector.cup_buttons[&"horizontes"] as Button).text.begins_with("🔒"), "The cup selector exposes locked campaign events at %dx%d." % [viewport_size.x, viewport_size.y])
	menu.queue_free()
	viewport.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else: failed = true; push_error("FAIL: " + message)
