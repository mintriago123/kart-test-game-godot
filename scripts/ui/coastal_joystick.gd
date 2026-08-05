class_name CoastalJoystick
extends Control

const MAX_RADIUS := 54.0

var _touch_index: int = -1
var _value := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(150.0, 150.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Dirección"
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed and _touch_index == -1:
			_touch_index = touch_event.index
			_update_value(touch_event.position)
			accept_event()
		elif not touch_event.pressed and touch_event.index == _touch_index:
			_touch_index = -1
			_update_value(size * 0.5)
			accept_event()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == _touch_index:
			_update_value(drag_event.position)
			accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_value((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_update_value(mouse_event.position if mouse_event.pressed else size * 0.5)
			accept_event()


func _exit_tree() -> void:
	_release_actions()


func _update_value(pointer_position: Vector2) -> void:
	var center := size * 0.5
	var delta := pointer_position - center
	_value = delta.limit_length(MAX_RADIUS) / MAX_RADIUS
	_apply_actions()
	queue_redraw()


func _apply_actions() -> void:
	var left_strength := maxf(-_value.x, 0.0)
	var right_strength := maxf(_value.x, 0.0)
	if left_strength > 0.04:
		Input.action_press(&"steer_left", left_strength)
	else:
		Input.action_release(&"steer_left")
	if right_strength > 0.04:
		Input.action_press(&"steer_right", right_strength)
	else:
		Input.action_release(&"steer_right")


func _release_actions() -> void:
	_value = Vector2.ZERO
	Input.action_release(&"steer_left")
	Input.action_release(&"steer_right")
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 67.0, Color(0.015, 0.07, 0.09, 0.7))
	draw_circle(center, 58.0, Color(0.13, 0.55, 0.61, 0.42))
	draw_arc(center, 59.0, 0.0, TAU, 48, Color(0.55, 0.95, 0.91, 0.65), 3.0, true)
	draw_circle(center + _value * MAX_RADIUS, 30.0, Color("#f5d66f"))
	if has_focus():
		draw_arc(center, 68.0, 0.0, TAU, 48, Color.WHITE, 4.0, true)
