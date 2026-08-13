class_name PlayerProgress
extends RefCounted
const SCHEMA_VERSION := 3
const SAVE_PATH := "user://progression.cfg"
var save_path := SAVE_PATH
var best_medals: Dictionary = {}
var unlocked_reward_ids: Dictionary = {}
var seen_reward_ids: Dictionary = {}
var equipped_kart_variant_id: StringName
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
func record_medal(cup: CupDefinition, difficulty: DifficultyDefinition, medal: int) -> PackedStringArray:
	var granted := PackedStringArray()
	var ordered := cup.difficulties.duplicate()
	ordered.sort_custom(func(a, b): return a.sort_order < b.sort_order)
	var selected_order := difficulty.sort_order
	for value in ordered:
		if value.sort_order > selected_order: continue
		var key := medal_key(cup.id, value.id)
		best_medals[key] = maxi(int(best_medals.get(key, 0)), medal)
		for unlock in cup.unlocks:
			if unlock.difficulty_id == value.id and unlock.required_medal <= medal and not unlocked_reward_ids.has(unlock.id):
				unlocked_reward_ids[unlock.id] = true
				granted.append(unlock.id)
	return granted
func can_equip(variant_id: StringName, catalog: UnlockCatalog) -> bool:
	if catalog != null and not catalog.unlocks.is_empty() and catalog.unlocks[0] != null and catalog.unlocks[0].kart_variant != null and catalog.unlocks[0].kart_variant.id == variant_id:
		return true
	for unlock_id in unlocked_reward_ids:
		var unlock := catalog.get_unlock(StringName(unlock_id))
		if unlock != null and unlock.kart_variant.id == variant_id: return true
	return false
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
	return config.save(save_path)
func load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	var schema := int(config.get_value("progress", "schema_version", 1))
	if schema < 1 or schema > SCHEMA_VERSION:
		return
	best_medals = config.get_value("progress", "best_medals", {})
	unlocked_reward_ids = config.get_value("progress", "unlocked_reward_ids", {})
	seen_reward_ids = config.get_value("progress", "seen_reward_ids", {}) if schema >= 3 else unlocked_reward_ids.duplicate()
	equipped_kart_variant_id = StringName(config.get_value("progress", "equipped_kart_variant_id", ""))
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
