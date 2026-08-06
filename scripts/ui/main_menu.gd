class_name MainMenu
extends CanvasLayer

signal play_requested(track_id: StringName)
signal track_selected(track_id: StringName)
signal graphics_profile_changed(profile: String)
signal vibration_changed(enabled: bool)
signal volume_changed(value: float)

var graphics_profile := "medium"
var track_catalog: TrackCatalog
var _settings_panel: Control
var _play_button: Button
var _first_settings_button: Button
var _profile_value: Label
var _vibration_toggle: CheckButton
var _volume_slider: HSlider
var _track_buttons: Dictionary = {}
var _best_times: Dictionary = {}
var _selected_track_id: StringName = &"coastal"
var _track_selector: TrackSelectScreen


func _ready() -> void:
	layer = 30
	_build_interface()


func apply_settings(
	profile: String,
	vibration: bool,
	volume: float,
	best_times: Dictionary,
	selected_track_id: StringName
) -> void:
	graphics_profile = profile
	_best_times = best_times.duplicate(true)
	_select_track(selected_track_id, false)
	if _profile_value != null:
		_profile_value.text = "ACTUAL: " + profile.to_upper()
	if _vibration_toggle != null:
		_vibration_toggle.set_pressed_no_signal(vibration)
	if _volume_slider != null:
		_volume_slider.set_value_no_signal(volume)
	_update_best_time_label()


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var background := ColorRect.new()
	background.color = Color("#082d37")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

	var sun := ColorRect.new()
	sun.color = Color("#f2b84d")
	sun.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	sun.offset_left = -330.0
	sun.offset_right = 0.0
	sun.offset_top = 0.0
	sun.offset_bottom = 0.0
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sun)

	var stripe := ColorRect.new()
	stripe.color = Color("#ef7151")
	stripe.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	stripe.offset_left = -365.0
	stripe.offset_right = -329.0
	stripe.offset_top = 0.0
	stripe.offset_bottom = 0.0
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stripe)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	content.position = Vector2(72.0, -210.0)
	content.size = Vector2(610.0, 420.0)
	content.add_theme_constant_override("separation", 15)
	root.add_child(content)

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
	_track_selector.configure(track_catalog, _best_times, _selected_track_id)
	_track_selector.race_requested.connect(
		func(track_id: StringName) -> void: play_requested.emit(track_id)
	)
	_track_selector.track_selected.connect(_handle_track_selected)
	_track_selector.back_requested.connect(_hide_track_selector)
	_track_buttons = _track_selector.track_buttons

	_settings_panel = _build_settings_panel()
	root.add_child(_settings_panel)
	_select_track(_selected_track_id, false)
	_play_button.grab_focus.call_deferred()


func _select_track(track_id: StringName, should_emit: bool = true) -> void:
	if _track_selector == null:
		return
	_track_selector.select_track(track_id, should_emit)
	_selected_track_id = _track_selector.get_selected_track_id()


func _update_best_time_label() -> void:
	if _track_selector != null:
		_track_selector.update_best_times(_best_times)


func _show_track_selector() -> void:
	_track_selector.update_best_times(_best_times)
	_track_selector.select_track(_selected_track_id, false)
	_track_selector.show_screen()


func _hide_track_selector() -> void:
	_track_selector.visible = false
	_play_button.grab_focus.call_deferred()


func _handle_track_selected(track_id: StringName) -> void:
	_selected_track_id = track_id
	track_selected.emit(track_id)


func _build_settings_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.06, 0.08, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	var card_panel := PanelContainer.new()
	card_panel.set_anchors_preset(Control.PRESET_CENTER)
	card_panel.position = Vector2(-280.0, -280.0)
	card_panel.size = Vector2(560.0, 560.0)
	card_panel.add_theme_stylebox_override("panel", _style(Color("#12404a"), 24))
	overlay.add_child(card_panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	card_panel.add_child(content)

	var title := Label.new()
	title.text = "AJUSTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#fff1b5"))
	content.add_child(title)

	var profile_label := Label.new()
	profile_label.text = "CALIDAD GRÁFICA"
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_label.add_theme_font_size_override("font_size", 17)
	profile_label.add_theme_color_override("font_color", Color("#a9ddd4"))
	content.add_child(profile_label)

	_profile_value = Label.new()
	_profile_value.text = "ACTUAL: MEDIA"
	_profile_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_value.add_theme_font_size_override("font_size", 16)
	_profile_value.add_theme_color_override("font_color", Color("#f5d66f"))
	content.add_child(_profile_value)

	var profile_row := HBoxContainer.new()
	profile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	profile_row.add_theme_constant_override("separation", 12)
	content.add_child(profile_row)
	_first_settings_button = _create_button("BAJA", Color("#73cdbf"), Vector2(150.0, 64.0))
	_first_settings_button.pressed.connect(func() -> void: _set_graphics_profile("low"))
	profile_row.add_child(_first_settings_button)
	var medium := _create_button("MEDIA", Color("#f5d25f"), Vector2(150.0, 64.0))
	medium.pressed.connect(func() -> void: _set_graphics_profile("medium"))
	profile_row.add_child(medium)

	_vibration_toggle = CheckButton.new()
	_vibration_toggle.text = "Vibración"
	_vibration_toggle.button_pressed = true
	_vibration_toggle.custom_minimum_size = Vector2(220.0, 56.0)
	_vibration_toggle.add_theme_font_size_override("font_size", 19)
	_vibration_toggle.toggled.connect(func(enabled: bool) -> void: vibration_changed.emit(enabled))
	content.add_child(_vibration_toggle)

	var volume_label := Label.new()
	volume_label.text = "VOLUMEN"
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	volume_label.add_theme_font_size_override("font_size", 16)
	volume_label.add_theme_color_override("font_color", Color("#a9ddd4"))
	content.add_child(volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = 0.8
	_volume_slider.custom_minimum_size = Vector2(310.0, 48.0)
	_volume_slider.tooltip_text = "Volumen principal"
	_volume_slider.value_changed.connect(func(value: float) -> void: volume_changed.emit(value))
	content.add_child(_volume_slider)

	var close := _create_button("VOLVER", Color("#ef7656"), Vector2(180.0, 64.0))
	close.pressed.connect(_toggle_settings)
	content.add_child(close)
	return overlay


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
