@tool
class_name TrackEditorScreen
extends Control

signal play_requested(scene_path: String, track_id: StringName, laps: int)

const CATALOG_PATH := "res://levels/track_catalog.tres"
const ASSET_LIBRARY_PATH := "res://assets/track/track_asset_library.tres"
const STEP_LABELS := [
	"1  CONFIGURACIÓN",
	"2  CARRETERA",
	"3  ATAJOS",
	"4  OBJETOS",
	"5  REVISAR",
]

var session := TrackEditorSession.new()

var _title_label: Label
var _dirty_label: Label
var _status_label: Label
var _step_buttons: Array[Button] = []
var _properties: VBoxContainer
var _map_view: TrackMapView
var _preview_container: SubViewportContainer
var _preview_viewport: SubViewport
var _preview_camera: Camera3D
var _view_toggle: Button
var _undo_button: Button
var _redo_button: Button
var _track_picker: OptionButton
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _new_size: OptionButton
var _open_dialog: FileDialog
var _unsaved_dialog: ConfirmationDialog
var _guide_dialog: AcceptDialog
var _pending_action := ""
var _pending_path := ""
var _current_step := 0
var _laps := 3
var _description := ""
var _is_showing_preview := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _create_workshop_theme()
	_build_interface()
	_connect_session()
	_reload_track_picker()
	if _track_picker.item_count > 0:
		_load_selected_track()


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not key_event.ctrl_pressed:
		return
	if key_event.keycode == KEY_Z:
		if key_event.shift_pressed:
			session.redo_route()
		else:
			session.undo_route()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_Y:
		session.redo_route()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_S:
		_handle_save_pressed()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	var navigation := _build_navigation()
	body.add_child(navigation)

	var workspace := _build_workspace()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(workspace)

	var inspector := _build_inspector()
	body.add_child(inspector)

	_status_label = Label.new()
	_status_label.name = "EditorStatus"
	_status_label.text = "● Abre una pista o crea una nueva."
	_status_label.custom_minimum_size.y = 40.0
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color("#aab5b9"))
	_status_label.add_theme_color_override("font_shadow_color", Color("#151b1f"))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_status_label)

	_build_new_dialog()
	_build_open_dialog()
	_build_unsaved_dialog()
	_build_guide_dialog()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "PitLaneToolbar"
	header.custom_minimum_size.y = 64.0
	header.add_theme_constant_override("separation", 8)

	_title_label = Label.new()
	_title_label.text = "PISTAS  /  SIN PISTA"
	_title_label.custom_minimum_size.x = 280.0
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color("#f6c344"))
	header.add_child(_title_label)

	var new_button := _button("＋ NUEVA", _handle_new_pressed)
	header.add_child(new_button)
	header.add_child(_button("ABRIR", _handle_open_pressed))

	_track_picker = OptionButton.new()
	_track_picker.name = "TrackPicker"
	_track_picker.custom_minimum_size = Vector2(220.0, 44.0)
	_track_picker.item_selected.connect(func(_index: int) -> void: _request_load_selected())
	header.add_child(_track_picker)

	header.add_child(_button("GUARDAR", _handle_save_pressed))

	_undo_button = _button("↶", session.undo_route, "Deshacer cambio de carretera")
	_undo_button.custom_minimum_size.x = 48.0
	header.add_child(_undo_button)
	_redo_button = _button("↷", session.redo_route, "Rehacer cambio de carretera")
	_redo_button.custom_minimum_size.x = 48.0
	header.add_child(_redo_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	header.add_child(_button("? GUÍA", _show_guide))

	_dirty_label = Label.new()
	_dirty_label.text = "GUARDADO"
	_dirty_label.add_theme_color_override("font_color", Color("#42c7b9"))
	header.add_child(_dirty_label)

	header.add_child(_button("▶ PROBAR", _handle_test_pressed))
	header.add_child(_button("PUBLICAR", _handle_publish_pressed, "", true))
	return header


func _build_navigation() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 210.0
	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	panel.add_child(navigation)

	var label := Label.new()
	label.text = "RUTA DE TRABAJO"
	label.add_theme_color_override("font_color", Color("#7f8c92"))
	navigation.add_child(label)

	var group := ButtonGroup.new()
	for step_index in STEP_LABELS.size():
		var step_button := Button.new()
		step_button.text = STEP_LABELS[step_index]
		step_button.toggle_mode = true
		step_button.button_group = group
		step_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		step_button.custom_minimum_size = Vector2(190.0, 50.0)
		step_button.pressed.connect(_show_step.bind(step_index))
		navigation.add_child(step_button)
		_step_buttons.append(step_button)
	_step_buttons[0].button_pressed = true

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)

	var help := Label.new()
	help.text = (
		"CONSEJO DE BOXES\n\nSigue los pasos de arriba hacia abajo. "
		+ "No necesitas usar el árbol de nodos ni el Inspector."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color("#aab5b9"))
	navigation.add_child(help)
	return panel


func _build_workspace() -> VBoxContainer:
	var workspace := VBoxContainer.new()
	workspace.add_theme_constant_override("separation", 0)

	var view_bar := HBoxContainer.new()
	view_bar.custom_minimum_size.y = 48.0
	var map_label := Label.new()
	map_label.text = "  MESA DE TRAZADO"
	map_label.add_theme_color_override("font_color", Color("#f4f1e8"))
	view_bar.add_child(map_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_bar.add_child(spacer)
	_view_toggle = _button("VISTA 3D", _toggle_view)
	view_bar.add_child(_view_toggle)
	workspace.add_child(view_bar)

	var view_stack := Control.new()
	view_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(view_stack)

	_map_view = TrackMapView.new()
	_map_view.name = "TrackMap"
	_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_view.edit_started.connect(session.snapshot_route_for_undo)
	_map_view.route_edited.connect(_handle_route_edited)
	_map_view.edit_finished.connect(_handle_route_edit_finished)
	_map_view.point_selected.connect(_handle_point_selected)
	view_stack.add_child(_map_view)

	_preview_container = SubViewportContainer.new()
	_preview_container.name = "TrackPreview3D"
	_preview_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_container.stretch = true
	_preview_container.visible = false
	view_stack.add_child(_preview_container)
	_preview_viewport = SubViewport.new()
	_preview_viewport.own_world_3d = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_preview_viewport)
	_build_preview_world()
	return workspace


func _build_inspector() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320.0
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_properties = VBoxContainer.new()
	_properties.custom_minimum_size.x = 292.0
	_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_properties.add_theme_constant_override("separation", 10)
	scroll.add_child(_properties)
	return panel


func _build_preview_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#22343a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d8ece6")
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	_preview_viewport.add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	_preview_viewport.add_child(light)

	_preview_camera = Camera3D.new()
	_preview_camera.position = Vector3(135.0, 150.0, 135.0)
	_preview_camera.fov = 58.0
	_preview_camera.look_at_from_position(
		_preview_camera.position,
		Vector3.ZERO
	)
	_preview_viewport.add_child(_preview_camera)


func _connect_session() -> void:
	session.track_changed.connect(_handle_track_changed)
	session.route_changed.connect(_handle_session_route_changed)
	session.dirty_changed.connect(_handle_dirty_changed)
	session.history_changed.connect(_handle_history_changed)


func _reload_track_picker() -> void:
	_track_picker.clear()
	var catalog := load(CATALOG_PATH) as TrackCatalog
	if catalog == null:
		return
	for definition in catalog.tracks:
		if definition != null and definition.scene != null:
			_track_picker.add_item(definition.display_name)
			_track_picker.set_item_metadata(
				_track_picker.item_count - 1,
				definition.scene.resource_path
			)


func _request_load_selected() -> void:
	if _track_picker.selected < 0:
		return
	var path := str(_track_picker.get_item_metadata(_track_picker.selected))
	if session.is_dirty:
		_show_unsaved_dialog("load", path)
	else:
		_load_path(path)


func _load_selected_track() -> void:
	if _track_picker.selected >= 0:
		_load_path(str(_track_picker.get_item_metadata(_track_picker.selected)))


func _load_path(path: String) -> void:
	var error := session.load_track(path)
	if error != OK:
		_show_error("No se pudo abrir la pista (%s)." % error_string(error))
		return
	var catalog := load(CATALOG_PATH) as TrackCatalog
	var definition := (
		catalog.get_track(session.track.track_id)
		if catalog != null
		else null
	)
	if definition != null:
		_laps = definition.laps
		_description = definition.description
	else:
		_laps = 3
		_description = ""
	if session.last_repair_summary.is_empty():
		_show_success("Pista abierta. Comienza por Configuración o Carretera.")
	else:
		_show_success(
			"%s. Guarda para conservar la reparación."
			% session.last_repair_summary.capitalize()
		)


func _handle_track_changed(track: TrackLevel) -> void:
	for child in _preview_viewport.get_children():
		if child is TrackLevel:
			_preview_viewport.remove_child(child)
			child.queue_free()
	if track.get_parent() != null:
		track.get_parent().remove_child(track)
	_preview_viewport.add_child(track)
	_map_view.set_track(track)
	_title_label.text = "PISTAS  /  %s" % track.display_name.to_upper()
	_rebuild_preview()
	_show_step(_current_step)


func _handle_dirty_changed(is_dirty: bool) -> void:
	_dirty_label.text = "● SIN GUARDAR" if is_dirty else "✓ GUARDADO"
	_dirty_label.add_theme_color_override(
		"font_color",
		Color("#f6c344") if is_dirty else Color("#42c7b9")
	)


func _handle_session_route_changed() -> void:
	_map_view.set_track(session.track)
	_rebuild_preview()
	if _current_step == 1:
		_show_step(1)


func _handle_history_changed(can_undo: bool, can_redo: bool) -> void:
	_undo_button.disabled = not can_undo
	_redo_button.disabled = not can_redo


func _show_step(step_index: int) -> void:
	_current_step = clampi(step_index, 0, STEP_LABELS.size() - 1)
	_step_buttons[_current_step].set_pressed_no_signal(true)
	for child in _properties.get_children():
		child.queue_free()
	_add_section_title(STEP_LABELS[_current_step])
	if session.track == null:
		_add_help("Abre o crea una pista para comenzar.")
		return
	match _current_step:
		0:
			_build_setup_properties()
		1:
			_build_route_properties()
		2:
			_build_shortcut_properties()
		3:
			_build_object_properties()
		4:
			_build_review_properties()


func _build_setup_properties() -> void:
	_add_help("Ponle identidad a la pista. Las opciones técnicas se configuran solas.")
	_add_field_label("Nombre visible")
	var name_edit := LineEdit.new()
	name_edit.text = session.track.display_name
	name_edit.custom_minimum_size.y = 44.0
	name_edit.text_changed.connect(func(value: String) -> void:
		session.track.display_name = value
		session.track.start_banner_text = value.to_upper()
		_title_label.text = "PISTAS  /  %s" % value.to_upper()
		session.mark_dirty()
	)
	_properties.add_child(name_edit)
	_add_field_label("Identificador")
	var id_label := Label.new()
	id_label.text = str(session.track.track_id)
	id_label.add_theme_color_override("font_color", Color("#aab5b9"))
	_properties.add_child(id_label)
	_add_field_label("Vueltas")
	var laps := SpinBox.new()
	laps.min_value = 1.0
	laps.max_value = 9.0
	laps.value = _laps
	laps.custom_minimum_size.y = 44.0
	laps.value_changed.connect(func(value: float) -> void: _laps = int(value))
	_properties.add_child(laps)
	_add_field_label("Descripción para el menú")
	var description := TextEdit.new()
	description.text = _description
	description.custom_minimum_size.y = 100.0
	description.text_changed.connect(func() -> void: _description = description.text)
	_properties.add_child(description)


func _build_route_properties() -> void:
	_add_help(
		"Selecciona un punto blanco y arrástralo. Las flechas del teclado "
		+ "también lo mueven con precisión."
	)
	var selected := _map_view.selected_point
	var selected_label := Label.new()
	selected_label.text = (
		"Punto seleccionado: %d" % (selected + 1)
		if selected >= 0
		else "Selecciona un punto en el mapa"
	)
	selected_label.add_theme_color_override("font_color", Color("#f6c344"))
	_properties.add_child(selected_label)
	var add_button := _button("＋ AÑADIR PUNTO DESPUÉS", _handle_add_point)
	add_button.disabled = selected < 0
	_properties.add_child(add_button)
	var delete_button := _button("ELIMINAR PUNTO", _handle_delete_point)
	delete_button.disabled = selected < 0 or _route_point_count() <= 4
	_properties.add_child(delete_button)
	_add_field_label("Altura del punto")
	var height := SpinBox.new()
	height.min_value = 0.0
	height.max_value = 12.0
	height.step = 0.25
	height.custom_minimum_size.y = 44.0
	height.editable = selected >= 0
	if selected >= 0:
		height.value = session.track.get_main_route().curve.get_point_position(selected).y
	height.value_changed.connect(func(value: float) -> void:
		if height.editable:
			_map_view.set_selected_height(value)
	)
	_properties.add_child(height)
	var start_button := _button("MARCAR COMO SALIDA", _handle_mark_start)
	start_button.disabled = selected < 0
	_properties.add_child(start_button)


func _build_shortcut_properties() -> void:
	_add_help(
		"Elige dos puntos de la carretera. La entrada debe aparecer antes "
		+ "que la salida siguiendo las flechas."
	)
	var entry := OptionButton.new()
	var exit := OptionButton.new()
	for point_index in _route_point_count():
		entry.add_item("Entrada en punto %d" % (point_index + 1))
		exit.add_item("Salida en punto %d" % (point_index + 1))
	entry.custom_minimum_size.y = 44.0
	exit.custom_minimum_size.y = 44.0
	exit.select(mini(3, maxi(0, exit.item_count - 1)))
	_properties.add_child(entry)
	_properties.add_child(exit)
	_properties.add_child(
		_button(
			"＋ CREAR ATAJO",
			func() -> void: _create_shortcut(entry.selected, exit.selected)
		)
	)
	for shortcut in session.track.get_shortcuts():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "✓ %s" % shortcut.display_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(
			_button(
				"Eliminar",
				_delete_shortcut.bind(shortcut),
				"Eliminar %s" % shortcut.display_name
			)
		)
		_properties.add_child(row)


func _build_object_properties() -> void:
	_add_help(
		"Elige un punto y un lado. El editor coloca la decoración fuera "
		+ "de la carretera para no bloquear los karts."
	)
	_add_field_label("Cajas de objetos")
	var route_point := OptionButton.new()
	for point_index in _route_point_count():
		route_point.add_item("Punto %d" % (point_index + 1))
	route_point.custom_minimum_size.y = 44.0
	_properties.add_child(route_point)
	_properties.add_child(
		_button(
			"＋ AÑADIR CAJA",
			func() -> void: _add_item_spawn(route_point.selected)
		)
	)
	_add_field_label("Decoración CC0")
	var asset_picker := OptionButton.new()
	var asset_entries: Array[TrackAssetEntry] = []
	var library := load(ASSET_LIBRARY_PATH) as TrackAssetLibrary
	if library != null:
		asset_entries = library.get_valid_entries()
		for entry in asset_entries:
			asset_picker.add_item("%s  ·  %s" % [entry.category, entry.display_name])
	asset_picker.custom_minimum_size.y = 44.0
	asset_picker.disabled = asset_entries.is_empty()
	_properties.add_child(asset_picker)
	var side_picker := OptionButton.new()
	side_picker.add_item("Lado izquierdo")
	side_picker.add_item("Lado derecho")
	side_picker.custom_minimum_size.y = 44.0
	_properties.add_child(side_picker)
	_add_field_label("Distancia desde el centro")
	var asset_distance := SpinBox.new()
	asset_distance.min_value = 12.0
	asset_distance.max_value = 35.0
	asset_distance.step = 1.0
	asset_distance.value = 15.0
	asset_distance.suffix = " m"
	asset_distance.custom_minimum_size.y = 44.0
	_properties.add_child(asset_distance)
	_add_field_label("Rotación")
	var asset_rotation := SpinBox.new()
	asset_rotation.min_value = -180.0
	asset_rotation.max_value = 180.0
	asset_rotation.step = 15.0
	asset_rotation.suffix = "°"
	asset_rotation.custom_minimum_size.y = 44.0
	_properties.add_child(asset_rotation)
	var add_asset := _button(
		"＋ COLOCAR DECORACIÓN",
		func() -> void:
			if asset_picker.selected >= 0:
				_add_asset(
					asset_entries[asset_picker.selected],
					route_point.selected,
					-1.0 if side_picker.selected == 0 else 1.0,
					asset_distance.value,
					asset_rotation.value
				)
	)
	add_asset.disabled = asset_entries.is_empty()
	_properties.add_child(add_asset)
	var counts := Label.new()
	var props := session.track.get_node_or_null("Props")
	var items := session.track.get_node_or_null("ItemSpawns")
	counts.text = "Decoración: %d\nCajas: %d" % [
		props.get_child_count() if props != null else 0,
		items.get_child_count() if items != null else 0,
	]
	counts.add_theme_color_override("font_color", Color("#aab5b9"))
	_properties.add_child(counts)


func _build_review_properties() -> void:
	_add_help(
		"El editor revisa carretera, salida, cajas y atajos. "
		+ "Puedes guardar un borrador aunque todavía tenga errores."
	)
	var issues := _deduplicate_issues(session.track.inspect_track())
	if issues.is_empty():
		var ready := Label.new()
		ready.text = "✓ PISTA LISTA PARA PROBAR"
		ready.add_theme_color_override("font_color", Color("#42c7b9"))
		ready.add_theme_font_size_override("font_size", 17)
		_properties.add_child(ready)
	else:
		for issue in issues:
			var issue_button := _button(
				"⚠  " + issue.message,
				_focus_issue.bind(issue),
				"Ir al elemento con este problema"
			)
			issue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			issue_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			issue_button.add_theme_color_override("font_color", Color("#ffd3c8"))
			_properties.add_child(issue_button)
	_properties.add_child(_button("VALIDAR DE NUEVO", _handle_validate_pressed))
	_properties.add_child(_button("GUARDAR BORRADOR", _handle_save_pressed))
	var test_button := _button("▶ PROBAR CON EL KART", _handle_test_pressed)
	test_button.disabled = not issues.is_empty()
	_properties.add_child(test_button)
	var publish_button := _button("PUBLICAR EN EL JUEGO", _handle_publish_pressed, "", true)
	publish_button.disabled = not issues.is_empty()
	_properties.add_child(publish_button)


func _handle_new_pressed() -> void:
	if session.is_dirty:
		_show_unsaved_dialog("new", "")
	else:
		_new_dialog.popup_centered(Vector2i(460, 280))


func _handle_open_pressed() -> void:
	_open_dialog.popup_centered_ratio(0.72)


func _create_new_track() -> void:
	var size_ids := [&"small", &"medium", &"large"]
	session.create_track(size_ids[_new_size.selected], _new_name.text)
	_laps = 3
	_description = ""
	_new_dialog.hide()
	_show_success("Plantilla creada. Ajusta los puntos amarillos a tu gusto.")


func _handle_save_pressed() -> void:
	var error := session.save()
	if error == OK:
		session.clear_recovery()
		_show_success("Borrador guardado en %s." % session.scene_path)
	else:
		_show_error("No se pudo guardar (%s)." % error_string(error))


func _handle_publish_pressed() -> void:
	var issues := session.track.inspect_track() if session.track != null else []
	if not issues.is_empty():
		_show_error("Corrige los problemas indicados antes de publicar.")
		_show_step(4)
		return
	var error := session.publish(_laps, _description)
	if error == OK:
		_reload_track_picker()
		_show_success("Pista publicada. Ya aparece en el menú del juego.")
	else:
		_show_error("No se pudo publicar (%s)." % error_string(error))


func _handle_test_pressed() -> void:
	if session.track == null or not session.track.validate_track().is_empty():
		_show_error("La pista necesita pasar la revisión antes de probarla.")
		_show_step(4)
		return
	var error := session.save()
	if error != OK:
		_show_error("No se pudo preparar la prueba (%s)." % error_string(error))
		return
	play_requested.emit(session.scene_path, session.track.track_id, _laps)
	_show_success("Iniciando prueba con el kart del jugador…")


func _handle_validate_pressed() -> void:
	_rebuild_preview()
	if session.track.inspect_track().is_empty():
		_show_success("Revisión completa: no hay problemas.")
	else:
		_show_error("La pista tiene problemas. Usa los mensajes para localizarlos.")
	_show_step(4)


func _handle_route_edited() -> void:
	session.mark_dirty()
	_map_view.queue_redraw()


func _handle_route_edit_finished() -> void:
	session.recalculate_route_dependents()
	_rebuild_preview()
	_show_success("Carretera actualizada.")


func _handle_point_selected(_point_index: int) -> void:
	if _current_step == 1:
		_show_step(1)


func _handle_add_point() -> void:
	if _map_view.insert_point_after_selected():
		session.mark_dirty()
		_rebuild_preview()
		_show_step(1)


func _handle_delete_point() -> void:
	if _map_view.delete_selected_point():
		session.mark_dirty()
		_rebuild_preview()
		_show_step(1)
	else:
		_show_error("La carretera necesita al menos cuatro puntos.")


func _handle_mark_start() -> void:
	session.snapshot_route_for_undo()
	if _map_view.mark_selected_as_start():
		session.mark_dirty()
		_rebuild_preview()
		_show_success("La salida se moverá al punto seleccionado.")


func _create_shortcut(entry_index: int, exit_index: int) -> void:
	if exit_index <= entry_index + 1:
		_show_error("La salida debe estar al menos dos puntos después de la entrada.")
		return
	var curve := session.track.get_main_route().curve
	var shortcut := TrackShortcut.new()
	shortcut.name = "Shortcut%d" % (session.track.get_shortcuts().size() + 1)
	shortcut.shortcut_id = session.track.get_shortcuts().size()
	shortcut.display_name = "Atajo %d" % (shortcut.shortcut_id + 1)
	shortcut.curve = Curve3D.new()
	var start := curve.get_point_position(entry_index)
	var finish := curve.get_point_position(exit_index)
	var midpoint := start.lerp(finish, 0.5)
	var direct := Vector2(finish.x - start.x, finish.z - start.z).normalized()
	midpoint += Vector3(-direct.y, 0.0, direct.x) * 12.0
	var entry_forward := (
		curve.get_point_position((entry_index + 1) % curve.point_count)
		- curve.get_point_position(
			(entry_index - 1 + curve.point_count) % curve.point_count
		)
	).normalized()
	var exit_forward := (
		curve.get_point_position((exit_index + 1) % curve.point_count)
		- curve.get_point_position(
			(exit_index - 1 + curve.point_count) % curve.point_count
		)
	).normalized()
	var middle_tangent := (finish - start) / 7.0
	shortcut.curve.add_point(start, Vector3.ZERO, entry_forward * 10.0)
	shortcut.curve.add_point(midpoint, -middle_tangent, middle_tangent)
	shortcut.curve.add_point(finish, -exit_forward * 10.0)
	var shortcuts := session.track.get_node_or_null("Shortcuts")
	shortcuts.add_child(shortcut)
	shortcut.owner = session.track
	session.configure_shortcut_anchor(shortcut)
	session.mark_dirty()
	_map_view.queue_redraw()
	_rebuild_preview()
	_show_step(2)
	var errors := session.track.validate_track()
	if errors.is_empty():
		_show_success("Atajo creado y conectado.")
	else:
		_show_error("Atajo creado. Revisa su dirección y conexiones.")


func _delete_shortcut(shortcut: TrackShortcut) -> void:
	if not is_instance_valid(shortcut):
		return
	shortcut.get_parent().remove_child(shortcut)
	shortcut.free()
	session.mark_dirty()
	_map_view.queue_redraw()
	_rebuild_preview()
	_show_step(2)


func _add_item_spawn(point_index: int) -> void:
	var item_root := session.track.get_node_or_null("ItemSpawns")
	var route := session.track.get_main_route()
	if item_root == null or route == null or route.curve == null:
		_show_error("La pista no tiene un contenedor de cajas válido.")
		return
	var marker := Marker3D.new()
	marker.name = "ItemSpawn%d" % (item_root.get_child_count() + 1)
	marker.position = route.curve.get_point_position(point_index)
	item_root.add_child(marker)
	marker.owner = session.track
	session.anchor_item_spawn(
		marker,
		session.get_route_progress_for_control_point(point_index)
	)
	session.mark_dirty()
	_rebuild_preview()
	_show_step(3)
	_show_success("Caja colocada sobre la carretera.")


func _add_asset(
	entry: TrackAssetEntry,
	point_index: int,
	side_sign: float,
	distance: float,
	rotation_degrees_y: float
) -> void:
	var props := session.track.get_node_or_null("Props")
	var route := session.track.get_main_route()
	if props == null or route == null or entry == null or entry.scene == null:
		_show_error("No se pudo colocar el asset.")
		return
	var instance := entry.scene.instantiate() as Node3D
	if instance == null:
		_show_error("El asset seleccionado no es un modelo 3D.")
		return
	instance.name = entry.display_name.validate_node_name()
	var previous_index := (
		point_index - 1 + route.curve.point_count
	) % route.curve.point_count
	var next_index := (point_index + 1) % route.curve.point_count
	var forward := (
		route.curve.get_point_position(next_index)
		- route.curve.get_point_position(previous_index)
	)
	forward.y = 0.0
	forward = forward.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x) * side_sign
	instance.position = route.curve.get_point_position(point_index) + side * distance
	instance.rotation_degrees.y = rotation_degrees_y
	instance.scale = entry.default_scale
	props.add_child(instance)
	instance.owner = session.track
	session.anchor_prop(
		instance,
		session.get_route_progress_for_control_point(point_index),
		side_sign * distance,
		0.0,
		rotation_degrees_y
	)
	session.mark_dirty()
	_rebuild_preview()
	_show_step(3)
	_show_success("%s colocado junto a la carretera." % entry.display_name)


func _focus_issue(issue: TrackValidationIssue) -> void:
	match str(issue.target_path):
		"Shortcuts":
			_show_step(2)
		"ItemSpawns", "Props":
			_show_step(3)
		_:
			_show_step(1)
	_show_error(issue.message)


func _rebuild_preview() -> void:
	if session.track == null or not session.track.is_inside_tree():
		return
	session.track.rebuild_preview()
	_map_view.queue_redraw()
	if not session.track.route_points.is_empty():
		_frame_preview_camera()


func _deduplicate_issues(
	issues: Array[TrackValidationIssue]
) -> Array[TrackValidationIssue]:
	var unique_issues: Array[TrackValidationIssue] = []
	var observed: Dictionary = {}
	for issue in issues:
		var key := "%s|%s" % [issue.code, issue.target_path]
		if observed.has(key):
			continue
		observed[key] = true
		unique_issues.append(issue)
	return unique_issues


func _frame_preview_camera() -> void:
	var route := session.track.route_points
	if route.is_empty():
		return
	var maximum_radius := 50.0
	var center := Vector3.ZERO
	for point in route:
		center += point
	center /= route.size()
	for point in route:
		maximum_radius = maxf(maximum_radius, center.distance_to(point))
	_preview_camera.position = center + Vector3(
		maximum_radius * 1.25,
		maximum_radius * 1.15,
		maximum_radius * 1.25
	)
	_preview_camera.look_at(center)


func _toggle_view() -> void:
	_is_showing_preview = not _is_showing_preview
	_map_view.visible = not _is_showing_preview
	_preview_container.visible = _is_showing_preview
	_view_toggle.text = "MAPA AÉREO" if _is_showing_preview else "VISTA 3D"
	if _is_showing_preview:
		_rebuild_preview()


func _route_point_count() -> int:
	var route := session.track.get_main_route() if session.track != null else null
	return route.curve.point_count if route != null and route.curve != null else 0


func _show_success(message: String) -> void:
	_status_label.text = "✓  " + message
	_status_label.add_theme_color_override("font_color", Color("#42c7b9"))


func _show_error(message: String) -> void:
	_status_label.text = "⚠  " + message
	_status_label.add_theme_color_override("font_color", Color("#ffd3c8"))


func _add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#f6c344"))
	_properties.add_child(label)


func _add_help(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#c4ced1"))
	_properties.add_child(label)


func _add_field_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#aab5b9"))
	_properties.add_child(label)


func _button(
	text: String,
	callback: Callable,
	tooltip := "",
	is_primary := false
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44.0
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	if is_primary:
		button.add_theme_color_override("font_color", Color("#151b1f"))
		button.add_theme_stylebox_override("normal", _style_box(Color("#f6c344"), Color("#f6c344")))
		button.add_theme_stylebox_override("hover", _style_box(Color("#ffd66e"), Color("#ffffff")))
		button.add_theme_stylebox_override("pressed", _style_box(Color("#d9a72d"), Color("#ffffff")))
		button.add_theme_stylebox_override("focus", _style_box(Color("#f6c344"), Color("#ffffff"), 3))
	return button


func _build_new_dialog() -> void:
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Nueva pista"
	_new_dialog.ok_button_text = "Crear pista"
	_new_dialog.cancel_button_text = "Cancelar"
	_new_dialog.confirmed.connect(_create_new_track)
	add_child(_new_dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_new_dialog.add_child(content)
	var instructions := Label.new()
	instructions.text = "Elige un nombre y un tamaño. Todo lo demás se prepara automáticamente."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instructions)
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "Ejemplo: Bahía Relámpago"
	_new_name.custom_minimum_size.y = 44.0
	content.add_child(_new_name)
	_new_size = OptionButton.new()
	_new_size.add_item("Pequeña · carrera rápida")
	_new_size.add_item("Mediana · recomendada")
	_new_size.add_item("Grande · recorrido largo")
	_new_size.select(1)
	_new_size.custom_minimum_size.y = 44.0
	content.add_child(_new_size)


func _build_unsaved_dialog() -> void:
	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Cambios sin guardar"
	_unsaved_dialog.dialog_text = "Esta pista tiene cambios sin guardar. ¿Qué quieres hacer?"
	_unsaved_dialog.ok_button_text = "Guardar"
	_unsaved_dialog.cancel_button_text = "Cancelar"
	_unsaved_dialog.add_button("Descartar", true, "discard")
	_unsaved_dialog.confirmed.connect(_save_then_continue)
	_unsaved_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			_unsaved_dialog.hide()
			_continue_pending_action()
	)
	add_child(_unsaved_dialog)


func _build_open_dialog() -> void:
	_open_dialog = FileDialog.new()
	_open_dialog.title = "Abrir pista o borrador"
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.current_dir = "res://levels"
	_open_dialog.filters = PackedStringArray(["*.tscn ; Escenas de pista"])
	_open_dialog.file_selected.connect(func(path: String) -> void:
		if session.is_dirty:
			_show_unsaved_dialog("load", path)
		else:
			_load_path(path)
	)
	add_child(_open_dialog)


func _build_guide_dialog() -> void:
	_guide_dialog = AcceptDialog.new()
	_guide_dialog.title = "Cómo crear una pista"
	_guide_dialog.ok_button_text = "Entendido"
	_guide_dialog.dialog_text = (
		"1. CONFIGURACIÓN: escribe el nombre y las vueltas.\n\n"
		+ "2. CARRETERA: arrastra los puntos blancos en el mapa.\n\n"
		+ "3. ATAJOS: elige una entrada y una salida.\n\n"
		+ "4. OBJETOS: coloca cajas y decoración sin tocar nodos.\n\n"
		+ "5. REVISAR: corrige los avisos, prueba y publica.\n\n"
		+ "Puedes volver a abrir esta guía con el botón ? GUÍA."
	)
	add_child(_guide_dialog)


func _show_guide() -> void:
	_guide_dialog.popup_centered(Vector2i(540, 460))


func _show_unsaved_dialog(action: String, path: String) -> void:
	_pending_action = action
	_pending_path = path
	_unsaved_dialog.popup_centered()


func _save_then_continue() -> void:
	if session.save() == OK:
		_continue_pending_action()
	else:
		_show_error("No se pudo guardar; la acción fue cancelada.")


func _continue_pending_action() -> void:
	match _pending_action:
		"load":
			_load_path(_pending_path)
		"new":
			_new_dialog.popup_centered(Vector2i(460, 280))
	_pending_action = ""
	_pending_path = ""


func _create_workshop_theme() -> Theme:
	var workshop_theme := Theme.new()
	workshop_theme.set_color("font_color", "Label", Color("#f4f1e8"))
	workshop_theme.set_color("font_color", "Button", Color("#f4f1e8"))
	workshop_theme.set_color("font_hover_color", "Button", Color("#ffffff"))
	workshop_theme.set_color("font_pressed_color", "Button", Color("#ffffff"))
	workshop_theme.set_color("font_focus_color", "Button", Color("#ffffff"))
	workshop_theme.set_color("font_disabled_color", "Button", Color("#738087"))
	workshop_theme.set_stylebox("normal", "PanelContainer", _style_box(Color("#20282d"), Color("#354148")))
	workshop_theme.set_stylebox("normal", "Button", _style_box(Color("#2a343a"), Color("#46545b")))
	workshop_theme.set_stylebox("hover", "Button", _style_box(Color("#364249"), Color("#f6c344"), 2))
	workshop_theme.set_stylebox("pressed", "Button", _style_box(Color("#1c2428"), Color("#f6c344"), 2))
	workshop_theme.set_stylebox("focus", "Button", _style_box(Color("#2a343a"), Color("#f6c344"), 3))
	workshop_theme.set_stylebox("disabled", "Button", _style_box(Color("#242c30"), Color("#354148")))
	workshop_theme.set_stylebox("normal", "LineEdit", _style_box(Color("#151b1f"), Color("#46545b")))
	workshop_theme.set_stylebox("focus", "LineEdit", _style_box(Color("#151b1f"), Color("#f6c344"), 2))
	workshop_theme.set_color("font_color", "LineEdit", Color("#f4f1e8"))
	workshop_theme.set_constant("separation", "VBoxContainer", 8)
	workshop_theme.set_constant("separation", "HBoxContainer", 8)
	return workshop_theme


func _style_box(
	background: Color,
	border: Color,
	border_width := 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
