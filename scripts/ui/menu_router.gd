class_name MenuRouter
extends Control

signal route_changed(route: int, payload: Dictionary)
signal back_exhausted

var current_route: int = MenuRoute.Id.TITLE
var current_payload: Dictionary = {}
var _history: Array[Dictionary] = []
var _screens: Dictionary = {}
var _focus_memory: Dictionary = {}
var reduced_motion := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func register_screen(route: int, screen: Control) -> void:
	assert(MenuRoute.is_valid(route), "Invalid menu route")
	_screens[route] = screen
	screen.visible = route == current_route

func navigate(route: int, payload: Dictionary = {}) -> void:
	assert(MenuRoute.is_valid(route), "Invalid menu route")
	_remember_focus()
	_history.append({"route": current_route, "payload": current_payload.duplicate(true)})
	_show(route, payload)

func replace(route: int, payload: Dictionary = {}) -> void:
	assert(MenuRoute.is_valid(route), "Invalid menu route")
	_remember_focus()
	_show(route, payload)

func back() -> bool:
	if _history.is_empty():
		back_exhausted.emit()
		return false
	_remember_focus()
	var previous: Dictionary = _history.pop_back()
	_show(int(previous.route), previous.payload)
	return true

func clear_history() -> void:
	_history.clear()

func _show(route: int, payload: Dictionary) -> void:
	if _screens.has(current_route):
		(_screens[current_route] as Control).hide()
	current_route = route
	current_payload = payload.duplicate(true)
	if _screens.has(route):
		var screen := _screens[route] as Control
		screen.show()
		if not reduced_motion:
			screen.modulate.a = 0.0
			var tween := screen.create_tween()
			tween.tween_property(screen, "modulate:a", 1.0, 0.18)
		else:
			screen.modulate.a = 1.0
		_restore_focus.call_deferred(route, screen)
	route_changed.emit(route, current_payload)

func _remember_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		_focus_memory[current_route] = focus

func _restore_focus(route: int, screen: Control) -> void:
	var remembered := _focus_memory.get(route) as Control
	if is_instance_valid(remembered) and remembered.is_visible_in_tree():
		remembered.grab_focus()
		return
	var candidates := screen.find_children("*", "Button", true, false)
	for candidate in candidates:
		if (candidate as Button).is_visible_in_tree() and not (candidate as Button).disabled and (candidate as Button).focus_mode != Control.FOCUS_NONE:
			(candidate as Button).grab_focus()
			return

func _unhandled_input(event: InputEvent) -> void:
	var back_gesture: bool = event is InputEventPanGesture and event.delta.x > 80.0 and absf(event.delta.x) > absf(event.delta.y)
	var mouse_back: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_XBUTTON1 and event.pressed
	if event.is_action_pressed(&"ui_cancel") or back_gesture or mouse_back:
		if back():
			get_viewport().set_input_as_handled()
