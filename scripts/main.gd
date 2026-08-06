extends Node

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")

var settings := GameSettings.new()
var main_menu: MainMenu
var race_world: RaceWorld


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input_map()
	settings.load_from_disk()
	var initial_track := TRACK_CATALOG.get_valid_track(settings.selected_track_id)
	if initial_track != null:
		settings.select_track(initial_track.id)
	_apply_master_volume(settings.master_volume)
	_show_main_menu()
	if "--auto-race" in OS.get_cmdline_user_args():
		start_game.call_deferred()


func start_game(track_id: StringName = settings.selected_track_id) -> void:
	var track_definition := TRACK_CATALOG.get_valid_track(track_id)
	if track_definition == null:
		push_error("No valid track is available.")
		return
	settings.select_track(track_definition.id)
	settings.save_to_disk()
	if race_world != null:
		race_world.queue_free()
		race_world = null
	if main_menu != null:
		main_menu.queue_free()
		main_menu = null
	get_tree().paused = false
	race_world = RaceWorld.new()
	race_world.graphics_profile = settings.graphics_profile
	race_world.vibration_enabled = settings.vibration_enabled
	race_world.track_definition = track_definition
	race_world.retry_requested.connect(_restart_game)
	race_world.menu_requested.connect(_return_to_menu)
	race_world.race_completed.connect(_register_race_time)
	add_child(race_world)


func _show_main_menu() -> void:
	if main_menu != null:
		return
	main_menu = MainMenu.new()
	main_menu.track_catalog = TRACK_CATALOG
	main_menu.play_requested.connect(start_game)
	main_menu.track_selected.connect(_set_selected_track)
	main_menu.graphics_profile_changed.connect(_set_graphics_profile)
	main_menu.vibration_changed.connect(_set_vibration_enabled)
	main_menu.volume_changed.connect(_set_master_volume)
	add_child(main_menu)
	main_menu.apply_settings(
		settings.graphics_profile,
		settings.vibration_enabled,
		settings.master_volume,
		settings.best_times,
		settings.selected_track_id
	)


func _restart_game() -> void:
	start_game()


func _return_to_menu() -> void:
	if race_world != null:
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


func _set_selected_track(track_id: StringName) -> void:
	var track_definition := TRACK_CATALOG.get_track(track_id)
	if track_definition == null:
		return
	settings.select_track(track_definition.id)
	settings.save_to_disk()


func _apply_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value) if value > 0.0 else -80.0)


func _register_race_time(race_time: float) -> void:
	if settings.register_race_time(race_time, settings.selected_track_id):
		settings.save_to_disk()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and race_world != null:
		get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and race_world != null:
		get_tree().paused = not get_tree().paused
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


func _add_key_action(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == physical_keycode:
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, key_event)
