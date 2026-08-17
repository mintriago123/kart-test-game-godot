extends SceneTree

var _failed := false


class TestRacer extends Node3D:
	var racer_name := ""
	var race_manager: RaceManager
	var is_control_enabled := false
	var respawn_transform := Transform3D.IDENTITY

	func set_respawn_transform(value: Transform3D) -> void:
		respawn_transform = value

	func set_drive_input(
		_throttle: float, _brake: float, _steer: float,
		_drift: bool, _use_item: bool
	) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager := RaceManager.new()
	root.add_child(manager)
	manager.total_laps = 3
	manager.track_id = &"coastal"
	manager.cc_id = &"100cc"
	manager.previous_best_time = 40.0
	manager.previous_best_lap_time = 12.0
	manager.configure([
		Vector3(0, 0, 0), Vector3(10, 0, 0),
		Vector3(10, 0, 10), Vector3(0, 0, 10),
	])
	var player := TestRacer.new()
	player.racer_name = "Marea"
	root.add_child(player)
	manager.register_kart(player, true, 4)
	var rivals: Array[TestRacer] = []
	for index in 3:
		var rival := TestRacer.new()
		rival.racer_name = "Rival %d" % (index + 1)
		root.add_child(rival)
		manager.register_kart(rival, false, index + 1)
		rivals.append(rival)
	manager.state = RaceManager.RaceState.RACING
	player.is_control_enabled = true
	for rival in rivals:
		rival.is_control_enabled = true
	manager.record_item_collected(player)
	manager.record_item_used(player)
	manager.record_item_hit(player, rivals[0], Kart.HitResult.APPLIED)
	manager.record_item_hit(rivals[0], player, Kart.HitResult.BLOCKED)
	manager.record_recovery(player)
	_check(manager.complete_shortcut(player, 0, 2), "A valid shortcut is accepted.")
	# Restore normal checkpoint flow after verifying shortcut telemetry.
	manager.get_race_state(player).next_checkpoint = 1
	var completed_laps: Array[float] = []
	manager.lap_completed.connect(func(racer: Node, _lap: int, time: float) -> void:
		if racer == player:
			completed_laps.append(time)
	)
	var result_box: Array[RaceResult] = []
	manager.race_completed.connect(func(result: RaceResult) -> void:
		result_box.append(result)
	)
	var lap_ends := [10.0, 21.5, 34.0]
	for lap_end in lap_ends:
		manager.race_time = lap_end
		for checkpoint in [1, 2, 3, 0]:
			player.global_position = manager.route_points[checkpoint]
			manager._update_racers()
	_check(completed_laps.size() == 3, "Exactly three lap splits are emitted.")
	_check(_approx_array(completed_laps, [10.0, 11.5, 12.5]), "Lap splits use elapsed differences.")
	_check(manager.state == RaceManager.RaceState.WAITING_FOR_RIVALS, "Player finish starts the rival waiting phase.")
	_check(result_box.is_empty(), "Final results wait while rivals remain on track.")
	_check(not player.is_control_enabled and rivals[0].is_control_enabled, "Only the player is disabled during the wait.")
	manager._process(RaceManager.RESULTS_WAIT_DURATION + 0.1)
	var final_result: RaceResult = result_box[0] if not result_box.is_empty() else null
	_check(final_result != null, "The wait limit emits a final result.")
	if final_result != null:
		var data := final_result.player_result
		_check(data.finish_time == 34.0 and data.best_lap_time == 10.0, "Final and best-lap times are correct.")
		_check(data.items_collected == 1 and data.items_used == 1, "Item collection and use are counted.")
		_check(data.hits_landed == 1 and data.hits_blocked == 1, "Applied and blocked hits are attributed.")
		_check(data.shortcuts_used == 1 and data.recoveries == 1, "Shortcuts and recoveries are counted.")
		_check(data.get_position_delta() == 3, "Grid-to-finish position gain is calculated.")
		_check(final_result.standings.size() == 4, "The result snapshots all racers.")
		_check(final_result.standings[1].finish_time < 0.0 and final_result.standings[1].is_dnf, "Unfinished rivals are marked DNF.")
		_check(final_result.is_new_best_time and final_result.is_new_best_lap, "Record flags compare previous marks.")
	_check(manager.state == RaceManager.RaceState.FINISHED, "The wait limit ends the global race.")
	_check(not rivals[0].is_control_enabled, "All rivals are disabled when final results close.")

	if final_result != null:
		var settings := GameSettings.new()
		settings.is_persistence_enabled = false
		_check(settings.register_race_result(final_result), "A valid result updates persistent records.")
		_check(settings.get_best_time(&"coastal", &"100cc") == 34.0, "Best race is stored per track and CC.")
		_check(settings.get_best_lap_time(&"coastal", &"100cc") == 10.0, "Best lap is stored per track and CC.")
		var slower := RaceResult.new()
		slower.track_id = &"coastal"
		slower.cc_id = &"100cc"
		slower.player_result = final_result.player_result.duplicate_result()
		slower.player_result.finish_time = 40.0
		slower.player_result.best_lap_time = 11.0
		_check(not settings.register_race_result(slower), "Slower results do not overwrite records.")
		var persisted := GameSettings.new()
		persisted.settings_path = "user://race_telemetry_test.cfg"
		persisted.best_times = settings.best_times.duplicate(true)
		persisted.best_lap_times = settings.best_lap_times.duplicate(true)
		persisted.save_to_disk()
		var reloaded := GameSettings.new()
		reloaded.settings_path = persisted.settings_path
		reloaded.load_from_disk()
		_check(
			reloaded.get_best_time(&"coastal", &"100cc") == 34.0
			and reloaded.get_best_lap_time(&"coastal", &"100cc") == 10.0,
			"Saving and loading preserves race and lap records."
		)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(persisted.settings_path))

	manager.queue_free()
	for rival in rivals:
		rival.queue_free()
	player.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _approx_array(actual: Array[float], expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if not is_equal_approx(actual[index], float(expected[index])):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failed = true
		push_error("FAIL: " + message)
