class_name RaceTouchControls
extends Control

const STEERING_ZONE_TOP := 0.32
const STEERING_ZONE_RIGHT := 0.52

var steering_pad: CoastalJoystick
var item_button: MobileActionButton
var launch_button: MobileActionButton

var _player_kart: Kart
var _mobile_controls_enabled := false
var _is_auto_accelerating := false


func build_interface(
	mobile_controls_enabled: bool,
	vibration_enabled: bool
) -> void:
	name = "TouchControls"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_controls_enabled = mobile_controls_enabled
	visible = mobile_controls_enabled

	steering_pad = CoastalJoystick.new()
	steering_pad.name = "SteeringPad"
	steering_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	steering_pad.anchor_top = STEERING_ZONE_TOP
	steering_pad.anchor_right = STEERING_ZONE_RIGHT
	steering_pad.offset_left = 0.0
	steering_pad.offset_top = 0.0
	steering_pad.offset_right = 0.0
	steering_pad.offset_bottom = 0.0
	steering_pad.steering_changed.connect(_handle_steering_changed)
	add_child(steering_pad)

	_add_action_button(
		"DriftButton",
		&"drift",
		"DERRAPE",
		Color("#f5d66f"),
		Vector2(132.0, 132.0),
		Vector2(-156.0, -156.0),
		vibration_enabled
	)
	launch_button = _add_action_button(
		"LaunchButton", &"accelerate", "ACELERA", Color("#ffb238"),
		Vector2(132.0, 132.0), Vector2(-156.0, -156.0), vibration_enabled
	)
	launch_button.visible = false
	item_button = _add_action_button(
		"ItemButton",
		&"use_item",
		"OBJETO",
		Color("#ff7954"),
		Vector2(104.0, 104.0),
		Vector2(-280.0, -128.0),
		vibration_enabled
	)
	_add_action_button(
		"BrakeButton",
		&"brake",
		"FRENO",
		Color("#77d0c2"),
		Vector2(100.0, 100.0),
		Vector2(-152.0, -280.0),
		vibration_enabled
	)

	var auto_label := Label.new()
	auto_label.name = "AutoAccelerateIndicator"
	auto_label.text = "GAS AUTO"
	auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	auto_label.add_theme_font_size_override("font_size", 14)
	auto_label.add_theme_color_override("font_color", Color("#dfffe3"))
	auto_label.add_theme_stylebox_override(
		"normal",
		RaceHudStyle.style(Color(0.08, 0.35, 0.18, 0.88), 12)
	)
	auto_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	auto_label.position = Vector2(-286.0, -184.0)
	auto_label.size = Vector2(122.0, 34.0)
	add_child(auto_label)


func bind_player(kart: Kart) -> void:
	_clear_player_virtual_actions()
	_player_kart = kart
	_sync_player_virtual_actions()


func show_item(item: ItemDefinition) -> void:
	if item_button == null:
		return
	item_button.set_item_icon(
		item.icon if item != null else null,
		item.display_name if item != null else ""
	)


func set_mobile_controls_enabled(enabled: bool) -> void:
	_mobile_controls_enabled = enabled
	if not enabled:
		release_auto_acceleration()

func show_launch_button(show: bool) -> void:
	if launch_button != null:
		launch_button.visible = show and _mobile_controls_enabled


func update_state(
	is_paused: bool,
	results_visible: bool,
	is_intro_visible: bool
) -> void:
	set_controls_visible(
		_mobile_controls_enabled
		and not is_paused
		and not results_visible
		and not is_intro_visible
	)
	_update_auto_acceleration(is_paused, results_visible)


func set_controls_visible(is_visible: bool) -> void:
	if visible == is_visible:
		return
	visible = is_visible
	if not is_visible:
		release_auto_acceleration()


func release_auto_acceleration() -> void:
	if not _is_auto_accelerating:
		_set_player_virtual_action(&"accelerate", 0.0)
		return
	_is_auto_accelerating = false
	Input.action_release(&"accelerate")
	_set_player_virtual_action(&"accelerate", 0.0)


func _exit_tree() -> void:
	release_auto_acceleration()
	_clear_player_virtual_actions()


func _update_auto_acceleration(
	is_paused: bool,
	results_visible: bool
) -> void:
	var should_accelerate := (
		_mobile_controls_enabled
		and visible
		and _player_kart != null
		and _player_kart.is_control_enabled
		and not is_paused
		and not results_visible
		and not Input.is_action_pressed(&"brake")
	)
	if should_accelerate == _is_auto_accelerating:
		return
	_is_auto_accelerating = should_accelerate
	if _is_auto_accelerating:
		Input.action_press(&"accelerate")
		_set_player_virtual_action(&"accelerate", 1.0)
	else:
		Input.action_release(&"accelerate")
		_set_player_virtual_action(&"accelerate", 0.0)


func _add_action_button(
	node_name: String,
	action: StringName,
	label_text: String,
	color: Color,
	button_size: Vector2,
	button_position: Vector2,
	vibration_enabled: bool
) -> MobileActionButton:
	var button := MobileActionButton.new()
	button.name = node_name
	button.configure(action, label_text, color)
	button.haptics_enabled = vibration_enabled
	button.custom_minimum_size = button_size
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = button_position
	button.size = button_size
	button.pressed_changed.connect(_handle_action_button_changed)
	add_child(button)
	return button


func _handle_steering_changed(strength: float) -> void:
	_set_player_virtual_action(&"steer_left", maxf(-strength, 0.0))
	_set_player_virtual_action(&"steer_right", maxf(strength, 0.0))


func _handle_action_button_changed(action: StringName, pressed: bool) -> void:
	_set_player_virtual_action(action, 1.0 if pressed else 0.0)


func _set_player_virtual_action(action: StringName, strength: float) -> void:
	if _player_kart == null or _player_kart.input_source == null:
		return
	_player_kart.input_source.set_virtual_action_strength(action, strength)


func _sync_player_virtual_actions() -> void:
	if _player_kart == null or _player_kart.input_source == null:
		return
	_set_player_virtual_action(
		&"accelerate",
		1.0 if _is_auto_accelerating else 0.0
	)
	_handle_steering_changed(
		steering_pad._steering_strength if steering_pad != null else 0.0
	)
	for button in find_children("*", "MobileActionButton", true, false):
		var action_button := button as MobileActionButton
		_set_player_virtual_action(
			action_button.action_name,
			1.0 if action_button._is_pressed else 0.0
		)


func _clear_player_virtual_actions() -> void:
	if _player_kart != null and _player_kart.input_source != null:
		_player_kart.input_source.clear_virtual_actions()
