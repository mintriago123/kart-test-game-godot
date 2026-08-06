class_name GameSettings
extends RefCounted

const SETTINGS_PATH := "user://coastal_karts.cfg"
const DEFAULT_TRACK_ID := &"coastal"

var graphics_profile := "medium"
var vibration_enabled := true
var master_volume := 0.8
var best_time := -1.0
var selected_track_id: StringName = DEFAULT_TRACK_ID
var best_times: Dictionary = {}
var is_persistence_enabled := true


func load_from_disk() -> void:
	if not is_persistence_enabled:
		return
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
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
	var loaded_best_times: Variant = config.get_value("progress", "best_times", {})
	best_times = loaded_best_times.duplicate(true) if loaded_best_times is Dictionary else {}
	var legacy_best_time := maxf(
		float(config.get_value("progress", "best_time", -1.0)),
		-1.0
	)
	if legacy_best_time > 0.0 and not best_times.has(DEFAULT_TRACK_ID):
		best_times[DEFAULT_TRACK_ID] = legacy_best_time
	best_time = get_best_time(selected_track_id)


func save_to_disk() -> void:
	if not is_persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("video", "profile", graphics_profile)
	config.set_value("gameplay", "vibration", vibration_enabled)
	config.set_value("gameplay", "selected_track", selected_track_id)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("progress", "best_time", get_best_time(DEFAULT_TRACK_ID))
	config.set_value("progress", "best_times", best_times)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save MichiKart xd settings: %s" % error_string(error))


func select_track(track_id: StringName) -> void:
	selected_track_id = track_id
	best_time = get_best_time(track_id)


func get_best_time(track_id: StringName = selected_track_id) -> float:
	return maxf(float(best_times.get(track_id, -1.0)), -1.0)


func register_race_time(
	race_time: float,
	track_id: StringName = selected_track_id
) -> bool:
	if race_time <= 0.0:
		return false
	var current_best := get_best_time(track_id)
	if current_best > 0.0 and race_time >= current_best:
		return false
	best_times[track_id] = race_time
	if track_id == selected_track_id:
		best_time = race_time
	return true
