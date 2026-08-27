class_name SettingsScreen
extends Control

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

signal graphics_profile_changed(profile: String)
signal vibration_changed(enabled: bool)
signal volume_changed(value: float)
signal music_volume_changed(value: float)
signal effects_volume_changed(value: float)
signal camera_motion_changed(mode: String)
signal speed_lines_changed(enabled: bool)
signal threat_indicators_changed(enabled: bool)
signal vibration_intensity_changed(value: float)
signal reduced_motion_changed(enabled: bool)
signal gamepad_family_changed(family: StringName)
signal ghost_enabled_changed(enabled: bool)
signal controls_requested
signal restore_defaults_requested
signal apply_changes_requested
signal discard_changes_requested
signal back_requested

var _controls: Dictionary = {}
var gamepad_family_selector: OptionButton
var _category_buttons: Array[Button] = []
var _category_pages: Array[Control] = []
var _page_controls: Array[Array] = []
var _last_focus_by_category: Dictionary = {}
var _active_category := 0
var _scroll: ScrollContainer
var _apply_button: Button
var _discard_button: Button
var _back_button: Button
var _pending := false
var _snapshot: Dictionary = {}
var _suppress_changes := false
var _ghost_toggle: CheckButton

const CATEGORIES := ["JUEGO", "GRÁFICOS", "AUDIO", "ACCESIBILIDAD", "CONTROLES"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func apply_snapshot(settings: GameSettings) -> void:
	if settings == null or _controls.is_empty(): return
	_suppress_changes = true
	(_controls.profile as OptionButton).select(["low", "medium", "high", "ultra"].find(settings.graphics_profile))
	(_controls.vibration as CheckButton).set_pressed_no_signal(settings.vibration_enabled)
	(_controls.master as HSlider).set_value_no_signal(settings.master_volume)
	(_controls.music as HSlider).set_value_no_signal(settings.music_volume)
	(_controls.effects as HSlider).set_value_no_signal(settings.effects_volume)
	(_controls.camera as OptionButton).select(["reduced", "full", "off"].find(settings.camera_motion))
	(_controls.speed_lines as CheckButton).set_pressed_no_signal(settings.speed_lines_enabled)
	(_controls.threats as CheckButton).set_pressed_no_signal(settings.threat_indicators_enabled)
	(_controls.intensity as HSlider).set_value_no_signal(settings.vibration_intensity)
	(_controls.reduced_motion as CheckButton).set_pressed_no_signal(settings.ui_reduced_motion)
	_ghost_toggle.set_pressed_no_signal(settings.ghost_enabled)
	gamepad_family_selector.select(_family_index(settings.gamepad_visual_family))
	_snapshot = _read_deferred_values(); _pending = false; _update_pending_actions(); _suppress_changes = false

func focus_first_control() -> void:
	_set_category(0, false); _focus_category_control(0)

func has_pending_changes() -> bool:
	return _pending

func apply_pending_changes() -> void:
	if not _pending: return
	_pending = false; _snapshot = _read_deferred_values(); _update_pending_actions()
	graphics_profile_changed.emit(["low", "medium", "high", "ultra"][_controls.profile.selected])
	camera_motion_changed.emit(["reduced", "full", "off"][_controls.camera.selected])
	speed_lines_changed.emit(_controls.speed_lines.button_pressed)
	threat_indicators_changed.emit(_controls.threats.button_pressed)
	reduced_motion_changed.emit(_controls.reduced_motion.button_pressed)
	apply_changes_requested.emit()

func discard_pending_changes() -> void:
	if _pending: _apply_deferred_dictionary(_snapshot)
	_pending = false; _update_pending_actions(); discard_changes_requested.emit()

func _build() -> void:
	theme = UiTokens.create_theme()
	var scrim := ColorRect.new(); scrim.color = UiTokens.SCRIM; scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scrim.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(scrim)
	var card := PanelContainer.new(); card.set_anchors_preset(Control.PRESET_CENTER); card.size = Vector2(600, 330); card.position = -card.size * 0.5; card.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_LARGE)); add_child(card)
	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation", UiTokens.SPACE_3); card.add_child(outer)
	var heading := HBoxContainer.new(); outer.add_child(heading)
	var title := Label.new(); title.text = "AJUSTES"; title.add_theme_font_size_override("font_size", 34); title.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY); heading.add_child(title)
	var pending_label := Label.new(); pending_label.name = "PendingLabel"; pending_label.text = "CAMBIOS PENDIENTES"; pending_label.visible = false; pending_label.add_theme_color_override("font_color", UiTokens.ELECTRIC_YELLOW); pending_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; heading.add_child(pending_label)
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", UiTokens.SPACE_3); outer.add_child(body)
	var nav := VBoxContainer.new(); nav.custom_minimum_size.x = 190; nav.add_theme_constant_override("separation", 6); body.add_child(nav)
	var content_panel := PanelContainer.new(); content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content_panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_MEDIUM)); body.add_child(content_panel)
	_scroll = ScrollContainer.new(); _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; content_panel.add_child(_scroll)
	var pages_host := VBoxContainer.new(); pages_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _scroll.add_child(pages_host)
	for index in CATEGORIES.size():
		var category := Button.new(); category.text = CATEGORIES[index]; category.alignment = HORIZONTAL_ALIGNMENT_LEFT; category.custom_minimum_size.y = UiTokens.TOUCH_TARGET; category.pressed.connect(_set_category.bind(index, true)); nav.add_child(category); _category_buttons.append(category)
		var page := VBoxContainer.new(); page.add_theme_constant_override("separation", UiTokens.SPACE_3); page.size_flags_horizontal = Control.SIZE_EXPAND_FILL; page.visible = index == 0; pages_host.add_child(page); _category_pages.append(page); _page_controls.append([])
	_build_gameplay(_category_pages[0]); _build_graphics(_category_pages[1]); _build_audio(_category_pages[2]); _build_accessibility(_category_pages[3]); _build_controls(_category_pages[4])
	var footer := HBoxContainer.new(); footer.alignment = BoxContainer.ALIGNMENT_END; footer.add_theme_constant_override("separation", 8); outer.add_child(footer)
	_apply_button = _action("APLICAR", UiTokens.ELECTRIC_YELLOW); _apply_button.visible = false; _apply_button.pressed.connect(apply_pending_changes); footer.add_child(_apply_button)
	_discard_button = _action("DESCARTAR", UiTokens.WARM_WHITE); _discard_button.visible = false; _discard_button.pressed.connect(discard_pending_changes); footer.add_child(_discard_button)
	var defaults := _action("RESTABLECER", UiTokens.CYAN); defaults.pressed.connect(restore_defaults_requested.emit); footer.add_child(defaults)
	_back_button = _action("VOLVER", UiTokens.CORAL); _back_button.pressed.connect(_request_back); footer.add_child(_back_button)
	for controls in _page_controls:
		if not controls.is_empty():
			(controls.back() as Control).focus_neighbor_bottom = _back_button.get_path()
	_back_button.focus_neighbor_top = (_page_controls[0].back() as Control).get_path()
	resized.connect(func() -> void: card.size = Vector2(minf(940.0, size.x - 28.0), minf(620.0, size.y - 28.0)); card.position = -card.size * 0.5)

func _build_gameplay(page: VBoxContainer) -> void:
	_add_heading(page, "JUEGO", "Ajustes que se sienten al volante.")
	_ghost_toggle = _toggle(page, "Mostrar fantasma", true, func(value: bool) -> void: ghost_enabled_changed.emit(value)); _track_control(0, _ghost_toggle)

func _build_graphics(page: VBoxContainer) -> void:
	_add_heading(page, "GRÁFICOS", "La pista responde a tu equipo.")
	_controls.profile = _option(page, "CALIDAD", ["BAJA", "MEDIA", "ALTA", "ULTRA"], func(_index: int) -> void: _mark_pending()); _track_control(1, _controls.profile)
	_controls.speed_lines = _toggle(page, "Líneas de velocidad", true, func(_value: bool) -> void: _mark_pending()); _track_control(1, _controls.speed_lines)

func _build_audio(page: VBoxContainer) -> void:
	_add_heading(page, "AUDIO", "Mezcla el motor a tu gusto.")
	_controls.master = _slider(page, "VOLUMEN GENERAL", func(value: float) -> void: volume_changed.emit(value)); _controls.music = _slider(page, "MÚSICA", func(value: float) -> void: music_volume_changed.emit(value)); _controls.effects = _slider(page, "EFECTOS", func(value: float) -> void: effects_volume_changed.emit(value))
	_track_control(2, _controls.master); _track_control(2, _controls.music); _track_control(2, _controls.effects)

func _build_accessibility(page: VBoxContainer) -> void:
	_add_heading(page, "ACCESIBILIDAD", "Reduce el ruido visual sin perder información.")
	_controls.camera = _option(page, "MOVIMIENTO DE CÁMARA", ["REDUCIDO", "COMPLETO", "DESACTIVADO"], func(_index: int) -> void: _mark_pending()); _controls.threats = _toggle(page, "Indicadores de amenaza", true, func(_value: bool) -> void: _mark_pending()); _controls.reduced_motion = _toggle(page, "Reducir movimiento de menús", false, func(value: bool) -> void: _mark_pending(); reduced_motion_changed.emit(value)); _controls.vibration = _toggle(page, "Vibración", true, func(value: bool) -> void: vibration_changed.emit(value)); _controls.intensity = _slider(page, "INTENSIDAD DE VIBRACIÓN", func(value: float) -> void: vibration_intensity_changed.emit(value))
	for control in [_controls.camera, _controls.threats, _controls.reduced_motion, _controls.vibration, _controls.intensity]: _track_control(3, control)

func _build_controls(page: VBoxContainer) -> void:
	_add_heading(page, "CONTROLES", "La imagen de los botones se adapta a tu mando.")
	var label := Label.new(); label.text = "FAMILIA VISUAL DEL MANDO"; label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY); page.add_child(label)
	gamepad_family_selector = OptionButton.new(); gamepad_family_selector.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	for family_name in ["AUTOMÁTICA", "XBOX / GENÉRICO", "PLAYSTATION", "NINTENDO"]: gamepad_family_selector.add_item(family_name)
	gamepad_family_selector.item_selected.connect(func(index: int) -> void: gamepad_family_changed.emit([&"automatic", &"xbox", &"playstation", &"nintendo"][index])); page.add_child(gamepad_family_selector); _track_control(4, gamepad_family_selector)
	var customize := _action("REASIGNAR CONTROLES", UiTokens.CYAN); customize.pressed.connect(controls_requested.emit); page.add_child(customize); _track_control(4, customize)

func _add_heading(page: VBoxContainer, title: String, subtitle: String) -> void:
	var heading := Label.new(); heading.text = title; heading.add_theme_font_size_override("font_size", 24); heading.add_theme_color_override("font_color", UiTokens.CYAN); page.add_child(heading)
	var detail := Label.new(); detail.text = subtitle; detail.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY); page.add_child(detail)

func _toggle(page: VBoxContainer, text: String, initial: bool, callback: Callable) -> CheckButton:
	var control := CheckButton.new(); control.text = text; control.button_pressed = initial; control.custom_minimum_size.y = UiTokens.TOUCH_TARGET; control.toggled.connect(func(value: bool) -> void: if not _suppress_changes: callback.call(value)); page.add_child(control); return control

func _slider(page: VBoxContainer, text: String, callback: Callable) -> HSlider:
	var group := VBoxContainer.new(); group.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var label := Label.new(); label.text = text; label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY); group.add_child(label)
	var control := HSlider.new(); control.min_value = 0.0; control.max_value = 1.0; control.step = 0.05; control.value = 1.0; control.custom_minimum_size.y = UiTokens.TOUCH_TARGET; control.value_changed.connect(func(value: float) -> void: if not _suppress_changes: callback.call(value)); group.add_child(control); page.add_child(group); return control

func _option(page: VBoxContainer, text: String, items: Array, callback: Callable) -> OptionButton:
	var label := Label.new(); label.text = text; label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY); page.add_child(label); var control := OptionButton.new(); control.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	for item in items: control.add_item(item)
	control.item_selected.connect(func(index: int) -> void: if not _suppress_changes: callback.call(index)); page.add_child(control); return control

func _action(text: String, color: Color) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = UiTokens.TOUCH_TARGET; RaceHudStyle.apply_button_style(button, color); return button

func _track_control(category: int, control: Control) -> void:
	_page_controls[category].append(control); control.focus_entered.connect(func() -> void: _last_focus_by_category[category] = control; if _scroll != null: _scroll.ensure_control_visible(control))

func _set_category(category: int, focus_content := true) -> void:
	_active_category = clampi(category, 0, CATEGORIES.size() - 1)
	for index in _category_pages.size(): _category_pages[index].visible = index == _active_category
	for index in _category_buttons.size(): _category_buttons[index].modulate = UiTokens.ELECTRIC_YELLOW if index == _active_category else Color.WHITE
	if focus_content: _focus_category_control(_active_category)

func _focus_category_control(category: int) -> void:
	var remembered := _last_focus_by_category.get(category) as Control
	if is_instance_valid(remembered) and remembered.is_visible_in_tree(): remembered.grab_focus(); return
	for control in _page_controls[category]:
		if control is Control and (control as Control).is_visible_in_tree() and (control as Control).focus_mode != Control.FOCUS_NONE: (control as Control).grab_focus(); return

func _read_deferred_values() -> Dictionary:
	return {"profile": _controls.profile.selected, "camera": _controls.camera.selected, "speed_lines": _controls.speed_lines.button_pressed, "threats": _controls.threats.button_pressed, "reduced_motion": _controls.reduced_motion.button_pressed}

func _apply_deferred_dictionary(values: Dictionary) -> void:
	_suppress_changes = true; _controls.profile.select(int(values.get("profile", 1))); _controls.camera.select(int(values.get("camera", 0))); _controls.speed_lines.set_pressed_no_signal(bool(values.get("speed_lines", true))); _controls.threats.set_pressed_no_signal(bool(values.get("threats", true))); _controls.reduced_motion.set_pressed_no_signal(bool(values.get("reduced_motion", false))); _suppress_changes = false

func _mark_pending() -> void:
	if _suppress_changes: return
	_pending = _read_deferred_values() != _snapshot; _update_pending_actions()

func _update_pending_actions() -> void:
	if _apply_button == null: return
	_apply_button.visible = _pending; _discard_button.visible = _pending; var pending_label := find_child("PendingLabel", true, false) as Label; if pending_label != null: pending_label.visible = _pending

func _request_back() -> void:
	if not _pending:
		back_requested.emit(); return
	var modal := PanelContainer.new(); modal.process_mode = Node.PROCESS_MODE_ALWAYS; modal.set_anchors_preset(Control.PRESET_CENTER); modal.position = Vector2(-230, -145); modal.size = Vector2(460, 290); modal.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM)); add_child(modal)
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation", 10); modal.add_child(content)
	var title := Label.new(); title.text = "CAMBIOS PENDIENTES"; title.add_theme_font_size_override("font_size", 24); content.add_child(title)
	var message := Label.new(); message.text = "¿Qué quieres hacer con los cambios de gráficos y accesibilidad?"; message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(message)
	var apply := _action("APLICAR Y VOLVER", UiTokens.ELECTRIC_YELLOW); apply.pressed.connect(func() -> void: apply_pending_changes(); modal.queue_free(); back_requested.emit()); content.add_child(apply)
	var discard := _action("DESCARTAR Y VOLVER", UiTokens.CORAL); discard.pressed.connect(func() -> void: discard_pending_changes(); modal.queue_free(); back_requested.emit()); content.add_child(discard)
	var stay := _action("SEGUIR EDITANDO", UiTokens.WARM_WHITE); stay.pressed.connect(modal.queue_free); content.add_child(stay)
	apply.grab_focus.call_deferred()

func _family_index(family: StringName) -> int:
	return {&"automatic": 0, &"xbox": 1, &"generic": 1, &"playstation": 2, &"nintendo": 3}.get(family, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_right") and _is_category_focused(): _focus_category_control(_active_category)
	elif event.is_action_pressed(&"ui_left") and _is_content_focused(): _category_buttons[_active_category].grab_focus()

func _is_category_focused() -> bool:
	return _category_buttons.has(get_viewport().gui_get_focus_owner())

func _is_content_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner(); return focus != null and _category_pages[_active_category].is_ancestor_of(focus)
