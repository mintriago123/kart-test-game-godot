extends Node

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")
const PROGRESSION_CATALOG: ProgressionCatalog = preload("res://progression/progression_catalog.tres")

var settings := GameSettings.new()
var main_menu: MainMenu
var race_world: RaceWorld
var ghost_storage := GhostStorage.new()
var player_progress := PlayerProgress.new()
var cup_manager: CupManager
var selected_cup_difficulty_id: StringName = &"competitive"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input_map()
	settings.load_from_disk()
	_ensure_audio_buses()
	player_progress.load_from_disk()
	cup_manager = CupManager.new(PROGRESSION_CATALOG, player_progress)
	for diagnostic in PROGRESSION_CATALOG.validate():
		push_warning("Progression catalog: %s" % diagnostic)
	var initial_track := TRACK_CATALOG.get_valid_track(settings.selected_track_id)
	if initial_track != null:
		settings.select_track(initial_track.id)
	_apply_master_volume(settings.master_volume)
	_show_main_menu()
	if "--auto-race" in OS.get_cmdline_user_args():
		start_game.call_deferred(settings.selected_track_id, settings.selected_cc_id, GameModeDefinition.RACE, false)
	elif "--auto-time-trial" in OS.get_cmdline_user_args():
		start_game.call_deferred(settings.selected_track_id, settings.selected_cc_id, GameModeDefinition.TIME_TRIAL, false)


func start_game(
	track_id: StringName = settings.selected_track_id,
	cc_id_or_intro: Variant = settings.selected_cc_id,
	game_mode: int = GameModeDefinition.RACE,
	should_play_intro: bool = true
) -> void:
	# Compatibility with the former start_game(track_id, should_play_intro).
	var cc_id := settings.selected_cc_id
	if cc_id_or_intro is bool:
		should_play_intro = bool(cc_id_or_intro)
	else:
		cc_id = StringName(str(cc_id_or_intro))
	if game_mode == GameModeDefinition.CUP:
		if cup_manager.active_run == null and not cup_manager.start(&"tropical", selected_cup_difficulty_id, cc_id):
			push_error("Unable to start the configured cup.")
			return
		_start_session(cup_manager.create_session(), should_play_intro)
		return
	var track_definition := TRACK_CATALOG.get_valid_track(track_id)
	if track_definition == null:
		push_error("No valid track is available.")
		return
	settings.select_track(track_definition.id)
	settings.select_cc(cc_id)
	settings.select_game_mode(game_mode)
	settings.save_to_disk()
	var session := RaceSessionConfig.new()
	session.track = track_definition
	session.race_class = RaceClassDefinition.get_by_id(settings.selected_cc_id)
	session.game_mode = game_mode
	session.racers = PROGRESSION_CATALOG.racers.racers.duplicate()
	session.player_racer_id = &"marea"
	session.equipped_variant = PROGRESSION_CATALOG.unlocks.get_variant(player_progress.equipped_kart_variant_id)
	session.race_seed = randi()
	_start_session(session, should_play_intro)


func _start_session(session: RaceSessionConfig, should_play_intro: bool) -> void:
	if session == null:
		push_error("Cannot start an empty race session.")
		return
	if race_world != null:
		race_world.shutdown()
		race_world.queue_free()
		race_world = null
	if main_menu != null:
		main_menu.queue_free()
		main_menu = null
	get_tree().paused = false
	race_world = RaceWorld.new()
	race_world.graphics_profile = settings.graphics_profile
	race_world.vibration_enabled = settings.vibration_enabled
	race_world.vibration_intensity = settings.vibration_intensity
	race_world.camera_motion = settings.camera_motion
	race_world.speed_lines_enabled = settings.speed_lines_enabled
	race_world.threat_indicators_enabled = settings.threat_indicators_enabled
	race_world.play_intro = should_play_intro
	race_world.setup(session)
	race_world.game_mode = session.game_mode
	race_world.ghost_enabled = settings.ghost_enabled
	race_world.previous_best_time = settings.get_best_time(session.track.id, session.race_class.id, session.game_mode)
	race_world.previous_best_lap_time = settings.get_best_lap_time(session.track.id, session.race_class.id, session.game_mode)
	if session.game_mode == GameModeDefinition.TIME_TRIAL:
		var preview_track := session.track.scene.instantiate() as CoastalTrack
		if preview_track != null:
			add_child(preview_track)
			var fingerprint := TrackFingerprint.calculate(preview_track, session.track)
			preview_track.queue_free()
			race_world.ghost_recording = ghost_storage.load_compatible(session.track.id, fingerprint, session.race_class.id, session.track.laps)
	race_world.retry_requested.connect(_restart_game)
	race_world.menu_requested.connect(_return_to_menu)
	race_world.race_completed.connect(_register_race_time)
	add_child(race_world)


func _show_main_menu() -> void:
	if main_menu != null:
		return
	main_menu = MainMenu.new()
	main_menu.track_catalog = TRACK_CATALOG
	main_menu.has_active_cup = not player_progress.active_cup.is_empty()
	main_menu.progression_catalog = PROGRESSION_CATALOG
	main_menu.player_progress = player_progress
	main_menu.play_requested.connect(_handle_play_requested)
	main_menu.track_selected.connect(_set_selected_track)
	main_menu.race_class_selected.connect(_set_selected_cc)
	main_menu.game_mode_selected.connect(_set_selected_game_mode)
	main_menu.ghost_enabled_changed.connect(_set_ghost_enabled)
	main_menu.graphics_profile_changed.connect(_set_graphics_profile)
	main_menu.vibration_changed.connect(_set_vibration_enabled)
	main_menu.volume_changed.connect(_set_master_volume)
	main_menu.music_volume_changed.connect(_set_music_volume)
	main_menu.effects_volume_changed.connect(_set_effects_volume)
	main_menu.camera_motion_changed.connect(_set_camera_motion)
	main_menu.speed_lines_changed.connect(_set_speed_lines_enabled)
	main_menu.threat_indicators_changed.connect(_set_threat_indicators_enabled)
	main_menu.vibration_intensity_changed.connect(_set_vibration_intensity)
	main_menu.restore_defaults_requested.connect(_restore_presentation_defaults)
	main_menu.continue_cup_requested.connect(_continue_cup)
	main_menu.equip_variant_requested.connect(_equip_variant)
	add_child(main_menu)
	main_menu.apply_settings(
		settings.graphics_profile,
		settings.vibration_enabled,
		settings.master_volume,
		settings.best_times,
		settings.selected_track_id,
		settings.selected_cc_id,
		settings.selected_game_mode,
		settings.ghost_enabled,
		settings.music_volume,
		settings.effects_volume,
		settings.camera_motion,
		settings.speed_lines_enabled,
		settings.threat_indicators_enabled,
		settings.vibration_intensity
	)
	_refresh_ghost_availability()


func _continue_cup() -> void:
	if cup_manager.restore():
		_start_session(cup_manager.create_session(), true)


func _equip_variant(variant_id: StringName) -> void:
	player_progress.equip(variant_id, PROGRESSION_CATALOG.unlocks)


func _restart_game() -> void:
	if cup_manager != null and cup_manager.active_run != null:
		if cup_manager.active_run.is_completed:
			cup_manager.active_run = null
			_return_to_menu()
		else:
			_start_session(cup_manager.create_session(), false)
		return
	start_game(settings.selected_track_id, settings.selected_cc_id, settings.selected_game_mode, false)


func _return_to_menu() -> void:
	if race_world != null:
		race_world.shutdown()
		race_world.queue_free()
		race_world = null
	get_tree().paused = false
	_show_main_menu()


func _set_graphics_profile(profile: String) -> void:
	settings.graphics_profile = profile
	settings.save_to_disk()


func _set_vibration_enabled(enabled: bool) -> void:
	settings.vibration_enabled = enabled
	settings.save_to_disk()


func _set_master_volume(value: float) -> void:
	settings.master_volume = clampf(value, 0.0, 1.0)
	_apply_master_volume(settings.master_volume)
	settings.save_to_disk()

func _set_music_volume(value: float) -> void:
	settings.music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(&"Music", settings.music_volume)
	settings.save_to_disk()

func _set_effects_volume(value: float) -> void:
	settings.effects_volume = clampf(value, 0.0, 1.0)
	for bus_name in [&"Engine", &"Tires", &"Impacts", &"Items", &"UI"]:
		_set_bus_volume(bus_name, settings.effects_volume)
	settings.save_to_disk()

func _set_camera_motion(mode: String) -> void:
	settings.camera_motion = mode if mode in ["reduced", "full", "off"] else "reduced"
	settings.save_to_disk()

func _set_speed_lines_enabled(enabled: bool) -> void:
	settings.speed_lines_enabled = enabled
	settings.save_to_disk()

func _set_threat_indicators_enabled(enabled: bool) -> void:
	settings.threat_indicators_enabled = enabled
	settings.save_to_disk()

func _restore_presentation_defaults() -> void:
	settings.graphics_profile = "medium"
	settings.vibration_enabled = true
	settings.master_volume = 0.8
	settings.music_volume = 1.0
	settings.effects_volume = 1.0
	settings.camera_motion = "reduced"
	settings.speed_lines_enabled = true
	settings.threat_indicators_enabled = true
	settings.vibration_intensity = 1.0
	_apply_master_volume(settings.master_volume)
	_set_bus_volume(&"Music", settings.music_volume)
	for bus_name in [&"Engine", &"Tires", &"Impacts", &"Items", &"UI"]:
		_set_bus_volume(bus_name, settings.effects_volume)
	settings.save_to_disk()

func _set_vibration_intensity(value: float) -> void:
	settings.vibration_intensity = clampf(value, 0.0, 1.0)
	settings.vibration_enabled = settings.vibration_intensity > 0.0
	settings.save_to_disk()


func _set_selected_track(track_id: StringName) -> void:
	var track_definition := TRACK_CATALOG.get_track(track_id)
	if track_definition == null:
		return
	settings.select_track(track_definition.id)
	settings.save_to_disk()
	_refresh_ghost_availability()


func _set_selected_cc(cc_id: StringName) -> void:
	settings.select_cc(cc_id)
	settings.save_to_disk()
	_refresh_ghost_availability()


func _handle_play_requested(track_id: StringName, cc_id: StringName, game_mode: int, difficulty_id: StringName = &"competitive") -> void:
	settings.select_cc(cc_id)
	settings.select_game_mode(game_mode)
	selected_cup_difficulty_id = difficulty_id
	start_game(track_id, cc_id, game_mode, true)


func _set_selected_game_mode(game_mode: int) -> void:
	settings.select_game_mode(game_mode)
	settings.save_to_disk()
	_refresh_ghost_availability()


func _set_ghost_enabled(enabled: bool) -> void:
	settings.ghost_enabled = enabled
	settings.save_to_disk()


func _apply_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value) if value > 0.0 else -80.0)
	_set_bus_volume(&"Music", settings.music_volume)
	for bus_name in [&"Engine", &"Tires", &"Impacts", &"Items", &"UI"]:
		_set_bus_volume(bus_name, settings.effects_volume)

func _ensure_audio_buses() -> void:
	for bus_name in [&"Music", &"Engine", &"Tires", &"Impacts", &"Items", &"UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")

func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(value) if value > 0.0 else -80.0)


func _register_race_time(result: RaceResult) -> void:
	if result.game_mode == GameModeDefinition.CUP:
		if cup_manager.commit_race_result(result):
			result.set_meta("cup_standings", cup_manager.get_ordered_standings())
			result.set_meta("cup_completed", cup_manager.active_run.is_completed)
			result.set_meta("cup_medal", cup_manager.last_medal)
			result.set_meta("new_reward_ids", Array(cup_manager.last_granted_rewards))
		return
	var should_save_ghost := result.game_mode == GameModeDefinition.TIME_TRIAL and result.is_new_best_time
	var changed := settings.register_race_result(result)
	if should_save_ghost:
		var recording := result.get_meta("ghost_recording", null) as GhostRecording
		if recording != null:
			result.ghost_updated = ghost_storage.save_atomic(recording) == OK
	if changed:
		settings.save_to_disk()


func _refresh_ghost_availability() -> void:
	if main_menu == null or settings.selected_game_mode != GameModeDefinition.TIME_TRIAL:
		if main_menu != null:
			main_menu.set_ghost_available(false)
		return
	var definition := TRACK_CATALOG.get_valid_track(settings.selected_track_id)
	if definition == null:
		main_menu.set_ghost_available(false)
		return
	var track := definition.scene.instantiate() as CoastalTrack
	if track == null:
		main_menu.set_ghost_available(false)
		return
	add_child(track)
	var fingerprint := TrackFingerprint.calculate(track, definition)
	track.queue_free()
	main_menu.set_ghost_available(ghost_storage.has_compatible(definition.id, fingerprint, settings.selected_cc_id, definition.laps))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and race_world != null:
		get_tree().paused = true


func _exit_tree() -> void:
	if race_world != null:
		race_world.shutdown()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and race_world != null:
		if get_tree().paused:
			race_world._hud.request_resume()
		else:
			get_tree().paused = true
	if event.is_action_pressed(&"reset_kart") and race_world != null and race_world.player_kart != null:
		race_world.player_kart.reset_to_last_checkpoint()


func _configure_input_map() -> void:
	_add_key_action(&"steer_left", KEY_A)
	_add_key_action(&"steer_right", KEY_D)
	_add_key_action(&"accelerate", KEY_W)
	_add_key_action(&"brake", KEY_S)
	_add_key_action(&"drift", KEY_SPACE)
	_add_key_action(&"use_item", KEY_E)
	_add_key_action(&"pause", KEY_ESCAPE)
	_add_key_action(&"reset_kart", KEY_R)
	_add_joypad_axis_action(&"steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joypad_axis_action(&"steer_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joypad_axis_action(&"accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joypad_axis_action(&"brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joypad_button_action(&"drift", JOY_BUTTON_A)
	_add_joypad_button_action(&"use_item", JOY_BUTTON_X)
	_add_joypad_button_action(&"pause", JOY_BUTTON_START)
	_add_joypad_button_action(&"reset_kart", JOY_BUTTON_Y)


func _add_key_action(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == physical_keycode:
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key_event)


func _add_joypad_axis_action(
	action: StringName,
	axis: JoyAxis,
	axis_value: float
) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for existing_event in InputMap.action_get_events(action):
		if (
			existing_event is InputEventJoypadMotion
			and existing_event.axis == axis
			and signf(existing_event.axis_value) == signf(axis_value)
		):
			return
	var motion_event := InputEventJoypadMotion.new()
	motion_event.axis = axis
	motion_event.axis_value = axis_value
	InputMap.action_add_event(action, motion_event)


func _add_joypad_button_action(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for existing_event in InputMap.action_get_events(action):
		if (
			existing_event is InputEventJoypadButton
			and existing_event.button_index == button
		):
			return
	var button_event := InputEventJoypadButton.new()
	button_event.button_index = button
	InputMap.action_add_event(action, button_event)
