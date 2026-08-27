class_name RaceConfigurationScreen
extends Control

signal configuration_confirmed(payload: Dictionary)
signal back_requested

var payload: Dictionary = {}
var _cc_buttons: Dictionary = {}
var _mode_toggle: CheckButton
var _ghost_status: Label
var _summary: Label
var _continue: ActionButton
var _back: ActionButton
var _content: VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiTokens.GRAPHITE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.position = Vector2(-420, -270)
	_content.size = Vector2(840, 540)
	_content.pivot_offset = _content.size * 0.5
	_content.add_theme_constant_override("separation", UiTokens.SPACE_3)
	add_child(_content)
	var eyebrow := Label.new()
	eyebrow.text = "CONFIGURACIÓN DEL EVENTO"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", UiTokens.CYAN)
	_content.add_child(eyebrow)
	var title := Label.new()
	title.text = "AJUSTA TU CARRERA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiTokens.FONT_H1)
	_content.add_child(title)
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_content.add_child(_summary)
	_add_label("CILINDRADA")
	var cc_flow := FlowContainer.new()
	cc_flow.name = "CcOptions"
	cc_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	cc_flow.add_theme_constant_override("h_separation", UiTokens.SPACE_2)
	cc_flow.add_theme_constant_override("v_separation", UiTokens.SPACE_2)
	_content.add_child(cc_flow)
	for definition in RaceClassDefinition.get_all():
		var button := _chip(definition.display_name)
		button.name = str(definition.id)
		button.pressed.connect(_select_cc.bind(definition.id))
		cc_flow.add_child(button)
		_cc_buttons[definition.id] = button
	_mode_toggle = CheckButton.new()
	_mode_toggle.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_mode_toggle.toggled.connect(_toggle_mode_option)
	_content.add_child(_mode_toggle)
	_ghost_status = Label.new()
	_ghost_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ghost_status.add_theme_color_override("font_color", UiTokens.CYAN)
	_content.add_child(_ghost_status)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", UiTokens.SPACE_3)
	_content.add_child(actions)
	_back = ActionButton.new()
	_back.text = "VOLVER"
	_back.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(_back)
	_continue = ActionButton.new()
	_continue.kind = ActionButton.Kind.PRIMARY
	_continue.text = "ELEGIR PISTA"
	_continue.pressed.connect(_confirm)
	actions.add_child(_continue)
	resized.connect(_update_layout)
	_update_layout()

func configure(value: Dictionary) -> void:
	payload = value.duplicate(true)
	var mode := int(payload.get("mode", GameModeDefinition.RACE))
	var is_trial := mode == GameModeDefinition.TIME_TRIAL
	_mode_toggle.text = "FANTASMA" if is_trial else "OBJETOS"
	_mode_toggle.visible = true
	_mode_toggle.set_pressed_no_signal(bool(payload.get("ghost_enabled", true)) if is_trial else bool(payload.get("items_enabled", true)))
	_ghost_status.text = "RÉCORD: %s" % ("DISPONIBLE" if bool(payload.get("ghost_available", false)) else "SIN REGISTRO") if is_trial else "OBJETOS · DISPONIBLES DURANTE LA CARRERA"
	_summary.text = "%s  ·  %s" % [_mode_name(mode), "CONTRARRELOJ" if is_trial else "CARRERA INDIVIDUAL"]
	_select_cc(StringName(payload.get("cc_id", RaceClassDefinition.DEFAULT_ID)), false)
	_update_layout()
	_focus_first()

func _add_label(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTokens.MUTED)
	label.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION)
	_content.add_child(label)

func _chip(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(110, UiTokens.TOUCH_TARGET)
	button.focus_mode = Control.FOCUS_ALL
	return button

func _select_cc(id: StringName, update_payload := true) -> void:
	var selected := RaceClassDefinition.get_by_id(id).id
	if update_payload: payload["cc_id"] = selected
	for key in _cc_buttons:
		_style_chip(_cc_buttons[key] as Button, key == selected)

func _style_chip(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	button.add_theme_stylebox_override("normal", UiTokens.panel(UiTokens.ELECTRIC_YELLOW if selected else UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL, UiTokens.ELECTRIC_YELLOW if selected else Color.TRANSPARENT))
	button.add_theme_color_override("font_color", UiTokens.GRAPHITE if selected else UiTokens.WARM_WHITE)

func _toggle_mode_option(enabled: bool) -> void:
	if int(payload.get("mode", GameModeDefinition.RACE)) == GameModeDefinition.TIME_TRIAL:
		payload["ghost_enabled"] = enabled
	else:
		payload["items_enabled"] = enabled

func _confirm() -> void:
	configuration_confirmed.emit(payload.duplicate(true))

func _focus_first() -> void:
	for child in _content.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			button.grab_focus.call_deferred()
			return

func _update_layout() -> void:
	if _content == null: return
	var viewport := size if size.x > 1.0 else get_viewport_rect().size
	var width := clampf(viewport.x - 32.0, 320.0, 900.0)
	_content.size.x = width
	_content.position.x = (viewport.x - width) * 0.5
	_content.position.y = maxf(16.0, (viewport.y - _content.size.y) * 0.5)
	_content.pivot_offset = _content.size * 0.5

func _mode_name(mode: int) -> String:
	return {GameModeDefinition.RACE: "CARRERA RÁPIDA", GameModeDefinition.TIME_TRIAL: "CONTRARRELOJ"}.get(mode, "EVENTO")
