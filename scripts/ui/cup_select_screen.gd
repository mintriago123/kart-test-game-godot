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
var _details: Label
var _continue: ActionButton
var _back: ActionButton
var _list: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.INK; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var page := VBoxContainer.new(); page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); page.offset_left = 32; page.offset_top = 24; page.offset_right = -32; page.offset_bottom = -24; page.add_theme_constant_override("separation", 12); add_child(page)
	var heading := Label.new(); heading.text = "SELECCIONA COPA"; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_font_size_override("font_size", 38); page.add_child(heading)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; page.add_child(scroll)
	_list = HBoxContainer.new(); _list.alignment = BoxContainer.ALIGNMENT_CENTER; _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _list.add_theme_constant_override("separation", 18); scroll.add_child(_list)
	var panel := PanelContainer.new(); panel.custom_minimum_size.y = 170; page.add_child(panel)
	var info := VBoxContainer.new(); panel.add_child(info)
	_title = Label.new(); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _title.add_theme_font_size_override("font_size", 28); info.add_child(_title)
	_details = Label.new(); _details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _details.size_flags_vertical = Control.SIZE_EXPAND_FILL; info.add_child(_details)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER; page.add_child(actions)
	_back = ActionButton.new(); _back.text = "VOLVER"; _back.pressed.connect(func(): back_requested.emit()); actions.add_child(_back)
	_continue = ActionButton.new(); _continue.kind = ActionButton.Kind.PRIMARY; _continue.text = "CONTINUAR"; _continue.pressed.connect(_choose); actions.add_child(_continue)

func configure(value_catalog: CupCatalog, value_progress: PlayerProgress, value_payload: Dictionary) -> void:
	catalog = value_catalog; progress = value_progress; payload = value_payload.duplicate(true)
	selected_cup_id = StringName(payload.get("cup_id", &""))
	_build_cups()
	if selected_cup_id.is_empty() and catalog != null and not catalog.get_valid_cups().is_empty(): selected_cup_id = catalog.get_valid_cups()[0].id
	select_cup(selected_cup_id)

func _build_cups() -> void:
	if _list == null: return
	for child in _list.get_children(): child.queue_free()
	cup_buttons.clear()
	if catalog == null: return
	var group := ButtonGroup.new()
	for cup in catalog.get_valid_cups():
		var button := Button.new(); button.text = cup.display_name.to_upper(); button.custom_minimum_size = Vector2(260, 96); button.toggle_mode = true; button.button_group = group; button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(select_cup.bind(cup.id)); _list.add_child(button); cup_buttons[cup.id] = button

func select_cup(cup_id: StringName) -> void:
	var cup := catalog.get_cup(cup_id) if catalog != null else null
	if cup == null: return
	selected_cup_id = cup.id
	for id in cup_buttons: (cup_buttons[id] as Button).set_pressed_no_signal(id == cup.id)
	_title.text = cup.display_name.to_upper()
	var tracks := PackedStringArray()
	for track in cup.tracks:
		tracks.append(track.display_name)
	var difficulties := PackedStringArray()
	for difficulty in cup.difficulties:
		difficulties.append(difficulty.display_name)
	var medals := "BRONCE %d · PLATA %d · ORO %d" % [cup.medal_thresholds[0], cup.medal_thresholds[1], cup.medal_thresholds[2]]
	var rewards := PackedStringArray()
	for unlock in cup.unlocks:
		rewards.append(unlock.display_name)
	var scores := PackedStringArray()
	for score in cup.scoring_table:
		scores.append(str(score))
	var active_id := StringName(progress.active_cup.get("cup_id", "")) if progress != null else &""
	var state := "COPA ACTIVA" if active_id == cup.id else ("INICIAR ESTA COPA ABANDONARÁ LA ACTUAL" if not active_id.is_empty() else "DISPONIBLE")
	_details.text = "%s\nCIRCUITOS · %s\nPUNTOS · %s\nDIFICULTADES · %s\n%s\nRECOMPENSAS · %s" % [state, " → ".join(tracks), " / ".join(scores), " · ".join(difficulties), medals, " · ".join(rewards)]
	_continue.text = "CONTINUAR COPA" if active_id == cup.id else "CONTINUAR"
	_continue.grab_focus.call_deferred()

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
