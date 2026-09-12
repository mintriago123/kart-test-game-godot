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
var _first_settings_button: Button
var _profile_value: Label
var _vibration_toggle: CheckButton
var _volume_slider: HSlider
var _music_volume_slider: HSlider
var _effects_volume_slider: HSlider
var _camera_motion_selector: OptionButton
var _speed_lines_toggle: CheckButton
var _threat_toggle: CheckButton
var _vibration_intensity_slider: HSlider
var _ghost_toggle: CheckButton
var _percentage_labels: Dictionary = {}
var _track_buttons: Dictionary = {}
var _best_times: Dictionary = {}
var _selected_track_id: StringName = &"coastal"
var _selected_cc_id: StringName = RaceClassDefinition.DEFAULT_ID
var _selected_game_mode := GameModeDefinition.RACE
var _track_selector: TrackSelectScreen
var has_active_cup := false
var progression_catalog: ProgressionCatalog
var player_progress: PlayerProgress
var _device_coordinator: InputDeviceCoordinator
var _router: MenuRouter
var _title_screen: Control
var _title_dismissing := false
var _showroom: VehicleViewport
var _mode_screen: ModeSelectScreen
var _configuration_screen: RaceConfigurationScreen
var _preparation_screen: PreparationScreen
var _garage_panel: Control
var _vehicle_gallery: VehicleGalleryScreen
var _cup_selector: CupSelectScreen
var _profile_panel: Control
var _profile_card: VBoxContainer
var _profile_main_grid: GridContainer
var _profile_cup_list: VBoxContainer
var _profile_filter_buttons: Dictionary = {}
var _profile_cup_filter := &"all"
var _profile_content_host: VBoxContainer
var _profile_sidebar: PanelContainer
var _profile_nav_buttons: Dictionary = {}
var _profile_mobile_nav: HBoxContainer
var _profile_active_section := &"summary"
var _controls_panel: ControlsScreen
var _reduced_motion_toggle: CheckButton
var _quality_buttons: Dictionary = {}
var _ui_sound: SoundManager
var _garage_showroom: VehicleViewport
var _local_lobby: LocalMultiplayerLobby
var _pending_multiplayer_participants: Array[RaceParticipantConfig] = []
var _lan_lobby: LanMultiplayerLobby
var _active_play_payload: Dictionary = {}
var _landing: MainMenuLanding


func _ready() -> void:
	layer = 30
	_device_coordinator = InputDeviceCoordinator.new()
	add_child(_device_coordinator)
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
	_select_track(selected_track_id, false)
	_select_cc(selected_cc_id, false)
	_select_game_mode(selected_game_mode, false)
	if _profile_value != null:
		_profile_value.text = "ACTUAL: " + graphics_profile.to_upper()
	if _vibration_toggle != null:
		_vibration_toggle.set_pressed_no_signal(vibration)
	if _volume_slider != null:
		_volume_slider.set_value_no_signal(volume)
	if _music_volume_slider != null:
		_music_volume_slider.set_value_no_signal(music_volume)
	if _effects_volume_slider != null:
		_effects_volume_slider.set_value_no_signal(effects_volume)
	if _camera_motion_selector != null:
		_camera_motion_selector.select(["reduced", "full", "off"].find(camera_motion))
	if _speed_lines_toggle != null:
		_speed_lines_toggle.set_pressed_no_signal(speed_lines)
	if _threat_toggle != null:
		_threat_toggle.set_pressed_no_signal(threat_indicators)
	if _vibration_intensity_slider != null:
		_vibration_intensity_slider.set_value_no_signal(vibration_intensity)
	if _ghost_toggle != null:
		_ghost_toggle.set_pressed_no_signal(ghost_enabled)
	if _device_coordinator != null:
		_device_coordinator.set_manual_family(gamepad_family)
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
	if _device_coordinator == null or _device_coordinator.mode != &"gamepad":
		return -1
	return _device_coordinator.device_id


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
	_profile_panel = _build_profile_panel()
	root.add_child(_profile_panel)
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
		func(track_id: StringName, cc_id: StringName, game_mode: int, difficulty_id: StringName) -> void:
			_selected_game_mode = game_mode
			var value := _active_play_payload.duplicate(true)
			value["track_id"] = track_id
			value["cc_id"] = cc_id
			value["mode"] = game_mode
			value["difficulty_id"] = difficulty_id
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
	_configuration_screen = RaceConfigurationScreen.new()
	_configuration_screen.visible = false
	root.add_child(_configuration_screen)
	_configuration_screen.configuration_confirmed.connect(_handle_configuration_confirmed)
	_configuration_screen.back_requested.connect(func() -> void: _router.back())
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
	_local_lobby = LocalMultiplayerLobby.new()
	_local_lobby.visible = false
	root.add_child(_local_lobby)
	_local_lobby.configure(progression_catalog, player_progress)
	_local_lobby.participants_confirmed.connect(_handle_local_participants_confirmed)
	_local_lobby.back_requested.connect(func() -> void: _router.back())
	_lan_lobby = LanMultiplayerLobby.new()
	_lan_lobby.name = "LanLobby"
	_lan_lobby.visible = false
	root.add_child(_lan_lobby)
	_lan_lobby.configure(progression_catalog, track_catalog, player_progress)
	_lan_lobby.race_requested.connect(func(value_session: LanSession, value_payload: Dictionary) -> void: lan_race_requested.emit(value_session, value_payload))
	_lan_lobby.back_requested.connect(func() -> void: _router.back())

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
	_router.register_screen(MenuRoute.Id.PLAY_CONFIG, _configuration_screen)
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


func _build_profile_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.color = UiTokens.SCRIM
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.add_theme_constant_override("margin_left", 24); margin.add_theme_constant_override("margin_top", 20); margin.add_theme_constant_override("margin_right", 24); margin.add_theme_constant_override("margin_bottom", 20); overlay.add_child(margin)
	var shell := HBoxContainer.new(); shell.name = "ProfileShell"; shell.add_theme_constant_override("separation", UiTokens.SPACE_4); margin.add_child(shell)
	var sidebar := PanelContainer.new(); _profile_sidebar = sidebar; sidebar.name = "ProfileNavigation"; sidebar.custom_minimum_size.x = 210; sidebar.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_LARGE)); shell.add_child(sidebar)
	var nav := VBoxContainer.new(); nav.add_theme_constant_override("separation", UiTokens.SPACE_2); sidebar.add_child(nav)
	var eyebrow := _profile_value_label("PILOTO", UiTokens.CYAN, UiTokens.FONT_CAPTION); nav.add_child(eyebrow)
	var nav_title := _profile_value_label("PASAPORTE\nCOMPETICIÓN", UiTokens.WARM_WHITE, UiTokens.FONT_H3); nav.add_child(nav_title)
	for section_data in [["RESUMEN", &"summary"], ["COPAS", &"cups"], ["RÉCORDS", &"records"], ["MULTIJUGADOR", &"multiplayer"], ["COLECCIÓN", &"collection"]]:
		var nav_button := _create_button(section_data[0], UiTokens.INK_RAISED, Vector2(0, UiTokens.TOUCH_TARGET)); nav_button.name = "ProfileNav_%s" % section_data[1]; nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT; nav_button.pressed.connect(_show_profile_section.bind(section_data[1])); nav.add_child(nav_button); _profile_nav_buttons[section_data[1]] = nav_button
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; nav.add_child(spacer)
	var close := _create_button("VOLVER", UiTokens.CORAL, Vector2(0, UiTokens.BUTTON_HEIGHT)); close.pressed.connect(func() -> void: _router.back()); nav.add_child(close)
	_profile_mobile_nav = HBoxContainer.new(); _profile_mobile_nav.add_theme_constant_override("separation", UiTokens.SPACE_2); _profile_mobile_nav.visible = false; nav.add_child(_profile_mobile_nav)

	var content_panel := PanelContainer.new(); content_panel.name = "ProfileContent"; content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content_panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_LARGE)); shell.add_child(content_panel)
	var content_scroll := ScrollContainer.new(); content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; content_panel.add_child(content_scroll)
	_profile_content_host = VBoxContainer.new(); _profile_content_host.name = "ProfileContentHost"; _profile_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _profile_content_host.add_theme_constant_override("separation", UiTokens.SPACE_4); content_scroll.add_child(_profile_content_host)
	overlay.resized.connect(_update_profile_layout)
	_update_profile_layout()
	_show_profile_section(_profile_active_section)
	return overlay


func _profile_section(title: String) -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size.y = 116; panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_MEDIUM))
	var section := VBoxContainer.new(); section.add_theme_constant_override("separation", UiTokens.SPACE_2); panel.add_child(section)
	var heading := Label.new(); heading.text = title; heading.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION); heading.add_theme_color_override("font_color", UiTokens.MUTED); section.add_child(heading)
	return panel


func _profile_section_content(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0) as VBoxContainer


func _show_profile_section(section_id: StringName) -> void:
	if _profile_content_host == null: return
	_profile_active_section = section_id
	for child in _profile_content_host.get_children(): child.queue_free()
	for id in _profile_nav_buttons:
		var button := _profile_nav_buttons[id] as Button
		var active: bool = id == section_id
		button.add_theme_stylebox_override("normal", _style(UiTokens.ELECTRIC_YELLOW if active else UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL))
		button.add_theme_color_override("font_color", UiTokens.GRAPHITE if active else UiTokens.TEXT_PRIMARY)
	var heading := _profile_value_label(_profile_section_title(section_id), UiTokens.WARM_WHITE, UiTokens.FONT_H1)
	heading.name = "ProfileSectionTitle"; _profile_content_host.add_child(heading)
	var intro := _profile_value_label(_profile_section_intro(section_id), UiTokens.TEXT_TERTIARY, UiTokens.FONT_BODY); _profile_content_host.add_child(intro)
	match section_id:
		&"summary": _build_profile_summary()
		&"cups": _build_profile_cups()
		&"records": _build_profile_records()
		&"multiplayer": _build_profile_multiplayer()
		&"collection": _build_profile_collection()
	_profile_nav_buttons[section_id].grab_focus.call_deferred()


func _profile_section_title(section_id: StringName) -> String:
	return {&"summary": "RESUMEN", &"cups": "PALMARÉS", &"records": "RÉCORDS DE PISTA", &"multiplayer": "MULTIJUGADOR", &"collection": "COLECCIÓN"}.get(section_id, "PERFIL")


func _profile_section_intro(section_id: StringName) -> String:
	return {&"summary": "Tu rendimiento en una sola mirada.", &"cups": "Medallas conseguidas por dificultad.", &"records": "Las marcas que definen tu vuelta más rápida.", &"multiplayer": "Resultados separados por tipo de partida.", &"collection": "Tus vehículos, recompensas y progreso de garaje."}.get(section_id, "")


func _build_profile_summary() -> void:
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", UiTokens.SPACE_3); grid.add_theme_constant_override("v_separation", UiTokens.SPACE_3); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _profile_content_host.add_child(grid)
	_profile_add_metric(grid, str(player_progress.victories if player_progress else 0), "VICTORIAS", UiTokens.ELECTRIC_YELLOW)
	_profile_add_metric(grid, str(player_progress.podiums if player_progress else 0), "PODIOS", UiTokens.CYAN)
	_profile_add_metric(grid, str(player_progress.races_played if player_progress else 0), "CARRERAS", UiTokens.WARM_WHITE)
	_profile_add_metric(grid, str(player_progress.best_finish_position if player_progress and player_progress.best_finish_position > 0 else "—"), "MEJOR POSICIÓN", UiTokens.SUCCESS)
	var career_points := player_progress.get_career_points(progression_catalog) if player_progress != null and progression_catalog != null else 0
	var career_max := player_progress.get_max_career_points(progression_catalog) if player_progress != null and progression_catalog != null else 0
	var next_reward: UnlockDefinition = player_progress.get_next_career_reward(progression_catalog) if player_progress != null and progression_catalog != null else null
	var progression := _profile_section("PROGRESIÓN"); var progression_content := _profile_section_content(progression); _profile_content_host.add_child(progression)
	progression_content.add_child(_profile_value_label("%d / %d PUNTOS DE CARRERA\n%s" % [career_points, career_max, "%d PTOS · %s" % [next_reward.required_points, next_reward.display_name.to_upper()] if next_reward != null else "TODOS LOS HITOS CONSEGUIDOS"], UiTokens.ELECTRIC_YELLOW, UiTokens.FONT_LABEL))
	var bar := ProgressBar.new(); bar.max_value = maxf(1.0, career_max); bar.value = career_points; bar.show_percentage = false; bar.custom_minimum_size.y = UiTokens.SPACE_3; bar.add_theme_stylebox_override("background", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_SMALL)); bar.add_theme_stylebox_override("fill", UiTokens.panel(UiTokens.ELECTRIC_YELLOW, UiTokens.RADIUS_SMALL)); progression_content.add_child(bar)


func _build_profile_cups() -> void:
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation", UiTokens.SPACE_2); _profile_content_host.add_child(header)
	var label := _profile_value_label("FILTRAR POR MEDALLA", UiTokens.MUTED, UiTokens.FONT_CAPTION); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(label)
	_profile_filter_buttons.clear()
	for filter_data in [["TODAS", &"all"], ["BRONCE", &"bronze"], ["PLATA", &"silver"], ["ORO", &"gold"]]:
		var filter := _create_button(filter_data[0], UiTokens.INK_RAISED, Vector2(88, UiTokens.TOUCH_TARGET)); filter.name = "CupFilter_%s" % filter_data[1]; filter.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION); filter.pressed.connect(_set_profile_cup_filter.bind(filter_data[1])); header.add_child(filter); _profile_filter_buttons[filter_data[1]] = filter
	_profile_cup_list = VBoxContainer.new(); _profile_cup_list.add_theme_constant_override("separation", UiTokens.SPACE_2); _profile_content_host.add_child(_profile_cup_list); _refresh_profile_cups()


func _build_profile_records() -> void:
	var panel := _profile_section("RÉCORDS GLOBALES"); var content := _profile_section_content(panel); _profile_content_host.add_child(panel)
	var best_time: float = float(_best_times.values().min()) if not _best_times.is_empty() else 0.0
	content.add_child(_profile_value_label("MEJOR TIEMPO   %s\nTIEMPO CONDUCIDO   %s\nATAJOS   %d\nRECUPERACIONES   %d" % [_format_duration(best_time), _format_duration(player_progress.driving_time_seconds if player_progress else 0.0), player_progress.shortcuts_used if player_progress else 0, player_progress.recoveries if player_progress else 0], UiTokens.TEXT_PRIMARY, UiTokens.FONT_LABEL))
	var tracks := _profile_section("MEJORES TIEMPOS POR PISTA"); var track_content := _profile_section_content(tracks); _profile_content_host.add_child(tracks)
	if _best_times.is_empty(): track_content.add_child(_profile_value_label("AÚN NO HAY TIEMPOS REGISTRADOS", UiTokens.TEXT_TERTIARY, UiTokens.FONT_BODY))
	else:
		for track_id in _best_times:
			track_content.add_child(_profile_value_label("%s    %s" % [str(track_id).to_upper(), _format_duration(_best_times[track_id])], UiTokens.TEXT_SECONDARY, UiTokens.FONT_BODY))


func _build_profile_multiplayer() -> void:
	for data in [["LOCAL", player_progress.local_multiplayer if player_progress else MultiplayerStatistics.new()], ["LAN", player_progress.lan_multiplayer if player_progress else MultiplayerStatistics.new()]]:
		var panel := _profile_section(data[0]); var content := _profile_section_content(panel); _profile_content_host.add_child(panel); var stats: MultiplayerStatistics = data[1]
		content.add_child(_profile_value_label("%d CARRERAS\n%d VICTORIAS   ·   %d PODIOS\nMEJOR POSICIÓN   %s" % [stats.races_played, stats.victories, stats.podiums, str(stats.best_finish_position) if stats.best_finish_position > 0 else "—"], UiTokens.CYAN, UiTokens.FONT_LABEL))


func _build_profile_collection() -> void:
	var unlocked := player_progress.get_unlocked_variant_count(progression_catalog.unlocks) if player_progress != null and progression_catalog != null else 0
	var total := progression_catalog.unlocks.variants.size() if progression_catalog != null else 0
	var equipped_name := "—"
	if progression_catalog != null and player_progress != null:
		var equipped := progression_catalog.unlocks.get_variant(player_progress.equipped_kart_variant_id)
		if equipped != null: equipped_name = equipped.display_name
	var panel := _profile_section("ESTADO DEL GARAJE"); var content := _profile_section_content(panel); _profile_content_host.add_child(panel)
	content.add_child(_profile_value_label("COLECCIÓN   %d / %d\nEQUIPADO   %s\nNUEVOS   %d" % [unlocked, total, equipped_name.to_upper(), player_progress.get_new_reward_count() if player_progress else 0], UiTokens.TEXT_PRIMARY, UiTokens.FONT_LABEL))
	var garage := _create_button("ABRIR GARAJE", UiTokens.ELECTRIC_YELLOW, Vector2(240, UiTokens.BUTTON_HEIGHT)); garage.pressed.connect(_open_standalone_garage); garage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; _profile_content_host.add_child(garage)


func _profile_value_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _profile_add_metric(parent: GridContainer, value: String, label_text: String, color: Color) -> void:
	var metric := VBoxContainer.new(); metric.custom_minimum_size.x = 132.0; metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL; metric.add_theme_constant_override("separation", 0)
	var value_label := _profile_value_label(value, color, UiTokens.FONT_DISPLAY); value_label.add_theme_color_override("font_color", color); metric.add_child(value_label)
	var caption := _profile_value_label(label_text, UiTokens.MUTED, UiTokens.FONT_CAPTION); caption.autowrap_mode = TextServer.AUTOWRAP_OFF; caption.clip_text = true; metric.add_child(caption); parent.add_child(metric)


func _set_profile_cup_filter(filter_id: StringName) -> void:
	_profile_cup_filter = filter_id
	_refresh_profile_cups()


func _refresh_profile_cups() -> void:
	if _profile_cup_list == null: return
	for child in _profile_cup_list.get_children(): child.queue_free()
	for filter_id in _profile_filter_buttons:
		var button := _profile_filter_buttons[filter_id] as Button
		var selected: bool = filter_id == _profile_cup_filter
		button.add_theme_stylebox_override("normal", _style(UiTokens.ELECTRIC_YELLOW if selected else UiTokens.INK_RAISED, 12))
		button.add_theme_color_override("font_color", UiTokens.GRAPHITE if selected else UiTokens.TEXT_PRIMARY)
	if progression_catalog == null or progression_catalog.cups == null: return
	var medal_names := ["—", "BRONCE", "PLATA", "ORO"]
	var wanted := -1
	match _profile_cup_filter:
		&"bronze": wanted = UnlockDefinition.BRONZE
		&"silver": wanted = UnlockDefinition.SILVER
		&"gold": wanted = UnlockDefinition.GOLD
	var visible_cups := 0
	for cup in progression_catalog.cups.get_valid_cups():
		var best := player_progress.get_best_cup_medal(cup.id) if player_progress else UnlockDefinition.Medal.NONE
		var difficulty_medals := PackedStringArray()
		var matches_filter := wanted <= 0
		for difficulty in cup.difficulties:
			var medal := player_progress.get_medal(cup.id, difficulty.id) if player_progress else UnlockDefinition.Medal.NONE
			difficulty_medals.append("%s %s" % [difficulty.display_name.to_upper(), medal_names[medal]])
			if medal == wanted: matches_filter = true
		if not matches_filter: continue
		visible_cups += 1
		var cup_card := PanelContainer.new(); cup_card.custom_minimum_size.y = 58; cup_card.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL)); _profile_cup_list.add_child(cup_card)
		var cup_info := Label.new(); cup_info.text = "%s\n%s" % [cup.display_name.to_upper(), "   ".join(difficulty_medals)]; cup_info.add_theme_color_override("font_color", UiTokens.ELECTRIC_YELLOW if best == UnlockDefinition.GOLD else (UiTokens.TEXT_PRIMARY if best > 0 else UiTokens.TEXT_TERTIARY)); cup_card.add_child(cup_info)
	if visible_cups == 0:
		_profile_cup_list.add_child(_profile_value_label("NO HAY MEDALLAS EN ESTE FILTRO", UiTokens.TEXT_TERTIARY, UiTokens.FONT_BODY))


func _update_profile_layout() -> void:
	if _profile_panel == null or _profile_sidebar == null: return
	var compact := _profile_panel.size.x < UiTokens.BREAKPOINT_TWO_PANEL_WIDTH
	_profile_sidebar.custom_minimum_size.x = 168.0 if compact else 210.0
	if _profile_content_host != null:
		_profile_content_host.custom_minimum_size.x = maxf(300.0, _profile_panel.size.x - (260.0 if compact else 300.0))


func _build_garage_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.color = UiTokens.SCRIM
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	_garage_showroom = VehicleViewport.new()
	_garage_showroom.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_garage_showroom.offset_left = -720.0
	_garage_showroom.offset_right = -24.0
	_garage_showroom.offset_top = 60.0
	_garage_showroom.offset_bottom = -60.0
	_garage_showroom.set_framing(VehicleViewport.Framing.GARAGE)
	overlay.add_child(_garage_showroom)
	_garage_showroom.show_variant(_get_equipped_variant())
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	scroll.position = Vector2(32.0, -290.0)
	scroll.size = Vector2(660.0, 580.0)
	overlay.add_child(scroll)
	overlay.resized.connect(func() -> void:
		var compact := overlay.size.x < UiTokens.BREAKPOINT_SHOWROOM_WIDTH
		_garage_showroom.visible = not compact
		scroll.size = Vector2(minf(660.0, overlay.size.x - 32.0), minf(580.0, overlay.size.y - 32.0))
		scroll.position = Vector2((overlay.size.x - scroll.size.x) * 0.5 if compact else 32.0, -scroll.size.y * 0.5)
	)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 620.0
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var title := Label.new()
	title.text = "GARAJE"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	if progression_catalog != null and player_progress != null:
		for variant in progression_catalog.unlocks.variants:
			var unlock := progression_catalog.unlocks.get_unlock_for_variant(variant.id)
			var unlocked := player_progress.can_equip(variant.id, progression_catalog.unlocks)
			var button := _create_button(variant.display_name if unlocked else "%s · %s" % [variant.display_name, unlock.requirement_text(progression_catalog) if unlock != null else "Bloqueado"], UiTokens.SUCCESS if unlocked else UiTokens.TEXT_DISABLED, Vector2(600.0, 52.0))
			button.disabled = false
			button.pressed.connect(func() -> void:
				if unlocked: equip_variant_requested.emit(variant.id)
				else: _ui_sound.play_ui_error()
			)
			button.focus_entered.connect(func() -> void: _garage_showroom.show_variant(variant))
			button.mouse_entered.connect(func() -> void: _garage_showroom.show_variant(variant))
			list.add_child(button)
			if variant != null:
				var stats_row := VBoxContainer.new()
				for stat in [
					["Velocidad", variant.speed, 0.8, 1.2],
					["Aceleración", variant.acceleration, 0.8, 1.2],
					["Manejo", variant.handling, 0.8, 1.2],
					["Peso", variant.weight, 0.8, 1.25],
					["Miniturbo", variant.mini_turbo_duration_multiplier, 0.8, 1.25],
				]:
					var line := HBoxContainer.new()
					stats_row.add_child(line)
					var label := Label.new()
					label.text = str(stat[0])
					label.custom_minimum_size.x = 82.0
					line.add_child(label)
					var bar := ProgressBar.new()
					bar.min_value = float(stat[2])
					bar.max_value = float(stat[3])
					bar.value = float(stat[1])
					bar.show_percentage = false
					bar.custom_minimum_size = Vector2(190.0, 14.0)
					line.add_child(bar)
				list.add_child(stats_row)
	var close := _create_button("VOLVER", UiTokens.CORAL, Vector2(200.0, 58.0))
	close.pressed.connect(func() -> void: _router.back())
	list.add_child(close)
	return overlay


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
	_track_selector.show_screen()

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
		_active_play_payload = config_payload.duplicate(true)
		_configuration_screen.configure(config_payload)
		_router.navigate(MenuRoute.Id.PLAY_CONFIG, config_payload)


func _handle_configuration_confirmed(value: Dictionary) -> void:
	_active_play_payload = value.duplicate(true)
	_show_track_selector(value)


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
	_router.navigate(MenuRoute.Id.PLAY_VEHICLE, value)

func _open_standalone_garage() -> void:
	_vehicle_gallery.configure(progression_catalog, player_progress, {"source": "standalone", "variant_id": _vehicle_gallery.last_inspected_variant_id})
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
	if str(value.get("source", "standalone")) == "standalone":
		equip_variant_requested.emit(variant_id)
		_vehicle_gallery.configure(progression_catalog, player_progress, value)
		return
	equip_variant_requested.emit(variant_id)
	_show_preparation_payload(value)

func _show_preparation_payload(value: Dictionary) -> void:
	var payload := value.duplicate(true)
	var cup := progression_catalog.cups.get_cup(StringName(payload.get("cup_id", &""))) if progression_catalog != null else null
	var track_id := StringName(payload.get("track_id", &""))
	if cup != null:
		var race_index := int(player_progress.active_cup.get("current_race_index", 0)) if bool(payload.get("continue_active", false)) else 0
		if race_index >= 0 and race_index < cup.tracks.size(): track_id = cup.tracks[race_index].id
		payload["track_id"] = track_id
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

func _format_duration(seconds: float) -> String:
	var total := maxi(roundi(seconds), 0)
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _select_game_mode(game_mode: int, should_emit := true) -> void:
	if _track_selector != null:
		_track_selector.select_game_mode(game_mode, should_emit)
		_selected_game_mode = _track_selector.get_selected_game_mode()


func _build_settings_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.color = UiTokens.SCRIM
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	var card_panel := PanelContainer.new()
	card_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card_panel.anchor_bottom = 1.0
	card_panel.offset_top = 24.0
	card_panel.offset_bottom = -24.0
	card_panel.add_theme_stylebox_override("panel", _style(UiTokens.INK, 24))
	overlay.add_child(card_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size.x = 0.0
	scroll.add_child(content)

	var title := Label.new()
	title.text = "AJUSTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	content.add_child(title)

	var sections := TabContainer.new()
	sections.custom_minimum_size = Vector2(0.0, 420.0)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_stylebox_override("panel", _style(UiTokens.GRAPHITE, UiTokens.RADIUS_MEDIUM))
	sections.add_theme_stylebox_override("tab_unselected", _style(UiTokens.GRAPHITE, UiTokens.RADIUS_SMALL))
	sections.add_theme_stylebox_override("tab_selected", _style(UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL, 1))
	sections.add_theme_stylebox_override("tab_hovered", _style(UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL, 1))
	sections.add_theme_color_override("font_unselected_color", UiTokens.TEXT_TERTIARY)
	sections.add_theme_color_override("font_selected_color", UiTokens.TEXT_PRIMARY)
	content.add_child(sections)
	var gameplay_section := VBoxContainer.new()
	gameplay_section.name = "Juego"
	gameplay_section.add_theme_constant_override("separation", UiTokens.SPACE_3)
	sections.add_child(gameplay_section)
	var graphics_section := VBoxContainer.new()
	graphics_section.name = "Gráficos"
	graphics_section.add_theme_constant_override("separation", 10)
	sections.add_child(graphics_section)
	var audio_section := VBoxContainer.new()
	audio_section.name = "Audio"
	audio_section.add_theme_constant_override("separation", 10)
	sections.add_child(audio_section)
	var accessibility_section := VBoxContainer.new()
	accessibility_section.name = "Accesibilidad"
	accessibility_section.add_theme_constant_override("separation", 10)
	sections.add_child(accessibility_section)
	_reduced_motion_toggle = CheckButton.new()
	_reduced_motion_toggle.text = "Reducir movimiento de menús"
	_reduced_motion_toggle.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_reduced_motion_toggle.toggled.connect(func(enabled: bool) -> void:
		_router.reduced_motion = enabled
		if _showroom != null: _showroom.reduced_motion = enabled
		if _vehicle_gallery != null and _vehicle_gallery.showroom != null: _vehicle_gallery.showroom.reduced_motion = enabled
		reduced_motion_changed.emit(enabled)
	)
	accessibility_section.add_child(_reduced_motion_toggle)
	var controls_section := VBoxContainer.new()
	controls_section.name = "Controles"
	controls_section.add_theme_constant_override("separation", 10)
	sections.add_child(controls_section)
	var family_label := Label.new()
	family_label.text = "FAMILIA VISUAL DEL MANDO"
	controls_section.add_child(family_label)
	var family := OptionButton.new()
	for family_name in ["AUTOMÁTICA", "XBOX / GENÉRICO", "PLAYSTATION", "NINTENDO"]:
		family.add_item(family_name)
	family.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	family.item_selected.connect(func(index: int) -> void:
		var selected_family: StringName = [&"automatic", &"xbox", &"playstation", &"nintendo"][index]
		_device_coordinator.set_manual_family(selected_family)
		gamepad_family_changed.emit(selected_family)
	)
	controls_section.add_child(family)
	var customize := ActionButton.new()
	customize.text = "REASIGNAR CONTROLES"
	customize.pressed.connect(func() -> void: _router.navigate(MenuRoute.Id.CONTROLS))
	controls_section.add_child(customize)
	for action_data in [[&"accelerate", "ACELERAR"], [&"brake", "FRENAR"], [&"steer_left", "GIRAR"], [&"drift", "DERRAPE"], [&"use_item", "OBJETO"], [&"pause", "PAUSA"]]:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = UiTokens.TOUCH_TARGET
		controls_section.add_child(row)
		var action_label := Label.new()
		action_label.text = action_data[1]
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_label)
		var action_prompt := ActionPromptView.new()
		action_prompt.action = action_data[0]
		action_prompt.caption = "REASIGNAR"
		row.add_child(action_prompt)

	var profile_label := Label.new()
	profile_label.text = "CALIDAD GRÁFICA"
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_label.add_theme_font_size_override("font_size", 17)
	profile_label.add_theme_color_override("font_color", UiTokens.CYAN)
	graphics_section.add_child(profile_label)

	_profile_value = Label.new()
	_profile_value.text = "ACTUAL: MEDIA"
	_profile_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_value.add_theme_font_size_override("font_size", 16)
	_profile_value.add_theme_color_override("font_color", UiTokens.ELECTRIC_YELLOW)
	graphics_section.add_child(_profile_value)

	var profile_row := GridContainer.new()
	profile_row.columns = 5
	profile_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_row.add_theme_constant_override("separation", 12)
	graphics_section.add_child(profile_row)
	_first_settings_button = _create_button("ULTRA BAJA", UiTokens.CYAN, Vector2(110.0, 64.0))
	_first_settings_button.tooltip_text = "Máximo rendimiento para equipos muy débiles"
	_first_settings_button.pressed.connect(func() -> void: _set_graphics_profile("ultra_low"))
	_quality_buttons[&"ultra_low"] = _first_settings_button
	profile_row.add_child(_first_settings_button)
	var low := _create_button("BAJA", UiTokens.INK_RAISED, Vector2(110.0, 64.0))
	low.pressed.connect(func() -> void: _set_graphics_profile("low"))
	_quality_buttons[&"low"] = low
	profile_row.add_child(low)
	var medium := _create_button("MEDIA", UiTokens.INK_RAISED, Vector2(110.0, 64.0))
	medium.pressed.connect(func() -> void: _set_graphics_profile("medium"))
	_quality_buttons[&"medium"] = medium
	profile_row.add_child(medium)
	var high := _create_button("ALTA", UiTokens.INK_RAISED, Vector2(110.0, 64.0))
	high.pressed.connect(func() -> void: _set_graphics_profile("high"))
	_quality_buttons[&"high"] = high
	profile_row.add_child(high)
	var ultra := _create_button("ULTRA", UiTokens.INK_RAISED, Vector2(110.0, 64.0))
	ultra.tooltip_text = "Máxima calidad para escritorio potente"
	ultra.pressed.connect(func() -> void: _set_graphics_profile("ultra"))
	_quality_buttons[&"ultra"] = ultra
	profile_row.add_child(ultra)

	_vibration_toggle = CheckButton.new()
	_vibration_toggle.text = "Vibración"
	_vibration_toggle.button_pressed = true
	_vibration_toggle.custom_minimum_size = Vector2(220.0, UiTokens.BUTTON_HEIGHT)
	_vibration_toggle.add_theme_font_size_override("font_size", 19)
	_vibration_toggle.toggled.connect(func(enabled: bool) -> void: vibration_changed.emit(enabled))
	accessibility_section.add_child(_vibration_toggle)

	var volume_label := Label.new()
	volume_label.text = "VOLUMEN"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_label.add_theme_font_size_override("font_size", 16)
	volume_label.add_theme_color_override("font_color", UiTokens.CYAN)
	audio_section.add_child(volume_label)

	_volume_slider = _add_volume_control(audio_section, "Principal", 0.8, volume_changed)
	_music_volume_slider = _add_volume_control(audio_section, "Música", 1.0, music_volume_changed)
	_effects_volume_slider = _add_volume_control(audio_section, "Efectos", 1.0, effects_volume_changed)
	_camera_motion_selector = OptionButton.new()
	for label in ["Movimiento reducido", "Movimiento completo", "Movimiento desactivado"]:
		_camera_motion_selector.add_item(label)
	_camera_motion_selector.select(0)
	_camera_motion_selector.item_selected.connect(func(index: int) -> void: camera_motion_changed.emit(["reduced", "full", "off"][index]))
	accessibility_section.add_child(_camera_motion_selector)
	_speed_lines_toggle = _create_setting_toggle("Líneas de velocidad", true, speed_lines_changed)
	graphics_section.add_child(_speed_lines_toggle)
	_threat_toggle = _create_setting_toggle("Indicadores de amenaza", true, threat_indicators_changed)
	accessibility_section.add_child(_threat_toggle)
	_vibration_intensity_slider = _add_volume_control(accessibility_section, "Intensidad de vibración", 1.0, vibration_intensity_changed)

	_ghost_toggle = CheckButton.new()
	_ghost_toggle.text = "Mostrar fantasma"
	_ghost_toggle.button_pressed = true
	_ghost_toggle.custom_minimum_size = Vector2(220.0, UiTokens.BUTTON_HEIGHT)
	_ghost_toggle.add_theme_font_size_override("font_size", 19)
	_ghost_toggle.toggled.connect(func(enabled: bool) -> void: ghost_enabled_changed.emit(enabled))
	_style_setting_toggle(_ghost_toggle)
	gameplay_section.add_child(_ghost_toggle)

	var restore := _create_button("RESTAURAR VALORES", UiTokens.ELECTRIC_YELLOW, Vector2(250.0, 54.0))
	restore.tooltip_text = "Calidad media, movimiento reducido, indicadores activos y vibración al 100 %"
	restore.pressed.connect(_confirm_restore_defaults)
	content.add_child(restore)

	var close := _create_button("VOLVER", UiTokens.CORAL, Vector2(180.0, 64.0))
	close.pressed.connect(_toggle_settings)
	content.add_child(close)
	var update_settings_layout := func() -> void:
		var horizontal_margin := 12.0 if overlay.size.x < UiTokens.BREAKPOINT_SHELL_WIDTH else 24.0
		var half_width := maxf(0.0, (overlay.size.x - horizontal_margin * 2.0) * 0.5)
		card_panel.offset_left = -half_width
		card_panel.offset_right = half_width
		card_panel.offset_top = 12.0 if overlay.size.y < UiTokens.BREAKPOINT_SHELL_HEIGHT else 24.0
		card_panel.offset_bottom = -12.0 if overlay.size.y < UiTokens.BREAKPOINT_SHELL_HEIGHT else -24.0
		profile_row.columns = 2 if overlay.size.x < UiTokens.BREAKPOINT_FOCUSED_WIDTH else (3 if overlay.size.x < UiTokens.BREAKPOINT_TWO_PANEL_WIDTH else 5)
		sections.custom_minimum_size.y = maxf(260.0, minf(420.0, overlay.size.y - 170.0))
	overlay.resized.connect(update_settings_layout)
	update_settings_layout.call_deferred()
	return overlay

func _create_volume_slider(label_text: String, initial: float, changed_signal: Signal) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(310.0, 30.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "Volumen de " + label_text.to_lower()
	slider.value_changed.connect(func(value: float) -> void: changed_signal.emit(value))
	return slider

func _add_volume_control(parent: VBoxContainer, label_text: String, initial: float, changed_signal: Signal) -> HSlider:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = "%s · %d %%" % [label_text, roundi(initial * 100.0)]
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	group.add_child(label)
	var slider := _create_volume_slider(label_text, initial, changed_signal)
	_percentage_labels[slider] = label
	slider.value_changed.connect(func(value: float) -> void: label.text = "%s · %d %%" % [label_text, roundi(value * 100.0)])
	group.add_child(slider)
	parent.add_child(group)
	return slider

func _confirm_restore_defaults() -> void:
	if _settings_panel is SettingsScreen:
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
		return
	var modal := ConfirmationModal.new()
	modal.configure("RESTAURAR VALORES", "¿Restaurar los ajustes de presentación y audio? El progreso y los récords se conservarán.")
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.position = Vector2(-220, -95)
	modal.size = Vector2(440, 190)
	modal.confirmed.connect(func() -> void:
		_set_graphics_profile("medium")
		_vibration_toggle.button_pressed = true
		_volume_slider.value = 0.8
		_music_volume_slider.value = 1.0
		_effects_volume_slider.value = 1.0
		_camera_motion_selector.select(0)
		camera_motion_changed.emit("reduced")
		_speed_lines_toggle.button_pressed = true
		_threat_toggle.button_pressed = true
		_vibration_intensity_slider.value = 1.0
		restore_defaults_requested.emit()
		modal.queue_free()
	)
	modal.cancelled.connect(modal.queue_free)
	add_child(modal)
	modal.confirm_button.grab_focus.call_deferred()

func _create_setting_toggle(label_text: String, initial: bool, changed_signal: Signal) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = initial
	_style_setting_toggle(toggle)
	toggle.toggled.connect(func(enabled: bool) -> void: changed_signal.emit(enabled))
	return toggle

func _style_setting_toggle(toggle: CheckButton) -> void:
	toggle.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	toggle.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	toggle.add_theme_color_override("font_hover_color", UiTokens.TEXT_PRIMARY)
	toggle.add_theme_color_override("font_pressed_color", UiTokens.GRAPHITE)
	toggle.add_theme_stylebox_override("normal", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL))
	toggle.add_theme_stylebox_override("hover", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL, UiTokens.CYAN))
	toggle.add_theme_stylebox_override("pressed", UiTokens.panel(UiTokens.ELECTRIC_YELLOW.darkened(0.08), UiTokens.RADIUS_SMALL))
	toggle.add_theme_stylebox_override("focus", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL, UiTokens.ELECTRIC_YELLOW))


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
	if _profile_value != null:
		_profile_value.text = "ACTUAL: " + graphics_profile.to_upper()
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
	if _profile_value != null:
		_profile_value.text = "ACTUAL: " + graphics_profile.to_upper()
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
