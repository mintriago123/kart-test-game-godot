class_name MainMenu
extends CanvasLayer

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

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

var graphics_profile := "medium"
var track_catalog: TrackCatalog
var _settings_panel: Control
var _play_button: Button
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
var _preparation_screen: PreparationScreen
var _garage_panel: Control
var _vehicle_gallery: VehicleGalleryScreen
var _cup_selector: CupSelectScreen
var _profile_panel: Control
var _controls_panel: ControlsScreen
var _reduced_motion_toggle: CheckButton
var _ui_sound: SoundManager
var _garage_showroom: VehicleViewport


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
	graphics_profile = profile
	_best_times = best_times.duplicate(true)
	_select_track(selected_track_id, false)
	_select_cc(selected_cc_id, false)
	_select_game_mode(selected_game_mode, false)
	if _profile_value != null:
		_profile_value.text = "ACTUAL: " + profile.to_upper()
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
	_update_best_time_label()


func _build_interface() -> void:
	var root := Control.new()
	root.theme = UiTokens.create_theme()
	_router.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = UiTokens.GRAPHITE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sun := ColorRect.new()
	sun.color = UiTokens.ELECTRIC_YELLOW
	sun.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	sun.offset_left = -330.0
	sun.offset_right = 0.0
	sun.offset_top = 0.0
	sun.offset_bottom = 0.0
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sun)

	var stripe := ColorRect.new()
	stripe.color = UiTokens.CORAL
	stripe.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	stripe.offset_left = -365.0
	stripe.offset_right = -329.0
	stripe.offset_top = 0.0
	stripe.offset_bottom = 0.0
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stripe)

	var content := VBoxContainer.new()
	content.name = "MainContent"
	content.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	content.position = Vector2(72.0, -210.0)
	content.size = Vector2(610.0, 420.0)
	content.add_theme_constant_override("separation", 15)
	root.add_child(content)
	root.resized.connect(func() -> void: _update_menu_layout(root, content, sun, stripe))

	var eyebrow := Label.new()
	eyebrow.text = "CAMPEONATO ARCADE"
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", Color("#7be0d0"))
	content.add_child(eyebrow)

	var title := Label.new()
	title.text = "MICHIKART\nXD"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("#fff0b1"))
	title.add_theme_color_override("font_shadow_color", Color("#ef7151"))
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("line_spacing", -12)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Derrapa, toma atajos y conquista cada circuito."
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_color", Color("#d8f4e8"))
	content.add_child(subtitle)

	var actions := MenuList.new()
	actions.custom_minimum_size.x = 310.0
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)

	if has_active_cup:
		var continue_cup := actions.add_action("CONTINUAR COPA", _open_active_cup_flow, true)
		continue_cup.custom_minimum_size.y = 58.0
	_play_button = actions.add_action("JUGAR", _show_mode_selector, true)
	_play_button.custom_minimum_size.y = 58.0
	var garage := actions.add_action("GARAJE", func() -> void: pass)
	var profile := actions.add_action("PERFIL", func() -> void: pass)
	var settings := actions.add_action("AJUSTES", _toggle_settings)
	_vehicle_gallery = VehicleGalleryScreen.new()
	_vehicle_gallery.visible = false
	_vehicle_gallery.configure(progression_catalog, player_progress, {"source": "standalone", "variant_id": player_progress.equipped_kart_variant_id if player_progress else &""})
	_vehicle_gallery.action_requested.connect(_handle_vehicle_action)
	_vehicle_gallery.back_requested.connect(func() -> void: _router.back())
	_garage_panel = _vehicle_gallery
	root.add_child(_garage_panel)
	garage.pressed.connect(_open_standalone_garage)
	_profile_panel = _build_profile_panel()
	root.add_child(_profile_panel)
	profile.pressed.connect(func() -> void: _router.navigate(MenuRoute.Id.PROFILE))
	_showroom = VehicleViewport.new()
	_showroom.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_showroom.offset_left = -520.0
	_showroom.offset_right = -30.0
	_showroom.offset_top = 70.0
	_showroom.offset_bottom = -70.0
	_showroom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_showroom)
	_showroom.show_variant(_get_equipped_variant())

	var hint := Label.new()
	hint.text = "Teclado: WASD · Espacio: derrape · E: objeto"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#acd1cb"))
	content.add_child(hint)

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
			_show_play_vehicle({"source": "play", "mode": game_mode, "track_id": track_id, "cup_id": &"", "variant_id": player_progress.equipped_kart_variant_id if player_progress else &"", "cc_id": cc_id, "difficulty_id": difficulty_id, "ghost_enabled": _ghost_toggle.button_pressed if _ghost_toggle else true, "continue_active": false})
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

	_settings_panel = _build_settings_panel()
	root.add_child(_settings_panel)
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
	_router.register_screen(MenuRoute.Id.GARAGE, _garage_panel)
	_router.register_screen(MenuRoute.Id.PROFILE, _profile_panel)
	_router.register_screen(MenuRoute.Id.SETTINGS, _settings_panel)
	_router.register_screen(MenuRoute.Id.CONTROLS, _controls_panel)
	_select_track(_selected_track_id, false)
	_play_button.grab_focus.call_deferred()
	_update_menu_layout(root, content, sun, stripe)


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
	var championship := Label.new()
	championship.text = "CAMPEONATO ARCADE"
	championship.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	championship.add_theme_color_override("font_color", UiTokens.CYAN)
	center.add_child(championship)
	var logo := Label.new()
	logo.text = "MICHIKART XD"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 68)
	logo.add_theme_color_override("font_color", UiTokens.WARM_WHITE)
	center.add_child(logo)
	var enter := _create_button("PRESIONA PARA EMPEZAR", UiTokens.ELECTRIC_YELLOW, Vector2(360, 64))
	enter.pressed.connect(_request_title_dismiss)
	center.add_child(enter)
	var prompt := ActionPromptView.new()
	prompt.action = &"ui_accept"
	prompt.caption = "CONFIRMAR"
	center.add_child(prompt)
	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "1.0")
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color", UiTokens.MUTED)
	center.add_child(version)
	# Input is handled by the full-screen title, not by focus alone.
	enter.focus_mode = Control.FOCUS_NONE
	return overlay


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
	var card := VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-300, -240)
	card.size = Vector2(600, 480)
	card.pivot_offset = card.size * 0.5
	card.add_theme_constant_override("separation", 16)
	overlay.add_child(card)
	overlay.resized.connect(func() -> void:
		var factor := minf(1.0, minf((overlay.size.x - 32.0) / 600.0, (overlay.size.y - 32.0) / 480.0))
		card.scale = Vector2.ONE * maxf(factor, 0.5)
	)
	var title := Label.new()
	title.text = "PERFIL Y PROGRESO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	card.add_child(title)
	var progress := Label.new()
	var unlocked := player_progress.unlocked_reward_ids.size() if player_progress != null else 0
	var total := progression_catalog.unlocks.unlocks.size() if progression_catalog != null else 0
	progress.text = "PILOTO · MAREA\nCARRERAS · %d   VICTORIAS · %d   PODIOS · %d\nMEJOR POSICIÓN · %s   TIEMPO · %s\nOBJETOS · %d/%d   ATAJOS · %d   RECUPERACIONES · %d\nVEHÍCULOS · %d/%d   RÉCORDS · %d" % [player_progress.races_played if player_progress else 0, player_progress.victories if player_progress else 0, player_progress.podiums if player_progress else 0, str(player_progress.best_finish_position) if player_progress and player_progress.best_finish_position > 0 else "—", _format_duration(player_progress.driving_time_seconds if player_progress else 0.0), player_progress.items_collected if player_progress else 0, player_progress.items_used if player_progress else 0, player_progress.shortcuts_used if player_progress else 0, player_progress.recoveries if player_progress else 0, unlocked, total, _best_times.size()]
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 22)
	card.add_child(progress)
	var close := _create_button("VOLVER", UiTokens.CORAL, Vector2(180, 58))
	close.pressed.connect(func() -> void: _router.back())
	card.add_child(close)
	return overlay


func _update_menu_layout(
	root: Control,
	content: Control,
	sun: Control,
	stripe: Control
) -> void:
	var compact := root.size.x < 900.0 or root.size.y < 560.0
	if compact:
		var scale_factor := minf(0.78, (root.size.x - 40.0) / 760.0)
		content.scale = Vector2.ONE * scale_factor
		var desired_y := maxf(18.0, (root.size.y - content.size.y * scale_factor) * 0.5)
		content.offset_left = 24.0
		content.offset_right = 24.0 + content.size.x
		content.offset_top = desired_y - root.size.y * 0.5
		content.offset_bottom = content.offset_top + content.size.y
		sun.offset_left = -220.0
		stripe.offset_left = -244.0
		stripe.offset_right = -219.0
	else:
		content.scale = Vector2.ONE
		content.offset_left = 72.0
		content.offset_right = 682.0
		content.offset_top = -210.0
		content.offset_bottom = 210.0
		sun.offset_left = -330.0
		stripe.offset_left = -365.0
		stripe.offset_right = -329.0


func _build_garage_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.06, 0.08, 0.94)
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
		var compact := overlay.size.x < 1100.0
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
		for unlock in progression_catalog.unlocks.unlocks:
			var unlocked := player_progress.unlocked_reward_ids.has(unlock.id)
			var button := _create_button(unlock.display_name if unlocked else "%s · %s/%s/%s" % [unlock.display_name, unlock.cup_id, unlock.difficulty_id, ["", "BRONCE", "PLATA", "ORO"][unlock.required_medal]], Color("#75e6a4") if unlocked else Color("#637b80"), Vector2(600.0, 52.0))
			button.disabled = false
			button.pressed.connect(func() -> void:
				if unlocked: equip_variant_requested.emit(unlock.kart_variant.id)
				else: _ui_sound.play_ui_error()
			)
			button.focus_entered.connect(func() -> void: _garage_showroom.show_variant(unlock.kart_variant))
			button.mouse_entered.connect(func() -> void: _garage_showroom.show_variant(unlock.kart_variant))
			list.add_child(button)
			if unlock.kart_variant != null:
				var stats_row := VBoxContainer.new()
				for stat in [
					["Velocidad", unlock.kart_variant.speed, 0.8, 1.2],
					["Aceleración", unlock.kart_variant.acceleration, 0.8, 1.2],
					["Manejo", unlock.kart_variant.handling, 0.8, 1.2],
					["Peso", unlock.kart_variant.weight, 0.8, 1.25],
					["Miniturbo", unlock.kart_variant.mini_turbo_duration_multiplier, 0.8, 1.25],
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
	var close := _create_button("VOLVER", Color("#ef7151"), Vector2(200.0, 58.0))
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


func _show_track_selector() -> void:
	_router.navigate(MenuRoute.Id.PLAY_TRACK, {"mode": _selected_game_mode, "track": _selected_track_id, "cc": _selected_cc_id})
	_track_selector.update_best_times(_best_times)
	_track_selector.select_track(_selected_track_id, false)
	_track_selector.select_cc(_selected_cc_id, false)
	_track_selector.select_game_mode(_selected_game_mode, false)
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
		_cup_selector.configure(progression_catalog.cups if progression_catalog else null, player_progress, cup_payload)
		_router.navigate(MenuRoute.Id.PLAY_CUP, cup_payload)
	else:
		_show_track_selector()

func _show_play_vehicle(value: Dictionary) -> void:
	_vehicle_gallery.configure(progression_catalog, player_progress, value)
	_router.navigate(MenuRoute.Id.PLAY_VEHICLE, value)

func _open_standalone_garage() -> void:
	_vehicle_gallery.configure(progression_catalog, player_progress, {"source": "standalone", "variant_id": _vehicle_gallery.last_inspected_variant_id})
	_router.navigate(MenuRoute.Id.GARAGE, _vehicle_gallery.payload)

func _handle_route_changed(route: int, _payload: Dictionary) -> void:
	# The menu showroom is not part of routed overlays. Hide it explicitly so
	# only the shared gallery showroom renders on vehicle-selection routes.
	if _showroom != null:
		_showroom.visible = route == MenuRoute.Id.MAIN

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
	track_selected.emit(track_id)


func _handle_race_class_selected(cc_id: StringName) -> void:
	_selected_cc_id = cc_id
	race_class_selected.emit(cc_id)


func _handle_game_mode_selected(game_mode: int) -> void:
	_selected_game_mode = game_mode
	game_mode_selected.emit(game_mode)

func _get_equipped_variant() -> KartVariantDefinition:
	if progression_catalog == null or player_progress == null:
		return null
	var equipped := progression_catalog.unlocks.get_variant(player_progress.equipped_kart_variant_id)
	if equipped != null:
		return equipped
	for unlock in progression_catalog.unlocks.unlocks:
		if unlock.kart_variant != null:
			return unlock.kart_variant
	return null

func _format_duration(seconds: float) -> String:
	var total := maxi(roundi(seconds), 0)
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _select_game_mode(game_mode: int, should_emit := true) -> void:
	if _track_selector != null:
		_track_selector.select_game_mode(game_mode, should_emit)
		_selected_game_mode = _track_selector.get_selected_game_mode()


func _build_settings_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.06, 0.08, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	var card_panel := PanelContainer.new()
	card_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card_panel.anchor_bottom = 1.0
	card_panel.offset_left = -308.0
	card_panel.offset_right = 308.0
	card_panel.offset_top = 24.0
	card_panel.offset_bottom = -24.0
	card_panel.add_theme_stylebox_override("panel", _style(Color("#12404a"), 24))
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
	content.custom_minimum_size.x = 560.0
	scroll.add_child(content)

	var title := Label.new()
	title.text = "AJUSTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#fff1b5"))
	content.add_child(title)

	var sections := TabContainer.new()
	sections.custom_minimum_size = Vector2(540.0, 420.0)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(sections)
	var gameplay_section := VBoxContainer.new()
	gameplay_section.name = "Juego"
	sections.add_child(gameplay_section)
	var gameplay_help := Label.new()
	gameplay_help.text = "Preferencias de carrera y ayudas disponibles."
	gameplay_help.add_theme_color_override("font_color", UiTokens.MUTED)
	gameplay_section.add_child(gameplay_help)
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
	profile_label.add_theme_color_override("font_color", Color("#a9ddd4"))
	graphics_section.add_child(profile_label)

	_profile_value = Label.new()
	_profile_value.text = "ACTUAL: MEDIA"
	_profile_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_value.add_theme_font_size_override("font_size", 16)
	_profile_value.add_theme_color_override("font_color", Color("#f5d66f"))
	graphics_section.add_child(_profile_value)

	var profile_row := HBoxContainer.new()
	profile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	profile_row.add_theme_constant_override("separation", 12)
	graphics_section.add_child(profile_row)
	_first_settings_button = _create_button("BAJA", Color("#73cdbf"), Vector2(150.0, 64.0))
	_first_settings_button.pressed.connect(func() -> void: _set_graphics_profile("low"))
	profile_row.add_child(_first_settings_button)
	var medium := _create_button("MEDIA", Color("#f5d25f"), Vector2(150.0, 64.0))
	medium.pressed.connect(func() -> void: _set_graphics_profile("medium"))
	profile_row.add_child(medium)
	var high := _create_button("ALTA", Color("#78d9a0"), Vector2(110.0, 64.0))
	high.pressed.connect(func() -> void: _set_graphics_profile("high"))
	profile_row.add_child(high)
	var ultra := _create_button("ULTRA", Color("#ca8cff"), Vector2(110.0, 64.0))
	ultra.tooltip_text = "Máxima calidad para escritorio potente"
	ultra.pressed.connect(func() -> void: _set_graphics_profile("ultra"))
	profile_row.add_child(ultra)

	_vibration_toggle = CheckButton.new()
	_vibration_toggle.text = "Vibración"
	_vibration_toggle.button_pressed = true
	_vibration_toggle.custom_minimum_size = Vector2(220.0, 56.0)
	_vibration_toggle.add_theme_font_size_override("font_size", 19)
	_vibration_toggle.toggled.connect(func(enabled: bool) -> void: vibration_changed.emit(enabled))
	accessibility_section.add_child(_vibration_toggle)

	var volume_label := Label.new()
	volume_label.text = "VOLUMEN"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_label.add_theme_font_size_override("font_size", 16)
	volume_label.add_theme_color_override("font_color", Color("#a9ddd4"))
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
	_ghost_toggle.custom_minimum_size = Vector2(220.0, 48.0)
	_ghost_toggle.add_theme_font_size_override("font_size", 19)
	_ghost_toggle.toggled.connect(func(enabled: bool) -> void: ghost_enabled_changed.emit(enabled))
	graphics_section.add_child(_ghost_toggle)

	var restore := _create_button("RESTAURAR VALORES", Color("#f5d25f"), Vector2(250.0, 54.0))
	restore.tooltip_text = "Calidad media, movimiento reducido, indicadores activos y vibración al 100 %"
	restore.pressed.connect(_confirm_restore_defaults)
	content.add_child(restore)

	var close := _create_button("VOLVER", Color("#ef7656"), Vector2(180.0, 64.0))
	close.pressed.connect(_toggle_settings)
	content.add_child(close)
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
	label.add_theme_color_override("font_color", Color("#d8eeeb"))
	group.add_child(label)
	var slider := _create_volume_slider(label_text, initial, changed_signal)
	_percentage_labels[slider] = label
	slider.value_changed.connect(func(value: float) -> void: label.text = "%s · %d %%" % [label_text, roundi(value * 100.0)])
	group.add_child(slider)
	parent.add_child(group)
	return slider

func _confirm_restore_defaults() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Restaurar valores"
	dialog.dialog_text = "¿Restaurar los ajustes de presentación y audio? El progreso y los récords se conservarán."
	dialog.ok_button_text = "Restaurar"
	dialog.confirmed.connect(func() -> void:
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
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 190))

func _create_setting_toggle(label_text: String, initial: bool, changed_signal: Signal) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = initial
	toggle.toggled.connect(func(enabled: bool) -> void: changed_signal.emit(enabled))
	return toggle


func _toggle_settings() -> void:
	if _router.current_route != MenuRoute.Id.SETTINGS:
		_router.navigate(MenuRoute.Id.SETTINGS)
		_first_settings_button.grab_focus()
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

func _bind_ui_feedback() -> void:
	for candidate in find_children("*", "Button", true, false):
		var button := candidate as Button
		button.focus_entered.connect(_ui_sound.play_ui_navigate)
		button.pressed.connect(_ui_sound.play_ui_confirm)


func _set_graphics_profile(profile: String) -> void:
	graphics_profile = profile
	_profile_value.text = "ACTUAL: " + profile.to_upper()
	graphics_profile_changed.emit(profile)


func _create_button(text: String, color: Color, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("#102d32"))
	button.add_theme_color_override("font_focus_color", Color("#102d32"))
	button.add_theme_stylebox_override("normal", _style(color, 18))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.1), 18))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.14), 18))
	button.add_theme_stylebox_override("focus", _style(Color("#ffffff"), 18, 4))
	button.add_theme_stylebox_override("disabled", _style(Color(0.32, 0.37, 0.38, 0.6), 18))
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
		style.border_color = Color("#ffffff")
	return style
