class_name TouchScrollContainer
extends ScrollContainer

const DRAG_DEADZONE := 8.0

var _touch_index := -1
var _last_touch_position := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	follow_focus = true


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and get_global_rect().has_point(touch.position):
			_touch_index = touch.index
			_last_touch_position = touch.position
			_dragging = false
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_dragging = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		var movement := drag.position - _last_touch_position
		_last_touch_position = drag.position
		if not _dragging and absf(movement.y) < DRAG_DEADZONE:
			return
		_dragging = true
		scroll_vertical = clampi(
			scroll_vertical - roundi(movement.y),
			0,
			maxi(0, get_v_scroll_bar().max_value - get_v_scroll_bar().page)
		)
		get_viewport().set_input_as_handled()
