class_name CupSelectScreen
extends Control

const FallbackEmblem = preload("res://scripts/ui/fallback_emblem.gd")

signal cup_selected(payload: Dictionary)
signal back_requested
signal abandon_requested(payload: Dictionary)

var catalog: CupCatalog
var progression_catalog: ProgressionCatalog
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
var _hero_status: Label

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

func configure(value_catalog: Variant, value_progress: PlayerProgress, value_payload: Dictionary) -> void:
	progression_catalog = value_catalog as ProgressionCatalog
	catalog = progression_catalog.cups if progression_catalog != null else value_catalog as CupCatalog
	progress = value_progress; payload = value_payload.duplicate(true)
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
		var unlocked := _is_cup_unlocked(cup)
		var button := Button.new(); button.text = "%s%s" % ["" if unlocked else "🔒 ", cup.display_name.to_upper()]; button.custom_minimum_size = Vector2(240, 58); button.toggle_mode = true; button.button_group = group
		button.pressed.connect(select_cup.bind(cup.id)); _list.add_child(button); cup_buttons[cup.id] = button

func select_cup(cup_id: StringName) -> void:
	var cup := catalog.get_cup(cup_id) if catalog != null else null
	if cup == null: return
	selected_cup_id = cup.id
	for id in cup_buttons: (cup_buttons[id] as Button).set_pressed_no_signal(id == cup.id)
	for child in _content.get_children():
		if child != _title: child.queue_free()
	_title.text = cup.display_name.to_upper()
	var unlocked := _is_cup_unlocked(cup)
	_add_cup_hero(cup, unlocked)
	if not unlocked: _add_section("ACCESO BLOQUEADO", _cup_requirement_text(cup))
	_add_track_cards(cup)
	_add_section("PUNTUACIÓN", "1º %d  ·  2º %d  ·  3º %d  ·  4º %d\nMEDALLAS  ·  BRONCE %d  ·  PLATA %d  ·  ORO %d" % [cup.scoring_table[0], cup.scoring_table[1], cup.scoring_table[2], cup.scoring_table[3], cup.medal_thresholds[0], cup.medal_thresholds[1], cup.medal_thresholds[2]])
	_add_career_status()
	_add_difficulties(cup)
	_add_rewards(cup)
	var active_id := StringName(progress.active_cup.get("cup_id", "")) if progress != null else &""
	_active_banner.text = "● COPA ACTIVA · CONTINÚA DONDE LA DEJASTE" if active_id == cup.id else ""
	_warning_banner.text = "⚠ INICIAR ESTA COPA ABANDONARÁ LA COPA ACTIVA" if not active_id.is_empty() and active_id != cup.id else ""
	_continue.text = "CONTINUAR COPA" if active_id == cup.id else ("ELEGIR COPA" if unlocked else "COPA BLOQUEADA")
	_continue.disabled = not unlocked and active_id != cup.id
	_continue.grab_focus.call_deferred()

func _add_cup_hero(cup: CupDefinition, unlocked: bool) -> void:
	var hero := PanelContainer.new()
	hero.custom_minimum_size.y = 116
	hero.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_LARGE, UiTokens.CYAN if unlocked else UiTokens.CORAL))
	_content.add_child(hero)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", UiTokens.SPACE_6); hero.add_child(row)
	var emblem: Control
	var emblem_path := "res://assets/cups/emblems/%s.svg" % cup.id
	var emblem_texture := cup.icon
	if emblem_texture == null and ResourceLoader.exists(emblem_path): emblem_texture = load(emblem_path) as Texture2D
	if emblem_texture != null:
		var image := TextureRect.new(); image.texture = emblem_texture; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.custom_minimum_size = Vector2(84, 84); emblem = image
	else:
		var fallback := FallbackEmblem.new(); fallback.accent = UiTokens.CYAN if unlocked else UiTokens.MUTED; fallback.seed_text = cup.id.to_upper().substr(0, 2); fallback.custom_minimum_size = Vector2(84, 84); emblem = fallback
	row.add_child(emblem)
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(copy)
	var active := progress != null and StringName(progress.active_cup.get("cup_id", "")) == cup.id
	var state := UiBadge.new(); copy.add_child(state)
	state.configure(UiBadge.State.ACTIVE if active else (UiBadge.State.AVAILABLE if unlocked else UiBadge.State.LOCKED))
	var description := Label.new(); description.text = cup.description if not cup.description.is_empty() else "Tres circuitos. Una copa. Tu mejor vuelta cuenta."; description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; description.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY); copy.add_child(description)
	var progress_label := Label.new(); progress_label.text = _cup_progress_text(cup); progress_label.add_theme_color_override("font_color", UiTokens.ELECTRIC_YELLOW); copy.add_child(progress_label)

func _cup_progress_text(cup: CupDefinition) -> String:
	if progress == null: return "PROGRESO · SIN DATOS"
	var best := progress.get_best_cup_medal(cup.id)
	var active := StringName(progress.active_cup.get("cup_id", "")) == cup.id
	var race_index := int(progress.active_cup.get("current_race_index", 0)) + 1 if active else 0
	return "MEJOR MEDALLA · %s   ·   %s" % [["SIN MEDALLA", "BRONCE", "PLATA", "ORO"][best], "%d/3 CARRERAS" % race_index if active else "LISTA PARA EMPEZAR"]

func _add_track_cards(cup: CupDefinition) -> void:
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; _content.add_child(row)
	var compact := size.x < 760.0
	for index in cup.tracks.size():
		var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(170 if compact else 210, 148); panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM)); row.add_child(panel)
		var box := VBoxContainer.new(); panel.add_child(box)
		var name_label := Label.new(); name_label.text = "%02d  %s" % [index + 1, cup.tracks[index].display_name.to_upper()]; name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(name_label)
		var map := TrackMinimapView.new(); map.custom_minimum_size = Vector2(150 if compact else 190, 92); map.set_minimap_data(cup.tracks[index].preview_map); box.add_child(map)

func _add_section(title: String, body: String) -> void:
	var label := Label.new(); label.text = "%s\n%s" % [title, body]; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _content.add_child(label)

func _add_difficulties(cup: CupDefinition) -> void:
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; _content.add_child(row)
	for difficulty in cup.difficulties:
		var medal := progress.get_medal(cup.id, difficulty.id) if progress != null else 0
		var chip := Button.new(); chip.disabled = true; chip.custom_minimum_size = Vector2(190, 48); chip.text = "%s ×%d · %s" % [difficulty.display_name.to_upper(), difficulty.progress_multiplier, ["—", "BRONCE", "PLATA", "ORO"][medal]]; row.add_child(chip)

func _add_rewards(cup: CupDefinition) -> void:
	var grid := GridContainer.new(); grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; _content.add_child(grid)
	var card_width := 170 if size.x < 760.0 else 210
	for medal in range(1, 4):
		var unlock: UnlockDefinition
		for candidate in cup.unlocks:
			if candidate != null and candidate.required_medal == medal: unlock = candidate; break
		var card := Label.new(); card.custom_minimum_size = Vector2(card_width, 58); card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if unlock == null:
			card.text = "%s\nSIN PREMIO DIRECTO" % ["BRONCE", "PLATA", "ORO"][medal - 1]
		else:
			var unlocked := progress != null and progress.unlocked_reward_ids.has(unlock.id)
			var fresh := unlocked and progress.is_reward_new(unlock.id)
			card.text = "%s%s\n%s · %s" % ["" if unlocked else "🔒 ", unlock.display_name.to_upper(), ["", "BRONCE", "PLATA", "ORO"][medal], "NUEVO" if fresh else ("DESBLOQUEADO" if unlocked else "POR CONSEGUIR")]
		grid.add_child(card)

func _add_career_status() -> void:
	if progress == null or progression_catalog == null: return
	var points := progress.get_career_points(progression_catalog)
	var maximum := progress.get_max_career_points(progression_catalog)
	var next := progress.get_next_career_reward(progression_catalog)
	var next_text := "%d PTOS · %s" % [next.required_points, next.display_name.to_upper()] if next != null else "TODOS LOS HITOS CONSEGUIDOS"
	_add_section("PROGRESO GLOBAL", "%d/%d PUNTOS DE CARRERA  ·  SIGUIENTE HITO: %s" % [points, maximum, next_text])

func _is_cup_unlocked(cup: CupDefinition) -> bool:
	return progress == null or progression_catalog == null or progress.is_cup_unlocked(cup, progression_catalog)

func _cup_requirement_text(cup: CupDefinition) -> String:
	if cup.prerequisite_cup_id.is_empty(): return "Disponible desde el inicio."
	var previous := catalog.get_cup(cup.prerequisite_cup_id) if catalog != null else null
	var cup_name := previous.display_name if previous != null else str(cup.prerequisite_cup_id)
	var difficulty_name := "cualquier dificultad"
	if not cup.prerequisite_difficulty_id.is_empty() and progression_catalog != null:
		var difficulty := progression_catalog.difficulties.get_difficulty(cup.prerequisite_difficulty_id)
		difficulty_name = difficulty.display_name if difficulty != null else str(cup.prerequisite_difficulty_id)
	return "%s en %s · %s" % [["", "Bronce", "Plata", "Oro"][cup.prerequisite_medal], cup_name, difficulty_name]

func _choose() -> void:
	var cup := catalog.get_cup(selected_cup_id) if catalog != null else null
	var active_id := StringName(progress.active_cup.get("cup_id", "")) if progress != null else &""
	if cup == null or (not _is_cup_unlocked(cup) and active_id != selected_cup_id): return
	var result := payload.duplicate(true); result["cup_id"] = selected_cup_id
	result["continue_active"] = active_id == selected_cup_id
	if bool(result["continue_active"]):
		result["cc_id"] = StringName(progress.active_cup.get("cc_id", result.get("cc_id", &"150")))
		result["difficulty_id"] = StringName(progress.active_cup.get("difficulty_id", result.get("difficulty_id", &"competitive")))
		result["variant_id"] = StringName(progress.active_cup.get("variant_id", result.get("variant_id", &"")))
	if not active_id.is_empty() and active_id != selected_cup_id: abandon_requested.emit(result)
	else: cup_selected.emit(result)
