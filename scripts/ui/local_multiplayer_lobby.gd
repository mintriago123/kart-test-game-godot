class_name LocalMultiplayerLobby
extends Control

signal participants_confirmed(participants: Array)
signal back_requested
signal vehicle_pick_requested(slot: int, current_variant_id: StringName)

var catalog: ProgressionCatalog
var progress: PlayerProgress
var _racer_options: Array[OptionButton] = []
var _vehicle_buttons: Array[Button] = []
var _vehicle_ids: Array[StringName] = []
var _device_options: Array[OptionButton] = []
var _ready_toggles: Array[CheckButton] = []
var _portraits: Array[RacerPortrait] = []
var _pilot_names: Array[Label] = []
var _player_summaries: Array[Label] = []
var _ready_badges: Array[Label] = []
var _status: Label
var _start: ActionButton
var _gamepad_ids: Array[int] = []
var _mock_gamepads := false
var _page: Control
var _actions: HBoxContainer
var _cards: GridContainer
var _card_scroll: ScrollContainer
var _title: Label
var _back_button: ActionButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiTokens.GRAPHITE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var page := VBoxContainer.new()
	_page = page
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 24.0
	page.offset_top = 18.0
	page.offset_right = -24.0
	page.offset_bottom = -104.0
	page.add_theme_constant_override("separation", UiTokens.SPACE_4)
	add_child(page)
	var eyebrow := Label.new()
	eyebrow.text = "PARRILLA LOCAL · 8 CORREDORES"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color", UiTokens.CYAN)
	page.add_child(eyebrow)
	var title := Label.new()
	_title = title
	title.text = "DOS JUGADORES, UNA PANTALLA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	page.add_child(title)
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "PlayersScroll"
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_card_scroll.follow_focus = true
	_card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_card_scroll)
	var cards := GridContainer.new()
	_cards = cards
	cards.columns = 2
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", UiTokens.SPACE_6)
	cards.add_theme_constant_override("v_separation", UiTokens.SPACE_4)
	_card_scroll.add_child(cards)
	for index in 2:
		cards.add_child(_build_player_card(index))
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiTokens.MUTED)
	page.add_child(_status)
	var actions := HBoxContainer.new()
	_actions = actions
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_set_action_bar(actions)
	add_child(actions)
	_back_button = ActionButton.new()
	_back_button.text = "VOLVER"
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(_back_button)
	_start = ActionButton.new()
	_start.kind = ActionButton.Kind.PRIMARY
	_start.text = "ELEGIR CIRCUITO"
	_start.pressed.connect(_confirm)
	actions.add_child(_start)
	_back_button.focus_neighbor_right = _start.get_path()
	_start.focus_neighbor_left = _back_button.get_path()
	_wire_focus_order()
	# The first player selector is the useful entry point for both keyboard and pad.
	_device_options[0].grab_focus.call_deferred()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_gamepads()
	_refresh_state()
	resized.connect(_update_layout)
	_update_layout()


func configure(value_catalog: ProgressionCatalog, value_progress: PlayerProgress) -> void:
	catalog = value_catalog
	progress = value_progress
	if not is_node_ready():
		return
	_populate_catalog_options()
	_refresh_gamepads()
	_refresh_state()


func set_mock_gamepads(ids: Array[int]) -> void:
	_mock_gamepads = true
	_gamepad_ids.assign(ids)
	_refresh_device_options()
	_refresh_state()


func get_participants() -> Array[RaceParticipantConfig]:
	var result: Array[RaceParticipantConfig] = []
	if catalog == null or catalog.racers == null or catalog.unlocks == null:
		return result
	for index in 2:
		var racer := catalog.racers.get_racer(StringName(_racer_options[index].get_item_metadata(_racer_options[index].selected)))
		var vehicle := catalog.unlocks.get_variant(_vehicle_ids[index])
		var device_metadata: Dictionary = _device_options[index].get_item_metadata(_device_options[index].selected)
		result.append(RaceParticipantConfig.create(
			index,
			racer,
			vehicle,
			RaceParticipantConfig.ControlType.LOCAL,
			StringName(device_metadata.get("type", RaceParticipantConfig.DEVICE_NONE)),
			int(device_metadata.get("id", -1))
		))
	return result


func _build_player_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Player%dCard" % (index + 1)
	card.custom_minimum_size = Vector2(430, 370)
	card.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_LARGE, UiTokens.CYAN if index == 0 else UiTokens.CORAL))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.SPACE_3)
	card.add_child(column)
	var heading := Label.new()
	heading.text = "%02d  ·  JUGADOR %d" % [index + 1, index + 1]
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", UiTokens.CYAN if index == 0 else UiTokens.CORAL)
	column.add_child(heading)
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", UiTokens.SPACE_4)
	column.add_child(hero)
	var portrait := RacerPortrait.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(88, 88)
	hero.add_child(portrait)
	_portraits.append(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(identity)
	var pilot_name := Label.new()
	pilot_name.name = "PilotName"
	pilot_name.text = "PILOTO SIN ELEGIR"
	pilot_name.add_theme_font_size_override("font_size", 22)
	pilot_name.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	pilot_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(pilot_name)
	_pilot_names.append(pilot_name)
	var summary := Label.new()
	summary.name = "SelectionSummary"
	summary.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
	summary.add_theme_color_override("font_color", UiTokens.MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(summary)
	_player_summaries.append(summary)
	_add_field_label(column, "DISPOSITIVO")
	var device := OptionButton.new()
	device.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	device.item_selected.connect(func(_value: int) -> void: _refresh_state())
	column.add_child(device)
	_device_options.append(device)
	_add_field_label(column, "PILOTO")
	var racer := OptionButton.new()
	racer.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	racer.item_selected.connect(func(_value: int) -> void: _refresh_state())
	column.add_child(racer)
	_racer_options.append(racer)
	_add_field_label(column, "VEHÍCULO")
	var vehicle := Button.new()
	vehicle.text = "ELEGIR VEHÍCULO"
	vehicle.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	vehicle.pressed.connect(func() -> void: vehicle_pick_requested.emit(index, _vehicle_ids[index]))
	column.add_child(vehicle)
	_vehicle_buttons.append(vehicle)
	_vehicle_ids.append(&"")
	var ready := CheckButton.new()
	ready.text = "LISTO PARA CORRER"
	ready.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	ready.toggled.connect(func(_value: bool) -> void: _refresh_state())
	var ready_row := HBoxContainer.new()
	ready_row.add_theme_constant_override("separation", UiTokens.SPACE_3)
	ready_row.add_child(ready)
	var ready_badge := _status_badge("FALTA", UiTokens.CORAL)
	ready_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	ready_row.add_child(ready_badge)
	column.add_child(ready_row)
	_ready_toggles.append(ready)
	_ready_badges.append(ready_badge)
	return card


func _wire_focus_order() -> void:
	# Wired top-to-bottom within each card only (not left/right across cards):
	# the grid collapses to a single column in compact layouts, so a
	# left/right link between P1 and P2 would be wrong whenever the cards are
	# stacked instead of side by side.
	for index in 2:
		var chain: Array[Control] = [
			_device_options[index], _racer_options[index], _vehicle_buttons[index], _ready_toggles[index]
		]
		for chain_index in chain.size() - 1:
			chain[chain_index].focus_neighbor_bottom = chain[chain_index + 1].get_path()
			chain[chain_index + 1].focus_neighbor_top = chain[chain_index].get_path()
		chain.back().focus_neighbor_bottom = _back_button.get_path()


func _add_field_label(parent: VBoxContainer, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UiTokens.MUTED)
	parent.add_child(label)


func _populate_catalog_options() -> void:
	for option in _racer_options:
		option.clear()
	if catalog == null:
		return
	for racer in catalog.racers.racers:
		for option in _racer_options:
			option.add_item(racer.display_name.to_upper())
			option.set_item_metadata(option.item_count - 1, racer.id)
	if _racer_options.size() == 2 and _racer_options[1].item_count > 1:
		_racer_options[1].select(1)
	var default_variant_id := _default_variant_id()
	for index in _vehicle_ids.size():
		_vehicle_ids[index] = default_variant_id
		_update_vehicle_button(index)


func _default_variant_id() -> StringName:
	if catalog == null or catalog.unlocks == null:
		return &""
	if progress != null and progress.can_equip(progress.equipped_kart_variant_id, catalog.unlocks):
		return progress.equipped_kart_variant_id
	for variant in catalog.unlocks.variants:
		if progress == null or progress.can_equip(variant.id, catalog.unlocks):
			return variant.id
	return catalog.unlocks.variants[0].id if not catalog.unlocks.variants.is_empty() else &""


func _update_vehicle_button(index: int) -> void:
	if index >= _vehicle_buttons.size():
		return
	var variant := catalog.unlocks.get_variant(_vehicle_ids[index]) if catalog != null and catalog.unlocks != null else null
	_vehicle_buttons[index].text = variant.display_name.to_upper() if variant != null else "ELEGIR VEHÍCULO"


func apply_picked_vehicle(slot: int, variant_id: StringName) -> void:
	if slot < 0 or slot >= _vehicle_ids.size():
		return
	_vehicle_ids[slot] = variant_id
	_update_vehicle_button(slot)
	_refresh_state()


func _refresh_gamepads() -> void:
	if not _mock_gamepads:
		_gamepad_ids.assign(Input.get_connected_joypads())
	_refresh_device_options()


func _refresh_device_options() -> void:
	if _device_options.size() < 2:
		return
	var previous := []
	for option in _device_options:
		previous.append(option.get_item_metadata(option.selected) if option.item_count > 0 else {})
		option.clear()
	_add_device(_device_options[0], "TECLADO · WASD", RaceParticipantConfig.DEVICE_KEYBOARD, -1)
	for gamepad_id in _gamepad_ids:
		var label := "MANDO %d · %s" % [gamepad_id + 1, Input.get_joy_name(gamepad_id) if not _mock_gamepads else "PRUEBA"]
		_add_device(_device_options[0], label, RaceParticipantConfig.DEVICE_GAMEPAD, gamepad_id)
		_add_device(_device_options[1], label, RaceParticipantConfig.DEVICE_GAMEPAD, gamepad_id)
	for index in _device_options.size():
		_select_device_metadata(_device_options[index], previous[index])
	if _device_options[1].item_count == 0:
		_add_device(_device_options[1], "CONECTA UN MANDO", RaceParticipantConfig.DEVICE_NONE, -1)
		_device_options[1].disabled = true
	else:
		_device_options[1].disabled = false


func _add_device(option: OptionButton, label: String, type: StringName, id: int) -> void:
	option.add_item(label)
	option.set_item_metadata(option.item_count - 1, {"type": type, "id": id})


func _select_device_metadata(option: OptionButton, metadata: Variant) -> void:
	if not metadata is Dictionary:
		return
	for index in option.item_count:
		if option.get_item_metadata(index) == metadata:
			option.select(index)
			return


func _refresh_state() -> void:
	if _start == null:
		return
	var errors := _get_errors()
	_refresh_portraits()
	for index in 2:
		var racer_text := _option_text(_racer_options[index], "PILOTO SIN ELEGIR")
		var vehicle_text := _vehicle_buttons[index].text
		var device_text := _option_text(_device_options[index], "DISPOSITIVO SIN ELEGIR")
		_pilot_names[index].text = racer_text
		_player_summaries[index].text = "%s\n%s · %s" % [racer_text, device_text, vehicle_text]
		_style_status_badge(_ready_badges[index], "LISTO" if _ready_toggles[index].button_pressed else "FALTA", UiTokens.SUCCESS if _ready_toggles[index].button_pressed else UiTokens.CORAL)
	_start.disabled = not errors.is_empty()
	_status.text = "PARRILLA LISTA · 2 HUMANOS + 6 IA" if errors.is_empty() else errors[0]
	_status.add_theme_color_override("font_color", UiTokens.SUCCESS if errors.is_empty() else UiTokens.CORAL)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _refresh_portraits() -> void:
	if catalog == null or _portraits.size() < 2: return
	for index in 2:
		if _racer_options[index].item_count == 0: continue
		var racer := catalog.racers.get_racer(StringName(_racer_options[index].get_item_metadata(_racer_options[index].selected)))
		_portraits[index].configure(racer)


func _get_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _racer_options.size() < 2 or _racer_options[0].item_count == 0:
		errors.append("El catálogo de pilotos no está disponible.")
		return errors
	if _device_options[1].disabled:
		errors.append("Conecta un mando para J2.")
		return errors
	var participants := get_participants()
	if participants.size() != 2:
		errors.append("Completa ambos jugadores.")
		return errors
	if participants[0].racer == participants[1].racer:
		errors.append("Cada jugador debe elegir un piloto distinto.")
	if participants[0].device_type == RaceParticipantConfig.DEVICE_GAMEPAD and participants[0].device_id == participants[1].device_id:
		errors.append("Ese mando ya pertenece a J1.")
	if _ready_toggles.any(func(toggle: CheckButton) -> bool: return not toggle.button_pressed):
		errors.append("Ambos jugadores deben marcar LISTO.")
	return errors


func _confirm() -> void:
	if not _get_errors().is_empty():
		return
	participants_confirmed.emit(get_participants())


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_gamepads()
	_refresh_state()


func _update_layout() -> void:
	if _page == null:
		return
	var compact := size.x < UiTokens.BREAKPOINT_ROSTER_WIDTH or size.y < UiTokens.BREAKPOINT_ROSTER_HEIGHT
	_cards.columns = 1 if compact else 2
	var available_width := maxf(280.0, size.x - 48.0)
	var content_width := minf(1160.0, available_width)
	_cards.custom_minimum_size.x = content_width
	_cards.size.x = content_width
	var width := content_width if compact else (content_width - UiTokens.SPACE_6) / 2.0
	_title.add_theme_font_size_override("font_size", UiTokens.FONT_TITLE_COMPACT if compact else UiTokens.FONT_TITLE_WIDE)
	for child in _cards.get_children():
		(child as Control).custom_minimum_size = Vector2(width, 350.0 if compact else 370.0)
		(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_set_action_bar(_actions)


func _option_text(option: OptionButton, fallback: String) -> String:
	return option.get_item_text(option.selected) if option.item_count > 0 and option.selected >= 0 else fallback


func _status_badge(text: String, color: Color) -> Label:
	var badge := Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(72, UiTokens.TOUCH_TARGET)
	_style_status_badge(badge, text, color)
	return badge


func _style_status_badge(badge: Label, text: String, color: Color) -> void:
	badge.text = text
	badge.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION)
	badge.add_theme_color_override("font_color", color)
	badge.add_theme_stylebox_override("normal", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_SMALL, color))


func _set_action_bar(actions: Control) -> void:
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_left = UiTokens.SPACE_4
	actions.offset_right = -UiTokens.SPACE_4
	actions.offset_top = -UiTokens.BUTTON_HEIGHT_LARGE - UiTokens.SPACE_3
	actions.offset_bottom = -UiTokens.SPACE_3
