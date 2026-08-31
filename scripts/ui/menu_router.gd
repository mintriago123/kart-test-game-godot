class_name MenuRouter
extends Control

signal route_changed(route: int, payload: Dictionary)
signal back_exhausted

var current_route: int = MenuRoute.Id.TITLE
var current_payload: Dictionary = {}
var _history: Array[Dictionary] = []
var _screens: Dictionary = {}
var _focus_memory: Dictionary = {}
var _fallback_focus: Dictionary = {}
var _fallback_scopes: Dictionary = {}
var reduced_motion := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)


func _process(_delta: float) -> void:
	# A hidden routed screen can keep the old focus owner alive for one or
	# more frames.  This is especially visible with a gamepad: the next
	# confirm press can then activate a control that is no longer on screen.
	var screen := _screens.get(current_route) as Control
	var fallback := _fallback_focus.get(current_route) as Control
	var fallback_scope := _fallback_scopes.get(current_route) as Control
	if screen == null and fallback == null:
		return
	if screen == null:
		var focus := get_viewport().gui_get_focus_owner()
		var scope := fallback_scope if fallback_scope != null else fallback
		var focus_control := focus as Control
		if focus == null or not scope.is_ancestor_of(focus) or not focus.is_visible_in_tree() or focus_control == null or focus_control.focus_mode == Control.FOCUS_NONE:
			if fallback.is_visible_in_tree() and fallback.focus_mode != Control.FOCUS_NONE:
				fallback.grab_focus()
		return
	if screen == null or not screen.visible:
		return
	var focus: Node = get_viewport().gui_get_focus_owner()
	# OptionButton popups live in a temporary PopupMenu outside the routed
	# screen. They own focus legitimately while the list is open.
	if focus is PopupMenu:
		return
	var focus_control := focus as Control
	if focus == null or not screen.is_ancestor_of(focus) or not focus.is_visible_in_tree() or focus_control == null or focus_control.focus_mode == Control.FOCUS_NONE:
		_restore_focus(current_route, screen)

func register_screen(route: int, screen: Control) -> void:
	assert(MenuRoute.is_valid(route), "Invalid menu route")
	_screens[route] = screen
	screen.visible = route == current_route


func set_fallback_focus(route: int, control: Control, scope: Control = null) -> void:
	# Used by persistent layers such as the main menu, which are not routed
	# screens but must still have a focus recovery target.
	if control == null:
		_fallback_focus.erase(route)
		_fallback_scopes.erase(route)
	else:
		_fallback_focus[route] = control
		if scope != null:
			_fallback_scopes[route] = scope

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
	# Never let a stale control receive the confirm event while the new route
	# is being shown.
	get_viewport().gui_release_focus()
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
	var remembered_button := remembered as BaseButton
	if is_instance_valid(remembered) and remembered.is_visible_in_tree() and (remembered_button == null or not remembered_button.disabled) and remembered.focus_mode != Control.FOCUS_NONE:
		remembered.grab_focus()
		return
	for candidate in screen.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE and button.button_pressed:
			button.grab_focus()
			return
	for candidate in screen.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return

func _unhandled_input(event: InputEvent) -> void:
	var back_gesture: bool = event is InputEventPanGesture and event.delta.x > 80.0 and absf(event.delta.x) > absf(event.delta.y)
	var mouse_back: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_XBUTTON1 and event.pressed
	if event.is_action_pressed(&"ui_cancel") or back_gesture or mouse_back:
		if back():
			get_viewport().set_input_as_handled()
