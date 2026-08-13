class_name ControlsScreen
extends Control

signal binding_captured(action: StringName, event: InputEvent)
signal conflict_detected(action: StringName, conflicting_action: StringName, event: InputEvent)
signal back_requested

const ACTIONS := [&"accelerate", &"brake", &"steer_left", &"steer_right", &"drift", &"use_item", &"ui_accept", &"ui_cancel", &"pause"]

var profile := InputBindingProfile.new()
var capturing_action: StringName = &""
var _pending_event: InputEvent
var _pending_conflict: StringName = &""
var _defaults: Dictionary = {}
var _binding_buttons: Dictionary = {}
var _conflict_modal: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	profile.capture_from_input_map(ACTIONS)
	_defaults = profile.bindings.duplicate(true)
	_build_interface()
	conflict_detected.connect(_show_conflict)
	binding_captured.connect(func(_action: StringName, _event: InputEvent) -> void: _save_active_profile())
	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		var id := int(joypads.front())
		load_profile(Input.get_joy_guid(id), _detect_family(Input.get_joy_name(id)))

func begin_capture(action: StringName) -> bool:
	if action not in ACTIONS:
		return false
	capturing_action = action
	_pending_event = null
	_pending_conflict = &""
	return true

func cancel_capture() -> void:
	capturing_action = &""
	_pending_event = null
	_pending_conflict = &""

func resolve_conflict(resolution: StringName) -> bool:
	if _pending_event == null or resolution not in [&"swap", &"replace", &"cancel"]:
		return false
	var changed := profile.assign(capturing_action, _pending_event, resolution)
	if changed:
		profile.apply_to_input_map()
		_save_active_profile()
	cancel_capture()
	return changed

func restore_controller_defaults(device: int = -1) -> void:
	for action in ACTIONS:
		var retained: Array[InputEvent] = []
		for event in InputMap.action_get_events(action):
			if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or (device >= 0 and event.device != device):
				retained.append(event)
		InputMap.action_erase_events(action)
		for event in retained:
			InputMap.action_add_event(action, event)
	profile.capture_from_input_map(ACTIONS)
	var manager := get_node_or_null("/root/PromptManager")
	if manager != null:
		manager.refresh()

func restore_all_defaults() -> void:
	profile.bindings = _defaults.duplicate(true)
	profile.apply_to_input_map()

func can_leave() -> bool:
	return profile.is_valid()

func get_profile_path(guid: String, family: StringName) -> String:
	var safe_guid := guid.validate_filename()
	return "user://input_profiles/%s.tres" % (safe_guid if not safe_guid.is_empty() else str(family))

func save_profile(guid: String, family: StringName) -> Error:
	profile.guid = guid
	profile.family = family
	return profile.save_to_disk(get_profile_path(guid, family))

func load_profile(guid: String, family: StringName) -> bool:
	var exact_path := get_profile_path(guid, family)
	var fallback_path := get_profile_path("", family)
	var path := exact_path if ResourceLoader.exists(exact_path) else fallback_path
	if not ResourceLoader.exists(path):
		return false
	var loaded := ResourceLoader.load(path, "InputBindingProfile", ResourceLoader.CACHE_MODE_IGNORE) as InputBindingProfile
	if loaded == null or not loaded.is_valid():
		return false
	profile = loaded
	return profile.apply_to_input_map()

func _input(event: InputEvent) -> void:
	if capturing_action.is_empty() or not event.is_pressed() or event.is_echo():
		return
	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.65:
		return
	_pending_event = event.duplicate()
	_pending_conflict = profile.find_conflict(_pending_event, capturing_action)
	if not _pending_conflict.is_empty():
		conflict_detected.emit(capturing_action, _pending_conflict, _pending_event)
	else:
		if profile.assign(capturing_action, _pending_event):
			profile.apply_to_input_map()
			binding_captured.emit(capturing_action, _pending_event)
		cancel_capture()
	get_viewport().set_input_as_handled()

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new(); scrim.color = UiTokens.SCRIM; scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(scrim)
	var panel := PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position = Vector2(-340, -300); panel.size = Vector2(680, 600); panel.theme = UiTokens.create_theme(); scrim.add_child(panel)
	resized.connect(func() -> void:
		panel.size = Vector2(minf(680.0, size.x - 32.0), minf(600.0, size.y - 32.0))
		panel.position = -panel.size * 0.5
	)
	var scroll := ScrollContainer.new(); panel.add_child(scroll)
	var content := VBoxContainer.new(); content.custom_minimum_size.x = 620; scroll.add_child(content)
	var title := Label.new(); title.text = "CONTROLES"; title.add_theme_font_size_override("font_size", 38); content.add_child(title)
	var device := Label.new(); device.text = "TECLADO Y MANDO · SELECCIONA UNA ACCIÓN PARA REASIGNAR"; device.add_theme_color_override("font_color", UiTokens.CYAN); content.add_child(device)
	for action in ACTIONS:
		var row := HBoxContainer.new(); row.custom_minimum_size.y = UiTokens.TOUCH_TARGET; content.add_child(row)
		var label := Label.new(); label.text = str(action).replace("_", " ").to_upper(); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
		var button := ActionButton.new(); button.text = _binding_text(action); button.pressed.connect(func(): begin_capture(action); button.text = "PRESIONA UNA ENTRADA…"); row.add_child(button); _binding_buttons[action] = button
	binding_captured.connect(func(action: StringName, _event: InputEvent) -> void:
		if _binding_buttons.has(action):
			(_binding_buttons[action] as Button).text = _binding_text(action)
	)
	var defaults := ActionButton.new(); defaults.text = "RESTAURAR ESTE MANDO"; defaults.pressed.connect(restore_controller_defaults); content.add_child(defaults)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func() -> void:
		if can_leave(): back_requested.emit()
	); content.add_child(back)

func _binding_text(action: StringName) -> String:
	var events: Array = profile.bindings.get(action, [])
	return (events.front() as InputEvent).as_text() if not events.is_empty() else "SIN ASIGNAR"

func _show_conflict(action: StringName, conflicting_action: StringName, _event: InputEvent) -> void:
	if _conflict_modal != null: _conflict_modal.queue_free()
	_conflict_modal = PanelContainer.new(); _conflict_modal.process_mode = Node.PROCESS_MODE_ALWAYS; _conflict_modal.set_anchors_preset(Control.PRESET_CENTER); _conflict_modal.position = Vector2(-260, -150); _conflict_modal.size = Vector2(520, 300); _conflict_modal.theme = UiTokens.create_theme(); add_child(_conflict_modal)
	var content := VBoxContainer.new(); _conflict_modal.add_child(content)
	var title := Label.new(); title.text = "ENTRADA EN CONFLICTO"; title.add_theme_font_size_override("font_size", 30); content.add_child(title)
	var message := Label.new(); message.text = "%s ya usa esta entrada. ¿Qué hacemos con %s?" % [str(conflicting_action).to_upper(), str(action).to_upper()]; message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(message)
	for descriptor in [[&"swap", "INTERCAMBIAR"], [&"replace", "REEMPLAZAR"], [&"cancel", "CANCELAR"]]:
		var button := ActionButton.new(); button.text = descriptor[1]; button.pressed.connect(_resolve_and_close.bind(descriptor[0])); content.add_child(button)
	(content.get_child(2) as Button).grab_focus.call_deferred()

func _resolve_and_close(resolution: StringName) -> void:
	resolve_conflict(resolution)
	if _conflict_modal != null: _conflict_modal.queue_free(); _conflict_modal = null

func _save_active_profile() -> void:
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		save_profile("", &"keyboard")
		return
	var id := int(joypads.front())
	save_profile(Input.get_joy_guid(id), _detect_family(Input.get_joy_name(id)))

func _detect_family(device_name: String) -> StringName:
	var value := device_name.to_lower()
	if "nintendo" in value or "switch" in value: return &"nintendo"
	if "dualshock" in value or "dualsense" in value or "playstation" in value: return &"playstation"
	if "xbox" in value or "xinput" in value: return &"xbox"
	return &"generic"
