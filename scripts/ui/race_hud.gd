class_name RaceHud
extends CanvasLayer

signal retry_requested
signal menu_requested
signal intro_skip_requested

var _lap_label: Label
var _position_label: Label
var _time_label: Label
var _speed_label: Label
var _item_label: Label
var _countdown_label: Label
var _drift_bar: ProgressBar
var _results_panel: Control
var _results_title: Label
var _retry_button: Button
var _pause_overlay: Control
var _player_kart: Kart
var _touch_controls: Control
var _steering_pad: CoastalJoystick
var _race_elements: Array[CanvasItem] = []
var _intro_overlay: Control
var _intro_content: Control
var _intro_title: Label
var _intro_laps: Label
var _intro_skip_button: Button
var _is_intro_visible := false
var _is_auto_accelerating := false

var mobile_controls_enabled := (
	OS.has_feature("android")
	or OS.has_feature("ios")
	or DisplayServer.is_touchscreen_available()
)
var vibration_enabled := true


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()


func bind_player(kart: Kart) -> void:
	_player_kart = kart
	kart.item_changed.connect(_handle_item_changed)
	kart.boost_changed.connect(_handle_boost_changed)


func update_race_info(lap: int, total_laps: int, position: int, racers: int, race_time: float) -> void:
	_lap_label.text = "VUELTA %d/%d" % [lap, total_laps]
	_position_label.text = "%dº / %d" % [position, racers]
	_time_label.text = _format_time(race_time)


func show_countdown(text: String) -> void:
	_countdown_label.text = text
	_countdown_label.visible = (
		not _is_intro_visible and not text.is_empty()
	)


func show_intro(track_name: String, total_laps: int) -> void:
	_is_intro_visible = true
	_intro_title.text = track_name.to_upper()
	_intro_laps.text = "%d VUELTAS" % total_laps
	_intro_content.modulate.a = 0.0
	_intro_overlay.visible = true
	set_intro_skip_enabled(false)
	_set_race_elements_visible(false)
	_set_touch_controls_visible(false)
	_release_auto_acceleration()


func update_intro_progress(elapsed: float) -> void:
	if not _is_intro_visible:
		return
	var fade_in := smoothstep(0.0, 0.75, elapsed)
	var fade_out := 1.0 - smoothstep(4.8, 6.0, elapsed)
	_intro_content.modulate.a = minf(fade_in, fade_out)


func set_intro_skip_enabled(enabled: bool) -> void:
	if _intro_skip_button == null:
		return
	_intro_skip_button.visible = enabled
	_intro_skip_button.disabled = not enabled
	if enabled:
		_intro_skip_button.grab_focus.call_deferred()


func hide_intro() -> void:
	if not _is_intro_visible:
		return
	_is_intro_visible = false
	_intro_overlay.visible = false
	set_intro_skip_enabled(false)
	_set_race_elements_visible(true)
	_countdown_label.visible = not _countdown_label.text.is_empty()


func show_results(position: int, race_time: float) -> void:
	_results_title.text = "%s\n%s · %s" % [
		"¡PODIO!" if position <= 3 else "¡META!",
		"%dº LUGAR" % position,
		_format_time(race_time),
	]
	_results_panel.visible = true
	_set_touch_controls_visible(false)
	_retry_button.grab_focus()


func _process(_delta: float) -> void:
	if _player_kart != null:
		_speed_label.text = "%03d km/h" % _player_kart.get_speed_kph()
	if _pause_overlay != null:
		_pause_overlay.visible = get_tree().paused and not _results_panel.visible
	if _touch_controls != null and not _results_panel.visible:
		_set_touch_controls_visible(
			mobile_controls_enabled
			and not get_tree().paused
			and not _is_intro_visible
		)
	_update_auto_acceleration()


func _exit_tree() -> void:
	_release_auto_acceleration()


func set_mobile_controls_enabled(enabled: bool) -> void:
	mobile_controls_enabled = enabled
	if _touch_controls != null:
		_set_touch_controls_visible(
			enabled
			and not get_tree().paused
			and not _results_panel.visible
			and not _is_intro_visible
		)
		_update_auto_acceleration()
	if not enabled:
		_release_auto_acceleration()


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.name = "RaceInfo"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 24.0
	top_bar.offset_top = 18.0
	top_bar.offset_right = -24.0
	top_bar.offset_bottom = 92.0
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)
	_race_elements.append(top_bar)

	_position_label = _create_chip("1º / 4", 28)
	top_bar.add_child(_position_label)
	_lap_label = _create_chip("VUELTA 1/3", 22)
	top_bar.add_child(_lap_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	_time_label = _create_chip("00:00.000", 22)
	top_bar.add_child(_time_label)
	_speed_label = _create_chip("000 km/h", 20)
	top_bar.add_child(_speed_label)

	_item_label = _create_chip("SIN OBJETO", 18)
	_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_item_label.position = Vector2(-95.0, 102.0)
	_item_label.size = Vector2(190.0, 54.0)
	root.add_child(_item_label)
	_race_elements.append(_item_label)

	_drift_bar = ProgressBar.new()
	_drift_bar.min_value = 0.0
	_drift_bar.max_value = 1.0
	_drift_bar.value = 0.0
	_drift_bar.show_percentage = false
	_drift_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_drift_bar.position = Vector2(-90.0, -52.0)
	_drift_bar.size = Vector2(180.0, 13.0)
	_drift_bar.add_theme_stylebox_override("background", _style(Color(0.02, 0.08, 0.1, 0.76), 8))
	_drift_bar.add_theme_stylebox_override("fill", _style(Color("#f5d66f"), 8))
	root.add_child(_drift_bar)
	_race_elements.append(_drift_bar)

	_countdown_label = Label.new()
	_countdown_label.text = "3"
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 78)
	_countdown_label.add_theme_color_override("font_color", Color("#fff4c7"))
	_countdown_label.add_theme_color_override("font_outline_color", Color("#13373d"))
	_countdown_label.add_theme_constant_override("outline_size", 14)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.position = Vector2(-180.0, -100.0)
	_countdown_label.size = Vector2(360.0, 200.0)
	_countdown_label.visible = false
	root.add_child(_countdown_label)
	_race_elements.append(_countdown_label)

	_build_touch_controls(root)

	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pausa"
	pause_button.custom_minimum_size = Vector2(64.0, 64.0)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-86.0, 106.0)
	pause_button.size = Vector2(64.0, 64.0)
	pause_button.pressed.connect(_toggle_pause)
	_apply_button_style(pause_button, Color("#f5d66f"))
	root.add_child(pause_button)

	_intro_overlay = _build_intro_overlay()
	root.add_child(_intro_overlay)
	_pause_overlay = _build_pause_overlay()
	root.add_child(_pause_overlay)
	_results_panel = _build_results_panel()
	root.add_child(_results_panel)


func _build_touch_controls(root: Control) -> void:
	_touch_controls = Control.new()
	_touch_controls.name = "TouchControls"
	_touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_controls.visible = mobile_controls_enabled
	root.add_child(_touch_controls)

	_steering_pad = CoastalJoystick.new()
	_steering_pad.name = "SteeringPad"
	_steering_pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_steering_pad.position = Vector2(20.0, -212.0)
	_steering_pad.size = Vector2(250.0, 192.0)
	_touch_controls.add_child(_steering_pad)

	_add_action_button(
		_touch_controls,
		"DriftButton",
		&"drift",
		"DERRAPE",
		Color("#f5d66f"),
		Vector2(132.0, 132.0),
		Vector2(-156.0, -156.0)
	)
	_add_action_button(
		_touch_controls,
		"ItemButton",
		&"use_item",
		"OBJETO",
		Color("#ff7954"),
		Vector2(104.0, 104.0),
		Vector2(-280.0, -128.0)
	)
	_add_action_button(
		_touch_controls,
		"BrakeButton",
		&"brake",
		"FRENO",
		Color("#77d0c2"),
		Vector2(100.0, 100.0),
		Vector2(-152.0, -280.0)
	)

	var auto_label := Label.new()
	auto_label.name = "AutoAccelerateIndicator"
	auto_label.text = "GAS AUTO"
	auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	auto_label.add_theme_font_size_override("font_size", 14)
	auto_label.add_theme_color_override("font_color", Color("#dfffe3"))
	auto_label.add_theme_stylebox_override("normal", _style(Color(0.08, 0.35, 0.18, 0.88), 12))
	auto_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	auto_label.position = Vector2(-286.0, -184.0)
	auto_label.size = Vector2(122.0, 34.0)
	_touch_controls.add_child(auto_label)


func _build_intro_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "RaceIntro"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false

	_intro_content = VBoxContainer.new()
	_intro_content.name = "Presentation"
	_intro_content.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_intro_content.position = Vector2(-360.0, 66.0)
	_intro_content.size = Vector2(720.0, 180.0)
	_intro_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_content.add_theme_constant_override("separation", 6)
	overlay.add_child(_intro_content)

	_intro_title = Label.new()
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.add_theme_font_size_override("font_size", 48)
	_intro_title.add_theme_color_override("font_color", Color("#fff4c7"))
	_intro_title.add_theme_color_override("font_outline_color", Color("#13373d"))
	_intro_title.add_theme_constant_override("outline_size", 12)
	_intro_content.add_child(_intro_title)

	_intro_laps = Label.new()
	_intro_laps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_laps.add_theme_font_size_override("font_size", 23)
	_intro_laps.add_theme_color_override("font_color", Color("#d8f4e8"))
	_intro_laps.add_theme_color_override("font_outline_color", Color("#13373d"))
	_intro_laps.add_theme_constant_override("outline_size", 7)
	_intro_content.add_child(_intro_laps)

	_intro_skip_button = Button.new()
	_intro_skip_button.name = "SkipIntro"
	_intro_skip_button.text = "OMITIR"
	_intro_skip_button.tooltip_text = "Omitir introducción (Enter o Espacio)"
	_intro_skip_button.custom_minimum_size = Vector2(180.0, 64.0)
	_intro_skip_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_intro_skip_button.position = Vector2(-90.0, -102.0)
	_intro_skip_button.size = Vector2(180.0, 64.0)
	_intro_skip_button.visible = false
	_intro_skip_button.disabled = true
	_intro_skip_button.pressed.connect(_request_intro_skip)
	_apply_button_style(_intro_skip_button, Color("#f5d66f"))
	overlay.add_child(_intro_skip_button)
	return overlay


func _build_pause_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.06, 0.08, 0.58)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	var label := Label.new()
	label.text = "PAUSA\nToca Ⅱ o pulsa Esc para continuar"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color("#fff1b5"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(label)
	return overlay


func _build_results_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "Results"
	overlay.color = Color(0.01, 0.06, 0.08, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	var card := VBoxContainer.new()
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-260.0, -150.0)
	card.size = Vector2(520.0, 300.0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 22)
	card.add_theme_stylebox_override("panel", _style(Color("#123b42"), 24))
	var card_panel := PanelContainer.new()
	card_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_panel.add_theme_stylebox_override("panel", _style(Color("#123b42"), 24))
	overlay.add_child(card_panel)
	card_panel.add_child(card)

	_results_title = Label.new()
	_results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_title.add_theme_font_size_override("font_size", 36)
	_results_title.add_theme_color_override("font_color", Color("#fff1b5"))
	card.add_child(_results_title)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	card.add_child(actions)

	_retry_button = Button.new()
	_retry_button.name = "Retry"
	_retry_button.text = "OTRA CARRERA"
	_retry_button.custom_minimum_size = Vector2(190.0, 72.0)
	_retry_button.pressed.connect(func() -> void: retry_requested.emit())
	_apply_button_style(_retry_button, Color("#f2c958"))
	actions.add_child(_retry_button)

	var menu := Button.new()
	menu.text = "MENÚ"
	menu.custom_minimum_size = Vector2(140.0, 72.0)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	_apply_button_style(menu, Color("#ef7656"))
	actions.add_child(menu)
	return overlay


func _add_action_button(
	parent: Control,
	node_name: String,
	action: StringName,
	label_text: String,
	color: Color,
	button_size: Vector2,
	button_position: Vector2
) -> void:
	var button := MobileActionButton.new()
	button.name = node_name
	button.configure(action, label_text, color)
	button.haptics_enabled = vibration_enabled
	button.custom_minimum_size = button_size
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = button_position
	button.size = button_size
	parent.add_child(button)


func _create_chip(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(122.0, 58.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff6d7"))
	label.add_theme_stylebox_override("normal", _style(Color(0.03, 0.16, 0.18, 0.86), 14))
	return label


func _apply_button_style(button: Button, color: Color) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#102d32"))
	button.add_theme_color_override("font_focus_color", Color("#102d32"))
	button.add_theme_stylebox_override("normal", _style(color, 16))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.1), 16))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.13), 16))
	button.add_theme_stylebox_override("focus", _style(Color("#ffffff"), 16, 4))
	button.add_theme_stylebox_override("disabled", _style(Color(0.3, 0.36, 0.37, 0.62), 16))


func _style(color: Color, radius: int, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = Color.WHITE
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	return style


func _handle_item_changed(display_name: String) -> void:
	_item_label.text = display_name.to_upper() if not display_name.is_empty() else "SIN OBJETO"


func _handle_boost_changed(charge_ratio: float) -> void:
	_drift_bar.value = charge_ratio


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if (
		not _is_intro_visible
		or _intro_skip_button == null
		or not _intro_skip_button.visible
		or _intro_skip_button.disabled
	):
		return
	if event.is_action_pressed(&"ui_accept"):
		_request_intro_skip()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if (
		key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		or key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	):
		_request_intro_skip()
		get_viewport().set_input_as_handled()


func _request_intro_skip() -> void:
	if (
		not _is_intro_visible
		or _intro_skip_button == null
		or not _intro_skip_button.visible
		or _intro_skip_button.disabled
	):
		return
	intro_skip_requested.emit()


func _set_touch_controls_visible(is_visible: bool) -> void:
	if _touch_controls.visible == is_visible:
		return
	_touch_controls.visible = is_visible
	if not is_visible:
		_release_auto_acceleration()


func _set_race_elements_visible(is_visible: bool) -> void:
	for element in _race_elements:
		element.visible = is_visible


func _update_auto_acceleration() -> void:
	var should_accelerate := (
		mobile_controls_enabled
		and _touch_controls != null
		and _touch_controls.visible
		and _player_kart != null
		and _player_kart.is_control_enabled
		and not get_tree().paused
		and not _results_panel.visible
		and not Input.is_action_pressed(&"brake")
	)
	if should_accelerate == _is_auto_accelerating:
		return
	_is_auto_accelerating = should_accelerate
	if _is_auto_accelerating:
		Input.action_press(&"accelerate")
	else:
		Input.action_release(&"accelerate")


func _release_auto_acceleration() -> void:
	if not _is_auto_accelerating:
		return
	_is_auto_accelerating = false
	Input.action_release(&"accelerate")


func _format_time(time: float) -> String:
	var minutes := floori(time / 60.0)
	var seconds := floori(fmod(time, 60.0))
	var milliseconds := floori(fmod(time * 1000.0, 1000.0))
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
