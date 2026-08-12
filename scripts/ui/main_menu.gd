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


func _ready() -> void:
	layer = 30
	_build_interface()


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
	vibration_intensity: float = 1.0
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
	_update_best_time_label()


func _build_interface() -> void:
	var root := Control.new()
	root.theme = UiTokens.create_theme()
	add_child(root)
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
	eyebrow.text = "PROTOTIPO DE CARRERAS ARCADE"
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

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)

	_play_button = _create_button("JUGAR", Color("#f5d25f"), Vector2(220.0, 76.0))
	_play_button.pressed.connect(_show_track_selector)
	actions.add_child(_play_button)

	var settings := _create_button("AJUSTES", Color("#74d3c4"), Vector2(180.0, 76.0))
	settings.pressed.connect(_toggle_settings)
	actions.add_child(settings)
	var garage := _create_button("GARAJE", Color("#7be0d0"), Vector2(170.0, 76.0))
	actions.add_child(garage)
	if has_active_cup:
		var continue_cup := _create_button("CONTINUAR COPA", Color("#ef9c64"), Vector2(230.0, 76.0))
		continue_cup.pressed.connect(func() -> void: continue_cup_requested.emit())
		actions.add_child(continue_cup)
	var garage_panel := _build_garage_panel()
	root.add_child(garage_panel)
	garage.pressed.connect(func() -> void: garage_panel.visible = true)

	var hint := Label.new()
	hint.text = "Teclado: WASD · Espacio: derrape · E: objeto"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#acd1cb"))
	content.add_child(hint)

	var badge := Label.new()
	badge.text = "60\nFPS"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 31)
	badge.add_theme_color_override("font_color", Color("#12353a"))
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.position = Vector2(-235.0, -230.0)
	badge.size = Vector2(138.0, 138.0)
	badge.add_theme_stylebox_override("normal", _style(Color("#fff1ae"), 69))
	root.add_child(badge)

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
			play_requested.emit(track_id, cc_id, game_mode, difficulty_id)
	)
	_track_selector.track_selected.connect(_handle_track_selected)
	_track_selector.race_class_selected.connect(_handle_race_class_selected)
	_track_selector.game_mode_selected.connect(_handle_game_mode_selected)
	_track_selector.back_requested.connect(_hide_track_selector)
	_track_buttons = _track_selector.track_buttons

	_settings_panel = _build_settings_panel()
	root.add_child(_settings_panel)
	_select_track(_selected_track_id, false)
	_play_button.grab_focus.call_deferred()
	_update_menu_layout(root, content, sun, stripe)


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
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_CENTER)
	scroll.position = Vector2(-330.0, -290.0)
	scroll.size = Vector2(660.0, 580.0)
	overlay.add_child(scroll)
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
			button.disabled = not unlocked
			button.pressed.connect(func() -> void: equip_variant_requested.emit(unlock.kart_variant.id))
			list.add_child(button)
			if unlock.kart_variant != null:
				var stats_row := HBoxContainer.new()
				for stat in [
					["Peso", unlock.kart_variant.weight, 0.8, 1.25],
					["Miniturbo", unlock.kart_variant.mini_turbo_duration_multiplier, 0.8, 1.25],
				]:
					var label := Label.new()
					label.text = str(stat[0])
					label.custom_minimum_size.x = 82.0
					stats_row.add_child(label)
					var bar := ProgressBar.new()
					bar.min_value = float(stat[2])
					bar.max_value = float(stat[3])
					bar.value = float(stat[1])
					bar.show_percentage = false
					bar.custom_minimum_size = Vector2(190.0, 14.0)
					stats_row.add_child(bar)
				list.add_child(stats_row)
	var close := _create_button("VOLVER", Color("#ef7151"), Vector2(200.0, 58.0))
	close.pressed.connect(func() -> void: overlay.visible = false)
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
	_track_selector.update_best_times(_best_times)
	_track_selector.select_track(_selected_track_id, false)
	_track_selector.select_cc(_selected_cc_id, false)
	_track_selector.select_game_mode(_selected_game_mode, false)
	_track_selector.show_screen()


func _hide_track_selector() -> void:
	_track_selector.visible = false
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
	var graphics_section := VBoxContainer.new()
	graphics_section.name = "Gráficos"
	graphics_section.add_theme_constant_override("separation", 10)
	sections.add_child(graphics_section)
	var audio_section := VBoxContainer.new()
	audio_section.name = "Audio"
	audio_section.add_theme_constant_override("separation", 10)
	sections.add_child(audio_section)
	var accessibility_section := VBoxContainer.new()
	accessibility_section.name = "Cámara y accesibilidad"
	accessibility_section.add_theme_constant_override("separation", 10)
	sections.add_child(accessibility_section)

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
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible:
		_first_settings_button.grab_focus()
	else:
		_play_button.grab_focus()


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
