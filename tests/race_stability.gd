extends SceneTree

const SIMULATION_SECONDS := 30.0
const MAX_ALLOWED_RECOVERIES := 4

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 4.0
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "Main scene loads for stability test.")
	if packed_scene == null:
		_finish(1)
		return
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.settings.is_persistence_enabled = false
	main.start_game()
	await process_frame
	var manager: RaceManager = main.race_world.race_manager
	for racer_index in range(1, manager.racers.size()):
		var observed_racer: Kart = manager.racers[racer_index]
		observed_racer.recovered.connect(_log_recovery.bind(observed_racer, manager))
	await create_timer(SIMULATION_SECONDS).timeout

	for racer_index in range(1, manager.racers.size()):
		var racer: Kart = manager.racers[racer_index]
		var completed_checkpoints := manager.get_completed_checkpoint_count(racer)
		print(
			"INFO: %s progress=%d/%d recoveries=%d speed=%.1f" % [
				racer.racer_name,
				completed_checkpoints,
				manager.route_points.size(),
				racer.recovery_count,
				Vector2(racer.velocity.x, racer.velocity.z).length(),
			]
		)
		_check(
			completed_checkpoints >= manager.route_points.size(),
			"%s completes at least one lap without getting stuck." % racer.racer_name
		)
		_check(
			racer.recovery_count <= MAX_ALLOWED_RECOVERIES,
			"%s does not enter a recovery loop." % racer.racer_name
		)
		_check(
			racer.global_position.y > -2.5,
			"%s remains on a recoverable driving surface." % racer.racer_name
		)

	main.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	_finish(1 if _has_failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)


func _log_recovery(racer: Kart, manager: RaceManager) -> void:
	print(
		"RECOVERY: %s checkpoint=%d from=%s reason=%s" % [
			racer.racer_name,
			manager.get_next_checkpoint_index(racer),
			racer.last_recovery_position,
			racer.last_recovery_reason,
		]
	)


func _finish(exit_code: int) -> void:
	Engine.time_scale = 1.0
	quit(exit_code)
