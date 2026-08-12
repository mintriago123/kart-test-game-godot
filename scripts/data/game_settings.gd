class_name GameSettings
extends RefCounted

const SETTINGS_PATH := "user://coastal_karts.cfg"
const DEFAULT_TRACK_ID := &"coastal"
const DEFAULT_CC_ID := RaceClassDefinition.DEFAULT_ID

var graphics_profile := "medium"
var vibration_enabled := true
var master_volume := 0.8
var best_time := -1.0
var selected_track_id: StringName = DEFAULT_TRACK_ID
var selected_cc_id: StringName = DEFAULT_CC_ID
var best_times: Dictionary = {}
var is_persistence_enabled := true
var settings_path := SETTINGS_PATH


func load_from_disk() -> void:
	if not is_persistence_enabled:
		return
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error != OK:
		return
	graphics_profile = str(config.get_value("video", "profile", "medium"))
	if graphics_profile not in ["low", "medium"]:
		graphics_profile = "medium"
	vibration_enabled = bool(config.get_value("gameplay", "vibration", true))
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	selected_track_id = StringName(
		str(config.get_value("gameplay", "selected_track", DEFAULT_TRACK_ID))
	)
	selected_cc_id = RaceClassDefinition.get_by_id(StringName(
		str(config.get_value("gameplay", "selected_cc", DEFAULT_CC_ID))
	)).id
	var loaded_best_times: Variant = config.get_value("progress", "best_times", {})
	best_times = migrate_best_times(
		loaded_best_times if loaded_best_times is Dictionary else {}
	)
	var legacy_best_time := maxf(
		float(config.get_value("progress", "best_time", -1.0)),
		-1.0
	)
	var legacy_key := get_record_key(DEFAULT_TRACK_ID, DEFAULT_CC_ID)
	if legacy_best_time > 0.0 and not best_times.has(legacy_key):
		best_times[legacy_key] = legacy_best_time
	best_time = get_best_time(selected_track_id)


func save_to_disk() -> void:
	if not is_persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("video", "profile", graphics_profile)
	config.set_value("gameplay", "vibration", vibration_enabled)
	config.set_value("gameplay", "selected_track", selected_track_id)
	config.set_value("gameplay", "selected_cc", selected_cc_id)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value(
		"progress",
		"best_time",
		get_best_time(DEFAULT_TRACK_ID, DEFAULT_CC_ID)
	)
	config.set_value("progress", "best_times", best_times)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save MichiKart xd settings: %s" % error_string(error))


func select_track(track_id: StringName) -> void:
	selected_track_id = track_id
	best_time = get_best_time(track_id)


func select_cc(cc_id: StringName) -> void:
	selected_cc_id = RaceClassDefinition.get_by_id(cc_id).id
	best_time = get_best_time(selected_track_id, selected_cc_id)


func get_best_time(
	track_id: StringName = selected_track_id,
	cc_id: StringName = selected_cc_id
) -> float:
	return maxf(float(best_times.get(get_record_key(track_id, cc_id), -1.0)), -1.0)


func register_race_time(
	race_time: float,
	track_id: StringName = selected_track_id,
	cc_id: StringName = selected_cc_id
) -> bool:
	if race_time <= 0.0:
		return false
	var current_best := get_best_time(track_id, cc_id)
	if current_best > 0.0 and race_time >= current_best:
		return false
	best_times[get_record_key(track_id, cc_id)] = race_time
	if track_id == selected_track_id and cc_id == selected_cc_id:
		best_time = race_time
	return true


static func get_record_key(track_id: StringName, cc_id: StringName) -> StringName:
	return StringName("%s|%s" % [track_id, cc_id])


static func migrate_best_times(records: Dictionary) -> Dictionary:
	var migrated: Dictionary = {}
	for raw_key in records:
		var raw_value: Variant = records[raw_key]
		var key_text := str(raw_key)
		if raw_value is Dictionary:
			for raw_cc_id in raw_value:
				_store_valid_time(
					migrated,
					get_record_key(StringName(key_text), StringName(str(raw_cc_id))),
					raw_value[raw_cc_id]
				)
		elif "|" in key_text:
			_store_valid_time(migrated, StringName(key_text), raw_value)
		else:
			_store_valid_time(
				migrated,
				get_record_key(StringName(key_text), DEFAULT_CC_ID),
				raw_value
			)
	return migrated


static func _store_valid_time(
	target: Dictionary,
	record_key: StringName,
	raw_time: Variant
) -> void:
	var race_time := float(raw_time)
	if race_time > 0.0:
		target[record_key] = race_time
