class_name PreparationScreen
extends Control

signal start_requested(track_id: StringName, cc_id: StringName, mode: int, difficulty_id: StringName)
signal back_requested
signal change_vehicle_requested(payload: Dictionary)
var payload: Dictionary
var start_button: ActionButton
var summary: Label
var _card: Control
var _cc_selector: OptionButton
var _difficulty_selector: OptionButton
var _mode_option: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.GRAPHITE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var card := VBoxContainer.new(); _card = card; card.set_anchors_preset(Control.PRESET_CENTER); card.position = Vector2(-330, -230); card.size = Vector2(660, 460); card.pivot_offset = card.size * 0.5; add_child(card)
	var title := Label.new(); title.text = "TODO LISTO"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 44); card.add_child(title)
	summary = Label.new(); summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary.add_theme_font_size_override("font_size", 22); summary.size_flags_vertical = Control.SIZE_EXPAND_FILL; card.add_child(summary)
	_cc_selector = OptionButton.new(); _cc_selector.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	for race_class in RaceClassDefinition.get_all(): _cc_selector.add_item("%s CC" % race_class.id); _cc_selector.set_item_metadata(_cc_selector.item_count - 1, race_class.id)
	_cc_selector.item_selected.connect(func(index: int): payload["cc_id"] = _cc_selector.get_item_metadata(index)); card.add_child(_cc_selector)
	_difficulty_selector = OptionButton.new(); _difficulty_selector.custom_minimum_size.y = UiTokens.TOUCH_TARGET; _difficulty_selector.item_selected.connect(func(index: int): payload["difficulty_id"] = _difficulty_selector.get_item_metadata(index)); card.add_child(_difficulty_selector)
	_mode_option = CheckButton.new(); _mode_option.custom_minimum_size.y = UiTokens.TOUCH_TARGET
	_mode_option.toggled.connect(func(enabled: bool):
		if int(payload.get("mode", 0)) == GameModeDefinition.TIME_TRIAL:
			payload["ghost_enabled"] = enabled
		else:
			payload["items_enabled"] = enabled
	)
	card.add_child(_mode_option)
	start_button = ActionButton.new(); start_button.text = "INICIAR CARRERA"; start_button.kind = ActionButton.Kind.PRIMARY; start_button.pressed.connect(_start); card.add_child(start_button)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func(): back_requested.emit()); card.add_child(back)
	resized.connect(_update_layout); _update_layout()

func configure(value: Dictionary, track: TrackDefinition, variant: KartVariantDefinition, cup: CupDefinition = null) -> void:
	payload = value.duplicate(true)
	var mode_names := ["CARRERA RÁPIDA", "CONTRARRELOJ", "COPA"]
	var mode := int(payload.get("mode", 0)); var cc := StringName(payload.get("cc_id", &"150")); var locked := bool(payload.get("continue_active", false))
	for index in _cc_selector.item_count:
		if StringName(_cc_selector.get_item_metadata(index)) == cc: _cc_selector.select(index)
	_cc_selector.disabled = locked
	_difficulty_selector.clear()
	if cup != null:
		for difficulty in cup.difficulties: _difficulty_selector.add_item(difficulty.display_name.to_upper()); _difficulty_selector.set_item_metadata(_difficulty_selector.item_count - 1, difficulty.id)
		for index in _difficulty_selector.item_count:
			if StringName(_difficulty_selector.get_item_metadata(index)) == StringName(payload.get("difficulty_id", &"competitive")): _difficulty_selector.select(index)
	_difficulty_selector.visible = cup != null; _difficulty_selector.disabled = locked
	_mode_option.visible = cup == null; _mode_option.text = "FANTASMA" if mode == GameModeDefinition.TIME_TRIAL else "OBJETOS"; _mode_option.set_pressed_no_signal(bool(payload.get("ghost_enabled", true)) if mode == GameModeDefinition.TIME_TRIAL else bool(payload.get("items_enabled", true)))
	var event_name := cup.display_name.to_upper() if cup != null else (track.display_name.to_upper() if track else "EVENTO")
	var detail := ""
	if locked:
		detail = "SIGUIENTE · %s\nVALORES BLOQUEADOS" % (track.display_name if track else "")
	elif cup != null:
		detail = "CIRCUITOS · %d\nDIFICULTAD · %s" % [cup.tracks.size(), str(payload.get("difficulty_id", &"competitive")).to_upper()]
	elif mode == GameModeDefinition.RACE:
		detail = "PARTICIPANTES · 4\nOBJETOS · %s" % ("SÍ" if GameModeDefinition.has_items(mode) else "NO")
	else:
		detail = "FANTASMA · %s" % ("SÍ" if bool(payload.get("ghost_enabled", true)) else "NO")
	summary.text = "%s\n%s · %s CC\n%s\n%s" % [event_name, variant.display_name if variant else "VEHÍCULO BASE", str(cc), mode_names[mode], detail]
	start_button.text = "SIGUIENTE CARRERA" if locked else ("INICIAR CONTRARRELOJ" if mode == GameModeDefinition.TIME_TRIAL else ("INICIAR COPA" if mode == GameModeDefinition.CUP else "INICIAR CARRERA"))
	var existing := _card.get_node_or_null("ChangeVehicle") as ActionButton
	if existing == null:
		existing = ActionButton.new(); existing.name = "ChangeVehicle"; existing.text = "CAMBIAR VEHÍCULO"; existing.pressed.connect(func(): change_vehicle_requested.emit(payload)); _card.add_child(existing); _card.move_child(existing, _card.get_child_count() - 2)
	existing.disabled = locked
	start_button.grab_focus.call_deferred()

func _start() -> void:
	start_requested.emit(payload.get("track_id", &""), payload.get("cc_id", &"150"), int(payload.get("mode", 0)), payload.get("difficulty_id", &"competitive"))

func _update_layout() -> void:
	if _card == null: return
	var factor := minf(1.0, minf((size.x - 32.0) / 660.0, (size.y - 32.0) / 460.0))
	_card.scale = Vector2.ONE * maxf(factor, 0.5)
