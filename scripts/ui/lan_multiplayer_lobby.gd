class_name LanMultiplayerLobby
extends Control

signal race_requested(lan_session: LanSession, payload: Dictionary)
signal back_requested

var progression: ProgressionCatalog
var tracks: TrackCatalog
var progress: PlayerProgress
var session: LanSession
var discovery: LanDiscoveryService

var _name_edit: LineEdit
var _racer_option: OptionButton
var _vehicle_option: OptionButton
var _track_option: OptionButton
var _cc_option: OptionButton
var _items_toggle: CheckButton
var _bots_toggle: CheckButton
var _address_edit: LineEdit
var _port_spin: SpinBox
var _rooms_list: VBoxContainer
var _slots_list: VBoxContainer
var _status: Label
var _status_panel: PanelContainer
var _ready_toggle: CheckButton
var _start: ActionButton
var _host_button: ActionButton
var _join_button: ActionButton
var _back_button: ActionButton
var _profile_summary: Label
var _room_summary: Label
var _page: Control
var _columns: BoxContainer
var _columns_scroll: ScrollContainer
var _actions: HBoxContainer
var _title: Label
var _portrait: RacerPortrait
var _mode_panel: PanelContainer
var _profile_panel: PanelContainer
var _connection_panel: PanelContainer
var _room_panel: PanelContainer
var _slots_scroll: ScrollContainer
var _room_heading: Label
var _continue: ActionButton
var _host_mode_button: ActionButton
var _join_mode_button: ActionButton
var _stage_label: Label
var _stage := 0
var _hosting := false

const STAGE_NETWORK := 0
const STAGE_PROFILE := 1
const STAGE_CONNECTION := 2
const STAGE_RACE := 3
const STAGE_ROOM := 4


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
	add_child(page)
	var title := Label.new()
	_title = title
	title.text = "RED LOCAL · HASTA 4 DISPOSITIVOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UiTokens.WARM_WHITE)
	page.add_child(title)
	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.add_theme_color_override("font_color", UiTokens.CYAN)
	_stage_label.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	_stage_label.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION)
	page.add_child(_stage_label)
	var trust_row := HBoxContainer.new()
	trust_row.alignment = BoxContainer.ALIGNMENT_CENTER
	trust_row.add_theme_constant_override("separation", UiTokens.SPACE_2)
	var trust_icon := Label.new()
	trust_icon.text = "◈"
	trust_icon.add_theme_color_override("font_color", UiTokens.CORAL)
	trust_row.add_child(trust_icon)
	var trust := Label.new()
	trust.text = "UDP SIN CIFRADO · RED LOCAL DE CONFIANZA"
	trust.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
	trust_row.add_child(trust)
	page.add_child(trust_row)
	var columns_scroll := ScrollContainer.new()
	_columns_scroll = columns_scroll
	columns_scroll.name = "LobbyScroll"
	columns_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	columns_scroll.follow_focus = true
	columns_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns_scroll)
	_columns = BoxContainer.new()
	_columns.vertical = false
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("h_separation", UiTokens.SPACE_4)
	_columns.add_theme_constant_override("v_separation", UiTokens.SPACE_4)
	columns_scroll.add_child(_columns)
	_mode_panel = _build_mode_panel()
	_profile_panel = _build_profile_panel()
	_connection_panel = _build_connection_panel()
	_room_panel = _build_room_panel()
	_columns.add_child(_mode_panel)
	_columns.add_child(_profile_panel)
	_columns.add_child(_connection_panel)
	_columns.add_child(_room_panel)
	_status_panel = PanelContainer.new()
	_status_panel.name = "LobbyStatus"
	_status_panel.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_panel.add_theme_stylebox_override("panel", UiTokens.status_badge(UiTokens.CYAN))
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.text = "LISTO PARA CONECTAR"
	_status.add_theme_color_override("font_color", UiTokens.WARM_WHITE)
	_status_panel.add_child(_status)
	page.add_child(_status_panel)
	var actions := HBoxContainer.new()
	_actions = actions
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_set_action_bar(actions)
	add_child(actions)
	var back := ActionButton.new()
	_back_button = back
	back.text = "VOLVER"
	back.pressed.connect(_back)
	actions.add_child(back)
	_continue = ActionButton.new()
	_continue.name = "ContinueStage"
	_continue.text = "CONTINUAR"
	_continue.pressed.connect(_advance_stage)
	actions.add_child(_continue)
	_ready_toggle = CheckButton.new()
	_ready_toggle.text = "LISTO"
	_ready_toggle.custom_minimum_size = Vector2(140, UiTokens.TOUCH_TARGET)
	_ready_toggle.disabled = true
	_ready_toggle.toggled.connect(_set_ready)
	actions.add_child(_ready_toggle)
	_start = ActionButton.new()
	_start.kind = ActionButton.Kind.PRIMARY
	_start.text = "INICIAR CARRERA"
	_start.disabled = true
	_start.pressed.connect(_host_start)
	actions.add_child(_start)
	_show_stage(STAGE_NETWORK, false)
	_host_room_focus.call_deferred()
	_setup_services()
	_populate_options()
	_focus_stage.call_deferred()
	if DisplayServer.get_name() != "headless":
		discovery.start_browsing()
	resized.connect(_update_layout)
	_update_layout()


func configure(value_progression: ProgressionCatalog, value_tracks: TrackCatalog, value_progress: PlayerProgress) -> void:
	progression = value_progression
	tracks = value_tracks
	progress = value_progress
	if is_node_ready():
		session.configure(progression, tracks)
		_populate_options()
		_hosting = false
		_show_stage(STAGE_NETWORK, false)


func detach_session() -> LanSession:
	# Keep the node in its original scene-tree path while RPC packets can still
	# be in flight. Reparenting here makes Godot reject those packets by path.
	if session == null:
		return null
	return session


func _build_mode_panel() -> PanelContainer:
	var panel := _panel("RED LOCAL")
	var column := panel.get_child(0) as VBoxContainer
	var intro := Label.new()
	intro.text = "ELIGE CÓMO QUIERES JUGAR"
	intro.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(intro)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", UiTokens.SPACE_3)
	column.add_child(options)
	_host_mode_button = ActionButton.new()
	_host_mode_button.name = "CreateRoomMode"
	_host_mode_button.kind = ActionButton.Kind.PRIMARY
	_host_mode_button.text = "CREAR SALA"
	_host_mode_button.custom_minimum_size = Vector2(220, UiTokens.BUTTON_HEIGHT_LARGE)
	_host_mode_button.pressed.connect(func() -> void: _choose_role(true))
	options.add_child(_host_mode_button)
	_join_mode_button = ActionButton.new()
	_join_mode_button.name = "JoinRoomMode"
	_join_mode_button.text = "UNIRSE A SALA"
	_join_mode_button.custom_minimum_size = Vector2(220, UiTokens.BUTTON_HEIGHT_LARGE)
	_join_mode_button.pressed.connect(func() -> void: _choose_role(false))
	options.add_child(_join_mode_button)
	return panel


func _setup_services() -> void:
	discovery = LanDiscoveryService.new()
	discovery.name = "LanDiscovery"
	add_child(discovery)
	discovery.rooms_changed.connect(_rebuild_rooms)
	discovery.discovery_error.connect(_show_error)
	session = LanSession.new()
	session.name = "LanSession"
	add_child(session)
	if progression != null and tracks != null:
		session.configure(progression, tracks)
	session.connection_state_changed.connect(func(state: StringName, message: String) -> void: _set_status(message, _status_color(state)))
	session.room_changed.connect(_rebuild_slots)
	session.join_rejected.connect(_show_error)
	session.race_start_received.connect(func(payload: Dictionary) -> void: race_requested.emit(session, payload))
	session.host_lost.connect(func(message: String) -> void: _show_error(message))


func _choose_role(hosting: bool) -> void:
	_hosting = hosting
	_randomize_profile_racer()
	if _bots_toggle != null:
		_bots_toggle.disabled = not hosting
		if hosting:
			_bots_toggle.set_pressed_no_signal(true)
	if hosting:
		discovery.stop()
		_show_stage(STAGE_PROFILE)
	else:
		if DisplayServer.get_name() != "headless":
			discovery.start_browsing()
		_show_stage(STAGE_PROFILE)


func _randomize_profile_racer() -> void:
	if _racer_option == null or _racer_option.item_count == 0:
		return
	_racer_option.select(randi_range(0, _racer_option.item_count - 1))
	_refresh_profile_summary()


func _advance_stage() -> void:
	match _stage:
		STAGE_PROFILE:
			_show_stage(STAGE_RACE if _hosting else STAGE_CONNECTION)
		STAGE_RACE:
			_host_room()


func _show_stage(stage: int, focus := true) -> void:
	_stage = stage
	if _mode_panel != null:
		_mode_panel.visible = stage == STAGE_NETWORK
	if _profile_panel != null:
		_profile_panel.visible = stage == STAGE_PROFILE
	if _connection_panel != null:
		_connection_panel.visible = stage == STAGE_CONNECTION
	if _room_panel != null:
		_room_panel.visible = stage == STAGE_RACE or stage == STAGE_ROOM
	if _slots_scroll != null:
		_slots_scroll.visible = stage == STAGE_ROOM
	if _room_heading != null:
		_room_heading.text = ("03  CARRERA" if stage == STAGE_RACE else "04  SALA")
	if _stage_label != null:
		_stage_label.text = ["01  RED LOCAL", "02  TU PILOTO", "03  CONEXIÓN", "03  CARRERA", "04  SALA"][stage]
	if _continue != null:
		_continue.visible = stage == STAGE_PROFILE or stage == STAGE_RACE
		_continue.text = "CREAR SALA" if stage == STAGE_RACE else "CONTINUAR"
	if _ready_toggle != null:
		_ready_toggle.visible = stage == STAGE_ROOM
	if _start != null:
		_start.visible = stage == STAGE_ROOM and _hosting
	if focus:
		_focus_stage.call_deferred()


func _focus_stage(should_grab := true) -> void:
	var controls: Array = []
	match _stage:
		STAGE_NETWORK:
			controls = [_host_mode_button, _join_mode_button, _back_button]
		STAGE_PROFILE:
			controls = [_name_edit, _racer_option, _vehicle_option, _continue, _back_button]
		STAGE_CONNECTION:
			controls = [_address_edit, _port_spin, _join_button, _back_button]
		STAGE_RACE:
			controls = [_track_option, _cc_option, _items_toggle, _bots_toggle, _continue, _back_button]
		STAGE_ROOM:
			controls = [_ready_toggle, _start, _back_button] if _hosting else [_ready_toggle, _back_button]
	if _stage == STAGE_CONNECTION and _rooms_list != null:
		var room_actions := _rooms_list.find_children("JoinRoom", "ActionButton", true, false)
		for action in room_actions:
			controls.insert(controls.size() - 1, action as Control)
	var available: Array[Control] = []
	for control in controls:
		if _can_focus(control):
			available.append(control)
	for index in available.size():
		var control := available[index]
		control.focus_neighbor_bottom = available[(index + 1) % available.size()].get_path()
		control.focus_neighbor_top = available[(index - 1 + available.size()) % available.size()].get_path()
	if should_grab and not available.is_empty():
		available[0].grab_focus()


func _can_focus(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton:
		return not (control as BaseButton).disabled
	if control is LineEdit:
		return (control as LineEdit).editable
	return true


func _build_profile_panel() -> PanelContainer:
	var panel := _panel("TU PILOTO")
	var column := panel.get_child(0) as VBoxContainer
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", UiTokens.SPACE_3)
	column.add_child(identity)
	_portrait = RacerPortrait.new()
	_portrait.name = "RacerPortrait"
	_portrait.custom_minimum_size = Vector2(88, 88)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	identity.add_child(_portrait)
	var identity_copy := VBoxContainer.new()
	identity_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_copy.add_theme_constant_override("separation", UiTokens.SPACE_1)
	identity.add_child(identity_copy)
	var identity_label := Label.new()
	identity_label.text = "IDENTIDAD ACTIVA"
	identity_label.label_settings = UiTokens.kicker(UiTokens.CYAN)
	identity_copy.add_child(identity_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nombre local"
	_name_edit.text = "Piloto"
	_name_edit.max_length = 24
	_name_edit.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_name_edit.text_changed.connect(func(_value: String) -> void: _refresh_profile_summary())
	identity_copy.add_child(_name_edit)
	_profile_summary = Label.new()
	_profile_summary.text = "CONFIGURA TU PILOTO"
	_profile_summary.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	_profile_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_copy.add_child(_profile_summary)
	_add_label(column, "PILOTO")
	_racer_option = OptionButton.new()
	_racer_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_racer_option.item_selected.connect(func(_index: int) -> void: _refresh_profile_summary())
	column.add_child(_racer_option)
	_add_label(column, "VEHÍCULO LOCAL")
	_vehicle_option = OptionButton.new()
	_vehicle_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_vehicle_option.item_selected.connect(func(_index: int) -> void: _refresh_profile_summary())
	column.add_child(_vehicle_option)
	return panel


func _build_connection_panel() -> PanelContainer:
	var panel := _panel("CONECTAR")
	var column := panel.get_child(0) as VBoxContainer
	var host := ActionButton.new()
	_host_button = host
	host.kind = ActionButton.Kind.PRIMARY
	host.text = "CREAR SALA"
	host.pressed.connect(_host_room)
	host.visible = false
	column.add_child(host)
	_add_label(column, "UNIRSE A UNA SALA EXISTENTE")
	_add_label(column, "IP MANUAL")
	var address_row := HBoxContainer.new()
	address_row.add_theme_constant_override("separation", UiTokens.SPACE_2)
	column.add_child(address_row)
	_address_edit = LineEdit.new()
	_address_edit.text = "127.0.0.1"
	_address_edit.placeholder_text = "192.168.1.25"
	_address_edit.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	address_row.add_child(_address_edit)
	_port_spin = SpinBox.new()
	_port_spin.min_value = 1
	_port_spin.max_value = 65535
	_port_spin.value = LanProtocol.RACE_PORT
	_port_spin.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_port_spin.custom_minimum_size.x = 108
	address_row.add_child(_port_spin)
	var join := ActionButton.new()
	_join_button = join
	join.text = "UNIRSE POR IP"
	join.pressed.connect(func() -> void: _join_room(_address_edit.text, int(_port_spin.value)))
	column.add_child(join)
	_add_label(column, "SALAS ENCONTRADAS · UDP %d" % LanProtocol.DISCOVERY_PORT)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 184
	column.add_child(scroll)
	_rooms_list = VBoxContainer.new()
	_rooms_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rooms_list)
	return panel


func _build_room_panel() -> PanelContainer:
	var panel := _panel("SALA Y CARRERA")
	var column := panel.get_child(0) as VBoxContainer
	_add_label(column, "CONFIGURACIÓN DE LA CARRERA")
	_add_label(column, "CIRCUITO · SOLO ANFITRIÓN")
	_track_option = OptionButton.new()
	_track_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_track_option.item_selected.connect(func(_index: int) -> void: _host_options_changed())
	column.add_child(_track_option)
	_add_label(column, "CILINDRADA")
	_cc_option = OptionButton.new()
	_cc_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_cc_option.item_selected.connect(func(_index: int) -> void: _host_options_changed())
	column.add_child(_cc_option)
	_items_toggle = CheckButton.new()
	_items_toggle.text = "OBJETOS"
	_items_toggle.button_pressed = true
	_items_toggle.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_items_toggle.toggled.connect(func(_enabled: bool) -> void: _host_options_changed())
	column.add_child(_items_toggle)
	_bots_toggle = CheckButton.new()
	_bots_toggle.name = "FillWithBots"
	_bots_toggle.text = "RELLENAR CON BOTS"
	_bots_toggle.button_pressed = true
	_bots_toggle.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_bots_toggle.toggled.connect(func(_enabled: bool) -> void: _host_options_changed())
	column.add_child(_bots_toggle)
	_room_summary = Label.new()
	_room_summary.text = "CONFIGURACIÓN DE SALA"
	_room_summary.add_theme_color_override("font_color", UiTokens.MUTED)
	_room_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_room_summary)
	_add_label(column, "SLOTS HUMANOS")
	var slots_scroll := ScrollContainer.new()
	_slots_scroll = slots_scroll
	slots_scroll.name = "HumanSlotsScroll"
	slots_scroll.custom_minimum_size.y = 132
	slots_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slots_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(slots_scroll)
	_slots_list = VBoxContainer.new()
	_slots_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_scroll.add_child(_slots_list)
	return panel


func _panel(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 340
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_LARGE))
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	if title == "SALA Y CARRERA":
		_room_heading = heading
	var number := "01" if title == "RED LOCAL" else ("02" if title == "TU PILOTO" else "03")
	heading.text = "%s  %s" % [number, title]
	heading.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	heading.add_theme_font_size_override("font_size", UiTokens.FONT_H2)
	heading.add_theme_color_override("font_color", UiTokens.CYAN)
	column.add_child(heading)
	return panel


func _add_label(parent: VBoxContainer, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.label_settings = UiTokens.kicker(UiTokens.MUTED)
	parent.add_child(label)


func _populate_options() -> void:
	if _racer_option == null:
		return
	_racer_option.clear()
	_vehicle_option.clear()
	_track_option.clear()
	_cc_option.clear()
	if progression != null:
		for racer in progression.racers.racers:
			_racer_option.add_item(racer.display_name.to_upper())
			_racer_option.set_item_metadata(_racer_option.item_count - 1, racer.id)
		for vehicle in progression.unlocks.variants:
			if progress == null or progress.can_equip(vehicle.id, progression.unlocks):
				_vehicle_option.add_item(vehicle.display_name.to_upper())
				_vehicle_option.set_item_metadata(_vehicle_option.item_count - 1, vehicle.id)
				if progress != null and vehicle.id == progress.equipped_kart_variant_id:
					_vehicle_option.select(_vehicle_option.item_count - 1)
	if tracks != null:
		for track in tracks.tracks:
			_track_option.add_item(track.display_name.to_upper())
			_track_option.set_item_metadata(_track_option.item_count - 1, track.id)
	for race_class in RaceClassDefinition.get_all():
		_cc_option.add_item(race_class.display_name)
		_cc_option.set_item_metadata(_cc_option.item_count - 1, race_class.id)
	_refresh_profile_summary()
	_refresh_room_summary()


func _profile() -> Dictionary:
	return {
		"name": _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "Piloto",
		"racer_id": StringName(_racer_option.get_item_metadata(_racer_option.selected)) if _racer_option.item_count > 0 else &"",
		"vehicle_id": StringName(_vehicle_option.get_item_metadata(_vehicle_option.selected)) if _vehicle_option.item_count > 0 else &"",
	}


func _host_room() -> void:
	var port := int(_port_spin.value)
	var settings := _selected_room_settings(port)
	if session.host_room(_profile(), settings, port) != OK:
		return
	_bots_toggle.disabled = false
	discovery.start_advertising({
		"room_id": session.local_token,
		"name": settings.room_name,
		"port": port,
		"humans": 1,
		"max_humans": LanProtocol.MAX_HUMANS,
		"catalog_fingerprint": session.catalog_fingerprint,
		"track_id": settings.track_id,
	})
	_ready_toggle.disabled = false
	_track_option.disabled = false
	_cc_option.disabled = false
	_items_toggle.disabled = false
	_refresh_start_state()
	_show_stage(STAGE_ROOM)


func _join_room(address: String, port: int) -> void:
	if session.join_room(address, _profile(), port, session.local_token) != OK:
		return
	_bots_toggle.disabled = true
	discovery.stop()
	_ready_toggle.disabled = false
	_track_option.disabled = true
	_cc_option.disabled = true
	_items_toggle.disabled = true
	_start.visible = false
	_show_stage(STAGE_ROOM)


func _set_ready(value: bool) -> void:
	var profile := _profile()
	if not session.set_local_selection(profile.racer_id, profile.vehicle_id, value):
		_ready_toggle.set_pressed_no_signal(false)
		_show_error("No se pudo reservar ese piloto o vehículo.")
	_refresh_start_state()


func _host_start() -> void:
	if not session.host_start_race():
		_show_error("Todos los jugadores conectados deben estar listos.")


func _rebuild_rooms(rooms: Array) -> void:
	for child in _rooms_list.get_children():
		child.queue_free()
	if rooms.is_empty():
		var empty := EmptyState.new()
		empty.configure("BUSCANDO PARTIDAS", "Esperando anuncios UDP en la red local…")
		_rooms_list.add_child(empty)
		return
	for room in rooms:
		var compatible := str(room.get("catalog_fingerprint", "")) == session.catalog_fingerprint
		var row := PanelContainer.new()
		row.name = "RoomRow_%s" % str(room.get("room_id", room.get("name", "room")))
		row.custom_minimum_size.y = 64
		row.add_theme_stylebox_override("panel", UiTokens.room_row())
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", UiTokens.SPACE_3)
		row.add_child(content)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation", UiTokens.SPACE_1)
		content.add_child(copy)
		var name := Label.new()
		name.text = str(room.get("name", "SALA")).to_upper()
		name.clip_text = true
		name.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
		name.add_theme_font_size_override("font_size", UiTokens.FONT_LABEL)
		copy.add_child(name)
		var detail := Label.new()
		detail.text = "%d/%d PILOTOS  ·  %s" % [int(room.get("humans", 0)), int(room.get("max_humans", 4)), "CATÁLOGO COMPATIBLE" if compatible else "CATÁLOGO INCOMPATIBLE"]
		detail.add_theme_color_override("font_color", UiTokens.SUCCESS if compatible else UiTokens.CORAL)
		detail.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION)
		detail.clip_text = true
		copy.add_child(detail)
		var join := ActionButton.new()
		join.name = "JoinRoom"
		join.text = "UNIRSE" if compatible else "NO DISPONIBLE"
		join.disabled = not compatible
		join.custom_minimum_size = Vector2(112, UiTokens.TOUCH_TARGET)
		join.tooltip_text = "Versión o catálogo distintos" if not compatible else "Unirse a %s:%d" % [room.address, int(room.port)]
		join.pressed.connect(_join_room.bind(str(room.address), int(room.port)))
		content.add_child(join)
		_rooms_list.add_child(row)
		join.focus_entered.connect(_focus_entered.bind(join))
	if _stage == STAGE_CONNECTION:
		_focus_stage.call_deferred(false)


func _rebuild_slots(values: Array, settings: Dictionary) -> void:
	for child in _slots_list.get_children():
		child.queue_free()
	for index in LanProtocol.MAX_HUMANS:
		var slot: Dictionary = {}
		for candidate in values:
			if int(candidate.get("slot_id", -1)) == index:
				slot = candidate
				break
		var row := PanelContainer.new()
		row.name = "ParticipantRow_%02d" % (index + 1)
		row.custom_minimum_size.y = UiTokens.TOUCH_TARGET
		row.add_theme_stylebox_override("panel", UiTokens.participant_row())
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", UiTokens.SPACE_2)
		row.add_child(content)
		var number := Label.new()
		number.text = "%02d" % (index + 1)
		number.custom_minimum_size.x = 28
		number.add_theme_color_override("font_color", UiTokens.MUTED)
		content.add_child(number)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if slot.is_empty():
			label.text = "ESPERANDO PILOTO"
			label.add_theme_color_override("font_color", UiTokens.TEXT_TERTIARY)
			content.add_child(label)
			content.add_child(_status_badge("LIBRE", UiTokens.MUTED))
		else:
			var racer := progression.racers.get_racer(StringName(slot.racer_id))
			label.text = "%s  ·  %s" % [str(slot.name).to_upper(), racer.display_name.to_upper() if racer != null else str(slot.racer_id)]
			label.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
			content.add_child(label)
			var state_text := "LISTO" if bool(slot.ready) else ("IA TEMPORAL" if not bool(slot.connected) else "ELIGIENDO")
			var state_color := UiTokens.SUCCESS if bool(slot.ready) else (UiTokens.WARNING if not bool(slot.connected) else UiTokens.CYAN)
			content.add_child(_status_badge(state_text, state_color))
		_slots_list.add_child(row)
	if settings.has("track_id"):
		_select_metadata(_track_option, settings.track_id)
	if settings.has("cc_id"):
		_select_metadata(_cc_option, settings.cc_id)
	if settings.has("items_enabled"):
		_items_toggle.set_pressed_no_signal(bool(settings.items_enabled))
	if settings.has("bots_enabled"):
		_bots_toggle.set_pressed_no_signal(bool(settings.bots_enabled))
	_bots_toggle.disabled = not session.is_host
	if session.is_host:
		discovery.update_advertisement({
			"humans": values.size(),
			"track_id": settings.get("track_id", &""),
		})
	_refresh_start_state()
	_refresh_room_summary()


func _selected_room_settings(port := LanProtocol.RACE_PORT) -> Dictionary:
	return {
		"track_id": StringName(_track_option.get_item_metadata(_track_option.selected)),
		"cc_id": StringName(_cc_option.get_item_metadata(_cc_option.selected)),
		"items_enabled": _items_toggle.button_pressed,
		"bots_enabled": _bots_toggle.button_pressed,
		"port": port,
		"room_name": "%s · MichiKart" % _profile().name,
	}


func _host_options_changed() -> void:
	_refresh_room_summary()
	if session == null or not session.is_host or session.race_active:
		return
	session.host_update_room_settings(_selected_room_settings(int(_port_spin.value)))


func _select_metadata(option: OptionButton, value: Variant) -> void:
	for index in option.item_count:
		if StringName(option.get_item_metadata(index)) == StringName(value):
			option.select(index)
			return


func _status_badge(text: String, color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size.y = UiTokens.TOUCH_TARGET - UiTokens.SPACE_2
	badge.add_theme_stylebox_override("panel", UiTokens.status_badge(color))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION)
	label.add_theme_color_override("font_color", UiTokens.WARM_WHITE)
	badge.add_child(label)
	return badge


func _refresh_start_state() -> void:
	if _start != null:
		_start.disabled = not session.can_host_start()
	_refresh_profile_summary()


func _refresh_profile_summary() -> void:
	if _profile_summary != null:
		var name := _name_edit.text.strip_edges() if _name_edit != null and not _name_edit.text.strip_edges().is_empty() else "PILOTO"
		var racer := _racer_option.get_item_text(_racer_option.selected) if _racer_option != null and _racer_option.item_count > 0 else "PILOTO SIN ELEGIR"
		var vehicle := _vehicle_option.get_item_text(_vehicle_option.selected) if _vehicle_option != null and _vehicle_option.item_count > 0 else "VEHÍCULO SIN ELEGIR"
		_profile_summary.text = "%s\n%s · %s" % [name.to_upper(), racer, vehicle]
		if _portrait != null and _racer_option != null and _racer_option.item_count > 0 and progression != null:
			var racer_id := StringName(_racer_option.get_item_metadata(_racer_option.selected))
			_portrait.configure(progression.racers.get_racer(racer_id))


func _refresh_room_summary() -> void:
	if _room_summary == null:
		return
	var track := _track_option.get_item_text(_track_option.selected) if _track_option.item_count > 0 else "CIRCUITO SIN ELEGIR"
	var race_class := _cc_option.get_item_text(_cc_option.selected) if _cc_option.item_count > 0 else "CILINDRADA SIN ELEGIR"
	var bots := "BOTS ACTIVADOS" if _bots_toggle.button_pressed else "SOLO HUMANOS"
	_room_summary.text = "%s · %s · OBJETOS %s · %s" % [track, race_class, "ACTIVOS" if _items_toggle.button_pressed else "DESACTIVADOS", bots]


func _set_status(message: String, color: Color) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", UiTokens.WARM_WHITE)
	if _status_panel != null:
		_status_panel.add_theme_stylebox_override("panel", UiTokens.status_badge(color))


func _show_error(message: String) -> void:
	_set_status(message, UiTokens.CORAL)


func _status_color(state: StringName) -> Color:
	if state == &"connected" or state == &"hosting" or state == &"joined" or state == &"ready":
		return UiTokens.SUCCESS
	if state == &"error" or state == &"rejected" or state == &"host_lost":
		return UiTokens.CORAL
	return UiTokens.CYAN


func _back() -> void:
	if _stage > STAGE_NETWORK:
		if _stage == STAGE_ROOM and session != null:
			session.close()
			discovery.stop()
			_ready_toggle.set_pressed_no_signal(false)
			_ready_toggle.disabled = true
			_start.disabled = true
		if _stage == STAGE_PROFILE:
			_show_stage(STAGE_NETWORK)
		elif _stage == STAGE_RACE:
			_show_stage(STAGE_PROFILE)
		elif _stage == STAGE_CONNECTION:
			_show_stage(STAGE_PROFILE)
		elif _stage == STAGE_ROOM:
			_show_stage(STAGE_RACE if _hosting else STAGE_CONNECTION)
		return
	if session != null:
		session.close()
	if discovery != null:
		discovery.stop()
	back_requested.emit()


func _update_layout() -> void:
	if _page == null:
		return
	var compact := size.x < UiTokens.BREAKPOINT_NETWORK_WIDTH or size.y < UiTokens.BREAKPOINT_NETWORK_HEIGHT
	_columns.vertical = compact
	var visible_panels := 0
	for child in _columns.get_children():
		if (child as Control).visible:
			visible_panels += 1
	var single_stage := visible_panels == 1
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER if single_stage else BoxContainer.ALIGNMENT_BEGIN
	var available_width := maxf(280.0, minf(1240.0, size.x - 48.0))
	_columns_scroll.custom_minimum_size.x = available_width
	_columns_scroll.size.x = available_width
	_columns.custom_minimum_size.x = available_width
	_columns.size.x = available_width
	var width := maxf(280.0, (available_width - (UiTokens.SPACE_4 * 2.0 if not compact else 0.0)) / (1.0 if compact else 3.0))
	if single_stage and not compact:
		width = minf(840.0, available_width * 0.72)
	_title.add_theme_font_size_override("font_size", UiTokens.FONT_TITLE_COMPACT if compact else UiTokens.FONT_TITLE_WIDE)
	for child in _columns.get_children():
		var panel := child as Control
		panel.custom_minimum_size.x = width
		panel.size.x = width
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_set_action_bar(_actions)


func _set_action_bar(actions: Control) -> void:
	actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	actions.offset_left = UiTokens.SPACE_4
	actions.offset_right = -UiTokens.SPACE_4
	actions.offset_top = -UiTokens.BUTTON_HEIGHT_LARGE - UiTokens.SPACE_3
	actions.offset_bottom = -UiTokens.SPACE_3


func _host_room_focus() -> void:
	_focus_stage.call_deferred()


func _focus_entered(control: Control) -> void:
	if _columns_scroll != null and is_instance_valid(control):
		_columns_scroll.ensure_control_visible(control)
