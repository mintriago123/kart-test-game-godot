extends SceneTree

const BASE_MAX_SPEED := 25.0
const SPEED_TARGETS := {
	&"50": 22.0,
	&"100": 26.0,
	&"150": 30.0,
	&"200": 35.0,
}

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_ensure_input_actions()
	_test_race_class_scaling()
	_test_drive_curves()
	_test_barrier_retention()
	_test_kart_bumps()
	_test_recovery_sampling_reset()
	_test_record_migration_and_independence()
	_test_settings_persistence()
	_test_controller_bindings()
	_test_drift_boost_levels()
	await _test_drift_hop_and_snap()
	await _test_race_class_selector()
	await _test_shared_race_class_and_camera()
	quit(1 if _has_failed else 0)


func _test_recovery_sampling_reset() -> void:
	var kart := Kart.new()
	root.add_child(kart)
	kart.set_physics_process(false)
	kart.is_control_enabled = true
	kart.set_drive_input(1.0, 0.0, 0.0, false, false)
	kart._recovery_controller.update(1.25)
	kart._recovery_controller.update(1.25)
	kart.set_respawn_transform(kart.global_transform)
	kart._recovery_controller.update(1.25)
	kart._recovery_controller.update(1.25)
	_check(
		kart.recovery_count == 0,
		"Assigning a respawn point clears stale recovery motion samples."
	)
	kart._recovery_controller.update(1.25)
	_check(
		kart.recovery_count == 1 and kart.last_recovery_reason == "stalled",
		"A genuinely stationary kart still recovers after three seconds."
	)
	kart.queue_free()


func _ensure_input_actions() -> void:
	for action in [
		&"accelerate",
		&"brake",
		&"steer_left",
		&"steer_right",
		&"drift",
		&"use_item",
	]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _test_race_class_scaling() -> void:
	var base_stats := KartStats.new()
	for definition in RaceClassDefinition.get_all():
		var scaled_stats := definition.apply_to(base_stats)
		var target_speed: float = SPEED_TARGETS[definition.id]
		_check(
			absf(scaled_stats.max_speed - target_speed) <= target_speed * 0.05,
			"%s scales the base kart to %.0f m/s within five percent."
			% [definition.display_name, target_speed]
		)
	_check(
		is_equal_approx(base_stats.max_speed, BASE_MAX_SPEED),
		"Race class scaling does not mutate the shared base stats."
	)
	var slow_stats := RaceClassDefinition.get_by_id(&"50").apply_to(base_stats)
	var fast_stats := RaceClassDefinition.get_by_id(&"200").apply_to(base_stats)
	_check(
		fast_stats.acceleration > slow_stats.acceleration
		and fast_stats.braking > slow_stats.braking
		and fast_stats.grip < slow_stats.grip
		and fast_stats.drift_grip < slow_stats.drift_grip,
		"200 CC accelerates and brakes harder while retaining less grip than 50 CC."
	)


func _test_drive_curves() -> void:
	var speeds_after_one_second: Dictionary = {}
	var fixture := Node3D.new()
	root.add_child(fixture)
	for definition in RaceClassDefinition.get_all():
		var kart := Kart.new()
		kart.configure_for_race(KartStats.new(), definition)
		kart.set_physics_process(false)
		fixture.add_child(kart)
		for step in 600:
			kart._apply_ground_drive(1.0 / 60.0, 1.0, 0.0, 0.0)
			if step == 59:
				speeds_after_one_second[definition.id] = kart.get_horizontal_speed()
		var target_speed: float = SPEED_TARGETS[definition.id]
		_check(
			absf(kart.get_horizontal_speed() - target_speed) <= target_speed * 0.05,
			"%s reaches its soft maximum speed within five percent."
			% definition.display_name
		)

		var coasting_speed := kart.get_horizontal_speed()
		for _step in 60:
			kart._apply_ground_drive(1.0 / 60.0, 0.0, 0.0, 0.0)
		_check(
			kart.get_horizontal_speed() < coasting_speed,
			"%s loses speed progressively to rolling resistance."
			% definition.display_name
		)

		kart.velocity = Vector3(0.0, 0.0, -target_speed)
		for _step in 30:
			kart._apply_ground_drive(1.0 / 60.0, 0.0, 1.0, 0.0)
		_check(
			kart.get_horizontal_speed() < target_speed * 0.65,
			"%s full braking removes substantial speed in half a second."
			% definition.display_name
		)
		kart.free()
	_check(
		float(speeds_after_one_second[&"200"])
		> float(speeds_after_one_second[&"50"]),
		"Higher CC classes accelerate faster during the first second."
	)
	_check(
		is_equal_approx(Kart.get_steering_factor(0.0, 30.0), 0.45)
		and is_equal_approx(Kart.get_steering_factor(12.0, 30.0), 1.0)
		and is_equal_approx(Kart.get_steering_factor(30.0, 30.0), 0.72),
		"Steering uses 45 percent at rest, 100 percent at 40 percent speed, and 72 percent at the limit."
	)
	_check(
		Kart.get_acceleration_factor(2.0, 30.0)
		> Kart.get_acceleration_factor(28.0, 30.0),
		"Acceleration falls progressively near maximum speed."
	)
	fixture.free()


func _test_barrier_retention() -> void:
	var wall_normal := Vector3.RIGHT
	var grazing_velocity := Vector3(-1.0, 0.0, -19.975)
	var frontal_velocity := Vector3(-20.0, 0.0, 0.0)
	var grazing_result := Kart.calculate_barrier_velocity(
		grazing_velocity,
		wall_normal
	)
	var frontal_result := Kart.calculate_barrier_velocity(
		frontal_velocity,
		wall_normal
	)
	var grazing_retention := grazing_result.length() / grazing_velocity.length()
	var frontal_retention := frontal_result.length() / frontal_velocity.length()
	_check(
		grazing_retention >= 0.85 and grazing_retention <= 1.0,
		"A barrier graze preserves at least 85 percent of horizontal momentum."
	)
	_check(
		frontal_retention >= 0.5 and frontal_retention <= 0.6,
		"A frontal barrier impact preserves 50-60 percent without bouncing."
	)


func _test_kart_bumps() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var manager := KartInteractionManager.new()
	manager.tuning = DrivingTuningDefinition.new()
	fixture.add_child(manager)
	var first := Kart.new()
	var second := Kart.new()
	first.configure_for_race(KartStats.new(), RaceClassDefinition.get_by_id(&"150"))
	second.configure_for_race(KartStats.new(), RaceClassDefinition.get_by_id(&"150"))
	first.is_control_enabled = true
	second.is_control_enabled = true
	first.position = Vector3(0.0, 0.6, 0.0)
	second.position = Vector3(0.0, 0.6, -2.3)
	fixture.add_child(first)
	fixture.add_child(second)
	first.velocity = Vector3(0.0, 0.0, -20.0)
	second.velocity = Vector3.ZERO
	manager._process_bump(first, second)
	_check(
		first.get_horizontal_speed() >= 16.0,
		"A frontal kart bump preserves most of the incoming speed."
	)
	_check(
		first.get_horizontal_speed() > 0.0,
		"A kart bump never leaves the incoming kart stopped."
	)
	_check(
		first.global_position.distance_to(second.global_position) >= Kart.COLLISION_SIZE.z - 0.01,
		"Overlapping karts are separated after a bump."
	)
	var first_velocity_after_bump := first.velocity
	first.global_position = Vector3(0.0, 0.6, 0.0)
	second.global_position = Vector3(0.0, 0.6, -2.3)
	manager._process_bump(first, second)
	_check(
		first.velocity.is_equal_approx(first_velocity_after_bump),
		"A sustained kart contact respects the bump cooldown."
	)
	manager._pair_cooldowns.clear()
	first.velocity = Vector3(0.0, 0.0, 20.0)
	second.velocity = Vector3.ZERO
	manager._process_bump(first, second)
	_check(
		first.velocity.is_equal_approx(Vector3(0.0, 0.0, 20.0)),
		"Karts moving apart do not receive an artificial impact impulse."
	)
	fixture.free()


func _test_record_migration_and_independence() -> void:
	var migrated := GameSettings.migrate_best_times({
		&"coastal": 91.25,
	})
	_check(
		is_equal_approx(
			float(migrated.get(
				GameSettings.get_record_key(&"coastal", &"150"),
				-1.0
			)),
			91.25
		),
		"Legacy per-track records migrate to 150 CC."
	)
	var settings := GameSettings.new()
	settings.is_persistence_enabled = false
	settings.register_race_time(100.0, &"coastal", &"50")
	settings.register_race_time(80.0, &"coastal", &"200")
	_check(
		is_equal_approx(settings.get_best_time(&"coastal", &"50"), 100.0)
		and is_equal_approx(settings.get_best_time(&"coastal", &"200"), 80.0),
		"Records remain independent for every track and CC combination."
	)


func _test_settings_persistence() -> void:
	var test_path := "user://driving_physics_settings.cfg"
	var saved_settings := GameSettings.new()
	saved_settings.settings_path = test_path
	saved_settings.select_cc(&"200")
	saved_settings.register_race_time(78.5, &"coastal", &"200")
	saved_settings.save_to_disk()
	var loaded_settings := GameSettings.new()
	loaded_settings.settings_path = test_path
	loaded_settings.load_from_disk()
	_check(
		loaded_settings.selected_cc_id == &"200"
		and is_equal_approx(
			loaded_settings.get_best_time(&"coastal", &"200"),
			78.5
		),
		"The selected CC and its records persist between sessions."
	)
	var absolute_test_path := ProjectSettings.globalize_path(test_path)
	if FileAccess.file_exists(absolute_test_path):
		DirAccess.remove_absolute(absolute_test_path)


func _test_controller_bindings() -> void:
	var main_script := load("res://scripts/main.gd") as Script
	var main_node := main_script.new() as Node
	main_node.call("_configure_input_map")
	var required_actions := [
		&"accelerate",
		&"brake",
		&"steer_left",
		&"steer_right",
		&"drift",
		&"use_item",
	]
	var actions_have_joypad_input := true
	for action in required_actions:
		var has_joypad_event := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				has_joypad_event = true
				break
		actions_have_joypad_input = actions_have_joypad_input and has_joypad_event
	_check(
		actions_have_joypad_input,
		"Driving, drifting, and item actions expose gamepad bindings."
	)
	main_node.free()


func _test_drift_boost_levels() -> void:
	var definition := RaceClassDefinition.get_by_id(&"150")
	var fixture := Node3D.new()
	root.add_child(fixture)
	for boost_level in range(1, 4):
		var kart := Kart.new()
		kart.configure_for_race(KartStats.new(), definition)
		kart.set_physics_process(false)
		fixture.add_child(kart)
		kart.velocity = Vector3(2.0, 0.0, -10.0)
		kart._drift_controller.update_charge(
			Kart.DRIFT_LEVEL_TIMES[boost_level - 1] + 0.01,
			1.0
		)
		kart.velocity = Vector3.ZERO
		kart._release_drift()
		var expected_power := (3.5 + boost_level * 2.0) * definition.boost_multiplier
		_check(
			absf(kart.get_horizontal_speed() - expected_power) < 0.001,
			"Drift charge level %d releases the expected CC-scaled miniturbo."
			% boost_level
		)
		kart.free()
	var side_kart := Kart.new()
	side_kart.set_physics_process(false)
	fixture.add_child(side_kart)
	side_kart.velocity = Vector3(0.0, 0.0, -10.0)
	side_kart._try_start_drift_hop(-1.0)
	var left_side := side_kart.get_drift_side()
	side_kart._drift_controller.reset()
	side_kart._try_start_drift_hop(1.0)
	_check(
		left_side < 0.0 and side_kart.get_drift_side() > 0.0,
		"Drift hop locks either side from the initial steering input."
	)
	fixture.free()


func _test_drift_hop_and_snap() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var floor := StaticBody3D.new()
	floor.collision_layer = PhysicsLayers.WORLD
	floor.collision_mask = 0
	fixture.add_child(floor)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(80.0, 0.2, 80.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor.add_child(floor_collision)

	var kart := Kart.new()
	kart.configure_for_race(KartStats.new(), RaceClassDefinition.get_by_id(&"150"))
	kart.is_control_enabled = true
	kart.position = Vector3(0.0, 0.6, 0.0)
	fixture.add_child(kart)
	for _step in 90:
		await physics_frame
		if kart.is_on_floor():
			break
	_check(kart.is_on_floor(), "Drift hop fixture settles the kart on its floor.")
	var floor_height := kart.global_position.y
	kart.velocity = Vector3(0.0, 0.0, -10.0)
	kart.set_drive_input(0.0, 0.0, 1.0, true, false)
	await physics_frame
	var maximum_height := kart.global_position.y
	var minimum_height := kart.global_position.y
	var hop_frames := 0
	for _step in 90:
		maximum_height = maxf(maximum_height, kart.global_position.y)
		minimum_height = minf(minimum_height, kart.global_position.y)
		if kart.get_drive_state() == Kart.DriveState.DRIFT_HOP:
			hop_frames += 1
		await physics_frame
		if kart.is_on_floor() and hop_frames > 1:
			break
	var hop_height := maximum_height - floor_height
	_check(
		hop_height >= 0.32 and hop_height <= 0.48,
		"Drift hop rises approximately 0.4 meters."
	)
	_check(
		hop_frames >= 18 and hop_frames <= 28,
		"Drift hop lasts approximately 0.38 seconds."
	)
	_check(
		minimum_height >= floor_height - 0.08,
		"Drift hop does not pass through its driving surface."
	)
	_check(
		absf(kart.rotation.y) > 0.03,
		"Airborne steering changes heading with light authority."
	)
	var landing_height := kart.global_position.y
	for _step in 18:
		await physics_frame
	_check(
		kart.is_on_floor()
		and kart.get_drive_state() == Kart.DriveState.DRIFT
		and absf(kart.global_position.y - landing_height) < 0.05,
		"Holding drift triggers one hop and remains stable after landing."
	)

	kart.set("_drive_state", Kart.DriveState.AIR)
	kart.velocity.y = 1.0
	kart._update_floor_snap()
	var ascending_snap := kart.floor_snap_length
	kart.velocity.y = -2.0
	kart._update_floor_snap()
	var descending_snap := kart.floor_snap_length
	kart.velocity.y = -8.0
	kart._update_floor_snap()
	var falling_snap := kart.floor_snap_length
	_check(
		is_zero_approx(ascending_snap)
		and is_equal_approx(descending_snap, Kart.FLOOR_SNAP_DISTANCE)
		and is_zero_approx(falling_snap),
		"Floor snap stays off while rising and reconnects only during a gentle descent."
	)
	fixture.queue_free()
	await process_frame


func _test_race_class_selector() -> void:
	var catalog := load("res://levels/track_catalog.tres") as TrackCatalog
	if catalog == null or catalog.tracks.is_empty():
		_check(false, "Race class selector has a track catalog fixture.")
		return
	var track_definition := catalog.get_default_track()
	var best_times := {
		GameSettings.get_record_key(track_definition.id, &"50"): 105.0,
		GameSettings.get_record_key(track_definition.id, &"200"): 75.0,
	}
	var selector := TrackSelectScreen.new()
	root.add_child(selector)
	await process_frame
	selector.configure(catalog, best_times, track_definition.id, &"150")
	await process_frame
	var buttons_are_accessible := selector.race_class_buttons.size() == 4
	for button in selector.race_class_buttons.values():
		buttons_are_accessible = (
			buttons_are_accessible
			and (button as Button).custom_minimum_size.y >= 44.0
			and (button as Button).focus_mode == Control.FOCUS_ALL
		)
	_check(
		buttons_are_accessible,
		"The selector exposes four keyboard and touch-friendly CC buttons."
	)
	selector.select_cc(&"200", false)
	_check(
		selector.get_selected_cc_id() == &"200"
		and "01:15.000" in selector._best_time_label.text
		and "frenadas obligatorias" in selector._race_class_description_label.text,
		"Changing CC updates its description and track record immediately."
	)
	var original_viewport_size := root.size
	for viewport_size in [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(1920, 1200),
	]:
		root.size = viewport_size
		await process_frame
		var viewport_rect := selector.get_viewport().get_visible_rect()
		var race_button_rect: Rect2 = selector._race_button.get_global_rect()
		_check(
			race_button_rect.position.x >= viewport_rect.position.x
			and race_button_rect.position.y >= viewport_rect.position.y
			and race_button_rect.end.x <= viewport_rect.end.x
			and race_button_rect.end.y <= viewport_rect.end.y,
			"The race button remains visible at %dx%d."
			% [viewport_size.x, viewport_size.y]
		)
	root.size = original_viewport_size
	selector.queue_free()
	await process_frame


func _test_shared_race_class_and_camera() -> void:
	var catalog := load("res://levels/track_catalog.tres") as TrackCatalog
	if catalog == null or catalog.get_default_track() == null:
		_check(false, "Race world has a track fixture for shared CC validation.")
		return
	var race_world := RaceWorld.new()
	race_world.track_definition = catalog.get_default_track()
	race_world.race_class = RaceClassDefinition.get_by_id(&"200")
	race_world.play_intro = false
	root.add_child(race_world)
	await process_frame
	var racers_share_cc := race_world.race_manager.racers.size() == 8
	for racer in race_world.race_manager.racers:
		racers_share_cc = (
			racers_share_cc
			and racer.race_class != null
			and racer.race_class.id == &"200"
		)
	_check(
		racers_share_cc,
		"The player and all AI racers receive the selected 200 CC definition."
	)
	var player := race_world.player_kart
	player.velocity = -player.global_transform.basis.z.normalized() * player.stats.max_speed
	_check(
		absf(race_world._follow_camera.get_target_fov() - 88.0) < 0.01,
		"The 200 CC follow camera reaches its 88-degree maximum FOV."
	)
	var speed_before_item := player.get_horizontal_speed()
	player.activate_boost(1.0, 10.0)
	_check(
		absf(
			player.get_horizontal_speed()
			- speed_before_item
			- 10.0 * race_world.race_class.boost_multiplier
		) < 0.01,
		"Item speed impulses scale with the selected race class."
	)
	race_world.shutdown()
	race_world.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
