class_name MobileActionButton
extends Control

@export var action_name: StringName
@export var button_label: String = "ACCIÓN"
@export var accent_color := Color("#ffba4a")
@export var haptics_enabled := true

var _touch_index: int = -1
var _is_pressed := false


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(96.0, 96.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	tooltip_text = button_label
	queue_redraw()


func configure(input_action: StringName, label_text: String, color: Color) -> void:
	action_name = input_action
	button_label = label_text
	accent_color = color
	tooltip_text = label_text
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and _touch_index == -1:
			_touch_index = touch_event.index
			_set_pressed(true)
			if haptics_enabled:
				Input.vibrate_handheld(18, 0.22)
			accept_event()
		elif not touch_event.pressed and touch_event.index == _touch_index:
			_touch_index = -1
			_set_pressed(false)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_pressed(mouse_event.pressed)
			accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not has_focus() or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
		_set_pressed(key_event.pressed and not key_event.echo)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_action()


func _exit_tree() -> void:
	_release_action()


func _set_pressed(value: bool) -> void:
	if _is_pressed == value:
		return
	_is_pressed = value
	if action_name != &"":
		if value:
			Input.action_press(action_name)
		else:
			Input.action_release(action_name)
	queue_redraw()


func _release_action() -> void:
	_touch_index = -1
	_set_pressed(false)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	var fill := accent_color
	var press_offset := Vector2(0.0, 4.0) if _is_pressed else Vector2.ZERO
	fill.a = 1.0 if _is_pressed else 0.84
	draw_circle(center + Vector2(0.0, 5.0), radius, Color(0.015, 0.07, 0.09, 0.82))
	draw_circle(center + press_offset, radius - 5.0, fill)
	draw_arc(
		center + press_offset,
		radius - 7.0,
		0.0,
		TAU,
		48,
		Color(1.0, 1.0, 1.0, 0.42),
		3.0,
		true
	)
	if has_focus():
		draw_arc(center, radius, 0.0, TAU, 48, Color.WHITE, 4.0, true)
	var font := ThemeDB.fallback_font
	var font_size := 18 if minf(size.x, size.y) >= 120.0 else 15
	var text_width := font.get_string_size(button_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(
		font,
		center + press_offset + Vector2(-text_width * 0.5, font_size * 0.35),
		button_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color("#102a30")
	)
