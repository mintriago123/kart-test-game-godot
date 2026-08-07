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
