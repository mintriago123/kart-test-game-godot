class_name PreparationScreen
extends Control

signal start_requested(track_id: StringName, cc_id: StringName, mode: int, difficulty_id: StringName)
signal back_requested
signal change_vehicle_requested(payload: Dictionary)

var payload: Dictionary = {}
var start_button: ActionButton
var summary: Label
var _card: Control
var _grid: GridContainer
var _event_column: VBoxContainer
var _options_column: VBoxContainer
var _showroom: VehicleViewport
var _minimap: TrackMinimapView
var _cc_chips: HBoxContainer
var _difficulty_chips: HBoxContainer
var _mode_option: CheckButton
var _change_vehicle: ActionButton
var _cup: CupDefinition
var _track: TrackDefinition

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.GRAPHITE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scroll.offset_left = 20; scroll.offset_top = 16; scroll.offset_right = -20; scroll.offset_bottom = -88; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	_grid = GridContainer.new(); _card = _grid; _grid.columns = 3; _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _grid.add_theme_constant_override("h_separation", 20); scroll.add_child(_grid)
	_event_column = VBoxContainer.new(); _event_column.custom_minimum_size.x = 300; _grid.add_child(_event_column)
	var title := Label.new(); title.text = "TODO LISTO"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 40); _event_column.add_child(title)
	summary = Label.new(); summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary.add_theme_font_size_override("font_size", 20); _event_column.add_child(summary)
	_minimap = TrackMinimapView.new(); _minimap.custom_minimum_size = Vector2(280, 170); _event_column.add_child(_minimap)
	_showroom = VehicleViewport.new(); _showroom.custom_minimum_size = Vector2(440, 380); _showroom.set_framing(VehicleViewport.Framing.GARAGE); _grid.add_child(_showroom)
	_options_column = VBoxContainer.new(); _options_column.custom_minimum_size.x = 300; _grid.add_child(_options_column)
	_add_heading(_options_column, "CILINDRADA")
	_cc_chips = HBoxContainer.new(); _options_column.add_child(_cc_chips)
	for race_class in RaceClassDefinition.get_all():
		var chip := _chip("%s CC" % race_class.id); chip.name = str(race_class.id); chip.pressed.connect(_select_cc.bind(race_class.id)); _cc_chips.add_child(chip)
	_add_heading(_options_column, "DIFICULTAD")
	_difficulty_chips = HBoxContainer.new(); _options_column.add_child(_difficulty_chips)
	_mode_option = CheckButton.new(); _mode_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET; _mode_option.toggled.connect(_toggle_mode_option); _options_column.add_child(_mode_option)
	_change_vehicle = ActionButton.new(); _change_vehicle.name = "ChangeVehicle"; _change_vehicle.text = "CAMBIAR VEHÍCULO"; _change_vehicle.pressed.connect(func(): change_vehicle_requested.emit(payload)); _options_column.add_child(_change_vehicle)
	var actions := HBoxContainer.new(); actions.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); actions.offset_left = 20; actions.offset_right = -20; actions.offset_top = -76; actions.offset_bottom = -14; actions.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(actions)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func(): back_requested.emit()); actions.add_child(back)
	start_button = ActionButton.new(); start_button.kind = ActionButton.Kind.PRIMARY; start_button.text = "INICIAR CARRERA"; start_button.pressed.connect(_start); actions.add_child(start_button)
	resized.connect(_update_layout); _update_layout()

func _add_heading(parent: VBoxContainer, text: String) -> void:
	var label := Label.new(); label.text = text; label.add_theme_color_override("font_color", UiTokens.MUTED); parent.add_child(label)

func _chip(text: String) -> Button:
	var button := Button.new(); button.text = text; button.toggle_mode = true; button.custom_minimum_size = Vector2(82, UiTokens.TOUCH_TARGET); return button

func configure(value: Dictionary, track: TrackDefinition, variant: KartVariantDefinition, cup: CupDefinition = null) -> void:
	payload = value.duplicate(true); _cup = cup; _track = track
	var mode := int(payload.get("mode", 0)); var locked := bool(payload.get("continue_active", false))
	_minimap.set_minimap_data(track.preview_map if track != null else null)
	_showroom.show_variant(variant)
	_select_cc(StringName(payload.get("cc_id", &"150")), false)
	for child in _difficulty_chips.get_children(): child.queue_free()
	if cup != null:
		for difficulty in cup.difficulties:
			var chip := _chip(difficulty.display_name.to_upper()); chip.name = str(difficulty.id); chip.pressed.connect(_select_difficulty.bind(difficulty.id)); _difficulty_chips.add_child(chip)
	_select_difficulty(StringName(payload.get("difficulty_id", &"competitive")), false)
	_difficulty_chips.visible = cup != null
	for chip in _cc_chips.get_children(): (chip as Button).disabled = locked
	for chip in _difficulty_chips.get_children(): (chip as Button).disabled = locked
	_mode_option.visible = cup == null; _mode_option.text = "FANTASMA" if mode == GameModeDefinition.TIME_TRIAL else "OBJETOS"; _mode_option.set_pressed_no_signal(bool(payload.get("ghost_enabled", true)) if mode == GameModeDefinition.TIME_TRIAL else bool(payload.get("items_enabled", true)))
	_change_vehicle.disabled = locked; _change_vehicle.tooltip_text = "Vehículo fijado durante una Copa activa" if locked else ""
	var event_name := cup.display_name.to_upper() if cup != null else (track.display_name.to_upper() if track else "EVENTO")
	var vehicle_name := variant.display_name.to_upper() if variant else "VEHÍCULO BASE"
	if locked:
		summary.text = "COPA ACTIVA\nSIGUIENTE CIRCUITO · %s\n%s\n🔒 CC, DIFICULTAD Y VEHÍCULO FIJADOS" % [track.display_name.to_upper() if track else "—", vehicle_name]
	elif cup != null:
		var tracks := PackedStringArray()
		for cup_track in cup.tracks: tracks.append(cup_track.display_name)
		summary.text = "%s\n3 CIRCUITOS · %s\nVEHÍCULO · %s" % [event_name, " → ".join(tracks), vehicle_name]
	elif mode == GameModeDefinition.TIME_TRIAL:
		summary.text = "%s\nCONTRARRELOJ · %s\nFANTASMA · %s\nREFERENCIA · %s" % [event_name, vehicle_name, "SÍ" if bool(payload.get("ghost_enabled", true)) else "NO", "DISPONIBLE" if bool(payload.get("ghost_available", false)) else "SIN REGISTRO"]
	elif mode == GameModeDefinition.LOCAL_MULTIPLAYER:
		summary.text = "%s\nPANTALLA DIVIDIDA · 2 HUMANOS + 6 IA\nOBJETOS %s" % [event_name, "SÍ" if bool(payload.get("items_enabled", true)) else "NO"]
	else:
		summary.text = "%s\nCARRERA RÁPIDA · %s\n8 PARTICIPANTES · OBJETOS %s" % [event_name, vehicle_name, "SÍ" if bool(payload.get("items_enabled", true)) else "NO"]
	start_button.text = "SIGUIENTE CARRERA" if locked else ("INICIAR CONTRARRELOJ" if mode == GameModeDefinition.TIME_TRIAL else ("INICIAR COPA" if mode == GameModeDefinition.CUP else "INICIAR CARRERA"))
	start_button.grab_focus.call_deferred()

func _select_cc(id: StringName, update_payload := true) -> void:
	if update_payload: payload["cc_id"] = id
	for chip in _cc_chips.get_children(): (chip as Button).set_pressed_no_signal(chip.name == str(id))

func _select_difficulty(id: StringName, update_payload := true) -> void:
	if update_payload: payload["difficulty_id"] = id
	for chip in _difficulty_chips.get_children(): (chip as Button).set_pressed_no_signal(chip.name == str(id))

func _toggle_mode_option(enabled: bool) -> void:
	if int(payload.get("mode", 0)) == GameModeDefinition.TIME_TRIAL: payload["ghost_enabled"] = enabled
	else: payload["items_enabled"] = enabled

func _start() -> void:
	start_requested.emit(payload.get("track_id", &""), payload.get("cc_id", &"150"), int(payload.get("mode", 0)), payload.get("difficulty_id", &"competitive"))

func _update_layout() -> void:
	if _grid == null: return
	var compact := size.x < 1050 or size.y < 600
	_grid.columns = 1 if compact else 3
	_showroom.custom_minimum_size = Vector2(maxf(320, size.x - 56), 230) if compact else Vector2(440, 380)
