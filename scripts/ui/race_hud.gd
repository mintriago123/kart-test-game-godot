class_name RaceHud
extends CanvasLayer

signal retry_requested
signal menu_requested

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
	_countdown_label.visible = not text.is_empty()


func show_results(position: int, race_time: float) -> void:
	_results_title.text = "%s\n%s · %s" % [
		"¡PODIO!" if position <= 3 else "¡META!",
		"%dº LUGAR" % position,
		_format_time(race_time),
	]
	_results_panel.visible = true
	_retry_button.grab_focus()


func _process(_delta: float) -> void:
	if _player_kart != null:
		_speed_label.text = "%03d km/h" % _player_kart.get_speed_kph()
	if _pause_overlay != null:
		_pause_overlay.visible = get_tree().paused and not _results_panel.visible


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 24.0
	top_bar.offset_top = 18.0
	top_bar.offset_right = -24.0
	top_bar.offset_bottom = 92.0
	top_bar.add_theme_constant_override("separation", 12)
	root.add_child(top_bar)

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
	root.add_child(_countdown_label)

	var joystick := CoastalJoystick.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(24.0, -178.0)
	joystick.size = Vector2(150.0, 150.0)
	root.add_child(joystick)

	var action_row := HBoxContainer.new()
	action_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_row.position = Vector2(-394.0, -126.0)
	action_row.size = Vector2(370.0, 102.0)
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)
	_add_action_button(action_row, &"brake", "FRENO", Color("#77d0c2"))
	_add_action_button(action_row, &"drift", "DERRAPE", Color("#f5d66f"))
	_add_action_button(action_row, &"use_item", "OBJETO", Color("#ff7954"))
	_add_action_button(action_row, &"accelerate", "GAS", Color("#71d27c"))

	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pausa"
	pause_button.custom_minimum_size = Vector2(64.0, 64.0)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-86.0, 106.0)
	pause_button.size = Vector2(64.0, 64.0)
	pause_button.pressed.connect(_toggle_pause)
	_apply_button_style(pause_button, Color("#f5d66f"))
	root.add_child(pause_button)

	_pause_overlay = _build_pause_overlay()
	root.add_child(_pause_overlay)
	_results_panel = _build_results_panel()
	root.add_child(_results_panel)


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


func _add_action_button(parent: Control, action: StringName, label_text: String, color: Color) -> void:
	var button := MobileActionButton.new()
	button.configure(action, label_text, color)
	button.size_flags_vertical = Control.SIZE_SHRINK_END
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


func _format_time(time: float) -> String:
	var minutes := floori(time / 60.0)
	var seconds := floori(fmod(time, 60.0))
	var milliseconds := floori(fmod(time * 1000.0, 1000.0))
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
