class_name CoastalJoystick
extends Control

const MAX_DRAG_DISTANCE := 78.0
const STEERING_DEADZONE := 0.08
const STEERING_RESPONSE := 11.0
const RESPONSE_EXPONENT := 1.2

var _touch_index: int = -1
var _touch_origin := Vector2.ZERO
var _target_strength := 0.0
var _steering_strength := 0.0
var _mouse_dragging := false
var _pointer_active := false
var _keyboard_left := false
var _keyboard_right := false


func _ready() -> void:
	custom_minimum_size = Vector2(240.0, 188.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Dirección flotante: toca y arrastra horizontalmente"
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if (
			touch_event.pressed
			and _touch_index == -1
			and not _mouse_dragging
		):
			_touch_index = touch_event.index
			_begin_drag(touch_event.position)
			accept_event()
		elif not touch_event.pressed and touch_event.index == _touch_index:
			_touch_index = -1
			_end_drag()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == _touch_index:
			_update_target(drag_event.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed and _touch_index == -1:
				_mouse_dragging = true
				_begin_drag(mouse_event.position)
				accept_event()
			elif not mouse_event.pressed and _mouse_dragging:
				_end_drag()
				accept_event()
	elif event is InputEventMouseMotion and _mouse_dragging:
		_update_target((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventKey and has_focus():
		_handle_key_input(event as InputEventKey)


func _process(delta: float) -> void:
	var previous_strength := _steering_strength
	_steering_strength = move_toward(
		_steering_strength,
		_target_strength,
		STEERING_RESPONSE * delta
	)
	if not is_equal_approx(previous_strength, _steering_strength):
		_apply_actions()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_actions()


func _exit_tree() -> void:
	_release_actions()


func _begin_drag(pointer_position: Vector2) -> void:
	_pointer_active = true
	_touch_origin = pointer_position
	_target_strength = 0.0
	_steering_strength = 0.0
	grab_focus()
	_apply_actions()
	queue_redraw()


func _update_target(pointer_position: Vector2) -> void:
	var raw_strength := clampf(
		(pointer_position.x - _touch_origin.x) / MAX_DRAG_DISTANCE,
		-1.0,
		1.0
	)
	_target_strength = _shape_strength(raw_strength)
	queue_redraw()


func _end_drag() -> void:
	_mouse_dragging = false
	_pointer_active = false
	_target_strength = _get_keyboard_strength()
	if is_zero_approx(_target_strength):
		_steering_strength = 0.0
		_apply_actions()
	queue_redraw()


func _shape_strength(raw_strength: float) -> float:
	var magnitude := absf(raw_strength)
	if magnitude <= STEERING_DEADZONE:
		return 0.0
	var normalized := (magnitude - STEERING_DEADZONE) / (1.0 - STEERING_DEADZONE)
	return signf(raw_strength) * pow(normalized, RESPONSE_EXPONENT)


func _handle_key_input(event: InputEventKey) -> void:
	if event.keycode != KEY_LEFT and event.keycode != KEY_RIGHT:
		return
	if event.keycode == KEY_LEFT:
		_keyboard_left = event.pressed
	else:
		_keyboard_right = event.pressed
	_target_strength = _get_keyboard_strength()
	accept_event()


func _get_keyboard_strength() -> float:
	var right_strength := 1.0 if _keyboard_right else 0.0
	var left_strength := 1.0 if _keyboard_left else 0.0
	return right_strength - left_strength


func _apply_actions() -> void:
	var left_strength := maxf(-_steering_strength, 0.0)
	var right_strength := maxf(_steering_strength, 0.0)
	if left_strength > 0.04:
		Input.action_press(&"steer_left", left_strength)
	else:
		Input.action_release(&"steer_left")
	if right_strength > 0.04:
		Input.action_press(&"steer_right", right_strength)
	else:
		Input.action_release(&"steer_right")


func _release_actions() -> void:
	_touch_index = -1
	_mouse_dragging = false
	_pointer_active = false
	_keyboard_left = false
	_keyboard_right = false
	_target_strength = 0.0
	_steering_strength = 0.0
	Input.action_release(&"steer_left")
	Input.action_release(&"steer_right")
	queue_redraw()


func _draw() -> void:
	if not _pointer_active:
		return
	var center := _touch_origin
	var knob_offset := Vector2(_steering_strength * MAX_DRAG_DISTANCE, 0.0)
	draw_circle(center + Vector2(0.0, 5.0), 76.0, Color(0.015, 0.07, 0.09, 0.76))
	draw_circle(center, 70.0, Color(0.13, 0.55, 0.61, 0.4))
	draw_arc(center, 70.0, 0.0, TAU, 56, Color(0.55, 0.95, 0.91, 0.72), 4.0, true)
	draw_line(center + Vector2(-48.0, 0.0), center + Vector2(48.0, 0.0), Color(0.8, 1.0, 0.95, 0.52), 4.0, true)
	draw_circle(center + knob_offset + Vector2(0.0, 4.0), 34.0, Color(0.015, 0.07, 0.09, 0.72))
	draw_circle(center + knob_offset, 31.0, Color("#f5d66f"))
	if has_focus():
		draw_arc(center, 77.0, 0.0, TAU, 56, Color.WHITE, 4.0, true)
