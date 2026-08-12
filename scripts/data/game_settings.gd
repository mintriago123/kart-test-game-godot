class_name GameSettings
extends RefCounted

const SETTINGS_PATH := "user://coastal_karts.cfg"
const DEFAULT_TRACK_ID := &"coastal"
const DEFAULT_CC_ID := RaceClassDefinition.DEFAULT_ID

var graphics_profile := "medium"
var vibration_enabled := true
var master_volume := 0.8
var music_volume := 1.0
var effects_volume := 1.0
var camera_motion := "reduced"
var speed_lines_enabled := true
var threat_indicators_enabled := true
var vibration_intensity := 1.0
var ui_reduced_motion := false
var best_time := -1.0
var selected_track_id: StringName = DEFAULT_TRACK_ID
var selected_cc_id: StringName = DEFAULT_CC_ID
var selected_game_mode := GameModeDefinition.RACE
var ghost_enabled := true
var best_times: Dictionary = {}
var best_lap_times: Dictionary = {}
var is_persistence_enabled := true
var settings_path := SETTINGS_PATH


func load_from_disk() -> void:
	if not is_persistence_enabled:
		return
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error != OK:
		return
	graphics_profile = PresentationQuality.sanitize(str(config.get_value("video", "profile", "medium")))
	vibration_enabled = bool(config.get_value("gameplay", "vibration", true))
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", 1.0)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("audio", "effects_volume", 1.0)), 0.0, 1.0)
	camera_motion = str(config.get_value("accessibility", "camera_motion", "reduced"))
	if camera_motion not in ["reduced", "full", "off"]:
		camera_motion = "reduced"
	speed_lines_enabled = bool(config.get_value("video", "speed_lines", true))
	threat_indicators_enabled = bool(config.get_value("gameplay", "threat_indicators", true))
	vibration_intensity = clampf(float(config.get_value("gameplay", "vibration_intensity", 1.0 if vibration_enabled else 0.0)), 0.0, 1.0)
	ui_reduced_motion = bool(config.get_value("accessibility", "ui_reduced_motion", false))
	selected_track_id = StringName(
		str(config.get_value("gameplay", "selected_track", DEFAULT_TRACK_ID))
	)
	selected_cc_id = RaceClassDefinition.get_by_id(StringName(
		str(config.get_value("gameplay", "selected_cc", DEFAULT_CC_ID))
	)).id
	selected_game_mode = GameModeDefinition.sanitize(int(config.get_value("gameplay", "selected_game_mode", GameModeDefinition.RACE)))
	ghost_enabled = bool(config.get_value("gameplay", "ghost_enabled", true))
	var loaded_best_times: Variant = config.get_value("progress", "best_times", {})
	best_times = migrate_best_times(
		loaded_best_times if loaded_best_times is Dictionary else {}
	)
	var loaded_best_laps: Variant = config.get_value("progress", "best_lap_times", {})
	best_lap_times = migrate_best_times(
		loaded_best_laps if loaded_best_laps is Dictionary else {}
	)
	var legacy_best_time := maxf(
		float(config.get_value("progress", "best_time", -1.0)),
		-1.0
	)
	var legacy_key := get_record_key(DEFAULT_TRACK_ID, DEFAULT_CC_ID, GameModeDefinition.RACE)
	if legacy_best_time > 0.0 and not best_times.has(legacy_key):
		best_times[legacy_key] = legacy_best_time
	best_time = get_best_time(selected_track_id, selected_cc_id, selected_game_mode)


func save_to_disk() -> void:
	if not is_persistence_enabled:
		return
	var config := ConfigFile.new()
	graphics_profile = PresentationQuality.sanitize(graphics_profile)
	config.set_value("video", "profile", graphics_profile)
	config.set_value("video", "speed_lines", speed_lines_enabled)
	config.set_value("gameplay", "vibration", vibration_enabled)
	config.set_value("gameplay", "vibration_intensity", vibration_intensity)
	config.set_value("gameplay", "threat_indicators", threat_indicators_enabled)
	config.set_value("accessibility", "camera_motion", camera_motion)
	config.set_value("accessibility", "ui_reduced_motion", ui_reduced_motion)
	config.set_value("gameplay", "selected_track", selected_track_id)
	config.set_value("gameplay", "selected_cc", selected_cc_id)
	config.set_value("gameplay", "selected_game_mode", selected_game_mode)
	config.set_value("gameplay", "ghost_enabled", ghost_enabled)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value(
		"progress",
		"best_time",
		get_best_time(DEFAULT_TRACK_ID, DEFAULT_CC_ID, GameModeDefinition.RACE)
	)
	config.set_value("progress", "best_times", best_times)
	config.set_value("progress", "best_lap_times", best_lap_times)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save MichiKart xd settings: %s" % error_string(error))


func select_track(track_id: StringName) -> void:
	selected_track_id = track_id
	best_time = get_best_time(track_id, selected_cc_id, selected_game_mode)


func select_cc(cc_id: StringName) -> void:
	selected_cc_id = RaceClassDefinition.get_by_id(cc_id).id
	best_time = get_best_time(selected_track_id, selected_cc_id, selected_game_mode)


func select_game_mode(game_mode: int) -> void:
	selected_game_mode = GameModeDefinition.sanitize(game_mode)
	best_time = get_best_time(selected_track_id, selected_cc_id, selected_game_mode)


func get_best_time(
	track_id: StringName = selected_track_id,
	cc_id: StringName = selected_cc_id,
	game_mode: int = selected_game_mode
) -> float:
	return maxf(float(best_times.get(get_record_key(track_id, cc_id, game_mode), -1.0)), -1.0)


func register_race_time(
	race_time: float,
	track_id: StringName = selected_track_id,
	cc_id: StringName = selected_cc_id,
	game_mode: int = selected_game_mode
) -> bool:
	if race_time <= 0.0:
		return false
	var current_best := get_best_time(track_id, cc_id, game_mode)
	if current_best > 0.0 and race_time >= current_best:
		return false
	best_times[get_record_key(track_id, cc_id, game_mode)] = race_time
	if track_id == selected_track_id and cc_id == selected_cc_id:
		best_time = race_time
	return true


func get_best_lap_time(
	track_id: StringName = selected_track_id,
	cc_id: StringName = selected_cc_id,
	game_mode: int = selected_game_mode
) -> float:
	return maxf(float(best_lap_times.get(get_record_key(track_id, cc_id, game_mode), -1.0)), -1.0)


func register_race_result(result: RaceResult) -> bool:
	if result == null or result.player_result == null:
		return false
	var changed := register_race_time(
		result.player_result.finish_time,
		result.track_id,
		result.cc_id,
		result.game_mode
	)
	var lap_time := result.player_result.best_lap_time
	var record_key := get_record_key(result.track_id, result.cc_id, result.game_mode)
	var current_best := get_best_lap_time(result.track_id, result.cc_id, result.game_mode)
	if lap_time > 0.0 and (current_best <= 0.0 or lap_time < current_best):
		best_lap_times[record_key] = lap_time
		changed = true
	return changed


static func get_record_key(track_id: StringName, cc_id: StringName, game_mode: int = GameModeDefinition.RACE) -> StringName:
	return StringName("%s|%s|%s" % [GameModeDefinition.to_id(game_mode), track_id, cc_id])


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
		elif key_text.count("|") >= 2:
			_store_valid_time(migrated, StringName(key_text), raw_value)
		elif "|" in key_text:
			var parts := key_text.split("|")
			_store_valid_time(migrated, get_record_key(StringName(parts[0]), StringName(parts[1]), GameModeDefinition.RACE), raw_value)
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
