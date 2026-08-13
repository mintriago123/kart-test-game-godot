extends SceneTree

const CATALOG: ProgressionCatalog = preload("res://progression/progression_catalog.tres")
var failures := 0


func _init() -> void:
	var errors := CATALOG.validate()
	_check(errors.is_empty(), "Progression catalog is valid: %s" % errors)
	_test_catalog_shape()
	_test_access_ladder()
	_test_points_and_rewards()
	_test_run()
	for schema in range(1, 4): _test_migration(schema)
	quit(1 if failures else 0)


func _test_catalog_shape() -> void:
	var cups := CATALOG.cups.get_valid_cups()
	_check(cups.size() == 7, "Seven valid cups load.")
	_check(CATALOG.racers.racers.size() == 4, "Four racers load.")
	_check(CATALOG.difficulties.difficulties.size() == 3, "Three difficulties load.")
	_check(CATALOG.unlocks.variants.size() == 13 and CATALOG.unlocks.initial_variant.id == &"sedan", "Thirteen variants load with Sedan as the explicit initial vehicle.")
	_check(CATALOG.unlocks.unlocks.size() == 12, "Twelve unlockable rewards load.")
	var expected_reward_variants := {&"tropical_bronze": &"kart_oobi", &"tropical_silver": &"taxi", &"horizontes_bronze": &"kart_oodi", &"horizontes_silver": &"van", &"salvaje_bronze": &"kart_ooli", &"salvaje_silver": &"suv_luxury", &"extrema_bronze": &"kart_oozi", &"extrema_silver": &"sedan_sports", &"career_12": &"kart_oopi", &"career_30": &"hatchback_sports", &"career_56": &"race", &"career_90": &"race_future"}
	_check(expected_reward_variants.keys().all(func(id): return CATALOG.unlocks.get_unlock(id).kart_variant.id == expected_reward_variants[id]), "Every medal and milestone reward maps to its specified vehicle.")
	_check([CATALOG.difficulties.get_difficulty(&"relaxed").progress_multiplier, CATALOG.difficulties.get_difficulty(&"competitive").progress_multiplier, CATALOG.difficulties.get_difficulty(&"expert").progress_multiplier] == [1, 2, 3], "Difficulty progress multipliers are 1/2/3.")
	var expected_tracks := {
		&"tropical": [&"coastal", &"garden", &"bahia_turbo"],
		&"horizontes": [&"dunas_doradas", &"valle_de_otoo", &"baha_pirata"],
		&"salvaje": [&"pantano_brumoso", &"can_carmes", &"ruinas_esmeralda"],
		&"extrema": [&"caldera_furiosa", &"cumbre_glacial", &"nen_medianoche"],
		&"contrastes": [&"bahia_turbo", &"dunas_doradas", &"cumbre_glacial"],
		&"expedicion": [&"coastal", &"pantano_brumoso", &"caldera_furiosa"],
		&"festival": [&"garden", &"baha_pirata", &"nen_medianoche"],
	}
	for cup in cups:
		var ids: Array[StringName] = []
		for track in cup.tracks: ids.append(track.id)
		_check(ids == expected_tracks[cup.id], "%s uses its official three-track order without repetition." % cup.display_name)
	var invalid := CATALOG.cups.get_cup(&"tropical").duplicate(true) as CupDefinition
	invalid.tracks[1] = invalid.tracks[0]
	_check(not invalid.validate().is_empty(), "Repeated cup tracks are rejected.")


func _test_access_ladder() -> void:
	var progress := PlayerProgress.new()
	var tropical := CATALOG.cups.get_cup(&"tropical")
	var horizons := CATALOG.cups.get_cup(&"horizontes")
	var wild := CATALOG.cups.get_cup(&"salvaje")
	var extreme := CATALOG.cups.get_cup(&"extrema")
	_check(progress.get_unlocked_cups(CATALOG).map(func(cup): return cup.id) == [&"tropical"], "Only Tropical is initially available.")
	var manager := CupManager.new(CATALOG, progress)
	_check(not manager.start(&"horizontes", &"relaxed", &"150"), "CupManager rejects a locked cup.")
	progress.record_medal(tropical, CATALOG.difficulties.get_difficulty(&"relaxed"), UnlockDefinition.BRONZE, CATALOG)
	_check(progress.is_cup_unlocked(horizons, CATALOG), "Tropical relaxed bronze opens Horizons.")
	_check(not progress.is_cup_unlocked(wild, CATALOG), "Wild remains locked before Horizons competitive bronze.")
	progress.record_medal(horizons, CATALOG.difficulties.get_difficulty(&"competitive"), UnlockDefinition.BRONZE, CATALOG)
	_check(progress.is_cup_unlocked(wild, CATALOG), "Horizons competitive bronze opens Wild.")
	progress.record_medal(wild, CATALOG.difficulties.get_difficulty(&"expert"), UnlockDefinition.BRONZE, CATALOG)
	_check(progress.is_cup_unlocked(extreme, CATALOG), "Wild expert bronze opens Extreme.")
	var remix_ids := [&"contrastes", &"expedicion", &"festival"]
	_check(remix_ids.all(func(id): return not progress.is_cup_unlocked(CATALOG.cups.get_cup(id), CATALOG)), "All remix cups remain locked before an Extreme medal.")
	progress.record_medal(extreme, CATALOG.difficulties.get_difficulty(&"competitive"), UnlockDefinition.BRONZE, CATALOG)
	_check(remix_ids.all(func(id): return progress.is_cup_unlocked(CATALOG.cups.get_cup(id), CATALOG)), "Any Extreme medal opens all three remix cups together.")
	_check(manager.start(&"festival", &"expert", &"200", 77), "CupManager accepts a newly unlocked remix cup.")
	manager.abandon()


func _test_points_and_rewards() -> void:
	var progress := PlayerProgress.new()
	var tropical := CATALOG.cups.get_cup(&"tropical")
	var relaxed := CATALOG.difficulties.get_difficulty(&"relaxed")
	var competitive := CATALOG.difficulties.get_difficulty(&"competitive")
	var expert := CATALOG.difficulties.get_difficulty(&"expert")
	var granted := progress.record_medal(tropical, expert, UnlockDefinition.SILVER, CATALOG)
	_check(progress.get_medal(&"tropical", &"expert") == UnlockDefinition.SILVER and progress.get_medal(&"tropical", &"competitive") == 0 and progress.get_medal(&"tropical", &"relaxed") == 0, "A medal is stored only for its exact difficulty.")
	_check(granted == PackedStringArray([&"tropical_bronze", &"tropical_silver"]), "Silver grants cumulative direct cup rewards in one completion.")
	_check(progress.get_career_points(CATALOG) == 6, "Silver expert contributes 2 × 3 career points.")
	var repeated := progress.record_medal(tropical, expert, UnlockDefinition.BRONZE, CATALOG)
	_check(repeated.is_empty() and progress.get_career_points(CATALOG) == 6, "Repeating an inferior result cannot farm points or rewards.")
	progress.record_medal(tropical, competitive, UnlockDefinition.GOLD, CATALOG)
	progress.record_medal(tropical, relaxed, UnlockDefinition.BRONZE, CATALOG)
	_check(progress.get_career_points(CATALOG) == 13, "Career points sum medal value times each difficulty multiplier.")
	_check(progress.unlocked_reward_ids.has(&"career_12"), "Crossing 12 points grants Kart Oopi.")

	var batched := PlayerProgress.new()
	batched.best_medals[batched.medal_key(&"tropical", &"expert")] = UnlockDefinition.GOLD
	batched.best_medals[batched.medal_key(&"horizontes", &"expert")] = UnlockDefinition.GOLD
	batched.best_medals[batched.medal_key(&"salvaje", &"expert")] = UnlockDefinition.GOLD
	batched.best_medals[batched.medal_key(&"extrema", &"competitive")] = UnlockDefinition.BRONZE
	var batch := batched.evaluate_rewards(CATALOG)
	_check(batched.get_career_points(CATALOG) == 29 and batch.has(&"career_12"), "Central reward evaluation catches previously unclaimed milestones.")
	batched.unlocked_reward_ids.erase(&"career_12")
	batched.best_medals[batched.medal_key(&"extrema", &"expert")] = UnlockDefinition.BRONZE
	batch = batched.evaluate_rewards(CATALOG)
	_check(batch.has(&"career_12") and batch.has(&"career_30"), "One evaluation can grant multiple newly reached milestones.")

	var maximum := PlayerProgress.new()
	for cup in CATALOG.cups.get_valid_cups():
		for difficulty in cup.difficulties: maximum.best_medals[maximum.medal_key(cup.id, difficulty.id)] = UnlockDefinition.GOLD
	_check(maximum.get_career_points(CATALOG) == 126 and maximum.get_max_career_points(CATALOG) == 126, "Seven cups have a 126-point maximum.")
	_check(maximum.evaluate_rewards(CATALOG).size() == 12, "A complete career grants all twelve unlockable vehicles.")
	_check(maximum.can_equip(&"sedan", CATALOG.unlocks), "Sedan is explicitly available without a reward.")


func _test_run() -> void:
	var progress := PlayerProgress.new()
	progress.save_path = "/tmp/michikart-cup-test.cfg"
	var manager := CupManager.new(CATALOG, progress)
	_check(manager.start(&"tropical", &"expert", &"200", 1234), "An available cup starts.")
	var first_session := manager.create_session()
	_check(first_session.track.id == &"coastal" and first_session.race_seed == 1234 and first_session.equipped_variant.id == &"sedan", "First session uses cup data and the explicit initial Sedan.")
	var result := _result_for(first_session, [&"marea", &"lima", &"coral", &"brisa"])
	_check(manager.commit_race_result(result), "Expected result commits.")
	_check(not manager.commit_race_result(result), "Duplicate result is idempotently rejected.")
	var restored_progress := PlayerProgress.new(); restored_progress.save_path = progress.save_path; restored_progress.load_from_disk()
	var restored := CupManager.new(CATALOG, restored_progress)
	_check(restored.restore() and restored.active_run.current_race_index == 1, "Run restores between races.")
	var final_summary: CupResultSummary
	for ignored in 2:
		var session := restored.create_session()
		var next_result := _result_for(session, [&"marea", &"lima", &"coral", &"brisa"])
		_check(restored.commit_race_result(next_result), "Next race commits.")
		final_summary = next_result.cup_summary
	_check(final_summary.player_position == 1 and final_summary.player_points == 27, "Final cup summary exposes player position and points.")
	_check(restored_progress.get_medal(&"tropical", &"expert") == UnlockDefinition.GOLD and restored_progress.get_medal(&"tropical", &"competitive") == 0, "Expert gold does not cascade to lower difficulties.")
	_check(final_summary.new_reward_ids == PackedStringArray([&"tropical_bronze", &"tropical_silver"]), "A completed cup reports every direct reward granted together.")
	_check(restored_progress.equip(&"taxi", CATALOG.unlocks), "An unlocked direct vehicle can be equipped.")
	_check(not restored_progress.equip(&"race_future", CATALOG.unlocks), "A locked milestone vehicle cannot be equipped.")
	DirAccess.remove_absolute(progress.save_path)


func _test_migration(schema: int) -> void:
	var path := "/tmp/michikart-progress-schema-%d.cfg" % schema
	var old_ids := [&"relaxed_bronze", &"relaxed_silver", &"relaxed_gold", &"competitive_bronze", &"competitive_silver", &"competitive_gold", &"expert_bronze", &"expert_silver", &"expert_gold"]
	var unlocked := {}
	for id in old_ids: unlocked[id] = true
	var fixture := ConfigFile.new()
	fixture.set_value("progress", "schema_version", schema)
	fixture.set_value("progress", "best_medals", {"tropical/competitive": 2})
	fixture.set_value("progress", "unlocked_reward_ids", unlocked)
	if schema >= 3: fixture.set_value("progress", "seen_reward_ids", {&"relaxed_bronze": true, &"expert_gold": true})
	fixture.set_value("progress", "equipped_kart_variant_id", "" if schema == 1 else "race_future")
	fixture.set_value("progress", "active_cup", {"cup_id": &"tropical", "current_race_index": 1})
	fixture.set_value("telemetry", "races_played", schema)
	fixture.save(path)
	var loaded := PlayerProgress.new(); loaded.save_path = path; loaded.load_from_disk()
	var expected_new := [&"tropical_bronze", &"horizontes_bronze", &"salvaje_bronze", &"career_12", &"extrema_bronze", &"extrema_silver", &"career_30", &"career_56", &"career_90"]
	_check(expected_new.all(func(id): return loaded.unlocked_reward_ids.has(id)) and old_ids.all(func(id): return not loaded.unlocked_reward_ids.has(id)), "Schema %d maps all nine legacy reward IDs by vehicle." % schema)
	_check(loaded.equipped_kart_variant_id == (&"sedan" if schema == 1 else &"race_future") and not loaded.active_cup.is_empty() and loaded.races_played == schema, "Schema %d preserves active cup, telemetry and equipped vehicle, defaulting an empty vehicle to Sedan." % schema)
	if schema < 3:
		_check(loaded.get_new_reward_count() == 0, "Schema %d migrates historical rewards as already seen." % schema)
	else:
		_check(loaded.seen_reward_ids.has(&"tropical_bronze") and loaded.seen_reward_ids.has(&"career_90") and loaded.get_new_reward_count() == 7, "Schema 3 preserves seen and unseen reward state through ID migration.")
	loaded.save_to_disk()
	var migrated_file := ConfigFile.new(); migrated_file.load(path)
	_check(int(migrated_file.get_value("progress", "schema_version", 0)) == PlayerProgress.SCHEMA_VERSION, "Schema %d saves back as schema 4." % schema)
	DirAccess.remove_absolute(path)


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
