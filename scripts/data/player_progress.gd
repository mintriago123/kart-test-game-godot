class_name PlayerProgress
extends RefCounted
const SCHEMA_VERSION := 4
const SAVE_PATH := "user://progression.cfg"
const INITIAL_VARIANT_ID := &"sedan"
const LEGACY_REWARD_MIGRATION := {
	&"relaxed_bronze": &"tropical_bronze",
	&"relaxed_silver": &"horizontes_bronze",
	&"relaxed_gold": &"salvaje_bronze",
	&"competitive_bronze": &"career_12",
	&"competitive_silver": &"extrema_bronze",
	&"competitive_gold": &"extrema_silver",
	&"expert_bronze": &"career_30",
	&"expert_silver": &"career_56",
	&"expert_gold": &"career_90",
}
var save_path := SAVE_PATH
var loaded_schema_version := SCHEMA_VERSION
var best_medals: Dictionary = {}
var unlocked_reward_ids: Dictionary = {}
var seen_reward_ids: Dictionary = {}
var equipped_kart_variant_id: StringName = INITIAL_VARIANT_ID
var active_cup: Dictionary = {}
var races_played := 0
var victories := 0
var podiums := 0
var best_finish_position := 0
var driving_time_seconds := 0.0
var items_collected := 0
var items_used := 0
var shortcuts_used := 0
var recoveries := 0
var _recorded_result_ids: Dictionary = {}
func medal_key(cup_id: StringName, difficulty_id: StringName) -> String:
	return "%s/%s" % [cup_id, difficulty_id]
func get_medal(cup_id: StringName, difficulty_id: StringName) -> int:
	return int(best_medals.get(medal_key(cup_id, difficulty_id), 0))

func get_best_cup_medal(cup_id: StringName) -> int:
	var best := UnlockDefinition.Medal.NONE
	var prefix := "%s/" % cup_id
	for key in best_medals:
		if str(key).begins_with(prefix): best = maxi(best, int(best_medals[key]))
	return best

func get_best_medal_for_cup(cup_id: StringName) -> int:
	return get_best_cup_medal(cup_id)

func get_career_points(catalog: ProgressionCatalog) -> int:
	if catalog == null or catalog.cups == null:
		return 0
	var total := 0
	for cup in catalog.cups.get_valid_cups():
		for difficulty in cup.difficulties:
			if difficulty != null:
				total += get_medal(cup.id, difficulty.id) * difficulty.progress_multiplier
	return total

func get_max_career_points(catalog: ProgressionCatalog) -> int:
	if catalog == null or catalog.cups == null:
		return 0
	var total := 0
	for cup in catalog.cups.get_valid_cups():
		for difficulty in cup.difficulties:
			if difficulty != null: total += UnlockDefinition.GOLD * difficulty.progress_multiplier
	return total

func record_medal(cup: CupDefinition, difficulty: DifficultyDefinition, medal: int, catalog: ProgressionCatalog = null) -> PackedStringArray:
	if cup == null or difficulty == null or difficulty not in cup.difficulties:
		return PackedStringArray()
	var key := medal_key(cup.id, difficulty.id)
	best_medals[key] = maxi(int(best_medals.get(key, 0)), clampi(medal, UnlockDefinition.Medal.NONE, UnlockDefinition.GOLD))
	if catalog != null:
		return evaluate_rewards(catalog)
	return _evaluate_unlocks(cup.unlocks, 0)

func evaluate_rewards(catalog: ProgressionCatalog) -> PackedStringArray:
	if catalog == null or catalog.unlocks == null:
		return PackedStringArray()
	return _evaluate_unlocks(catalog.unlocks.unlocks, get_career_points(catalog))

func _evaluate_unlocks(unlocks: Array[UnlockDefinition], career_points: int) -> PackedStringArray:
	var granted := PackedStringArray()
	for unlock in unlocks:
		if unlock == null or unlocked_reward_ids.has(unlock.id): continue
		var eligible := false
		if unlock.requirement_type == UnlockDefinition.CUP_MEDAL:
			eligible = get_best_cup_medal(unlock.cup_id) >= unlock.required_medal
		elif unlock.requirement_type == UnlockDefinition.CAREER_POINTS and career_points > 0:
			eligible = career_points >= unlock.required_points
		if eligible:
			unlocked_reward_ids[unlock.id] = true
			granted.append(unlock.id)
	return granted

func is_cup_unlocked(cup: CupDefinition, catalog: ProgressionCatalog) -> bool:
	if cup == null:
		return false
	if cup.prerequisite_cup_id.is_empty():
		return true
	if catalog == null or catalog.cups == null or catalog.cups.get_cup(cup.prerequisite_cup_id) == null:
		return false
	var medal := get_best_cup_medal(cup.prerequisite_cup_id)
	if not cup.prerequisite_difficulty_id.is_empty():
		medal = get_medal(cup.prerequisite_cup_id, cup.prerequisite_difficulty_id)
	return medal >= cup.prerequisite_medal

func get_unlocked_cups(catalog: ProgressionCatalog) -> Array[CupDefinition]:
	var result: Array[CupDefinition] = []
	if catalog == null or catalog.cups == null:
		return result
	for cup in catalog.cups.get_valid_cups():
		if is_cup_unlocked(cup, catalog): result.append(cup)
	return result

func get_available_cups(catalog: ProgressionCatalog) -> Array[CupDefinition]:
	return get_unlocked_cups(catalog)

func get_next_career_reward(catalog: ProgressionCatalog) -> UnlockDefinition:
	if catalog == null or catalog.unlocks == null:
		return null
	var points := get_career_points(catalog)
	for unlock in catalog.unlocks.get_career_rewards():
		if unlock.required_points > points: return unlock
	return null

func can_equip(variant_id: StringName, catalog: UnlockCatalog) -> bool:
	if catalog == null or catalog.get_variant(variant_id) == null:
		return false
	if catalog.is_initial_variant(variant_id):
		return true
	for unlock_id in unlocked_reward_ids:
		var unlock := catalog.get_unlock(StringName(unlock_id))
		if unlock != null and unlock.kart_variant.id == variant_id: return true
	return false

func get_unlocked_variant_count(catalog: UnlockCatalog) -> int:
	if catalog == null: return 0
	var result := int(catalog.initial_variant != null)
	for unlock in catalog.unlocks:
		if unlocked_reward_ids.has(unlock.id): result += 1
	return result
func equip(variant_id: StringName, catalog: UnlockCatalog) -> bool:
	if not can_equip(variant_id, catalog): return false
	equipped_kart_variant_id = variant_id
	save_to_disk()
	return true
func is_reward_new(reward_id: StringName) -> bool:
	return unlocked_reward_ids.has(reward_id) and not seen_reward_ids.has(reward_id)
func get_new_reward_count() -> int:
	var count := 0
	for reward_id in unlocked_reward_ids:
		count += int(not seen_reward_ids.has(reward_id))
	return count
func mark_reward_seen(reward_id: StringName) -> bool:
	if not unlocked_reward_ids.has(reward_id) or seen_reward_ids.has(reward_id): return false
	seen_reward_ids[reward_id] = true
	save_to_disk()
	return true
func record_race_result(result: RaceResult) -> bool:
	if result == null or result.player_result == null:
		return false
	var result_id := _result_id(result)
	if _recorded_result_ids.has(result_id):
		return false
	_recorded_result_ids[result_id] = true
	var player := result.player_result
	races_played += 1
	if player.finish_position == 1:
		victories += 1
	if player.finish_position > 0 and player.finish_position <= 3:
		podiums += 1
	if player.finish_position > 0 and (best_finish_position == 0 or player.finish_position < best_finish_position):
		best_finish_position = player.finish_position
	driving_time_seconds += maxf(player.finish_time, 0.0)
	items_collected += player.items_collected
	items_used += player.items_used
	shortcuts_used += player.shortcuts_used
	recoveries += player.recoveries
	save_to_disk()
	return true
func _result_id(result: RaceResult) -> String:
	if not result.run_id.is_empty():
		return "run:%s:%d" % [result.run_id, result.cup_race_index]
	return "%s:%s:%d:%s:%s" % [result.track_id, result.cc_id, result.game_mode, result.player_result.racer_id, snappedf(result.player_result.finish_time, 0.001)]
func save_to_disk() -> Error:
	var config := ConfigFile.new()
	config.set_value("progress", "schema_version", SCHEMA_VERSION)
	config.set_value("progress", "best_medals", best_medals)
	config.set_value("progress", "unlocked_reward_ids", unlocked_reward_ids)
	config.set_value("progress", "seen_reward_ids", seen_reward_ids)
	config.set_value("progress", "equipped_kart_variant_id", str(equipped_kart_variant_id))
	config.set_value("progress", "active_cup", active_cup)
	config.set_value("telemetry", "races_played", races_played)
	config.set_value("telemetry", "victories", victories)
	config.set_value("telemetry", "podiums", podiums)
	config.set_value("telemetry", "best_finish_position", best_finish_position)
	config.set_value("telemetry", "driving_time_seconds", driving_time_seconds)
	config.set_value("telemetry", "items_collected", items_collected)
	config.set_value("telemetry", "items_used", items_used)
	config.set_value("telemetry", "shortcuts_used", shortcuts_used)
	config.set_value("telemetry", "recoveries", recoveries)
	config.set_value("telemetry", "recorded_result_ids", _recorded_result_ids)
	var error := config.save(save_path)
	if error == OK: loaded_schema_version = SCHEMA_VERSION
	return error
func load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var schema := int(config.get_value("progress", "schema_version", 1))
	if schema < 1 or schema > SCHEMA_VERSION:
		return
	loaded_schema_version = schema
	best_medals = config.get_value("progress", "best_medals", {})
	unlocked_reward_ids = config.get_value("progress", "unlocked_reward_ids", {})
	seen_reward_ids = config.get_value("progress", "seen_reward_ids", {}) if schema >= 3 else unlocked_reward_ids.duplicate()
	if schema < SCHEMA_VERSION:
		unlocked_reward_ids = _migrate_reward_ids(unlocked_reward_ids)
		seen_reward_ids = _migrate_reward_ids(seen_reward_ids)
	equipped_kart_variant_id = StringName(config.get_value("progress", "equipped_kart_variant_id", str(INITIAL_VARIANT_ID)))
	if equipped_kart_variant_id.is_empty(): equipped_kart_variant_id = INITIAL_VARIANT_ID
	active_cup = config.get_value("progress", "active_cup", {})
	races_played = int(config.get_value("telemetry", "races_played", 0))
	victories = int(config.get_value("telemetry", "victories", 0))
	podiums = int(config.get_value("telemetry", "podiums", 0))
	best_finish_position = int(config.get_value("telemetry", "best_finish_position", 0))
	driving_time_seconds = float(config.get_value("telemetry", "driving_time_seconds", 0.0))
	items_collected = int(config.get_value("telemetry", "items_collected", 0))
	items_used = int(config.get_value("telemetry", "items_used", 0))
	shortcuts_used = int(config.get_value("telemetry", "shortcuts_used", 0))
	recoveries = int(config.get_value("telemetry", "recoveries", 0))
	_recorded_result_ids = config.get_value("telemetry", "recorded_result_ids", {})

func _migrate_reward_ids(source: Dictionary) -> Dictionary:
	var migrated := {}
	for raw_id in source:
		if not bool(source[raw_id]): continue
		var id := StringName(raw_id)
		migrated[LEGACY_REWARD_MIGRATION.get(id, id)] = true
	return migrated
