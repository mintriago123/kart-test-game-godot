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
	for route in [MenuRoute.Id.PLAY_MODE, MenuRoute.Id.PLAY_CUP, MenuRoute.Id.PLAY_READY, MenuRoute.Id.PLAY_LOCAL_LOBBY, MenuRoute.Id.PLAY_LAN_LOBBY, MenuRoute.Id.GARAGE, MenuRoute.Id.PROFILE, MenuRoute.Id.SETTINGS, MenuRoute.Id.CONTROLS]:
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
		if route == MenuRoute.Id.PLAY_LOCAL_LOBBY:
			var local := screen as LocalMultiplayerLobby
			valid = valid and _check_action_bar(local._actions, bounds, "local", viewport_size)
			valid = valid and local._card_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		elif route == MenuRoute.Id.PLAY_LAN_LOBBY:
			var lan := screen as LanMultiplayerLobby
			valid = valid and _check_action_bar(lan._actions, bounds, "LAN", viewport_size)
			valid = valid and lan._columns_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			valid = valid and lan._stage == lan.STAGE_NETWORK and lan._host_mode_button.visible and lan._join_mode_button.visible
			lan._choose_role(true)
			lan._advance_stage()
			valid = valid and lan._stage == lan.STAGE_RACE and lan._room_panel.visible and not lan._slots_scroll.visible
			lan._back()
			lan._back()
			lan._choose_role(false)
			lan._advance_stage()
			valid = valid and lan._stage == lan.STAGE_CONNECTION and lan._connection_panel.visible
			lan._back()
			lan._back()
		_check(valid, "%s fits %dx%d with accessible actions." % [MenuRoute.route_name(route), viewport_size.x, viewport_size.y])
	_check((menu._cup_selector.cup_buttons[&"horizontes"] as Button).text.begins_with("🔒"), "The cup selector exposes locked campaign events at %dx%d." % [viewport_size.x, viewport_size.y])
	menu.queue_free()
	viewport.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else: failed = true; push_error("FAIL: " + message)


func _check_action_bar(actions: Control, bounds: Rect2, lobby_name: String, viewport_size: Vector2i) -> bool:
	var valid := actions != null and actions.is_visible_in_tree()
	if valid:
		var rect := actions.get_global_rect()
		valid = rect.position.x >= bounds.position.x and rect.end.x <= bounds.end.x and rect.position.y >= bounds.position.y and rect.end.y <= bounds.end.y
	if not valid:
		push_error("FAIL: %s action bar is not fixed inside %dx%d viewport." % [lobby_name, viewport_size.x, viewport_size.y])
	return valid
