extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")
const SIMULATION_SECONDS_PER_TRACK := 30.0
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

	for track_definition in TRACK_CATALOG.tracks:
		await _test_track_stability(packed_scene, track_definition)

	_finish(1 if _has_failed else 0)


func _test_track_stability(
	packed_scene: PackedScene,
	track_definition: TrackDefinition
) -> void:
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.settings.is_persistence_enabled = false
	main.start_game(track_definition.id)
	await process_frame
	var manager: RaceManager = main.race_world.race_manager
	for racer_index in range(1, manager.racers.size()):
		var observed_racer: Kart = manager.racers[racer_index]
		observed_racer.recovered.connect(
			_log_recovery.bind(observed_racer, manager, track_definition)
		)
	await create_timer(SIMULATION_SECONDS_PER_TRACK).timeout

	for racer_index in range(1, manager.racers.size()):
		var racer: Kart = manager.racers[racer_index]
		var completed_checkpoints := manager.get_completed_checkpoint_count(racer)
		print(
			"INFO: %s / %s progress=%d/%d recoveries=%d speed=%.1f" % [
				track_definition.display_name,
				racer.racer_name,
				completed_checkpoints,
				manager.route_points.size(),
				racer.recovery_count,
				Vector2(racer.velocity.x, racer.velocity.z).length(),
			]
		)
		_check(
			completed_checkpoints >= manager.route_points.size(),
			"%s / %s completes at least one lap without getting stuck."
			% [track_definition.display_name, racer.racer_name]
		)
		_check(
			racer.recovery_count <= MAX_ALLOWED_RECOVERIES,
			"%s / %s does not enter a recovery loop."
			% [track_definition.display_name, racer.racer_name]
		)
		_check(
			racer.global_position.y > -2.5,
			"%s / %s remains on a recoverable driving surface."
			% [track_definition.display_name, racer.racer_name]
		)

	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)


func _log_recovery(
	racer: Kart,
	manager: RaceManager,
	track_definition: TrackDefinition
) -> void:
	print(
		"RECOVERY: %s / %s checkpoint=%d from=%s reason=%s" % [
			track_definition.display_name,
			racer.racer_name,
			manager.get_next_checkpoint_index(racer),
			racer.last_recovery_position,
			racer.last_recovery_reason,
		]
	)


func _finish(exit_code: int) -> void:
	Engine.time_scale = 1.0
	quit(exit_code)
