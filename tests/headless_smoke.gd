extends SceneTree

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "Main scene loads.")
	if packed_scene == null:
		quit(1)
		return
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.settings.is_persistence_enabled = false
	main.settings.best_time = -1.0
	_check(main.main_menu != null, "Main menu is created.")
	main.main_menu._toggle_settings()
	await process_frame
	_check(main.main_menu._settings_panel.visible, "Settings panel opens.")
	main.main_menu._toggle_settings()
	main.start_game()
	await process_frame
	await process_frame
	_check(main.race_world != null, "Race world is created.")
	if main.race_world != null:
		_check(main.race_world.race_manager.racers.size() == 4, "Four racers are registered.")
		_check(main.race_world.race_manager.route_points.size() >= 40, "Track route is complete.")
		_check(main.race_world.player_kart != null, "Player kart is available.")
		await create_timer(4.2).timeout
		_check(
			main.race_world.race_manager.state == RaceManager.RaceState.RACING,
			"Countdown transitions to an active race."
		)
		var active_racers := 0
		for racer in main.race_world.race_manager.racers:
			if racer.is_control_enabled:
				active_racers += 1
		_check(active_racers == 4, "All racers receive control after the countdown.")
		var moving_ai := 0
		for racer_index in range(1, 4):
			var ai_racer: Node = main.race_world.race_manager.racers[racer_index]
			if Vector2(ai_racer.velocity.x, ai_racer.velocity.z).length() > 0.5:
				moving_ai += 1
		_check(moving_ai >= 2, "AI racers accelerate and follow the route.")

		var player: Kart = main.race_world.player_kart
		var track: CoastalTrack = main.race_world._track
		var manager: RaceManager = main.race_world.race_manager
		_check(track.get_route_length() >= 400.0, "Expanded track is at least 400 meters long.")
		_check(track.shortcut_definitions.size() == 2, "Two physical shortcuts are available.")
		_check(
			track.get_node_or_null("MainBarrierLeftCollision") != null
			and track.get_node_or_null("MainBarrierRightCollision") != null,
			"Continuous barriers protect both sides of the main route."
		)
		_check((player.collision_mask & 8) != 0, "Player collides with shortcut surfaces.")
		for racer_index in range(1, 4):
			var ai_kart: Kart = manager.racers[racer_index]
			_check(
				(ai_kart.collision_mask & 8) == 0,
				"%s stays on the main-route physics layer." % ai_kart.racer_name
			)

		var player_id := player.get_instance_id()
		var saved_race_data: Dictionary = manager._race_data[player_id].duplicate(true)
		var saved_transform := player.global_transform
		var shortcut: Dictionary = track.shortcut_definitions[0]
		var shortcut_test_data: Dictionary = saved_race_data.duplicate(true)
		shortcut_test_data.next_checkpoint = int(shortcut.entry_index)
		manager._race_data[player_id] = shortcut_test_data
		var shortcut_points: Array[Vector3] = shortcut.points
		for shortcut_point in shortcut_points:
			player.global_position = shortcut_point + Vector3.UP * 0.7
			player.velocity = Vector3.ZERO
			await physics_frame
		await physics_frame
		await process_frame
		var shortcut_result: Dictionary = manager._race_data[player_id]
		_check(
			int(shortcut_result.next_checkpoint) == int(shortcut.exit_index) + 1,
			"Shortcut gate advances only to its declared exit checkpoint."
		)
		manager._race_data[player_id] = saved_race_data
		player.global_transform = saved_transform
		player.velocity = Vector3.ZERO

		player.held_item = ItemDefinition.boost()
		player.use_item()
		_check(player.held_item == null, "Boost item is consumed.")
		player.held_item = ItemDefinition.tropical_projectile()
		player.use_item()
		_check(player.held_item == null, "Projectile item is consumed.")

		for lap in manager.total_laps:
			for route_index in range(1, manager.route_points.size()):
				player.global_position = manager.route_points[route_index]
				player.velocity = Vector3.ZERO
				manager._update_racers()
				await process_frame
			player.global_position = manager.route_points[0]
			player.velocity = Vector3.ZERO
			manager._update_racers()
			await process_frame
		_check(not player.is_control_enabled, "Three valid laps finish the player race.")
	main.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit(1 if _has_failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
