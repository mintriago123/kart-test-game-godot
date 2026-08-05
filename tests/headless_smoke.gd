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
		player.held_item = ItemDefinition.boost()
		player.use_item()
		_check(player.held_item == null, "Boost item is consumed.")
		player.held_item = ItemDefinition.tropical_projectile()
		player.use_item()
		_check(player.held_item == null, "Projectile item is consumed.")

		var manager: RaceManager = main.race_world.race_manager
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
