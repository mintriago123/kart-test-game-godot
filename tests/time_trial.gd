extends SceneTree

var _failures := 0


func _init() -> void:
	_test_record_keys_and_migration()
	_test_progress_and_result_mode()
	_test_ghost_round_trip()
	if _failures == 0:
		print("TIME TRIAL TESTS PASSED")
	quit(_failures)


func _test_record_keys_and_migration() -> void:
	var race_key := GameSettings.get_record_key(&"coastal", &"150", GameModeDefinition.RACE)
	var trial_key := GameSettings.get_record_key(&"coastal", &"150", GameModeDefinition.TIME_TRIAL)
	_expect(race_key != trial_key, "race and time-trial keys are separate")
	var migrated := GameSettings.migrate_best_times({&"coastal|150": 42.0})
	_expect(float(migrated.get(race_key, -1.0)) == 42.0, "legacy key migrates to race")
	_expect(not migrated.has(trial_key), "legacy key never migrates to time trial")


func _test_progress_and_result_mode() -> void:
	var manager := RaceManager.new()
	root.add_child(manager)
	manager.game_mode = GameModeDefinition.TIME_TRIAL
	manager.configure([Vector3.ZERO, Vector3(0, 0, 10), Vector3(10, 0, 10)])
	var kart := Node3D.new()
	kart.set_script(preload("res://tests/support/time_trial_test_kart.gd"))
	root.add_child(kart)
	kart.set("race_manager", manager)
	kart.set("is_control_enabled", false)
	manager.register_kart(kart, true)
	_expect(manager.racers.size() == 1, "time trial manager accepts one racer")
	_expect(manager.get_racer_ahead(kart) == null, "time trial has no previous rival")
	kart.queue_free()
	manager.queue_free()


func _test_ghost_round_trip() -> void:
	var storage := GhostStorage.new()
	storage.root_path = "user://time_trial_test_ghosts"
	var recording := GhostRecording.new()
	recording.track_id = &"track/unsafe"
	recording.track_fingerprint = "fingerprint"
	recording.cc_id = &"150"
	recording.total_laps = 1
	recording.total_time = 1.0
	recording.lap_times = [1.0]
	for data in [[0.0, Vector3.ZERO, 0.0], [1.0, Vector3.ONE, 3.0]]:
		var sample := GhostSample.new()
		sample.time = data[0]
		sample.position = data[1]
		sample.progress = data[2]
		recording.samples.append(sample)
	var error := storage.save_atomic(recording)
	_expect(error == OK, "valid ghost saves atomically")
	var loaded := storage.load_compatible(&"track/unsafe", "fingerprint", &"150", 1)
	_expect(loaded != null and loaded.samples.size() == 2, "saved ghost loads with samples")
	_expect(storage.load_compatible(&"track/unsafe", "old", &"150", 1) == null, "fingerprint mismatch is rejected")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("TIME TRIAL: " + message)
