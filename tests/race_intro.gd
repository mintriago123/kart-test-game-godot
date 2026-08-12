extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload(
	"res://levels/track_catalog.tres"
)

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_configure_input()
	if "--verify-auto-race" in OS.get_cmdline_user_args():
		await _test_auto_race_argument()
		quit(1 if _has_failed else 0)
		return
	await _test_skip_sequence_and_pause()
	await _test_natural_sequence()
	await _test_invalid_route_fallback()
	_test_small_elevated_route_math()
	await _test_hud_component_contracts()
	await _test_hud_resolution(Vector2i(640, 360))
	await _test_hud_resolution(Vector2i(1920, 1080))
	await _test_hud_skip_inputs()
	await _test_retry_skips_intro()
	quit(1 if _has_failed else 0)


func _test_skip_sequence_and_pause() -> void:
	var world := _create_world(true)
	root.add_child(world)
	await process_frame
	await process_frame

	var manager := world.race_manager
	var hud := world._hud
	var intro := world._intro_camera
	var follow_camera := world._follow_camera
	var countdown_observation := {"starts": 0}
	manager.countdown_changed.connect(
		func(text: String) -> void:
			if text == "3":
				countdown_observation.starts += 1
	)
	_check(
		manager.state == RaceManager.RaceState.PRE_RACE
		and is_zero_approx(manager.race_time),
		"Intro keeps the race and timer in PRE_RACE."
	)
	_check(
		intro != null
		and intro.is_running()
		and not follow_camera.is_active(),
		"Intro camera is exclusive while the follow camera is inactive."
	)
	_check(
		_all_racers_have_control(manager, false),
		"No racer receives control during the intro."
	)
	_check(
		_all_ai_drivers_processing(world, false),
		"AI drivers remain inactive during the intro."
	)
	_check(
		hud._intro_title.text == "COSTA TURBO"
		and hud._intro_laps.text == "3 VUELTAS"
		and not hud._race_elements[0].visible,
		"Intro displays the selected track and laps while hiding race indicators."
	)

	hud.set_mobile_controls_enabled(true)
	await process_frame
	_check(
		not hud._touch_controls.visible,
		"Mobile controls stay hidden during the intro."
	)
	_check(
		_all_item_boxes_monitoring(world, false),
		"Item boxes remain inactive before the race."
	)

	var elapsed_before_pause := intro.elapsed
	paused = true
	await process_frame
	await process_frame
	_check(
		is_equal_approx(intro.elapsed, elapsed_before_pause),
		"Pausing freezes intro progress."
	)
	paused = false

	intro.set_process(false)
	var early_key := _make_skip_key()
	hud._unhandled_input(early_key)
	_check(
		manager.state == RaceManager.RaceState.PRE_RACE
		and not intro.request_skip(),
		"Skip requests are ignored before two seconds."
	)
	intro._process(
		RaceIntroCamera.SKIP_AVAILABLE_TIME - intro.elapsed - 0.01
	)
	_check(
		not hud._intro_skip_button.visible,
		"Skip button remains hidden before the exact threshold."
	)
	intro._process(0.02)
	_check(
		hud._intro_skip_button.visible
		and not hud._intro_skip_button.disabled,
		"Skip button becomes operable after two seconds."
	)

	hud._unhandled_input(_make_skip_key())
	_check(
		not hud._intro_skip_button.visible,
		"Space starts the short transition and hides the skip action."
	)
	var expected_follow_transform := follow_camera.get_target_transform()
	intro._process(RaceIntroCamera.SKIP_TRANSITION_DURATION)
	await process_frame
	_check(
		manager.state == RaceManager.RaceState.COUNTDOWN
		and countdown_observation.starts == 1,
		"Skipping starts exactly one countdown."
	)
	_check(
		world._intro_camera == null
		and follow_camera.is_active()
		and follow_camera.global_position.distance_to(
			expected_follow_transform.origin
		) < 0.05,
		"Skip removes the temporary camera at the follow-camera pose."
	)
	_check(
		hud._touch_controls.visible,
		"Mobile controls return when the intro finishes."
	)

	manager.set_process(false)
	manager._process_countdown(3.1)
	await process_frame
	_check(
		manager.state == RaceManager.RaceState.RACING
		and _all_racers_have_control(manager, true)
		and _all_ai_drivers_processing(world, true),
		"All four racers activate only when the countdown reaches ¡YA!."
	)
	_check(
		_all_item_boxes_monitoring(world, true),
		"Item boxes activate with the race."
	)
	manager.begin()
	_check(
		countdown_observation.starts == 1,
		"RaceManager ignores duplicate begin requests."
	)

	world.queue_free()
	await process_frame


func _test_natural_sequence() -> void:
	var world := _create_world(true)
	root.add_child(world)
	await process_frame
	await process_frame
	var intro := world._intro_camera
	var manager := world.race_manager
	var countdown_observation := {"starts": 0}
	manager.countdown_changed.connect(
		func(text: String) -> void:
			if text == "3":
				countdown_observation.starts += 1
	)
	intro.set_process(false)

	intro._process(RaceIntroCamera.FLIGHT_DURATION)
	_check(
		intro.global_position.is_finite()
		and intro._camera.fov > 0.0,
		"Aerial flight produces a finite camera pose."
	)
	intro._process(
		RaceIntroCamera.GRID_END_TIME
		- RaceIntroCamera.FLIGHT_DURATION
	)
	_check(
		intro.global_position.is_finite(),
		"Grid presentation reaches a valid camera pose."
	)
	var expected_follow_transform := world._follow_camera.get_target_transform()
	intro._process(
		RaceIntroCamera.INTRO_DURATION
		- RaceIntroCamera.GRID_END_TIME
	)
	await process_frame
	_check(
		manager.state == RaceManager.RaceState.COUNTDOWN
		and countdown_observation.starts == 1,
		"Natural completion starts exactly one countdown."
	)
	_check(
		world._follow_camera.is_active()
		and world._follow_camera.global_position.distance_to(
			expected_follow_transform.origin
		) < 0.05,
		"Natural completion lands on the final follow-camera pose."
	)

	world.queue_free()
	await process_frame


func _test_invalid_route_fallback() -> void:
	var world := _create_world(true)
	root.add_child(world)
	var unusable_route: Array[Vector3] = [
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3.ZERO,
	]
	world.race_manager.configure(unusable_route)
	await process_frame
	await process_frame
	_check(
		world._intro_camera == null
		and world.race_manager.state == RaceManager.RaceState.COUNTDOWN
		and world._follow_camera.is_active(),
		"An unusable intro route falls back directly to the countdown."
	)

	world.queue_free()
	await process_frame


func _test_small_elevated_route_math() -> void:
	var intro := RaceIntroCamera.new()
	var small_elevated_route: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(4.0, 1.5, 0.0),
		Vector3(4.0, 3.0, 4.0),
		Vector3(0.0, 0.5, 4.0),
	]
	var is_usable := intro._prepare_route(small_elevated_route)
	var flight_transform := intro._get_flight_transform(0.5)
	var grid_transform := intro._get_grid_end_transform()
	_check(
		is_usable
		and flight_transform.origin.is_finite()
		and grid_transform.origin.is_finite(),
		"Small elevated routes produce finite procedural camera poses."
	)
	intro.free()


func _test_hud_component_contracts() -> void:
	var status := RaceStatusView.new()
	status.build_interface()
	root.add_child(status)
	status.update_race_info(2, 4, 3, 6, 125.5)
	status.update_speed(87.9)
	_check(
		RaceHudStyle.format_time(0.0) == "00:00.000"
		and RaceHudStyle.format_time(65.432) == "01:05.432"
		and RaceHudStyle.format_time(125.5) == "02:05.500"
		and status.lap_label.text == "VUELTA 2/4"
		and status.position_label.text == "3º / 6"
		and status.time_label.text == "02:05.500"
		and status.speed_label.text == "087 km/h",
		"RaceStatusView preserves time, lap, position, and speed formats."
	)
	status.show_countdown("2", true)
	_check(
		status.countdown_label.text == "2"
		and not status.countdown_label.visible,
		"RaceStatusView suppresses countdown text during the intro."
	)
	status.show_countdown("¡YA!", false)
	_check(
		status.countdown_label.visible
		and status.countdown_label.text == "¡YA!",
		"RaceStatusView reveals countdown text after the intro."
	)
	var boost := ItemDefinition.boost()
	var shield := ItemDefinition.sea_bubble()
	status.show_item(boost)
	status.show_boost(0.75)
	status.show_shield(shield, 3.25, 7.0, false)
	_check(
		status.item_label.text == boost.display_name.to_upper()
		and status.item_icon.texture == boost.icon
		and status.drift_bar.value == 0.75
		and status.shield_panel.visible
		and status.shield_label.text == "BURBUJA · 3.2 s"
		and status.shield_bar.value == 3.25
		and status.shield_bar.max_value == 7.0,
		"RaceStatusView renders item, shield, and drift state directly."
	)
	status.show_item(null)
	status.show_shield(shield, 3.0, 7.0, true)
	_check(
		status.item_label.text == "SIN OBJETO"
		and not status.item_icon.visible
		and not status.shield_panel.visible,
		"RaceStatusView clears item and hides shield state during the intro."
	)
	status.queue_free()
	await process_frame

	Input.action_release(&"accelerate")
	Input.action_release(&"brake")
	Input.action_release(&"drift")
	Input.action_release(&"use_item")
	var touch := RaceTouchControls.new()
	touch.build_interface(true, false)
	root.add_child(touch)
	var kart := Kart.new()
	kart.is_control_enabled = true
	touch.bind_player(kart)
	touch.show_item(boost)
	touch.update_state(false, false, false)
	_check(
		touch.visible
		and Input.is_action_pressed(&"accelerate")
		and touch.item_button.item_icon == boost.icon
		and boost.display_name in touch.item_button.tooltip_text,
		"RaceTouchControls exposes item state and automatic acceleration."
	)
	Input.action_press(&"brake")
	touch.update_state(false, false, false)
	_check(
		not Input.is_action_pressed(&"accelerate"),
		"RaceTouchControls yields automatic acceleration while braking."
	)
	Input.action_release(&"brake")
	var drift_button := (
		touch.get_node("DriftButton") as MobileActionButton
	)
	var brake_button := (
		touch.get_node("BrakeButton") as MobileActionButton
	)
	drift_button._set_pressed(true)
	touch.item_button._set_pressed(true)
	brake_button._set_pressed(true)
	touch.set_controls_visible(false)
	await process_frame
	_check(
		not Input.is_action_pressed(&"accelerate")
		and not Input.is_action_pressed(&"drift")
		and not Input.is_action_pressed(&"use_item")
		and not Input.is_action_pressed(&"brake"),
		"RaceTouchControls releases every action when hidden."
	)
	touch.set_controls_visible(true)
	touch.update_state(false, false, false)
	drift_button._set_pressed(true)
	touch.queue_free()
	await process_frame
	_check(
		not Input.is_action_pressed(&"accelerate")
		and not Input.is_action_pressed(&"drift"),
		"RaceTouchControls releases actions when destroyed."
	)
	kart.free()

	var flow := RaceFlowOverlay.new()
	flow.build_interface()
	root.add_child(flow)
	var flow_events := {
		"skip": 0,
		"retry": 0,
		"menu": 0,
	}
	flow.intro_skip_requested.connect(
		func() -> void: flow_events.skip += 1
	)
	flow.retry_requested.connect(
		func() -> void: flow_events.retry += 1
	)
	flow.menu_requested.connect(
		func() -> void: flow_events.menu += 1
	)
	flow.show_intro("Bahía táctil", 5)
	flow.update_intro_progress(0.5)
	flow.set_intro_skip_enabled(true)
	flow.request_intro_skip()
	_check(
		flow.is_intro_visible
		and flow.intro_overlay.visible
		and flow.intro_title.text == "BAHÍA TÁCTIL"
		and flow.intro_laps.text == "5 VUELTAS"
		and flow.intro_content.modulate.a > 0.0
		and flow.intro_skip_button.visible
		and flow_events.skip == 1,
		"RaceFlowOverlay presents intro state and emits skip requests."
	)
	flow.hide_intro()
	flow.update_pause_visibility(true)
	_check(
		not flow.intro_overlay.visible
		and flow.pause_overlay.visible,
		"RaceFlowOverlay transitions from intro to pause."
	)
	flow.show_results(4, 65.432)
	flow.update_pause_visibility(true)
	var actions := flow.results_panel.find_child(
		"Actions",
		true,
		false
	)
	var menu_button := actions.get_child(1) as Button
	flow.retry_button.pressed.emit()
	menu_button.pressed.emit()
	_check(
		flow.results_panel.visible
		and "¡META!" in flow.results_title.text
		and "4º LUGAR" in flow.results_title.text
		and "01:05.432" in flow.results_title.text
		and not flow.pause_overlay.visible
		and flow_events.retry == 1
		and flow_events.menu == 1,
		"RaceFlowOverlay formats results, hides pause, and emits actions."
	)
	flow.queue_free()
	await process_frame


func _test_hud_resolution(viewport_size: Vector2i) -> void:
	var test_viewport := SubViewport.new()
	test_viewport.size = viewport_size
	root.add_child(test_viewport)
	var hud := RaceHud.new()
	hud.mobile_controls_enabled = true
	test_viewport.add_child(hud)
	await process_frame
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	var controls: Array[Control] = [
		hud._status_view.get_node("RaceInfo") as Control,
		hud._item_chip,
		hud._drift_bar,
		hud._flow_overlay.get_node("PauseButton") as Control,
		hud._steering_pad,
		hud._touch_view.get_node("DriftButton") as Control,
		hud._touch_view.get_node("ItemButton") as Control,
		hud._touch_view.get_node("BrakeButton") as Control,
	]
	var controls_fit := true
	for control in controls:
		var control_rect := control.get_global_rect()
		if not viewport_rect.encloses(control_rect):
			print("INFO: HUD control outside %s: %s %s" % [viewport_size, control.name, control_rect])
		controls_fit = (
			controls_fit
			and viewport_rect.encloses(control_rect)
		)
	var drift_rect := (
		hud._touch_view.get_node("DriftButton") as Control
	).get_global_rect()
	var item_rect := (
		hud._touch_view.get_node("ItemButton") as Control
	).get_global_rect()
	var brake_rect := (
		hud._touch_view.get_node("BrakeButton") as Control
	).get_global_rect()
	_check(
		controls_fit
		and not drift_rect.intersects(item_rect)
		and not drift_rect.intersects(brake_rect)
		and not item_rect.intersects(brake_rect),
		"HUD controls fit without overlap at %dx%d."
		% [viewport_size.x, viewport_size.y]
	)
	hud.show_results(1, 65.432)
	await process_frame
	var results_card := (
		hud._results_panel.find_child("Card", true, false) as Control
	)
	_check(
		viewport_rect.encloses(results_card.get_global_rect()),
		"HUD results card fits at %dx%d."
		% [viewport_size.x, viewport_size.y]
	)
	test_viewport.queue_free()
	await process_frame


func _test_hud_skip_inputs() -> void:
	var hud := RaceHud.new()
	root.add_child(hud)
	await process_frame
	var skip_observation := {"requests": 0}
	hud.intro_skip_requested.connect(
		func() -> void: skip_observation.requests += 1
	)
	hud.show_intro("Circuito táctil", 2)
	hud.set_intro_skip_enabled(true)
	hud.show_countdown("2")
	hud._intro_skip_button.pressed.emit()
	hud._unhandled_input(_make_skip_key(KEY_ENTER))
	_check(
		skip_observation.requests == 2
		and hud._intro_skip_button.custom_minimum_size.y >= 44.0
		and hud._intro_skip_button.focus_mode == Control.FOCUS_ALL,
		"Native touch/click and Enter use an accessible skip button."
	)
	_check(
		hud._intro_overlay.visible
		and not hud._race_elements[0].visible
		and not hud._countdown_label.visible,
		"Intro presentation hides race status and pending countdown text."
	)
	hud.hide_intro()
	_check(
		not hud._intro_overlay.visible
		and hud._race_elements[0].visible
		and hud._countdown_label.visible,
		"Leaving the intro restores race status and pending countdown text."
	)
	hud.update_race_info(2, 3, 1, 4, 65.432)
	hud.show_results(1, 65.432)
	_check(
		hud._lap_label.text == "VUELTA 2/3"
		and hud._time_label.text == "01:05.432"
		and "01:05.432" in hud._results_title.text
		and hud._results_panel.visible,
		"HUD transitions preserve race labels, time format, and results content."
	)
	var drift_button := (
		hud._touch_controls.get_node("DriftButton")
		as MobileActionButton
	)
	drift_button._set_pressed(true)
	hud.queue_free()
	await process_frame
	_check(
		not Input.is_action_pressed(&"drift"),
		"Destroying the HUD releases active touch actions."
	)


func _test_retry_skips_intro() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.settings.is_persistence_enabled = false
	main.start_game(&"coastal")
	await process_frame
	await process_frame
	var first_world: RaceWorld = main.race_world
	_check(
		first_world.play_intro
		and first_world.race_manager.state
		== RaceManager.RaceState.PRE_RACE,
		"Starting from the menu enables the intro."
	)

	main._restart_game()
	await process_frame
	await process_frame
	_check(
		main.race_world != first_world
		and not main.race_world.play_intro
		and main.race_world.race_manager.state
		== RaceManager.RaceState.COUNTDOWN,
		"Another race skips the intro and starts at 3."
	)

	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout


func _test_auto_race_argument() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	_check(
		main.race_world != null
		and not main.race_world.play_intro
		and main.race_world.race_manager.state
		== RaceManager.RaceState.COUNTDOWN,
		"--auto-race skips the intro and starts at 3."
	)
	main.queue_free()
	await process_frame


func _create_world(should_play_intro: bool) -> RaceWorld:
	var world := RaceWorld.new()
	world.track_definition = TRACK_CATALOG.get_valid_track(&"coastal")
	world.play_intro = should_play_intro
	return world


func _all_racers_have_control(
	manager: RaceManager,
	expected_control: bool
) -> bool:
	for racer in manager.racers:
		if racer.is_control_enabled != expected_control:
			return false
	return true


func _all_item_boxes_monitoring(
	world: RaceWorld,
	expected_monitoring: bool
) -> bool:
	for item_box in world._item_boxes:
		if item_box.monitoring != expected_monitoring:
			return false
	return true


func _all_ai_drivers_processing(
	world: RaceWorld,
	expected_processing: bool
) -> bool:
	for ai_driver in world._ai_drivers:
		if ai_driver.is_physics_processing() != expected_processing:
			return false
	return true


func _make_skip_key(keycode: Key = KEY_SPACE) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _configure_input() -> void:
	var actions := {
		&"steer_left": KEY_A,
		&"steer_right": KEY_D,
		&"accelerate": KEY_W,
		&"brake": KEY_S,
		&"drift": KEY_SPACE,
		&"use_item": KEY_E,
	}
	for action in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		var event := InputEventKey.new()
		event.physical_keycode = actions[action]
		InputMap.action_add_event(action, event)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
