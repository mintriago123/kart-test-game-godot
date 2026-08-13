extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tokens_and_input_modes()
	await _test_router_and_shell()
	_test_binding_profiles()
	await _test_input_prompts()
	await _test_title_input_gate()
	await _test_settings_screen()
	await _test_pause_contract()
	_test_reduced_motion_persistence()
	await _test_shared_components_and_flow()
	_test_progress_schema_two()
	quit(1 if failed else 0)


func _test_router_and_shell() -> void:
	var router := MenuRouter.new()
	root.add_child(router)
	var main := Control.new()
	var garage := Control.new()
	router.add_child(main)
	router.add_child(garage)
	router.register_screen(MenuRoute.Id.MAIN, main)
	router.register_screen(MenuRoute.Id.GARAGE, garage)
	router.replace(MenuRoute.Id.MAIN)
	router.navigate(MenuRoute.Id.GARAGE, {"source": "test"})
	_check(router.current_route == MenuRoute.Id.GARAGE and garage.visible, "Typed router navigates with payloads.")
	_check(router.back() and router.current_route == MenuRoute.Id.MAIN, "Universal back restores the previous route.")
	var shell := MenuShell.new()
	root.add_child(shell)
	await process_frame
	shell.size = Vector2(640, 360)
	shell._update_layout()
	_check(shell.layout == MenuShell.Layout.COMPACT and shell.safe_margin >= 16, "Shell applies compact safe-area layout at 640x360.")
	router.queue_free()
	shell.queue_free()
	await process_frame


func _test_binding_profiles() -> void:
	for action in InputBindingProfile.REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var key := InputEventKey.new()
			key.physical_keycode = KEY_ENTER if action == &"ui_accept" else KEY_ESCAPE
			InputMap.action_add_event(action, key)
	var profile := InputBindingProfile.new()
	profile.capture_from_input_map(InputBindingProfile.REQUIRED_ACTIONS)
	_check(profile.is_valid(), "Binding profiles preserve confirm, back and pause.")
	var conflict_event := (profile.bindings[&"ui_accept"] as Array).front() as InputEvent
	_check(profile.find_conflict(conflict_event, &"pause") == &"ui_accept", "Binding conflicts are detected before replacement.")
	_check(not profile.assign(&"pause", conflict_event, &"cancel"), "Conflict cancellation leaves the profile unchanged.")
	var screen := ControlsScreen.new()
	root.add_child(screen)
	screen.begin_capture(&"pause")
	screen._pending_event = conflict_event
	screen._pending_conflict = &"ui_accept"
	screen._show_conflict(&"pause", &"ui_accept", conflict_event)
	_check(screen._conflict_modal != null and screen._conflict_modal.find_children("*", "Button", true, false).size() == 3, "Binding conflicts offer swap, replace, and cancel.")
	screen.queue_free()


func _test_input_prompts() -> void:
	var prompt := ActionPromptView.new()
	root.add_child(prompt)
	prompt.set_action(&"ui_accept")
	await process_frame
	_check(prompt.prompt != null and prompt.prompt.action == "ui_accept", "Local prompt adapter delegates actions to Godot Input Prompts.")
	var coordinator := InputDeviceCoordinator.new()
	root.add_child(coordinator)
	coordinator.set_manual_family(InputDeviceCoordinator.NINTENDO)
	var prompt_manager := root.get_node_or_null("PromptManager")
	_check(coordinator.get_visual_family() == &"nintendo" and prompt_manager != null and prompt_manager.preferred_icons == InputPrompt.Icons.NINTENDO, "Manual Nintendo family selects Nintendo glyphs.")
	prompt.queue_free()
	coordinator.queue_free()
	await process_frame


func _test_title_input_gate() -> void:
	var menu := MainMenu.new()
	root.add_child(menu)
	await process_frame
	var started := [false]
	menu.play_requested.connect(func(_track: StringName, _cc: StringName, _mode: int, _difficulty: StringName) -> void: started[0] = true)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	_check(menu._title_screen.visible, "Title remains above the menu while confirm is held.")
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	await process_frame
	await process_frame
	_check(not menu._title_screen.visible and not started[0] and not menu._track_selector.visible, "Confirm opens only the main menu and cannot leak into Play.")
	menu._router.navigate(MenuRoute.Id.GARAGE)
	_check(menu._router.current_route == MenuRoute.Id.GARAGE and menu._garage_panel.visible, "Garage is a real routed screen.")
	menu._router.navigate(MenuRoute.Id.SETTINGS)
	menu._router.navigate(MenuRoute.Id.CONTROLS)
	_check(menu._controls_panel.visible and menu._router.back() and menu._settings_panel.visible, "Settings and controls share router history.")
	menu.queue_free()
	await process_frame


func _test_tokens_and_input_modes() -> void:
	_check(UiTokens.TOUCH_TARGET >= 48, "Shared controls preserve the 48 px touch target.")
	var controller := UiInputModeController.new()
	root.add_child(controller)
	controller.set_mode(UiInputModeController.GAMEPAD)
	_check(controller.mode == &"gamepad" and controller.get_prompt(&"ui_accept") == "A", "Input mode exposes gamepad prompts.")
	controller.set_mode(UiInputModeController.KEYBOARD)
	_check(controller.get_prompt(&"ui_cancel") == "ESC", "Input mode exposes keyboard prompts.")
	controller.queue_free()


func _test_settings_screen() -> void:
	var screen := SettingsScreen.new()
	root.add_child(screen)
	await process_frame
	var settings := GameSettings.new()
	settings.ui_reduced_motion = true
	screen.apply_snapshot(settings)
	_check(screen._controls.size() == 10, "Reusable settings screen exposes every settings group.")
	_check((screen._controls.reduced_motion as CheckButton).button_pressed, "Settings snapshot includes reduced motion.")
	var emitted := [false]
	screen.reduced_motion_changed.connect(func(_enabled: bool) -> void: emitted[0] = true)
	(screen._controls.reduced_motion as CheckButton).toggled.emit(false)
	_check(emitted[0], "Reduced motion changes emit through the reusable screen.")
	screen.queue_free()
	await process_frame


func _test_pause_contract() -> void:
	var overlay := RaceFlowOverlay.new()
	root.add_child(overlay)
	overlay.build_interface()
	await process_frame
	_check(overlay.has_signal("resume_requested") and overlay.has_signal("restart_requested"), "Pause overlay preserves resume and restart contracts.")
	_check(overlay.has_signal("settings_requested") and overlay.has_signal("controls_requested") and overlay.has_signal("quit_requested"), "Pause overlay exposes settings, controls, and quit contracts.")
	var actions := overlay.pause_overlay.find_children("*", "Button", true, false)
	var touch_safe := actions.size() == 5
	for action in actions:
		touch_safe = touch_safe and (action as Button).custom_minimum_size.y >= 48.0
	_check(touch_safe, "All pause actions meet the minimum touch target.")
	var pause_button := overlay.get_node("PauseButton") as Button
	pause_button.pressed.emit()
	await process_frame
	_check(paused and overlay.pause_overlay.visible, "Touching pause immediately pauses and opens its menu.")
	var resume := overlay.pause_overlay.find_child("Resume", true, false) as Button
	resume.pressed.emit()
	await create_timer(RaceFlowOverlay.RESUME_DELAY + 0.05, true).timeout
	_check(not paused, "Continue releases the paused scene tree.")
	overlay.queue_free()
	await process_frame


func _test_reduced_motion_persistence() -> void:
	var path := "user://ui_redesign_test.cfg"
	var settings := GameSettings.new()
	settings.settings_path = path
	settings.ui_reduced_motion = true
	settings.save_to_disk()
	var loaded := GameSettings.new()
	loaded.settings_path = path
	loaded.load_from_disk()
	_check(loaded.ui_reduced_motion, "Reduced motion persists in GameSettings.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_shared_components_and_flow() -> void:
	var components: Array[Control] = [ActionButton.new(), MenuList.new(), EventCard.new(), StatBar.new(), SettingRow.new(), ConfirmationModal.new(), Toast.new(), RewardReveal.new()]
	for component in components: root.add_child(component)
	await process_frame
	_check((components[0] as ActionButton).custom_minimum_size.y >= 48.0 and components.size() == 8, "All eight shared UI components instantiate with accessible actions.")
	var showroom := VehicleViewport.new(); showroom.size = Vector2(480, 270); root.add_child(showroom); await process_frame
	showroom.set_framing(VehicleViewport.Framing.GARAGE); showroom.reduced_motion = true
	_check(showroom.viewport != null and showroom.camera != null and showroom.reduced_motion, "Shared showroom builds and respects reduced motion.")
	var second_showroom := VehicleViewport.new(); second_showroom.size = Vector2(480, 270); root.add_child(second_showroom); await process_frame
	_check(showroom.viewport.own_world_3d and second_showroom.viewport.own_world_3d and showroom.viewport.world_3d != second_showroom.viewport.world_3d, "Every showroom owns an isolated 3D world and cannot render another showroom's kart.")
	var progression: ProgressionCatalog = load("res://progression/progression_catalog.tres")
	for unlock in progression.unlocks.unlocks:
		showroom.show_variant(unlock.kart_variant)
	await process_frame
	await process_frame
	var visible_models := 0
	for candidate in showroom.model_holder.get_children():
		if candidate is Node3D and (candidate as Node3D).visible:
			visible_models += 1
	_check(visible_models == 1, "Shared showroom commits only the latest vehicle requested during rapid changes.")
	_check(showroom.model_holder.get_child_count() == 1, "Shared showroom releases superseded vehicle models after the frame.")
	var visible_characters := 0
	for character in showroom.model.find_children("character", "MeshInstance3D", true, false):
		if (character as MeshInstance3D).visible:
			visible_characters += 1
	_check(visible_characters == 0, "Garage showroom hides the generic driver and presents only one vehicle silhouette.")
	var modes := ModeSelectScreen.new(); root.add_child(modes); await process_frame
	var selected := [-1]; modes.mode_selected.connect(func(mode: int): selected[0] = mode); modes._choose(GameModeDefinition.TIME_TRIAL)
	_check(selected[0] == GameModeDefinition.TIME_TRIAL and modes.last_focused_mode == GameModeDefinition.TIME_TRIAL, "Mode selection emits its payload and remembers focus.")
	var race_minimap := RaceMinimap.new(); root.add_child(race_minimap); await process_frame
	race_minimap.set_game_mode(GameModeDefinition.TIME_TRIAL)
	_check(not race_minimap.direction_arrows_visible, "Time trial minimap hides direction chevrons that resemble rival markers.")
	race_minimap.set_game_mode(GameModeDefinition.RACE)
	_check(race_minimap.direction_arrows_visible, "Race minimap retains track direction chevrons.")
	for component in components: component.queue_free()
	showroom.queue_free(); second_showroom.queue_free(); modes.queue_free(); race_minimap.queue_free(); await process_frame

func _test_progress_schema_two() -> void:
	var path := "user://progress_schema_two_test.cfg"
	var fixture := ConfigFile.new()
	fixture.set_value("progress", "schema_version", 2)
	fixture.set_value("progress", "best_medals", {"tropical/competitive": 2})
	fixture.set_value("progress", "unlocked_reward_ids", {&"competitive_bronze": true})
	fixture.set_value("progress", "equipped_kart_variant_id", "taxi")
	fixture.set_value("progress", "active_cup", {"cup_id": &"tropical", "current_race_index": 1})
	fixture.set_value("telemetry", "races_played", 4)
	fixture.set_value("telemetry", "victories", 1)
	fixture.set_value("telemetry", "podiums", 3)
	fixture.set_value("telemetry", "items_used", 2)
	fixture.save(path)
	var loaded := PlayerProgress.new(); loaded.save_path = path; loaded.load_from_disk()
	_check(loaded.races_played == 4 and loaded.victories == 1 and loaded.podiums == 3 and loaded.items_used == 2, "Schema 2 telemetry persists and reloads.")
	_check(loaded.get_medal(&"tropical", &"competitive") == 2 and loaded.equipped_kart_variant_id == &"taxi" and not loaded.active_cup.is_empty(), "Schema 2 medals, equipped vehicle, and active cup survive migration.")
	_check(loaded.seen_reward_ids.has(&"career_12") and not loaded.seen_reward_ids.has(&"competitive_bronze") and loaded.get_new_reward_count() == 0, "Schema 2 rewards migrate to their vehicle-equivalent IDs as already seen.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)
