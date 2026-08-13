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
var _address_edit: LineEdit
var _port_spin: SpinBox
var _rooms_list: VBoxContainer
var _slots_list: VBoxContainer
var _status: Label
var _ready_toggle: CheckButton
var _start: ActionButton
var _page: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiTokens.GRAPHITE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var page := VBoxContainer.new()
	_page = page
	page.set_anchors_preset(Control.PRESET_CENTER)
	page.position = Vector2(-560, -340)
	page.size = Vector2(1120, 680)
	page.pivot_offset = page.size * 0.5
	add_child(page)
	var title := Label.new()
	title.text = "RED LOCAL · HASTA 4 DISPOSITIVOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	page.add_child(title)
	var trust := Label.new()
	trust.text = "UDP SIN CIFRADO · USA SOLO UNA RED LOCAL DE CONFIANZA"
	trust.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trust.add_theme_color_override("font_color", UiTokens.CORAL)
	page.add_child(trust)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", UiTokens.SPACE_4)
	page.add_child(columns)
	columns.add_child(_build_profile_panel())
	columns.add_child(_build_connection_panel())
	columns.add_child(_build_room_panel())
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", UiTokens.MUTED)
	page.add_child(_status)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(actions)
	var back := ActionButton.new()
	back.text = "VOLVER"
	back.pressed.connect(_back)
	actions.add_child(back)
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
	_setup_services()
	_populate_options()
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


func detach_session() -> LanSession:
	if session == null:
		return null
	var result := session
	if result.get_parent() == self:
		remove_child(result)
	session = null
	return result


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
	session.connection_state_changed.connect(func(_state: StringName, message: String) -> void: _set_status(message, UiTokens.MUTED))
	session.room_changed.connect(_rebuild_slots)
	session.join_rejected.connect(_show_error)
	session.race_start_received.connect(func(payload: Dictionary) -> void: race_requested.emit(session, payload))
	session.host_lost.connect(func(message: String) -> void: _show_error(message))


func _build_profile_panel() -> PanelContainer:
	var panel := _panel("TU PILOTO")
	var column := panel.get_child(0) as VBoxContainer
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nombre local"
	_name_edit.text = "Piloto"
	_name_edit.max_length = 24
	_name_edit.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	column.add_child(_name_edit)
	_add_label(column, "PILOTO")
	_racer_option = OptionButton.new()
	_racer_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	column.add_child(_racer_option)
	_add_label(column, "VEHÍCULO LOCAL")
	_vehicle_option = OptionButton.new()
	_vehicle_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	column.add_child(_vehicle_option)
	return panel


func _build_connection_panel() -> PanelContainer:
	var panel := _panel("CONECTAR")
	var column := panel.get_child(0) as VBoxContainer
	var host := ActionButton.new()
	host.kind = ActionButton.Kind.PRIMARY
	host.text = "CREAR SALA"
	host.pressed.connect(_host_room)
	column.add_child(host)
	_add_label(column, "IP MANUAL")
	_address_edit = LineEdit.new()
	_address_edit.text = "127.0.0.1"
	_address_edit.placeholder_text = "192.168.1.25"
	_address_edit.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	column.add_child(_address_edit)
	_port_spin = SpinBox.new()
	_port_spin.min_value = 1
	_port_spin.max_value = 65535
	_port_spin.value = LanProtocol.RACE_PORT
	_port_spin.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	column.add_child(_port_spin)
	var join := ActionButton.new()
	join.text = "UNIRSE POR IP"
	join.pressed.connect(func() -> void: _join_room(_address_edit.text, int(_port_spin.value)))
	column.add_child(join)
	_add_label(column, "SALAS DESCUBIERTAS · UDP %d" % LanProtocol.DISCOVERY_PORT)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 170
	column.add_child(scroll)
	_rooms_list = VBoxContainer.new()
	_rooms_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rooms_list)
	return panel


func _build_room_panel() -> PanelContainer:
	var panel := _panel("SALA Y CARRERA")
	var column := panel.get_child(0) as VBoxContainer
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
	_add_label(column, "SLOTS HUMANOS")
	_slots_list = VBoxContainer.new()
	column.add_child(_slots_list)
	return panel


func _panel(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 340
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_LARGE))
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", UiTokens.CYAN)
	column.add_child(heading)
	return panel


func _add_label(parent: VBoxContainer, value: String) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UiTokens.MUTED)
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


func _join_room(address: String, port: int) -> void:
	if session.join_room(address, _profile(), port, session.local_token) != OK:
		return
	discovery.stop()
	_ready_toggle.disabled = false
	_track_option.disabled = true
	_cc_option.disabled = true
	_items_toggle.disabled = true
	_start.visible = false


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
		var empty := Label.new()
		empty.text = "Buscando anuncios…"
		empty.add_theme_color_override("font_color", UiTokens.MUTED)
		_rooms_list.add_child(empty)
		return
	for room in rooms:
		var compatible := str(room.get("catalog_fingerprint", "")) == session.catalog_fingerprint
		var button := Button.new()
		button.text = "%s · %d/%d%s" % [room.get("name", "Sala"), int(room.get("humans", 0)), int(room.get("max_humans", 4)), "" if compatible else " · INCOMPATIBLE"]
		button.disabled = not compatible
		button.tooltip_text = "Versión o catálogo distintos" if not compatible else "Unirse a %s:%d" % [room.address, int(room.port)]
		button.pressed.connect(_join_room.bind(str(room.address), int(room.port)))
		_rooms_list.add_child(button)


func _rebuild_slots(values: Array, settings: Dictionary) -> void:
	for child in _slots_list.get_children():
		child.queue_free()
	for index in LanProtocol.MAX_HUMANS:
		var label := Label.new()
		var slot: Dictionary = {}
		for candidate in values:
			if int(candidate.get("slot_id", -1)) == index:
				slot = candidate
				break
		if slot.is_empty():
			label.text = "%02d  ·  LIBRE" % (index + 1)
			label.add_theme_color_override("font_color", UiTokens.MUTED)
		else:
			var racer := progression.racers.get_racer(StringName(slot.racer_id))
			label.text = "%02d  ·  %s · %s · %s" % [index + 1, str(slot.name).to_upper(), racer.display_name.to_upper() if racer != null else str(slot.racer_id), "LISTO" if bool(slot.ready) else ("IA TEMPORAL" if not bool(slot.connected) else "ELIGIENDO")]
			label.add_theme_color_override("font_color", UiTokens.SUCCESS if bool(slot.ready) else UiTokens.WARM_WHITE)
		_slots_list.add_child(label)
	if settings.has("track_id"):
		_select_metadata(_track_option, settings.track_id)
	if settings.has("cc_id"):
		_select_metadata(_cc_option, settings.cc_id)
	if settings.has("items_enabled"):
		_items_toggle.set_pressed_no_signal(bool(settings.items_enabled))
	if session.is_host:
		discovery.update_advertisement({
			"humans": values.size(),
			"track_id": settings.get("track_id", &""),
		})
	_refresh_start_state()


func _selected_room_settings(port := LanProtocol.RACE_PORT) -> Dictionary:
	return {
		"track_id": StringName(_track_option.get_item_metadata(_track_option.selected)),
		"cc_id": StringName(_cc_option.get_item_metadata(_cc_option.selected)),
		"items_enabled": _items_toggle.button_pressed,
		"port": port,
		"room_name": "%s · MichiKart" % _profile().name,
	}


func _host_options_changed() -> void:
	if session == null or not session.is_host or session.race_active:
		return
	session.host_update_room_settings(_selected_room_settings(int(_port_spin.value)))


func _select_metadata(option: OptionButton, value: Variant) -> void:
	for index in option.item_count:
		if StringName(option.get_item_metadata(index)) == StringName(value):
			option.select(index)
			return


func _refresh_start_state() -> void:
	if _start != null:
		_start.disabled = not session.can_host_start()


func _set_status(message: String, color: Color) -> void:
	_status.text = message
	_status.add_theme_color_override("font_color", color)


func _show_error(message: String) -> void:
	_set_status(message, UiTokens.CORAL)


func _back() -> void:
	if session != null:
		session.close()
	if discovery != null:
		discovery.stop()
	back_requested.emit()


func _update_layout() -> void:
	if _page == null:
		return
	var factor := minf(1.0, minf(
		(size.x - 32.0) / 1120.0,
		(size.y - 32.0) / 680.0
	))
	_page.scale = Vector2.ONE * maxf(factor, 0.45)
