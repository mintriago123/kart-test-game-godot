class_name MainMenu
extends CanvasLayer

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")
const MainMenuLanding = preload("res://scripts/ui/main_menu_landing.gd")

signal play_requested(track_id: StringName, cc_id: StringName, game_mode: int, difficulty_id: StringName)
signal track_selected(track_id: StringName)
signal race_class_selected(cc_id: StringName)
signal game_mode_selected(game_mode: int)
signal ghost_enabled_changed(enabled: bool)
signal graphics_profile_changed(profile: String)
signal vibration_changed(enabled: bool)
signal volume_changed(value: float)
signal music_volume_changed(value: float)
signal effects_volume_changed(value: float)
signal camera_motion_changed(mode: String)
signal speed_lines_changed(enabled: bool)
signal threat_indicators_changed(enabled: bool)
signal vibration_intensity_changed(value: float)
signal restore_defaults_requested
signal continue_cup_requested
signal equip_variant_requested(variant_id: StringName)
signal gamepad_family_changed(family: StringName)
signal reduced_motion_changed(enabled: bool)
signal abandon_cup_requested
signal lan_race_requested(lan_session: LanSession, payload: Dictionary)

var graphics_profile := "medium"
var track_catalog: TrackCatalog
var _settings_panel: Control
var _play_button: Button
var _main_actions: Control
var _track_buttons: Dictionary = {}
var _best_times: Dictionary = {}
var _selected_track_id: StringName = &"coastal"
var _selected_cc_id: StringName = RaceClassDefinition.DEFAULT_ID
var _selected_game_mode := GameModeDefinition.RACE
var _track_selector: TrackSelectScreen
var has_active_cup := false
var progression_catalog: ProgressionCatalog
var player_progress: PlayerProgress
var device_coordinator: InputDeviceCoordinator
var _router: MenuRouter
var _title_screen: Control
var _title_dismissing := false
var _showroom: VehicleViewport
var _mode_screen: ModeSelectScreen
var _preparation_screen: PreparationScreen
var _garage_panel: Control
var _vehicle_gallery: VehicleGalleryScreen
var _cup_selector: CupSelectScreen
var _profile_panel: ProfileScreen
var _controls_panel: ControlsScreen
var _reduced_motion_toggle: CheckButton
var _quality_buttons: Dictionary = {}
var _ui_sound: SoundManager
var _garage_showroom: VehicleViewport
var _local_lobby: LocalMultiplayerLobby
var _pending_multiplayer_participants: Array[RaceParticipantConfig] = []
var _lan_lobby: LanMultiplayerLobby
var _active_play_payload: Dictionary = {}
var _pending_vehicle_pick: Dictionary = {}
var _landing: MainMenuLanding


func _ready() -> void:
	layer = 30
	if device_coordinator == null:
		# Fallback for a MainMenu created without a shared coordinator (e.g. in
		# isolation/tests). Normally main.gd injects one that outlives the menu,
		# so gamepad/keyboard icon detection keeps working during a race.
		device_coordinator = InputDeviceCoordinator.new()
		add_child(device_coordinator)
	_router = MenuRouter.new()
	_router.name = "MenuRouter"
	add_child(_router)
	_router.route_changed.connect(_handle_route_changed)
	_ui_sound = SoundManager.new()
	add_child(_ui_sound)
	_ui_sound.play_menu_music()
	_build_interface()
	_bind_ui_feedback.call_deferred()


func apply_settings(
	profile: String,
	vibration: bool,
	volume: float,
	best_times: Dictionary,
	selected_track_id: StringName,
	selected_cc_id: StringName = RaceClassDefinition.DEFAULT_ID,
	selected_game_mode: int = GameModeDefinition.RACE,
	ghost_enabled: bool = true,
	music_volume: float = 1.0,
	effects_volume: float = 1.0,
	camera_motion: String = "reduced",
	speed_lines: bool = true,
	threat_indicators: bool = true,
	vibration_intensity: float = 1.0,
	gamepad_family: StringName = &"automatic",
	reduced_motion: bool = false
) -> void:
	graphics_profile = PresentationQuality.sanitize(profile)
	_refresh_quality_buttons()
	_apply_graphics_profile_to_showrooms()
	_best_times = best_times.duplicate(true)
	if _profile_panel != null:
		_profile_panel.configure(progression_catalog, player_progress, _best_times)
	_select_track(selected_track_id, false)
	_select_cc(selected_cc_id, false)
	_select_game_mode(selected_game_mode, false)
	if device_coordinator != null:
		device_coordinator.set_manual_family(gamepad_family)
	if _reduced_motion_toggle != null:
		_reduced_motion_toggle.set_pressed_no_signal(reduced_motion)
	if _router != null:
		_router.reduced_motion = reduced_motion
	if _showroom != null:
		_showroom.reduced_motion = reduced_motion
	if _vehicle_gallery != null and _vehicle_gallery.showroom != null:
		_vehicle_gallery.showroom.reduced_motion = reduced_motion
	if _settings_panel is SettingsScreen:
		var snapshot := GameSettings.new()
		snapshot.graphics_profile = graphics_profile
		snapshot.vibration_enabled = vibration
		snapshot.master_volume = volume
		snapshot.music_volume = music_volume
		snapshot.effects_volume = effects_volume
		snapshot.camera_motion = camera_motion
		snapshot.speed_lines_enabled = speed_lines
		snapshot.threat_indicators_enabled = threat_indicators
		snapshot.vibration_intensity = vibration_intensity
		snapshot.ui_reduced_motion = reduced_motion
		snapshot.gamepad_visual_family = gamepad_family
		snapshot.ghost_enabled = ghost_enabled
		(_settings_panel as SettingsScreen).apply_snapshot(snapshot)
	_update_best_time_label()
	_update_landing_context()


func get_active_gamepad_id() -> int:
	if device_coordinator == null or device_coordinator.mode != &"gamepad":
		return -1
	return device_coordinator.device_id


func _build_interface() -> void:
	var root := Control.new()
	root.name = "MenuRoot"
	root.theme = UiTokens.create_theme()
	_router.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_landing = MainMenuLanding.new()
	_landing.name = "MainLanding"
	_landing.has_active_cup = has_active_cup
	_landing.play_requested.connect(_show_mode_selector)
	_landing.quick_race_requested.connect(func() -> void: _handle_mode_card_selected(GameModeDefinition.RACE))
	_landing.continue_requested.connect(_open_active_cup_flow)
	_landing.garage_requested.connect(_open_standalone_garage)
	_landing.profile_requested.connect(func() -> void: _router.navigate(MenuRoute.Id.PROFILE))
	_landing.settings_requested.connect(_toggle_settings)
	root.add_child(_landing)
	_main_actions = _landing.main_actions
	_play_button = _landing.play_button
	_showroom = _landing.showroom
	_vehicle_gallery = VehicleGalleryScreen.new()
	_vehicle_gallery.visible = false
	_vehicle_gallery.configure(progression_catalog, player_progress, {"source": "standalone", "variant_id": player_progress.equipped_kart_variant_id if player_progress else &""})
	_vehicle_gallery.action_requested.connect(_handle_vehicle_action)
	_vehicle_gallery.back_requested.connect(func() -> void: _router.back())
	_garage_panel = _vehicle_gallery
	root.add_child(_garage_panel)
	_profile_panel = ProfileScreen.new()
	_profile_panel.visible = false
	root.add_child(_profile_panel)
	_profile_panel.configure(progression_catalog, player_progress, _best_times)
	_profile_panel.back_requested.connect(func() -> void: _router.back())
	_profile_panel.open_garage_requested.connect(_open_standalone_garage)
	_showroom.show_variant(_get_equipped_variant())

	_track_selector = TrackSelectScreen.new()
	_track_selector.visible = false
	root.add_child(_track_selector)
	_track_selector.configure(
		track_catalog,
		_best_times,
		_selected_track_id,
		_selected_cc_id
		, _selected_game_mode
	)
	_track_selector.race_requested.connect(
		func(track_id: StringName, cc_id: StringName, game_mode: int, difficulty_id: StringName, toggle_enabled: bool) -> void:
			_selected_game_mode = game_mode
			var value := _active_play_payload.duplicate(true)
			value["track_id"] = track_id
			value["cc_id"] = cc_id
			value["mode"] = game_mode
			value["difficulty_id"] = difficulty_id
			if game_mode == GameModeDefinition.TIME_TRIAL:
				value["ghost_enabled"] = toggle_enabled
			else:
				value["items_enabled"] = toggle_enabled
			value["variant_id"] = player_progress.equipped_kart_variant_id if player_progress else value.get("variant_id", &"")
			value["source"] = "play"
			value["cup_id"] = value.get("cup_id", &"")
			value["continue_active"] = false
			if game_mode == GameModeDefinition.LOCAL_MULTIPLAYER:
				_show_preparation_payload(value)
			else:
				_show_play_vehicle(value)
	)
	_track_selector.track_selected.connect(_handle_track_selected)
	_track_selector.race_class_selected.connect(_handle_race_class_selected)
	_track_selector.game_mode_selected.connect(_handle_game_mode_selected)
	_track_selector.back_requested.connect(_hide_track_selector)
	_track_buttons = _track_selector.track_buttons
	_mode_screen = ModeSelectScreen.new()
	_mode_screen.visible = false
	root.add_child(_mode_screen)
	_mode_screen.mode_selected.connect(_handle_mode_card_selected)
	_mode_screen.back_requested.connect(_back_to_main)
	_cup_selector = CupSelectScreen.new()
	_cup_selector.visible = false
	root.add_child(_cup_selector)
	_cup_selector.cup_selected.connect(_show_play_vehicle)
	_cup_selector.back_requested.connect(func() -> void: _router.back())
	_cup_selector.abandon_requested.connect(_confirm_cup_abandon)
	_preparation_screen = PreparationScreen.new()
	_preparation_screen.visible = false
	root.add_child(_preparation_screen)
	_preparation_screen.start_requested.connect(func(track_id: StringName, cc_id: StringName, mode: int, difficulty: StringName) -> void: play_requested.emit(track_id, cc_id, mode, difficulty))
	_preparation_screen.back_requested.connect(func() -> void: _router.back())
	_preparation_screen.change_vehicle_requested.connect(_show_play_vehicle)
	_preparation_screen.change_configuration_requested.connect(_show_track_selector)
	_local_lobby = LocalMultiplayerLobby.new()
	_local_lobby.visible = false
	root.add_child(_local_lobby)
	_local_lobby.configure(progression_catalog, player_progress)
	_local_lobby.participants_confirmed.connect(_handle_local_participants_confirmed)
	_local_lobby.back_requested.connect(func() -> void: _router.back())
	_local_lobby.vehicle_pick_requested.connect(
		func(slot: int, current_variant_id: StringName) -> void: _open_vehicle_picker("local", slot, current_variant_id)
	)
	_lan_lobby = LanMultiplayerLobby.new()
	_lan_lobby.name = "LanLobby"
	_lan_lobby.visible = false
	root.add_child(_lan_lobby)
	_lan_lobby.configure(progression_catalog, track_catalog, player_progress)
	_lan_lobby.race_requested.connect(func(value_session: LanSession, value_payload: Dictionary) -> void: lan_race_requested.emit(value_session, value_payload))
	_lan_lobby.back_requested.connect(func() -> void: _router.back())
	_lan_lobby.vehicle_pick_requested.connect(
		func(current_variant_id: StringName) -> void: _open_vehicle_picker("lan", -1, current_variant_id)
	)

	_settings_panel = SettingsScreen.new()
	root.add_child(_settings_panel)
	_settings_panel.graphics_profile_changed.connect(func(value: String) -> void: _set_graphics_profile(value))
	_settings_panel.vibration_changed.connect(func(value: bool) -> void: vibration_changed.emit(value))
	_settings_panel.volume_changed.connect(func(value: float) -> void: volume_changed.emit(value))
	_settings_panel.music_volume_changed.connect(func(value: float) -> void: music_volume_changed.emit(value))
	_settings_panel.effects_volume_changed.connect(func(value: float) -> void: effects_volume_changed.emit(value))
	_settings_panel.camera_motion_changed.connect(func(value: String) -> void: camera_motion_changed.emit(value))
	_settings_panel.speed_lines_changed.connect(func(value: bool) -> void: speed_lines_changed.emit(value))
	_settings_panel.threat_indicators_changed.connect(func(value: bool) -> void: threat_indicators_changed.emit(value))
	_settings_panel.vibration_intensity_changed.connect(func(value: float) -> void: vibration_intensity_changed.emit(value))
	_settings_panel.reduced_motion_changed.connect(func(value: bool) -> void: reduced_motion_changed.emit(value))
	_settings_panel.gamepad_family_changed.connect(func(value: StringName) -> void: gamepad_family_changed.emit(value))
	_settings_panel.ghost_enabled_changed.connect(func(value: bool) -> void: ghost_enabled_changed.emit(value))
	_settings_panel.restore_defaults_requested.connect(_confirm_restore_defaults)
	_settings_panel.controls_requested.connect(func() -> void: _router.navigate(MenuRoute.Id.CONTROLS))
	_settings_panel.back_requested.connect(func() -> void: _router.back())
	_controls_panel = ControlsScreen.new()
	_controls_panel.visible = false
	root.add_child(_controls_panel)
	_controls_panel.back_requested.connect(func() -> void: _router.back())
	_title_screen = _build_title_screen()
	root.add_child(_title_screen)
	_router.register_screen(MenuRoute.Id.TITLE, _title_screen)
	_router.register_screen(MenuRoute.Id.PLAY_MODE, _mode_screen)
	_router.register_screen(MenuRoute.Id.PLAY_TRACK, _track_selector)
	_router.register_screen(MenuRoute.Id.PLAY_CUP, _cup_selector)
	_router.register_screen(MenuRoute.Id.PLAY_VEHICLE, _vehicle_gallery)
	_router.register_screen(MenuRoute.Id.PLAY_READY, _preparation_screen)
	_router.register_screen(MenuRoute.Id.PLAY_LOCAL_LOBBY, _local_lobby)
	_router.register_screen(MenuRoute.Id.PLAY_LAN_LOBBY, _lan_lobby)
	_router.register_screen(MenuRoute.Id.GARAGE, _garage_panel)
	_router.register_screen(MenuRoute.Id.PROFILE, _profile_panel)
	_router.register_screen(MenuRoute.Id.SETTINGS, _settings_panel)
	_router.register_screen(MenuRoute.Id.CONTROLS, _controls_panel)
	_select_track(_selected_track_id, false)
	_router.set_fallback_focus(MenuRoute.Id.MAIN, _play_button, _main_actions)
	_play_button.grab_focus.call_deferred()
	_update_landing_context()


func _build_title_screen() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "TitleScreen"
	overlay.color = UiTokens.GRAPHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-320, -150)
	center.size = Vector2(640, 300)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(center)
	center.add_child(_wordmark(520.0, 120.0))
	var enter := _create_button("PRESIONA PARA EMPEZAR", UiTokens.ELECTRIC_YELLOW, Vector2(360, 64))
	enter.pressed.connect(_request_title_dismiss)
	center.add_child(enter)
	var prompt := ActionPromptView.new()
	prompt.action = &"ui_accept"
	prompt.caption = "CONFIRMAR"
	center.add_child(prompt)
	# Input is handled by the full-screen title, not by focus alone.
	enter.focus_mode = Control.FOCUS_NONE
	return overlay


func _wordmark(width: float, height: float) -> Control:
	return UiTokens.wordmark(width, height, 76)


func _input(event: InputEvent) -> void:
	if _title_screen == null or not _title_screen.visible or _title_dismissing:
		return
	var pointer_pressed: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	) or (event is InputEventScreenTouch and event.pressed)
	if pointer_pressed or event.is_action_pressed(&"ui_accept") or (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
			or event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	):
		_request_title_dismiss()
		get_viewport().set_input_as_handled()


func _request_title_dismiss() -> void:
	if _title_dismissing or _title_screen == null or not _title_screen.visible:
		return
	_title_dismissing = true
	_dismiss_title.call_deferred()


func _dismiss_title() -> void:
	# Keep the title above the menu until the initiating key/button is released;
	# otherwise that release can activate the newly focused Play button.
	await get_tree().process_frame
	while Input.is_action_pressed(&"ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_title_screen):
		return
	_title_screen.hide()
	_title_dismissing = false
	_router.replace(MenuRoute.Id.MAIN)
	_play_button.grab_focus.call_deferred()


func _select_track(track_id: StringName, should_emit: bool = true) -> void:
	if _track_selector == null:
		return
	_track_selector.select_track(track_id, should_emit)
	_selected_track_id = _track_selector.get_selected_track_id()


func _update_best_time_label() -> void:
	if _track_selector != null:
		_track_selector.update_best_times(_best_times)


func set_ghost_available(available: bool) -> void:
	if _track_selector != null:
		_track_selector.set_ghost_available(available)


func _select_cc(cc_id: StringName, should_emit: bool = true) -> void:
	if _track_selector == null:
		return
	_track_selector.select_cc(cc_id, should_emit)
	_selected_cc_id = _track_selector.get_selected_cc_id()


func _show_track_selector(value: Dictionary = {}) -> void:
	if value.is_empty():
		value = _active_play_payload.duplicate(true)
	value["mode"] = int(value.get("mode", _selected_game_mode))
	value["track_id"] = StringName(value.get("track_id", _selected_track_id))
	value["cc_id"] = StringName(value.get("cc_id", _selected_cc_id))
	value["difficulty_id"] = StringName(value.get("difficulty_id", &"competitive"))
	_active_play_payload = value.duplicate(true)
	_router.navigate(MenuRoute.Id.PLAY_TRACK, value)
	_track_selector.update_best_times(_best_times)
	_track_selector.select_track(StringName(value.get("track_id", _selected_track_id)), false)
	_track_selector.select_cc(StringName(value.get("cc_id", _selected_cc_id)), false)
	_track_selector.select_game_mode(int(value.get("mode", _selected_game_mode)), false)
	_track_selector.set_context_payload(value)
	_track_selector.configure_event_options(
		bool(value.get("items_enabled", true)),
		bool(value.get("ghost_enabled", true))
	)
	_track_selector.set_step_indicator(1, _step_total_for_mode(int(value.get("mode", _selected_game_mode))))
	_track_selector.show_screen()


func _step_total_for_mode(mode: int) -> int:
	# Local multiplayer picks vehicles in the lobby itself, so it never visits
	# PLAY_VEHICLE through this shared flow — same step count as Cup.
	if mode == GameModeDefinition.CUP or mode == GameModeDefinition.LOCAL_MULTIPLAYER:
		return 2
	return 3

func _show_mode_selector() -> void:
	_router.navigate(MenuRoute.Id.PLAY_MODE, {"mode": _selected_game_mode})
	_mode_screen.focus_last()

func _open_active_cup_flow() -> void:
	var active := player_progress.active_cup if player_progress != null else {}
	if active.is_empty():
		return
	var value := {"source": "play", "mode": GameModeDefinition.CUP, "track_id": &"", "cup_id": StringName(active.get("cup_id", &"")), "variant_id": StringName(active.get("variant_id", player_progress.equipped_kart_variant_id)), "cc_id": StringName(active.get("cc_id", &"150")), "difficulty_id": StringName(active.get("difficulty_id", &"competitive")), "ghost_enabled": false, "continue_active": true}
	_show_play_vehicle(value)

func _handle_mode_card_selected(mode: int) -> void:
	_select_game_mode(mode, true)
	if mode == GameModeDefinition.CUP:
		var cup_payload := {"source": "play", "mode": mode, "track_id": &"", "cup_id": &"", "variant_id": player_progress.equipped_kart_variant_id if player_progress else &"", "cc_id": _selected_cc_id, "difficulty_id": &"competitive", "ghost_enabled": false, "continue_active": false}
		_cup_selector.configure(progression_catalog, player_progress, cup_payload)
		_router.navigate(MenuRoute.Id.PLAY_CUP, cup_payload)
	elif mode == GameModeDefinition.LOCAL_MULTIPLAYER:
		_pending_multiplayer_participants.clear()
		_active_play_payload = {"source": "play", "mode": mode, "track_id": _selected_track_id, "cup_id": &"", "variant_id": player_progress.equipped_kart_variant_id if player_progress else &"", "cc_id": _selected_cc_id, "difficulty_id": &"competitive", "items_enabled": true, "continue_active": false, "player_summary": "2 JUGADORES"}
		_local_lobby.configure(progression_catalog, player_progress)
		_router.navigate(MenuRoute.Id.PLAY_LOCAL_LOBBY, {"mode": mode})
	elif mode == GameModeDefinition.LAN_MULTIPLAYER:
		_active_play_payload = {"source": "play", "mode": mode, "track_id": _selected_track_id, "cup_id": &"", "variant_id": player_progress.equipped_kart_variant_id if player_progress else &"", "cc_id": _selected_cc_id, "difficulty_id": &"competitive", "items_enabled": true, "continue_active": false, "player_summary": "RED LOCAL"}
		_lan_lobby.configure(progression_catalog, track_catalog, player_progress)
		_router.navigate(MenuRoute.Id.PLAY_LAN_LOBBY, {"mode": mode})
	else:
		var config_payload := {"source": "play", "mode": mode, "track_id": _selected_track_id, "cup_id": &"", "variant_id": player_progress.equipped_kart_variant_id if player_progress else &"", "cc_id": _selected_cc_id, "difficulty_id": &"competitive", "items_enabled": true, "ghost_enabled": true, "ghost_available": _ghost_available(), "continue_active": false}
		_show_track_selector(config_payload)


func _ghost_available() -> bool:
	return _track_selector != null and _track_selector.has_method("is_ghost_available") and _track_selector.is_ghost_available()


func _handle_local_participants_confirmed(values: Array) -> void:
	_pending_multiplayer_participants.clear()
	for value in values:
		if value is RaceParticipantConfig:
			_pending_multiplayer_participants.append(value)
	_show_track_selector()


func get_multiplayer_participants() -> Array[RaceParticipantConfig]:
	return _pending_multiplayer_participants.duplicate()


func detach_lan_session() -> LanSession:
	return _lan_lobby.detach_session() if _lan_lobby != null else null


func show_notice(message: String) -> void:
	var toast := Toast.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-280, 28)
	toast.size = Vector2(560, 64)
	add_child(toast)
	toast.show_message(message, 5.0)


func restore_main_route() -> void:
	_router.clear_history()
	_router.replace(MenuRoute.Id.MAIN)
	_play_button.grab_focus.call_deferred()

func _show_play_vehicle(value: Dictionary) -> void:
	_vehicle_gallery.configure(progression_catalog, player_progress, value)
	var mode := int(value.get("mode", _selected_game_mode))
	var total := _step_total_for_mode(mode)
	_vehicle_gallery.set_step_indicator(total - 1, total)
	_router.navigate(MenuRoute.Id.PLAY_VEHICLE, value)

func _open_standalone_garage() -> void:
	_vehicle_gallery.configure(progression_catalog, player_progress, {"source": "standalone", "variant_id": _vehicle_gallery.last_inspected_variant_id})
	_vehicle_gallery.set_step_indicator(0, 0)
	_router.navigate(MenuRoute.Id.GARAGE, _vehicle_gallery.payload)

func _handle_route_changed(route: int, _payload: Dictionary) -> void:
	# MAIN is a persistent layer rather than a routed screen. Disable its
	# buttons whenever another screen is over it so controller navigation can
	# never reach controls that are not currently visible.
	_set_main_menu_focus_enabled(route == MenuRoute.Id.MAIN)
	# The menu showroom is not part of routed overlays. Hide it explicitly so
	# only the shared gallery showroom renders on vehicle-selection routes.
	if _landing != null:
		_landing.set_route_visible(route == MenuRoute.Id.MAIN)


func _set_main_menu_focus_enabled(enabled: bool) -> void:
	if _main_actions == null:
		return
	for node in _main_actions.find_children("*", "Control", true, false):
		var control := node as Control
		if control is Button:
			control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _handle_vehicle_action(value: Dictionary) -> void:
	var variant_id := StringName(value.get("variant_id", &""))
	var source := str(value.get("source", "standalone"))
	if source == "lobby_pick":
		# Picking a vehicle for a lobby slot must never change the account's
		# globally-equipped kart, unlike the standalone/play flows below.
		match str(_pending_vehicle_pick.get("target", "")):
			"local": _local_lobby.apply_picked_vehicle(int(_pending_vehicle_pick.get("slot", 0)), variant_id)
			"lan": _lan_lobby.apply_picked_vehicle(variant_id)
		_pending_vehicle_pick = {}
		_router.back()
		return
	if source == "standalone":
		equip_variant_requested.emit(variant_id)
		_vehicle_gallery.configure(progression_catalog, player_progress, value)
		return
	equip_variant_requested.emit(variant_id)
	_show_preparation_payload(value)


func _open_vehicle_picker(target: String, slot: int, current_variant_id: StringName) -> void:
	_pending_vehicle_pick = {"target": target, "slot": slot}
	_vehicle_gallery.configure(progression_catalog, player_progress, {"source": "lobby_pick", "variant_id": current_variant_id})
	_vehicle_gallery.set_step_indicator(0, 0)
	_router.navigate(MenuRoute.Id.PLAY_VEHICLE, _vehicle_gallery.payload)

func _show_preparation_payload(value: Dictionary) -> void:
	var payload := value.duplicate(true)
	var cup := progression_catalog.cups.get_cup(StringName(payload.get("cup_id", &""))) if progression_catalog != null else null
	var track_id := StringName(payload.get("track_id", &""))
	if cup != null:
		var race_index := int(player_progress.active_cup.get("current_race_index", 0)) if bool(payload.get("continue_active", false)) else 0
		if race_index >= 0 and race_index < cup.tracks.size(): track_id = cup.tracks[race_index].id
		payload["track_id"] = track_id
	var total := _step_total_for_mode(int(payload.get("mode", _selected_game_mode)))
	_preparation_screen.set_step_indicator(total, total)
	_preparation_screen.configure(payload, track_catalog.get_track(track_id) if track_catalog else null, progression_catalog.unlocks.get_variant(StringName(payload.get("variant_id", &""))) if progression_catalog else null, cup)
	_router.navigate(MenuRoute.Id.PLAY_READY, payload)

func _confirm_cup_abandon(value: Dictionary) -> void:
	var modal := ConfirmationModal.new(); modal.set_anchors_preset(Control.PRESET_CENTER); modal.position = Vector2(-220, -120); modal.size = Vector2(440, 240); modal.configure("ABANDONAR COPA", "El progreso de la copa activa se perderá. ¿Quieres iniciar otra?"); add_child(modal)
	modal.confirmed.connect(func() -> void:
		abandon_cup_requested.emit()
		player_progress.active_cup = {}
		player_progress.save_to_disk()
		modal.queue_free()
		var next := value.duplicate(true)
		next["continue_active"] = false
		_show_play_vehicle(next)
	)
	modal.cancelled.connect(modal.queue_free)

func _show_preparation(track_id: StringName, cc_id: StringName, mode: int, difficulty_id: StringName) -> void:
	_show_preparation_payload({"source": "play", "track_id": track_id, "cc_id": cc_id, "mode": mode, "difficulty_id": difficulty_id, "variant_id": player_progress.equipped_kart_variant_id if player_progress else &""})

func _back_to_main() -> void:
	_router.back()
	_play_button.grab_focus.call_deferred()


func _hide_track_selector() -> void:
	_track_selector.visible = false
	_router.back()
	_play_button.grab_focus.call_deferred()


func _handle_track_selected(track_id: StringName) -> void:
	_selected_track_id = track_id
	_update_landing_context()
	track_selected.emit(track_id)


func _handle_race_class_selected(cc_id: StringName) -> void:
	_selected_cc_id = cc_id
	_update_landing_context()
	race_class_selected.emit(cc_id)


func _handle_game_mode_selected(game_mode: int) -> void:
	_selected_game_mode = game_mode
	_update_landing_context()
	game_mode_selected.emit(game_mode)

func _get_equipped_variant() -> KartVariantDefinition:
	if progression_catalog == null or player_progress == null:
		return null
	var equipped := progression_catalog.unlocks.get_variant(player_progress.equipped_kart_variant_id)
	if equipped != null:
		return equipped
	return progression_catalog.unlocks.initial_variant


func _update_landing_context() -> void:
	if _landing == null:
		return
	var variant := _get_equipped_variant()
	var track := track_catalog.get_track(_selected_track_id) if track_catalog != null else null
	var variant_name := variant.display_name.to_upper() if variant != null else "VEHÍCULO BASE"
	var track_name := track.display_name.to_upper() if track != null else "COSTA TURBO"
	var race_class := RaceClassDefinition.get_by_id(_selected_cc_id)
	var detail := "%s · %s" % [_game_mode_label(_selected_game_mode), race_class.display_name]
	var title := "%s · %s" % [variant_name, track_name]
	var badge := "CONFIGURACIÓN ACTUAL"
	if has_active_cup:
		badge = "COPA ACTIVA · CONTINUAR"
		var active_cup := player_progress.active_cup if player_progress != null else {}
		var cup_id := StringName(active_cup.get("cup_id", &""))
		var cup := progression_catalog.cups.get_cup(cup_id) if progression_catalog != null and progression_catalog.cups != null else null
		if cup != null:
			title = "COPA · %s" % cup.display_name.to_upper()
			detail = "%s · %s · %s" % [variant_name, track_name, race_class.display_name]
	_landing.set_context(title, detail, badge)


func _game_mode_label(game_mode: int) -> String:
	match game_mode:
		GameModeDefinition.TIME_TRIAL: return "CONTRARRELOJ"
		GameModeDefinition.CUP: return "COPA"
		GameModeDefinition.LOCAL_MULTIPLAYER: return "MULTIJUGADOR LOCAL"
		GameModeDefinition.LAN_MULTIPLAYER: return "RED LOCAL"
		_: return "CARRERA"


func _select_game_mode(game_mode: int, should_emit := true) -> void:
	if _track_selector != null:
		_track_selector.select_game_mode(game_mode, should_emit)
		_selected_game_mode = _track_selector.get_selected_game_mode()


func _confirm_restore_defaults() -> void:
	restore_defaults_requested.emit()
	graphics_profile = "medium"
	_refresh_quality_buttons()
	_apply_graphics_profile_to_showrooms()
	var current := GameSettings.new()
	current.graphics_profile = "medium"
	current.vibration_enabled = true
	current.master_volume = 0.8
	current.music_volume = 1.0
	current.effects_volume = 1.0
	current.camera_motion = "reduced"
	current.speed_lines_enabled = true
	current.threat_indicators_enabled = true
	current.vibration_intensity = 1.0
	(_settings_panel as SettingsScreen).apply_snapshot(current)

func _toggle_settings() -> void:
	if _router.current_route != MenuRoute.Id.SETTINGS:
		_router.navigate(MenuRoute.Id.SETTINGS)
		(_settings_panel as SettingsScreen).focus_first_control.call_deferred()
	else:
		_router.back()
		_play_button.grab_focus()

func refresh_equipped_variant() -> void:
	if _showroom != null:
		_showroom.show_variant(_get_equipped_variant())
	if _garage_showroom != null:
		_garage_showroom.show_variant(_get_equipped_variant())
	if _vehicle_gallery != null and _vehicle_gallery.visible:
		_vehicle_gallery.configure(progression_catalog, player_progress, _vehicle_gallery.payload)
	_update_landing_context()

func _bind_ui_feedback() -> void:
	for candidate in find_children("*", "Button", true, false):
		var button := candidate as Button
		button.focus_entered.connect(_ui_sound.play_ui_navigate)
		button.pressed.connect(_ui_sound.play_ui_confirm)


func _set_graphics_profile(profile: String) -> void:
	graphics_profile = PresentationQuality.sanitize(profile)
	_refresh_quality_buttons()
	_apply_graphics_profile_to_showrooms()
	graphics_profile_changed.emit(graphics_profile)


func _apply_graphics_profile_to_showrooms() -> void:
	for showroom in [_showroom, _garage_showroom]:
		if showroom != null:
			showroom.set_quality(graphics_profile)
	if _vehicle_gallery != null and _vehicle_gallery.showroom != null:
		_vehicle_gallery.showroom.set_quality(graphics_profile)
	if _preparation_screen != null:
		_preparation_screen.set_graphics_profile(graphics_profile)

func _refresh_quality_buttons() -> void:
	for profile_id in _quality_buttons:
		var button := _quality_buttons[profile_id] as Button
		var active := String(profile_id) == graphics_profile
		button.add_theme_stylebox_override("normal", _style(UiTokens.ELECTRIC_YELLOW if active else UiTokens.INK_RAISED, 18))
		button.add_theme_color_override("font_color", UiTokens.GRAPHITE if active else UiTokens.TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", UiTokens.GRAPHITE)


func _create_button(text: String, color: Color, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", UiTokens.GRAPHITE)
	button.add_theme_color_override("font_focus_color", UiTokens.GRAPHITE)
	button.add_theme_stylebox_override("normal", _style(color, 18))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.1), 18))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.14), 18))
	button.add_theme_stylebox_override("focus", _style(UiTokens.WARM_WHITE, 18, 4))
	button.add_theme_stylebox_override("disabled", _style(UiTokens.BUTTON_DISABLED_BG, 18))
	return button


func _style(color: Color, radius: int, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = UiTokens.WARM_WHITE
	return style
