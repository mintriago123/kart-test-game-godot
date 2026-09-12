class_name PreparationScreen
extends Control

signal start_requested(track_id: StringName, cc_id: StringName, mode: int, difficulty_id: StringName)
signal back_requested
signal change_vehicle_requested(payload: Dictionary)

var payload: Dictionary = {}
var start_button: ActionButton
var summary: Label
var _card: Control
var _scroll: ScrollContainer
var _grid: GridContainer
var _event_column: VBoxContainer
var _options_column: VBoxContainer
var _showroom: VehicleViewport
var _minimap: TrackMinimapView
var _cc_chips: FlowContainer
var _difficulty_chips: FlowContainer
var _mode_option: CheckButton
var _change_vehicle: ActionButton
var _back_button: ActionButton
var _focus_order: Array[Control] = []
var _cup: CupDefinition
var _track: TrackDefinition

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.GRAPHITE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(background)
	_scroll = TouchScrollContainer.new(); _scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _scroll.offset_left = 20; _scroll.offset_top = 14; _scroll.offset_right = -20; _scroll.offset_bottom = -92; _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _scroll.follow_focus = true; add_child(_scroll)
	var content := VBoxContainer.new(); content.name = "PreparationContent"; content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", UiTokens.SPACE_3); _scroll.add_child(content)
	var eyebrow := Label.new(); eyebrow.text = "PREPARACIÓN"; eyebrow.add_theme_color_override("font_color", UiTokens.CYAN); eyebrow.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION); content.add_child(eyebrow)
	var title := Label.new(); title.name = "Title"; title.text = "TODO LISTO"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", UiTokens.FONT_H1); content.add_child(title)
	_grid = GridContainer.new(); _card = _grid; _grid.name = "PreparationPanels"; _grid.columns = 3; _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; _grid.add_theme_constant_override("h_separation", UiTokens.SPACE_3); _grid.add_theme_constant_override("v_separation", UiTokens.SPACE_3); content.add_child(_grid)
	_event_column = VBoxContainer.new(); _event_column.name = "EventSummary"; _event_column.custom_minimum_size.x = 280; _event_column.add_theme_constant_override("separation", UiTokens.SPACE_2); _grid.add_child(_panel(_event_column, UiTokens.CYAN)); _add_heading(_event_column, "EVENTO")
	summary = Label.new(); summary.name = "EventSummaryText"; summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary.add_theme_font_size_override("font_size", UiTokens.FONT_BODY); _event_column.add_child(summary)
	_minimap = TrackMinimapView.new(); _minimap.name = "TrackMinimap"; _minimap.custom_minimum_size = Vector2(260, 170); _event_column.add_child(_minimap)
	_showroom = VehicleViewport.new(); _showroom.name = "VehicleShowroom"; _showroom.custom_minimum_size = Vector2(400, 330); _showroom.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _showroom.size_flags_vertical = Control.SIZE_SHRINK_CENTER; _showroom.set_framing(VehicleViewport.Framing.PREPARATION); _grid.add_child(_panel(_showroom, UiTokens.ELECTRIC_YELLOW))
	_options_column = VBoxContainer.new(); _options_column.name = "RaceConfiguration"; _options_column.custom_minimum_size.x = 280; _options_column.add_theme_constant_override("separation", UiTokens.SPACE_2); _grid.add_child(_panel(_options_column, UiTokens.CYAN)); _add_heading(_options_column, "CONFIGURACIÓN"); _add_label(_options_column, "CILINDRADA")
	_cc_chips = FlowContainer.new(); _cc_chips.name = "CcOptions"; _cc_chips.add_theme_constant_override("h_separation", UiTokens.SPACE_2); _cc_chips.add_theme_constant_override("v_separation", UiTokens.SPACE_2); _options_column.add_child(_cc_chips)
	for race_class in RaceClassDefinition.get_all():
		var chip := _chip("%s CC" % race_class.id); chip.name = str(race_class.id); chip.pressed.connect(_select_cc.bind(race_class.id)); _cc_chips.add_child(chip)
	_add_label(_options_column, "DIFICULTAD"); _difficulty_chips = FlowContainer.new(); _difficulty_chips.name = "DifficultyOptions"; _difficulty_chips.add_theme_constant_override("h_separation", UiTokens.SPACE_2); _difficulty_chips.add_theme_constant_override("v_separation", UiTokens.SPACE_2); _options_column.add_child(_difficulty_chips)
	_mode_option = CheckButton.new(); _mode_option.name = "ItemsOrGhost"; _mode_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET; _mode_option.toggled.connect(_toggle_mode_option); _options_column.add_child(_mode_option)
	_change_vehicle = ActionButton.new(); _change_vehicle.name = "ChangeVehicle"; _change_vehicle.text = "CAMBIAR VEHÍCULO"; _change_vehicle.pressed.connect(func(): change_vehicle_requested.emit(payload)); _options_column.add_child(_change_vehicle)
	var actions_panel := PanelContainer.new(); actions_panel.name = "ActionBar"; actions_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); actions_panel.offset_left = 20; actions_panel.offset_right = -20; actions_panel.offset_top = -82; actions_panel.offset_bottom = -10; actions_panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM, UiTokens.INK_RAISED)); add_child(actions_panel)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER; actions.add_theme_constant_override("separation", UiTokens.SPACE_3); actions_panel.add_child(actions)
	_back_button = ActionButton.new(); _back_button.name = "Back"; _back_button.text = "VOLVER"; _back_button.pressed.connect(func(): back_requested.emit()); actions.add_child(_back_button)
	start_button = ActionButton.new(); start_button.name = "Start"; start_button.kind = ActionButton.Kind.PRIMARY; start_button.text = "INICIAR CARRERA"; start_button.pressed.connect(_start); actions.add_child(start_button)
	resized.connect(_update_layout); _update_layout(); call_deferred("_update_layout")

func _panel(child: Control, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_LARGE, Color(accent, 0.32))); panel.add_child(child); return panel

func _add_heading(parent: VBoxContainer, text: String) -> void:
	var label := Label.new(); label.text = text; label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY); label.add_theme_font_size_override("font_size", UiTokens.FONT_H3); parent.add_child(label)

func _add_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new(); label.text = text; label.add_theme_color_override("font_color", UiTokens.MUTED); label.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION); parent.add_child(label)

func _chip(text: String) -> Button:
	var button := Button.new(); button.text = text; button.toggle_mode = true; button.focus_mode = Control.FOCUS_ALL; button.custom_minimum_size = Vector2(82, UiTokens.TOUCH_TARGET); button.add_theme_font_size_override("font_size", UiTokens.FONT_BODY); return button

func configure(value: Dictionary, track: TrackDefinition, variant: KartVariantDefinition, cup: CupDefinition = null) -> void:
	payload = value.duplicate(true); _cup = cup; _track = track
	var mode := int(payload.get("mode", 0)); var locked := bool(payload.get("continue_active", false)); _minimap.set_minimap_data(track.preview_map if track != null else null); _showroom.show_variant(variant); _select_cc(StringName(payload.get("cc_id", &"150")), false)
	for child in _difficulty_chips.get_children(): child.free()
	if cup != null:
		for difficulty in cup.difficulties:
			var chip := _chip(difficulty.display_name.to_upper()); chip.name = str(difficulty.id); chip.pressed.connect(_select_difficulty.bind(difficulty.id)); _difficulty_chips.add_child(chip)
	_select_difficulty(StringName(payload.get("difficulty_id", &"competitive")), false); _difficulty_chips.visible = cup != null
	for chip in _cc_chips.get_children(): (chip as Button).disabled = locked
	for chip in _difficulty_chips.get_children(): (chip as Button).disabled = locked
	_mode_option.visible = cup == null; _mode_option.text = "FANTASMA" if mode == GameModeDefinition.TIME_TRIAL else "OBJETOS"; _mode_option.set_pressed_no_signal(bool(payload.get("ghost_enabled", true)) if mode == GameModeDefinition.TIME_TRIAL else bool(payload.get("items_enabled", true))); _mode_option.disabled = locked; _change_vehicle.disabled = locked; _change_vehicle.tooltip_text = "Vehículo fijado durante una Copa activa" if locked else ""
	var event_name := cup.display_name.to_upper() if cup != null else (track.display_name.to_upper() if track else "EVENTO"); var vehicle_name := variant.display_name.to_upper() if variant else "VEHÍCULO BASE"
	if locked: summary.text = "COPA ACTIVA\n%s\n%s\n🔒 CONFIGURACIÓN FIJADA" % [track.display_name.to_upper() if track else "—", vehicle_name]
	elif cup != null:
		var tracks := PackedStringArray(); for cup_track in cup.tracks: tracks.append(cup_track.display_name)
		summary.text = "%s\n%s\nVEHÍCULO · %s" % [event_name, " → ".join(tracks), vehicle_name]
	elif mode == GameModeDefinition.TIME_TRIAL: summary.text = "%s\n%s\nCONTRARRELOJ · FANTASMA %s\nREFERENCIA · %s" % [event_name, vehicle_name, "SÍ" if bool(payload.get("ghost_enabled", true)) else "NO", "DISPONIBLE" if bool(payload.get("ghost_available", false)) else "SIN REGISTRO"]
	elif mode == GameModeDefinition.LOCAL_MULTIPLAYER: summary.text = "%s\n2 JUGADORES + 6 IA\nOBJETOS %s" % [event_name, "SÍ" if bool(payload.get("items_enabled", true)) else "NO"]
	elif mode == GameModeDefinition.LAN_MULTIPLAYER: summary.text = "%s\nHASTA 4 JUGADORES · PARRILLA DE 8\nOBJETOS %s" % [event_name, "SÍ" if bool(payload.get("items_enabled", true)) else "NO"]
	else: summary.text = "%s\nVEHÍCULO · %s\nOBJETOS %s" % [event_name, vehicle_name, "SÍ" if bool(payload.get("items_enabled", true)) else "NO"]
	start_button.text = "SIGUIENTE CARRERA" if locked else ("INICIAR CONTRARRELOJ" if mode == GameModeDefinition.TIME_TRIAL else ("INICIAR COPA" if mode == GameModeDefinition.CUP else "INICIAR CARRERA")); _update_focus_order(); _focus_first_available(); _update_layout(); call_deferred("_update_layout")


func set_graphics_profile(profile: String) -> void:
	if _showroom != null:
		_showroom.set_quality(profile)

func _select_cc(id: StringName, update_payload := true) -> void:
	if update_payload: payload["cc_id"] = id
	var focus_target: Button = null
	for chip in _cc_chips.get_children():
		var button := chip as Button
		var is_selected := button.name == str(id)
		_style_chip(button, is_selected)
		if is_selected:
			focus_target = button
	if focus_target != null and is_instance_valid(focus_target):
		focus_target.grab_focus.call_deferred()

func _select_difficulty(id: StringName, update_payload := true) -> void:
	if update_payload: payload["difficulty_id"] = id
	var focus_target: Button = null
	for chip in _difficulty_chips.get_children():
		var button := chip as Button
		var is_selected := button.name == str(id)
		_style_chip(button, is_selected)
		if is_selected:
			focus_target = button
	if focus_target != null and is_instance_valid(focus_target):
		focus_target.grab_focus.call_deferred()

func _style_chip(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	var bg_selected := UiTokens.ELECTRIC_YELLOW
	var bg_unselected := UiTokens.INK_RAISED
	var bg_hover_unselected := UiTokens.INK_RAISED.lightened(0.08)
	var border_selected := UiTokens.ELECTRIC_YELLOW
	var border_focus := UiTokens.WARM_WHITE
	var border_width := 4 if selected else 0
	button.add_theme_stylebox_override(
		"normal",
		_chip_style(bg_selected if selected else bg_unselected, border_selected, border_width)
	)
	button.add_theme_stylebox_override(
		"hover",
		_chip_style(
			bg_selected.lightened(0.05) if selected else bg_hover_unselected,
			border_selected if selected else UiTokens.CYAN,
			border_width if selected else 2
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_chip_style(
			bg_selected.darkened(0.14) if selected else bg_unselected.darkened(0.14),
			border_selected,
			border_width if selected else 2
		)
	)
	button.add_theme_stylebox_override(
		"focus",
		_chip_style(
			bg_selected if selected else bg_unselected,
			border_focus,
			4
		)
	)
	button.add_theme_color_override("font_color", UiTokens.GRAPHITE if selected else UiTokens.WARM_WHITE)
	button.add_theme_color_override("font_hover_color", UiTokens.GRAPHITE if selected else UiTokens.WARM_WHITE)


func _chip_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.corner_radius_top_left = UiTokens.RADIUS_SMALL
	box.corner_radius_top_right = UiTokens.RADIUS_SMALL
	box.corner_radius_bottom_left = UiTokens.RADIUS_SMALL
	box.corner_radius_bottom_right = UiTokens.RADIUS_SMALL
	box.content_margin_left = UiTokens.SPACE_4
	box.content_margin_right = UiTokens.SPACE_4
	box.content_margin_top = UiTokens.SPACE_3
	box.content_margin_bottom = UiTokens.SPACE_3
	if border.a > 0.0 and border_width > 0:
		box.set_border_width_all(border_width)
		box.border_color = border
	return box

func _toggle_mode_option(enabled: bool) -> void:
	if int(payload.get("mode", 0)) == GameModeDefinition.TIME_TRIAL: payload["ghost_enabled"] = enabled
	else: payload["items_enabled"] = enabled

func _start() -> void:
	start_requested.emit(payload.get("track_id", &""), payload.get("cc_id", &"150"), int(payload.get("mode", 0)), payload.get("difficulty_id", &"competitive"))

func _update_focus_order() -> void:
	_focus_order.clear(); for child in _cc_chips.get_children(): _focus_order.append(child as Control)
	if _difficulty_chips.visible: for child in _difficulty_chips.get_children(): _focus_order.append(child as Control)
	if _mode_option.visible: _focus_order.append(_mode_option)
	_focus_order.append(_change_vehicle); _focus_order.append(start_button)
	if _focus_order.is_empty(): return
	for index in _focus_order.size():
		var control := _focus_order[index]; control.focus_neighbor_bottom = _focus_order[(index + 1) % _focus_order.size()].get_path(); control.focus_neighbor_top = _focus_order[(index - 1 + _focus_order.size()) % _focus_order.size()].get_path()
	for group in [_cc_chips, _difficulty_chips]:
		for index in group.get_child_count():
			var control := group.get_child(index) as Control; control.focus_neighbor_left = group.get_child(maxi(0, index - 1)).get_path(); control.focus_neighbor_right = group.get_child(mini(group.get_child_count() - 1, index + 1)).get_path()

func _focus_first_available() -> void:
	for control in _focus_order:
		if control is Button and (control as Button).button_pressed \
				and control.is_visible_in_tree() and not (control as BaseButton).disabled:
			control.grab_focus.call_deferred()
			return
	for control in _focus_order:
		if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE \
				and not (control is BaseButton and (control as BaseButton).disabled):
			control.grab_focus.call_deferred()
			return

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and _back_button != null: _back_button.grab_focus()

func _update_layout() -> void:
	if _grid == null: return
	var layout_size := size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size; var compact := layout_size.x < UiTokens.BREAKPOINT_COLUMNS_WIDTH or layout_size.y < UiTokens.BREAKPOINT_COLUMNS_HEIGHT; _grid.columns = 1 if compact else 3; _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if compact else ScrollContainer.SCROLL_MODE_DISABLED
	_showroom.custom_minimum_size = Vector2(maxf(300.0, layout_size.x - 96.0), clampf(layout_size.y * 0.42, 230.0, 340.0)) if compact else Vector2(400.0, 280.0 if layout_size.y < 800.0 else 360.0)
