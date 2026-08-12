class_name PlayerProgress
extends RefCounted
const SCHEMA_VERSION := 1
const SAVE_PATH := "user://progression.cfg"
var save_path := SAVE_PATH
var best_medals: Dictionary = {}
var unlocked_reward_ids: Dictionary = {}
var equipped_kart_variant_id: StringName
var active_cup: Dictionary = {}
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
	for unlock_id in unlocked_reward_ids:
		var unlock := catalog.get_unlock(StringName(unlock_id))
		if unlock != null and unlock.kart_variant.id == variant_id: return true
	return false
func equip(variant_id: StringName, catalog: UnlockCatalog) -> bool:
	if not can_equip(variant_id, catalog): return false
	equipped_kart_variant_id = variant_id
	save_to_disk()
	return true
func save_to_disk() -> Error:
	var config := ConfigFile.new()
	config.set_value("progress", "schema_version", SCHEMA_VERSION)
	config.set_value("progress", "best_medals", best_medals)
	config.set_value("progress", "unlocked_reward_ids", unlocked_reward_ids)
	config.set_value("progress", "equipped_kart_variant_id", str(equipped_kart_variant_id))
	config.set_value("progress", "active_cup", active_cup)
	return config.save(save_path)
func load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(save_path) != OK or int(config.get_value("progress", "schema_version", 0)) != SCHEMA_VERSION:
		return
	best_medals = config.get_value("progress", "best_medals", {})
	unlocked_reward_ids = config.get_value("progress", "unlocked_reward_ids", {})
	equipped_kart_variant_id = StringName(config.get_value("progress", "equipped_kart_variant_id", ""))
	active_cup = config.get_value("progress", "active_cup", {})
