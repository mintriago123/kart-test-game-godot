class_name CupSelectScreen
extends Control

signal cup_selected(payload: Dictionary)
signal back_requested
signal abandon_requested(payload: Dictionary)

var catalog: CupCatalog
var progress: PlayerProgress
var selected_cup_id: StringName
var payload: Dictionary = {}
var cup_buttons: Dictionary = {}
var _title: Label
var _details: Label # Compatibility reference; visual details now live in _content.
var _continue: ActionButton
var _back: ActionButton
var _list: HBoxContainer
var _content: VBoxContainer
var _active_banner: Label
var _warning_banner: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.INK; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page.offset_left = 24; page.offset_top = 16; page.offset_right = -24; page.offset_bottom = -16; page.add_theme_constant_override("separation", 10); add_child(page)
	var heading := Label.new(); heading.text = "SELECCIONA COPA"; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_font_size_override("font_size", 36); page.add_child(heading)
	var carousel := ScrollContainer.new(); carousel.custom_minimum_size.y = 74; carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; page.add_child(carousel)
	_list = HBoxContainer.new(); _list.alignment = BoxContainer.ALIGNMENT_CENTER; _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _list.add_theme_constant_override("separation", 14); carousel.add_child(_list)
	_active_banner = Label.new(); _active_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _active_banner.add_theme_color_override("font_color", UiTokens.SUCCESS); page.add_child(_active_banner)
	_warning_banner = Label.new(); _warning_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _warning_banner.add_theme_color_override("font_color", UiTokens.CORAL); page.add_child(_warning_banner)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; page.add_child(scroll)
	_content = VBoxContainer.new(); _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _content.add_theme_constant_override("separation", 12); scroll.add_child(_content)
	_title = Label.new(); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _title.add_theme_font_size_override("font_size", 30); _content.add_child(_title)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER; page.add_child(actions)
	_back = ActionButton.new(); _back.text = "VOLVER"; _back.pressed.connect(func(): back_requested.emit()); actions.add_child(_back)
	_continue = ActionButton.new(); _continue.kind = ActionButton.Kind.PRIMARY; _continue.text = "CONTINUAR"; _continue.pressed.connect(_choose); actions.add_child(_continue)

func configure(value_catalog: CupCatalog, value_progress: PlayerProgress, value_payload: Dictionary) -> void:
	catalog = value_catalog; progress = value_progress; payload = value_payload.duplicate(true)
	selected_cup_id = StringName(payload.get("cup_id", &"")); _build_cups()
	var cups := catalog.get_valid_cups() if catalog != null else []
	if selected_cup_id.is_empty() and not cups.is_empty(): selected_cup_id = cups[0].id
	select_cup(selected_cup_id)

func _build_cups() -> void:
	if _list == null: return
	for child in _list.get_children(): child.queue_free()
	cup_buttons.clear()
	if catalog == null: return
	var group := ButtonGroup.new()
	for cup in catalog.get_valid_cups():
		var button := Button.new(); button.text = cup.display_name.to_upper(); button.custom_minimum_size = Vector2(240, 58); button.toggle_mode = true; button.button_group = group
		button.pressed.connect(select_cup.bind(cup.id)); _list.add_child(button); cup_buttons[cup.id] = button

func select_cup(cup_id: StringName) -> void:
	var cup := catalog.get_cup(cup_id) if catalog != null else null
	if cup == null: return
	selected_cup_id = cup.id
	for id in cup_buttons: (cup_buttons[id] as Button).set_pressed_no_signal(id == cup.id)
	for child in _content.get_children():
		if child != _title: child.queue_free()
	_title.text = cup.display_name.to_upper()
	_add_track_cards(cup)
	_add_section("PUNTUACIÓN", "1º %d  ·  2º %d  ·  3º %d  ·  4º %d\nMEDALLAS  ·  BRONCE %d  ·  PLATA %d  ·  ORO %d" % [cup.scoring_table[0], cup.scoring_table[1], cup.scoring_table[2], cup.scoring_table[3], cup.medal_thresholds[0], cup.medal_thresholds[1], cup.medal_thresholds[2]])
	_add_difficulties(cup)
	_add_rewards(cup)
	var active_id := StringName(progress.active_cup.get("cup_id", "")) if progress != null else &""
	_active_banner.text = "● COPA ACTIVA · CONTINÚA DONDE LA DEJASTE" if active_id == cup.id else ""
	_warning_banner.text = "⚠ INICIAR ESTA COPA ABANDONARÁ LA COPA ACTIVA" if not active_id.is_empty() and active_id != cup.id else ""
	_continue.text = "CONTINUAR COPA" if active_id == cup.id else "ELEGIR COPA"
	_continue.grab_focus.call_deferred()

func _add_track_cards(cup: CupDefinition) -> void:
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; _content.add_child(row)
	for index in cup.tracks.size():
		var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(210, 132); row.add_child(panel)
		var box := VBoxContainer.new(); panel.add_child(box)
		var name_label := Label.new(); name_label.text = "%02d  %s" % [index + 1, cup.tracks[index].display_name.to_upper()]; name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(name_label)
		var map := TrackMinimapView.new(); map.custom_minimum_size = Vector2(190, 92); map.set_minimap_data(cup.tracks[index].preview_map); box.add_child(map)

func _add_section(title: String, body: String) -> void:
	var label := Label.new(); label.text = "%s\n%s" % [title, body]; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _content.add_child(label)

func _add_difficulties(cup: CupDefinition) -> void:
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; _content.add_child(row)
	for difficulty in cup.difficulties:
		var medal := progress.get_medal(cup.id, difficulty.id) if progress != null else 0
		var chip := Button.new(); chip.disabled = true; chip.custom_minimum_size = Vector2(170, 48); chip.text = "%s · %s" % [difficulty.display_name.to_upper(), ["—", "BRONCE", "PLATA", "ORO"][medal]]; row.add_child(chip)

func _add_rewards(cup: CupDefinition) -> void:
	var grid := GridContainer.new(); grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; _content.add_child(grid)
	for unlock in cup.unlocks:
		var unlocked := progress != null and progress.unlocked_reward_ids.has(unlock.id)
		var fresh := unlocked and progress.is_reward_new(unlock.id)
		var card := Label.new(); card.custom_minimum_size = Vector2(210, 58); card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.text = "%s%s\n%s · %s" % ["" if unlocked else "🔒 ", unlock.display_name.to_upper(), ["", "BRONCE", "PLATA", "ORO"][unlock.required_medal], "NUEVO" if fresh else ("DESBLOQUEADO" if unlocked else unlock.difficulty_id.to_upper())]; grid.add_child(card)

func _choose() -> void:
	var result := payload.duplicate(true); result["cup_id"] = selected_cup_id
	var active_id := StringName(progress.active_cup.get("cup_id", "")) if progress != null else &""
	result["continue_active"] = active_id == selected_cup_id
	if bool(result["continue_active"]):
		result["cc_id"] = StringName(progress.active_cup.get("cc_id", result.get("cc_id", &"150")))
		result["difficulty_id"] = StringName(progress.active_cup.get("difficulty_id", result.get("difficulty_id", &"competitive")))
		result["variant_id"] = StringName(progress.active_cup.get("variant_id", result.get("variant_id", &"")))
	if not active_id.is_empty() and active_id != selected_cup_id: abandon_requested.emit(result)
	else: cup_selected.emit(result)
