@tool
class_name CupEditorScreen
extends Control

signal filesystem_refresh_requested

const Style := preload("res://addons/track_editor/track_editor_style.gd")
const STEP_NAMES := ["Información", "Circuitos", "Competición", "Medallas", "Recompensas", "Revisar y publicar"]
const MEDAL_NAMES := ["", "Bronce", "Plata", "Oro"]

var session := CupEditorSession.new()
var tabs: TabContainer
var status_label: Label
var publish_button: Button
var id_edit: LineEdit
var name_edit: LineEdit
var description_edit: TextEdit
var icon_edit: LineEdit
var sort_spin: SpinBox
var prerequisite_cup_option: OptionButton
var prerequisite_difficulty_option: OptionButton
var prerequisite_medal_option: OptionButton
var track_options: Array[OptionButton] = []
var racer_options: Array[OptionButton] = []
var score_spins: Array[SpinBox] = []
var medal_spins: Array[SpinBox] = []
var maximum_hint: Label
var difficulty_checks: Array[CheckBox] = []
var reward_options: Array[OptionButton] = []
var review_box: VBoxContainer
var simulation_orders: Array[OptionButton] = []
var simulation_output: RichTextLabel
var structural_confirmation: ConfirmationDialog
var open_dialog: FileDialog
var _refreshing := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.create_theme()
	_build()
	session.cup_changed.connect(_refresh)
	session.dirty_changed.connect(func(_dirty): _update_status())
	session.history_changed.connect(func(_a, _b): _update_status())
	session.published.connect(func(_cup): filesystem_refresh_requested.emit())
	session.create_cup()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var toolbar := HBoxContainer.new(); root.add_child(toolbar)
	_add_button(toolbar, "Nueva", _new_cup)
	_add_button(toolbar, "Abrir…", _open_known_cup)
	_add_button(toolbar, "Recuperar", _recover)
	_add_button(toolbar, "Guardar borrador", _save)
	_add_button(toolbar, "Deshacer", session.undo)
	_add_button(toolbar, "Rehacer", session.redo)
	status_label = Label.new(); status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; toolbar.add_child(status_label)
	tabs = TabContainer.new(); tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(tabs)
	_build_information(); _build_tracks(); _build_competition(); _build_medals(); _build_rewards(); _build_review()
	structural_confirmation = ConfirmationDialog.new()
	structural_confirmation.title = "Publicar cambios estructurales"
	structural_confirmation.dialog_text = "Cambiaste acceso, circuitos, puntuación, dificultades o premios. El progreso histórico se conservará. ¿Publicar?"
	structural_confirmation.confirmed.connect(_publish_confirmed)
	add_child(structural_confirmation)
	open_dialog = FileDialog.new(); open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; open_dialog.access = FileDialog.ACCESS_RESOURCES
	open_dialog.add_filter("*.tres", "Copas"); open_dialog.file_selected.connect(func(path): session.load_cup(path)); add_child(open_dialog)
	_enforce_minimum_targets()


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.name = title; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; tabs.add_child(scroll)
	var box := VBoxContainer.new(); box.custom_minimum_size = Vector2(760, 0); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12); scroll.add_child(box)
	var heading := Label.new(); heading.text = title; heading.add_theme_font_size_override("font_size", Style.TITLE_FONT_SIZE); box.add_child(heading)
	return box


func _build_information() -> void:
	var page := _page(STEP_NAMES[0])
	name_edit = _line_row(page, "Nombre")
	id_edit = _line_row(page, "ID")
	description_edit = TextEdit.new(); description_edit.custom_minimum_size = Vector2(0, 120); description_edit.placeholder_text = "Descripción para el selector de Copa"; page.add_child(description_edit)
	icon_edit = _line_row(page, "Icono opcional (ruta res://)")
	sort_spin = SpinBox.new(); sort_spin.custom_minimum_size.y = 48; sort_spin.max_value = 9999; page.add_child(_labeled("Orden", sort_spin))
	prerequisite_cup_option = OptionButton.new(); prerequisite_cup_option.custom_minimum_size.y = 48; page.add_child(_labeled("Copa previa", prerequisite_cup_option))
	prerequisite_difficulty_option = OptionButton.new(); prerequisite_difficulty_option.custom_minimum_size.y = 48; page.add_child(_labeled("Dificultad requerida", prerequisite_difficulty_option))
	prerequisite_medal_option = OptionButton.new(); prerequisite_medal_option.custom_minimum_size.y = 48; page.add_child(_labeled("Medalla requerida", prerequisite_medal_option))
	for medal in range(1, 4): prerequisite_medal_option.add_item(MEDAL_NAMES[medal], medal)
	name_edit.text_changed.connect(func(value): _edit(func(): session.cup.display_name = value))
	id_edit.text_changed.connect(func(value): _edit(func(): session.cup.id = StringName(value)))
	description_edit.text_changed.connect(func(): _edit(func(): session.cup.description = description_edit.text))
	icon_edit.text_submitted.connect(func(value): _edit(func(): session.cup.icon = load(value) as Texture2D if not value.is_empty() else null))
	sort_spin.value_changed.connect(func(value): _edit(func(): session.cup.sort_order = int(value)))
	prerequisite_cup_option.item_selected.connect(_prerequisite_cup_changed)
	prerequisite_difficulty_option.item_selected.connect(_prerequisite_difficulty_changed)
	prerequisite_medal_option.item_selected.connect(func(index): _edit(func(): session.cup.prerequisite_medal = prerequisite_medal_option.get_item_id(index)))


func _build_tracks() -> void:
	var page := _page(STEP_NAMES[1])
	var hint := Label.new(); hint.text = "Elige tres pistas publicadas y distintas. Usa ↑/↓ para cambiar el orden."; page.add_child(hint)
	for index in 3:
		var row := HBoxContainer.new(); page.add_child(row)
		var option := OptionButton.new(); option.custom_minimum_size = Vector2(420, 48); option.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(option); track_options.append(option)
		_add_button(row, "↑", func(): _move_track(index, -1))
		_add_button(row, "↓", func(): _move_track(index, 1))
		option.item_selected.connect(func(selected): _select_track(index, selected))


func _build_competition() -> void:
	var page := _page(STEP_NAMES[2])
	for label in ["Piloto", "Rival 1", "Rival 2", "Rival 3"]:
		var option := OptionButton.new(); option.custom_minimum_size.y = 48; page.add_child(_labeled(label, option)); racer_options.append(option)
		var racer_index := racer_options.size() - 1
		option.item_selected.connect(func(selected): _select_racer(racer_index, selected))
	var score_row := HBoxContainer.new(); page.add_child(score_row)
	for index in 4:
		var spin := SpinBox.new(); spin.min_value = 0; spin.max_value = 99; spin.custom_minimum_size = Vector2(120, 48); score_row.add_child(_labeled("%d.º" % (index + 1), spin)); score_spins.append(spin)
		spin.value_changed.connect(func(value): _score_changed(index, int(value)))
	var difficulty_title := Label.new(); difficulty_title.text = "Dificultades habilitadas"; page.add_child(difficulty_title)


func _build_medals() -> void:
	var page := _page(STEP_NAMES[3])
	for medal in ["Bronce", "Plata", "Oro"]:
		var spin := SpinBox.new(); spin.min_value = 0; spin.max_value = 297; spin.custom_minimum_size.y = 48; page.add_child(_labeled(medal, spin)); medal_spins.append(spin)
		var index := medal_spins.size() - 1
		spin.value_changed.connect(func(value): _medal_changed(index, int(value)))
	maximum_hint = Label.new(); page.add_child(maximum_hint)


func _build_rewards() -> void:
	var page := _page(STEP_NAMES[4])
	var hint := Label.new(); hint.text = "Hasta un vehículo por medalla, acumulativo sin importar la dificultad. «Sin premio» conserva como archivo cualquier premio publicado que retires."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(hint)
	var grid := GridContainer.new(); grid.columns = 3; page.add_child(grid)
	for medal in range(1, 4):
		var box := VBoxContainer.new(); grid.add_child(box)
		var label := Label.new(); label.text = MEDAL_NAMES[medal]; box.add_child(label)
		var option := OptionButton.new(); option.custom_minimum_size = Vector2(220, 48); box.add_child(option); reward_options.append(option)
		var reward_index := reward_options.size() - 1
		option.item_selected.connect(func(selected): _reward_changed(reward_index, selected))
	var milestone_title := Label.new(); milestone_title.text = "Hitos globales (solo lectura)"; milestone_title.add_theme_font_size_override("font_size", 20); page.add_child(milestone_title)
	var milestone_summary := Label.new(); milestone_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page.add_child(milestone_summary)
	var milestones := PackedStringArray()
	if session.catalog != null and session.catalog.unlocks != null:
		for reward in session.catalog.unlocks.get_career_rewards(): milestones.append("%d puntos · %s" % [reward.required_points, reward.display_name])
	milestone_summary.text = "     ".join(milestones) if not milestones.is_empty() else "No hay hitos globales configurados."


func _build_review() -> void:
	var page := _page(STEP_NAMES[5])
	review_box = VBoxContainer.new(); page.add_child(review_box)
	var simulator_title := Label.new(); simulator_title.text = "Simulador (posición del jugador por carrera)"; page.add_child(simulator_title)
	var row := HBoxContainer.new(); page.add_child(row)
	for race in 3:
		var option := OptionButton.new(); option.custom_minimum_size = Vector2(150, 48)
		for position in 4: option.add_item("Carrera %d: %d.º" % [race + 1, position + 1], position)
		row.add_child(option); simulation_orders.append(option)
	_add_button(row, "Simular", _simulate)
	simulation_output = RichTextLabel.new(); simulation_output.fit_content = true; simulation_output.custom_minimum_size.y = 110; page.add_child(simulation_output)
	publish_button = _add_button(page, "Publicar", _publish)


func _refresh(_cup: CupDefinition = null) -> void:
	if session.cup == null: return
	_refreshing = true
	name_edit.text = session.cup.display_name; id_edit.text = str(session.cup.id); id_edit.editable = not session.is_published
	description_edit.text = session.cup.description; sort_spin.value = session.cup.sort_order
	icon_edit.text = session.cup.icon.resource_path if session.cup.icon != null else ""
	_populate_prerequisites(); _populate_tracks(); _populate_racers(); _populate_difficulties(); _populate_rewards()
	for index in score_spins.size(): score_spins[index].value = session.cup.scoring_table[index] if index < session.cup.scoring_table.size() else 0
	for index in medal_spins.size(): medal_spins[index].value = session.cup.medal_thresholds[index] if index < session.cup.medal_thresholds.size() else 0
	maximum_hint.text = "Máximo posible: %d puntos" % ((session.cup.scoring_table[0] if session.cup.scoring_table.size() else 0) * 3)
	_refresh_review(); _refreshing = false; _update_status()


func _populate_tracks() -> void:
	var catalog := load("res://levels/track_catalog.tres") as TrackCatalog
	for index in track_options.size():
		var option := track_options[index]; option.clear(); option.add_item("Seleccionar pista…", 0); option.set_item_metadata(0, &"")
		if catalog != null:
			for track in catalog.tracks:
				if track == null or not track.is_valid(): continue
				option.add_item("%s · %d vueltas · %.1f km · %d atajos" % [track.display_name, track.laps, track.length_km, track.shortcut_count]); option.set_item_metadata(option.item_count - 1, track.id)
		var selected := session.cup.tracks[index].id if index < session.cup.tracks.size() and session.cup.tracks[index] != null else &""
		_select_by_metadata(option, selected)


func _populate_prerequisites() -> void:
	prerequisite_cup_option.clear(); prerequisite_cup_option.add_item("Sin requisito"); prerequisite_cup_option.set_item_metadata(0, &"")
	if session.catalog != null and session.catalog.cups != null:
		for candidate in session.catalog.cups.get_valid_cups():
			if candidate.id == session.cup.id: continue
			prerequisite_cup_option.add_item(candidate.display_name); prerequisite_cup_option.set_item_metadata(prerequisite_cup_option.item_count - 1, candidate.id)
	_select_by_metadata(prerequisite_cup_option, session.cup.prerequisite_cup_id)
	prerequisite_difficulty_option.clear(); prerequisite_difficulty_option.add_item("Cualquier dificultad"); prerequisite_difficulty_option.set_item_metadata(0, &"")
	if session.catalog != null and session.catalog.difficulties != null:
		for difficulty in session.catalog.difficulties.difficulties:
			prerequisite_difficulty_option.add_item(difficulty.display_name); prerequisite_difficulty_option.set_item_metadata(prerequisite_difficulty_option.item_count - 1, difficulty.id)
	_select_by_metadata(prerequisite_difficulty_option, session.cup.prerequisite_difficulty_id)
	prerequisite_medal_option.select(clampi(session.cup.prerequisite_medal - 1, 0, 2))
	var enabled := not session.cup.prerequisite_cup_id.is_empty()
	prerequisite_difficulty_option.disabled = not enabled; prerequisite_medal_option.disabled = not enabled


func _populate_racers() -> void:
	var racers := session.catalog.racers.racers if session.catalog != null else []
	for index in racer_options.size():
		var option := racer_options[index]; option.clear(); option.add_item("Seleccionar piloto…"); option.set_item_metadata(0, &"")
		for racer in racers:
			option.add_item(racer.display_name); option.set_item_metadata(option.item_count - 1, racer.id)
		var selected := session.cup.player_racer.id if index == 0 and session.cup.player_racer != null else (&"" if index == 0 or index - 1 >= session.cup.opponents.size() or session.cup.opponents[index - 1] == null else session.cup.opponents[index - 1].id)
		_select_by_metadata(option, selected)


func _populate_difficulties() -> void:
	var parent := score_spins[0].get_parent().get_parent()
	for check in difficulty_checks: check.queue_free()
	difficulty_checks.clear()
	if session.catalog == null: return
	for difficulty in session.catalog.difficulties.difficulties:
		var check := CheckBox.new(); check.text = difficulty.display_name; check.custom_minimum_size.y = 48; check.button_pressed = difficulty in session.cup.difficulties; parent.add_child(check); difficulty_checks.append(check)
		check.toggled.connect(func(enabled): _difficulty_changed(difficulty, enabled))


func _populate_rewards() -> void:
	if session.catalog == null: return
	for index in reward_options.size():
		var option := reward_options[index]; option.clear(); option.add_item("Sin premio"); option.set_item_metadata(0, &"")
		for variant in session.catalog.unlocks.variants:
			if variant == null or session.catalog.unlocks.is_initial_variant(variant.id): continue
			option.add_item(variant.display_name); option.set_item_metadata(option.item_count - 1, variant.id)
		var medal := index + 1
		var reward := _find_reward(medal)
		_select_by_metadata(option, reward.kart_variant.id if reward != null and reward.kart_variant != null else &"")


func _refresh_review() -> void:
	for child in review_box.get_children(): child.queue_free()
	var issues := session.validate()
	for issue in issues:
		var button := Button.new(); button.text = "• %s" % issue.message; button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.custom_minimum_size.y = 48; review_box.add_child(button)
		button.pressed.connect(func(): _navigate(issue.field_path))
	if issues.is_empty():
		var ok := Label.new(); ok.text = "✓ La Copa está lista para publicar."; review_box.add_child(ok)
	if publish_button != null: publish_button.disabled = not issues.is_empty()


func _edit(action: Callable) -> void:
	if _refreshing or session.cup == null: return
	session.snapshot(); action.call(); session.changed(); _refresh_review()


func _select_track(index: int, selected: int) -> void:
	if _refreshing: return
	var id: StringName = track_options[index].get_item_metadata(selected)
	var catalog := load("res://levels/track_catalog.tres") as TrackCatalog
	var track := catalog.get_track(id) if catalog != null and not id.is_empty() else null
	_edit(func():
		while session.cup.tracks.size() < 3: session.cup.tracks.append(null)
		session.cup.tracks[index] = track)


func _move_track(index: int, direction: int) -> void:
	var target := index + direction
	if target < 0 or target >= 3: return
	_edit(func():
		while session.cup.tracks.size() < 3: session.cup.tracks.append(null)
		var value = session.cup.tracks[index]; session.cup.tracks[index] = session.cup.tracks[target]; session.cup.tracks[target] = value)


func _select_racer(index: int, selected: int) -> void:
	if _refreshing: return
	var racer := session.catalog.racers.get_racer(racer_options[index].get_item_metadata(selected))
	_edit(func():
		if index == 0: session.cup.player_racer = racer
		else:
			while session.cup.opponents.size() < 3: session.cup.opponents.append(null)
			session.cup.opponents[index - 1] = racer)


func _score_changed(index: int, value: int) -> void:
	_edit(func():
		while session.cup.scoring_table.size() < 4: session.cup.scoring_table.append(0)
		session.cup.scoring_table[index] = value)


func _medal_changed(index: int, value: int) -> void:
	_edit(func():
		while session.cup.medal_thresholds.size() < 3: session.cup.medal_thresholds.append(0)
		session.cup.medal_thresholds[index] = value)


func _difficulty_changed(difficulty: DifficultyDefinition, enabled: bool) -> void:
	_edit(func():
		if enabled and difficulty not in session.cup.difficulties: session.cup.difficulties.append(difficulty)
		elif not enabled: session.cup.difficulties.erase(difficulty))


func _prerequisite_cup_changed(selected: int) -> void:
	if _refreshing: return
	var cup_id := StringName(prerequisite_cup_option.get_item_metadata(selected))
	_edit(func():
		session.cup.prerequisite_cup_id = cup_id
		if cup_id.is_empty(): session.cup.prerequisite_difficulty_id = &"")


func _prerequisite_difficulty_changed(selected: int) -> void:
	if _refreshing: return
	var difficulty_id := StringName(prerequisite_difficulty_option.get_item_metadata(selected))
	_edit(func(): session.cup.prerequisite_difficulty_id = difficulty_id)


func _reward_changed(index: int, selected: int) -> void:
	if _refreshing: return
	var medal := index + 1
	var variant_id: StringName = reward_options[index].get_item_metadata(selected)
	_edit(func():
		var reward := _find_reward(medal)
		if variant_id.is_empty():
			if reward != null: session.cup.unlocks.erase(reward)
			return
		var variant := session.catalog.unlocks.get_variant(variant_id)
		if reward == null: reward = UnlockDefinition.new(); reward.requirement_type = UnlockDefinition.CUP_MEDAL; reward.required_medal = medal; reward.cup_id = session.cup.id; session.cup.unlocks.append(reward)
		if variant != null: reward.kart_variant = variant; reward.display_name = variant.display_name)


func _find_reward(medal: int) -> UnlockDefinition:
	for reward in session.cup.unlocks:
		if reward != null and reward.requirement_type == UnlockDefinition.CUP_MEDAL and reward.required_medal == medal: return reward
	return null


func _simulate() -> void:
	if session.cup.player_racer == null or session.cup.opponents.size() != 3: simulation_output.text = "Completa los pilotos antes de simular."; return
	var ids := PackedStringArray([session.cup.player_racer.id])
	for racer in session.cup.opponents: ids.append(racer.id)
	var orders: Array = []
	for option in simulation_orders:
		var position := option.selected; var order := PackedStringArray(); var rivals := ids.slice(1)
		for slot in 4:
			if slot == position: order.append(ids[0])
			else: order.append(rivals[0]); rivals.remove_at(0)
		orders.append(order)
	var difficulty := session.cup.difficulties[0] if not session.cup.difficulties.is_empty() else null
	var result := CupEvaluator.evaluate(session.cup, difficulty, orders)
	if not result.is_valid(): simulation_output.text = "\n".join(result.errors); return
	var reward_names := PackedStringArray()
	for reward in result.eligible_rewards: reward_names.append(reward.display_name)
	simulation_output.text = "Puesto: %d.º · Puntos: %d · Medalla: %s\nPremios: %s" % [result.player_position, result.player_points, MEDAL_NAMES[result.medal], ", ".join(reward_names) if not reward_names.is_empty() else "ninguno"]


func _publish() -> void:
	if session.structural_changes_from_published():
		structural_confirmation.popup_centered(Vector2i(560, 220))
		return
	_publish_confirmed()


func _publish_confirmed() -> void:
	var error := session.publish_cup()
	status_label.text = "Publicada correctamente." if error == OK else session.last_error
	_refresh()


func _new_cup() -> void: session.create_cup()
func _recover() -> void: session.recover()
func _save() -> void:
	var error := session.save_draft(); status_label.text = "Borrador guardado." if error == OK else session.last_error


func _open_known_cup() -> void:
	open_dialog.current_dir = "res://progression/cups"
	open_dialog.popup_centered_ratio(0.7)


func _navigate(path: StringName) -> void:
	var root := str(path).get_slice("/", 0)
	var index := ["information", "tracks", "competition", "medals", "rewards", "review"].find(root)
	if index >= 0: tabs.current_tab = index


func _update_status() -> void:
	status_label.text = "%s%s" % ["Publicada" if session.is_published else "Borrador", " · cambios sin guardar" if session.is_dirty else ""]


func _line_row(parent: VBoxContainer, label: String) -> LineEdit:
	var edit := LineEdit.new(); edit.custom_minimum_size.y = 48; parent.add_child(_labeled(label, edit)); return edit


func _labeled(label_text: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new(); var label := Label.new(); label.text = label_text; box.add_child(label); box.add_child(control); return box


func _add_button(parent: Control, label: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = label; button.custom_minimum_size.y = 48; button.pressed.connect(callback); parent.add_child(button); return button


func _select_by_metadata(option: OptionButton, value: StringName) -> void:
	for index in option.item_count:
		if StringName(option.get_item_metadata(index)) == value: option.select(index); return


func _enforce_minimum_targets() -> void:
	for node in find_children("*", "BaseButton", true, false):
		(node as Control).custom_minimum_size.y = maxf((node as Control).custom_minimum_size.y, 48.0)
