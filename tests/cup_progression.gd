extends SceneTree

const CATALOG: ProgressionCatalog = preload("res://progression/progression_catalog.tres")
var failures := 0

func _init() -> void:
	var errors := CATALOG.validate()
	_check(errors.is_empty(), "Progression catalog is valid: %s" % errors)
	_check(CATALOG.cups.get_valid_cups().size() == 1, "One valid cup loads.")
	_check(CATALOG.racers.racers.size() == 4, "Four racers load.")
	_check(CATALOG.difficulties.difficulties.size() == 3, "Three difficulties load.")
	_check(CATALOG.unlocks.unlocks.size() == 9, "Nine rewards load.")
	_test_invalid_cup()
	_test_run()
	quit(1 if failures else 0)

func _test_invalid_cup() -> void:
	var source := CATALOG.cups.get_cup(&"tropical")
	var invalid := source.duplicate(true) as CupDefinition
	invalid.tracks[1] = invalid.tracks[0]
	_check(not invalid.validate().is_empty(), "Repeated cup tracks are rejected.")
	invalid = source.duplicate(true) as CupDefinition
	invalid.scoring_table = PackedInt32Array([9, 9, 3, 1])
	_check(not invalid.validate().is_empty(), "Non-decreasing scoring is rejected.")

func _test_run() -> void:
	var progress := PlayerProgress.new()
	progress.save_path = "/tmp/michikart-cup-test.cfg"
	var manager := CupManager.new(CATALOG, progress)
	_check(manager.start(&"tropical", &"expert", &"200", 1234), "Cup starts.")
	var first_session := manager.create_session()
	_check(first_session.track.id == &"coastal" and first_session.race_seed == 1234, "First session is configured from cup data.")
	var result := _result_for(first_session, [&"marea", &"lima", &"coral", &"brisa"])
	_check(manager.commit_race_result(result), "Expected result commits.")
	_check(not manager.commit_race_result(result), "Duplicate result is idempotently rejected.")
	_check(manager.active_run.standings[&"marea"].points == 9 and manager.active_run.standings[&"lima"].points == 6, "Positions award 9/6/3/1.")
	var restored_progress := PlayerProgress.new()
	restored_progress.save_path = progress.save_path
	restored_progress.load_from_disk()
	var restored := CupManager.new(CATALOG, restored_progress)
	_check(restored.restore() and restored.active_run.current_race_index == 1, "Run restores between races.")
	var final_summary: CupResultSummary
	for ignored in 2:
		var session := restored.create_session()
		var next_result := _result_for(session, [&"marea", &"lima", &"coral", &"brisa"])
		_check(restored.commit_race_result(next_result), "Next race commits.")
		_check(next_result.cup_summary != null, "Cup result carries a typed summary.")
		final_summary = next_result.cup_summary
	_check(restored.active_run.is_completed, "Three races complete the cup.")
	_check(final_summary.player_position == 1 and final_summary.player_points == 27, "Final cup summary exposes typed player position and points.")
	_check(restored_progress.get_medal(&"tropical", &"expert") == UnlockDefinition.GOLD, "27 points grant expert gold.")
	_check(restored_progress.unlocked_reward_ids.size() == 9, "Expert gold grants all lower rewards.")
	_check(restored_progress.seen_reward_ids.is_empty(), "New rewards remain unseen until gallery focus.")
	_check(restored_progress.get_new_reward_count() == 9, "New reward count is derived without duplicating progression logic.")
	_check(restored_progress.equip(&"race_future", CATALOG.unlocks), "Unlocked vehicle can be equipped.")
	_check(not restored_progress.equip(&"missing", CATALOG.unlocks), "Locked or unknown vehicle cannot be equipped.")

func _result_for(session: RaceSessionConfig, order: Array[StringName]) -> RaceResult:
	var result := RaceResult.new()
	result.run_id = session.run_id
	result.cup_id = session.cup_id
	result.cup_race_index = session.cup_race_index
	result.track_id = session.track.id
	for index in order.size():
		var row := RacerRaceResult.new()
		row.racer_id = order[index]
		row.finish_position = index + 1
		row.finish_time = 60.0 + index
		result.standings.append(row)
	return result

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)
