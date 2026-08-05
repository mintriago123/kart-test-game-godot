class_name GameSettings
extends RefCounted

const SETTINGS_PATH := "user://coastal_karts.cfg"

var graphics_profile := "medium"
var vibration_enabled := true
var master_volume := 0.8
var best_time := -1.0
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
	best_time = maxf(float(config.get_value("progress", "best_time", -1.0)), -1.0)


func save_to_disk() -> void:
	if not is_persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("video", "profile", graphics_profile)
	config.set_value("gameplay", "vibration", vibration_enabled)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("progress", "best_time", best_time)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save Coastal Karts settings: %s" % error_string(error))


func register_race_time(race_time: float) -> bool:
	if race_time <= 0.0:
		return false
	if best_time > 0.0 and race_time >= best_time:
		return false
	best_time = race_time
	return true
