@tool
class_name TrackSurfacePanel
extends "res://addons/track_editor/track_editor_panel.gd"

signal surface_selection_requested(selection: RefCounted)
signal create_requested(data: Dictionary)
signal update_requested(selection: RefCounted, data: Dictionary)
signal delete_requested(selection: RefCounted)

const Selection := preload("res://addons/track_editor/track_editor_selection.gd")
const SURFACE_DIRECTORY := "res://levels/surfaces"

var _track: TrackLevel
var _selected: RefCounted
var _surface_paths: Dictionary = {}
var _surface_picker: OptionButton
var _path_picker: OptionButton
var _shortcut_picker: OptionButton
var _start: SpinBox
var _end: SpinBox
var _lateral: SpinBox
var _width: SpinBox
var _priority: SpinBox
var _submit: Button
var _validation_label: Label


func configure(
	track: TrackLevel,
	button_factory: Callable,
	selected: RefCounted = null
) -> void:
	_track = track
	_selected = selected if selected != null else Selection.none()
	_surface_paths.clear()
	configure_panel("5  SUPERFICIES", button_factory)
	add_help(
		"Selecciona una zona sobre el mapa para editarla. Sus límites se dibujan "
		+ "directamente sobre la carretera; los solapamientos bloquean publicar."
	)
	_build_zone_list()
	_build_editor()


func _build_zone_list() -> void:
	var zones_label := Label.new()
	zones_label.text = "ZONAS EXISTENTES"
	zones_label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
	add_child(zones_label)
	if _track == null or _track.get_surface_zones().is_empty():
		var empty := Label.new()
		empty.text = "No hay zonas todavía."
		empty.add_theme_color_override("font_color", EditorStyle.TEXT_SECONDARY)
		add_child(empty)
		return
	for zone in _track.get_surface_zones():
		var zone_button := make_button(
			("●  " if _is_selected(zone) else "○  ")
			+ "%s · %.0f–%.0f%% · %.1f m"
			% [zone.surface.display_name if zone.surface != null else "Sin superficie", zone.start_progress * 100.0, zone.end_progress * 100.0, zone.width],
			func() -> void:
				surface_selection_requested.emit(Selection.node(
					Selection.Kind.SURFACE,
					_track.get_path_to(zone)
				))
		)
		zone_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		zone_button.tooltip_text = "Seleccionar y centrar esta zona en el mapa"
		zone_button.name = "SurfaceZone_%s" % zone.name
		add_child(zone_button)


func _build_editor() -> void:
	var editor_label := Label.new()
	editor_label.text = "NUEVA ZONA" if _selected.is_empty() else "EDITAR ZONA"
	editor_label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
	add_child(editor_label)
	add_field_label("Superficie asignada")
	_surface_picker = OptionButton.new()
	_surface_picker.name = "SurfacePicker"
	_surface_picker.custom_minimum_size.y = 44.0
	_surface_picker.focus_mode = Control.FOCUS_ALL
	for option in _discover_surface_options():
		var option_id: StringName = option.id
		_surface_paths[String(option_id)] = option.path
		_surface_picker.add_item(option.label)
		_surface_picker.set_item_metadata(_surface_picker.item_count - 1, option_id)
	var selected_surface := _get_selected_surface()
	if (
		selected_surface != null
		and not _surface_paths.has(String(selected_surface.id))
	):
		_surface_paths[String(selected_surface.id)] = selected_surface.resource_path
		_surface_picker.add_item(
			"⚠ %s (recurso existente)" % selected_surface.display_name
		)
		_surface_picker.set_item_metadata(
			_surface_picker.item_count - 1,
			selected_surface.id
		)
	add_child(_surface_picker)
	_surface_picker.item_selected.connect(func(_index: int) -> void: _validate_form())
	add_field_label("Tramo de aplicación")
	_path_picker = OptionButton.new()
	_path_picker.name = "SurfacePathPicker"
	_path_picker.custom_minimum_size.y = 44.0
	_path_picker.focus_mode = Control.FOCUS_ALL
	_path_picker.add_item("Ruta principal", TrackSurfaceZone.PathKind.MAIN)
	_path_picker.add_item("Atajo", TrackSurfaceZone.PathKind.SHORTCUT)
	add_child(_path_picker)
	_path_picker.item_selected.connect(func(_index: int) -> void: _update_shortcut_picker())
	add_field_label("Atajo (solo para tramo de atajo)")
	_shortcut_picker = OptionButton.new()
	_shortcut_picker.name = "SurfaceShortcutId"
	_shortcut_picker.custom_minimum_size.y = 44.0
	_shortcut_picker.focus_mode = Control.FOCUS_ALL
	_shortcut_picker.add_item("Sin atajo", -1)
	if _track != null:
		for shortcut in _track.get_shortcuts():
			_shortcut_picker.add_item(
				"%d · %s" % [shortcut.shortcut_id, shortcut.display_name],
				shortcut.shortcut_id
			)
	add_child(_shortcut_picker)
	_shortcut_picker.item_selected.connect(func(_index: int) -> void: _validate_form())
	add_field_label("Inicio del tramo (0–100%)")
	_start = _number_field("SurfaceStartProgress", "", -1.0, 2.0, 0.01, 0.1)
	add_field_label("Final del tramo (0–100%)")
	_end = _number_field("SurfaceEndProgress", "", -1.0, 2.0, 0.01, 0.2)
	add_field_label("Desplazamiento lateral (m)")
	_lateral = _number_field("SurfaceLateralOffset", "", -30.0, 30.0, 0.25, 0.0)
	add_field_label("Ancho de la zona (m)")
	_width = _number_field("SurfaceWidth", "", 0.0, CoastalTrack.ROAD_WIDTH, 0.25, 3.0)
	add_field_label("Prioridad de solapamiento")
	_priority = _number_field("SurfacePriority", "", 0.0, 100.0, 1.0, 0.0)
	for input in [_start, _end, _lateral, _width, _priority]:
		input.value_changed.connect(func(_value: float) -> void: _validate_form())
	_load_selected_values()
	_validation_label = Label.new()
	_validation_label.name = "SurfaceValidation"
	_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_validation_label.custom_minimum_size.y = 32.0
	add_child(_validation_label)
	_submit = make_button(
		"APLICAR CAMBIOS" if not _selected.is_empty() else "+ CREAR ZONA",
		_submit_zone,
		"Guardar esta configuración como una única operación"
	)
	_submit.name = "SurfaceSubmit"
	add_child(_submit)
	if not _selected.is_empty():
		var delete := make_button(
			"ELIMINAR ZONA",
			func() -> void: delete_requested.emit(_selected),
			"Eliminar la zona seleccionada"
		)
		delete.name = "SurfaceDelete"
		add_child(delete)
	_update_shortcut_picker()
	_validate_form()


func _number_field(
	control_name: String,
	prefix_text: String,
	minimum: float,
	maximum: float,
	step_value: float,
	default_value: float
) -> SpinBox:
	var input := SpinBox.new()
	input.name = control_name
	input.prefix = prefix_text
	input.min_value = minimum
	input.max_value = maximum
	input.step = step_value
	input.value = default_value
	input.custom_minimum_size.y = 44.0
	input.focus_mode = Control.FOCUS_ALL
	input.tooltip_text = prefix_text
	add_child(input)
	return input


func _discover_surface_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var directory := DirAccess.open(SURFACE_DIRECTORY)
	if directory == null:
		return options
	directory.list_dir_begin()
	while true:
		var filename := directory.get_next()
		if filename.is_empty():
			break
		if directory.current_is_dir() or filename.get_extension().to_lower() != "tres":
			continue
		var path := "%s/%s" % [SURFACE_DIRECTORY, filename]
		var definition := ResourceLoader.load(path, "SurfaceDefinition") as SurfaceDefinition
		if definition == null:
			continue
		var definition_id := definition.id
		if definition_id.is_empty():
			definition_id = StringName(filename.get_basename())
		options.append({
			"id": definition_id,
			"path": path,
			"label": definition.display_name,
		})
	directory.list_dir_end()
	options.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return str(first.get("label", "")).naturalnocasecmp_to(
			str(second.get("label", ""))
		) < 0
	)
	return options


func _get_selected_surface() -> SurfaceDefinition:
	if _track == null or _selected == null or _selected.is_empty():
		return null
	var zone := _track.get_node_or_null(_selected.node_path) as TrackSurfaceZone
	return zone.surface if zone != null else null


func _load_selected_values() -> void:
	if _selected.is_empty():
		return
	var zone := _track.get_node_or_null(_selected.node_path) as TrackSurfaceZone
	if zone == null:
		return
	_path_picker.select(zone.path_kind)
	var shortcut_index := _shortcut_picker.get_item_index(zone.shortcut_id)
	_shortcut_picker.select(shortcut_index if shortcut_index >= 0 else 0)
	_start.value = zone.start_progress
	_end.value = zone.end_progress
	_lateral.value = zone.lateral_offset
	_width.value = zone.width
	_priority.value = zone.surface_priority
	if zone.surface != null:
		for index in _surface_picker.item_count:
			if str(_surface_picker.get_item_metadata(index)) == str(zone.surface.id):
				_surface_picker.select(index)
				break


func _submit_zone() -> void:
	if not _validate_form():
		return
	var data := {
		"surface_id": StringName(str(_surface_picker.get_selected_metadata())),
		"surface_path": str(_surface_paths.get(
			str(_surface_picker.get_selected_metadata()),
			""
		)),
		"path_kind": _path_picker.get_selected_id(),
		"shortcut_id": _shortcut_picker.get_selected_id(),
		"start_progress": _start.value,
		"end_progress": _end.value,
		"lateral_offset": _lateral.value,
		"width": _width.value,
		"surface_priority": int(_priority.value),
	}
	if _selected.is_empty():
		create_requested.emit(data)
	else:
		update_requested.emit(_selected, data)


func _update_shortcut_picker() -> void:
	if _shortcut_picker == null or _path_picker == null:
		return
	var is_shortcut := _path_picker.get_selected_id() == TrackSurfaceZone.PathKind.SHORTCUT
	_shortcut_picker.disabled = not is_shortcut
	_shortcut_picker.modulate = Color.WHITE if is_shortcut else EditorStyle.TEXT_DISABLED
	if not is_shortcut:
		_shortcut_picker.select(0)
	_validate_form()


func _validate_form() -> bool:
	if _validation_label == null:
		return true
	var errors := PackedStringArray()
	var warnings := PackedStringArray()
	var surface_id := StringName(str(_surface_picker.get_selected_metadata()))
	var surface_path := str(_surface_paths.get(str(surface_id), ""))
	if surface_id.is_empty() or surface_path.is_empty() or not ResourceLoader.exists(surface_path):
		errors.append("Asigna una superficie disponible.")
	var path_kind := _path_picker.get_selected_id()
	var shortcut_id := _shortcut_picker.get_selected_id()
	if path_kind not in [TrackSurfaceZone.PathKind.MAIN, TrackSurfaceZone.PathKind.SHORTCUT]:
		errors.append("Selecciona un tramo válido.")
	if path_kind == TrackSurfaceZone.PathKind.SHORTCUT and shortcut_id < 0:
		errors.append("Selecciona el atajo donde se aplicará la zona.")
	if not is_finite(_start.value) or not is_finite(_end.value):
		errors.append("El progreso debe ser un número válido.")
	elif (
		_start.value < 0.0
		or _start.value > 1.0
		or _end.value < 0.0
		or _end.value > 1.0
		or _end.value <= _start.value
	):
		errors.append("El inicio debe ser menor que el final y ambos estar entre 0 y 1.")
	if not is_finite(_lateral.value) or not is_finite(_width.value):
		errors.append("El ancho y el desplazamiento deben ser números válidos.")
	elif _width.value < 0.5:
		errors.append("El ancho mínimo es 0.5 m.")
	elif absf(_lateral.value) + _width.value * 0.5 > CoastalTrack.ROAD_WIDTH * 0.5:
		errors.append("La zona excede el ancho transitable de la carretera.")
	if path_kind == TrackSurfaceZone.PathKind.SHORTCUT and _track != null:
		var shortcut_exists := false
		for shortcut in _track.get_shortcuts():
			if shortcut.shortcut_id == shortcut_id:
				shortcut_exists = true
				break
		if not shortcut_exists:
			errors.append("El atajo seleccionado ya no existe.")
	if errors.is_empty() and _track != null:
		for zone in _track.get_surface_zones():
			if not _selected.is_empty() and _track.get_path_to(zone) == _selected.node_path:
				continue
			if zone.path_kind != path_kind or (
				path_kind == TrackSurfaceZone.PathKind.SHORTCUT
				and zone.shortcut_id != shortcut_id
			):
				continue
			if zone.end_progress <= _start.value or _end.value <= zone.start_progress:
				continue
			if absf(zone.lateral_offset - _lateral.value) >= (zone.width + _width.value) * 0.5:
				continue
			if zone.surface_priority == int(_priority.value):
				errors.append("La zona se solapa con %s usando la misma prioridad." % zone.name)
			else:
				warnings.append("Se solapa con %s; ganará la prioridad más alta." % zone.name)
	var messages := PackedStringArray()
	for error in errors:
		messages.append("⚠  " + error)
	for warning in warnings:
		messages.append("△  " + warning)
	_validation_label.text = "\n".join(messages)
	_validation_label.add_theme_color_override(
		"font_color",
		EditorStyle.ERROR if not errors.is_empty() else EditorStyle.FOCUS
	)
	_validation_label.visible = not messages.is_empty()
	if _submit != null:
		_submit.disabled = not errors.is_empty()
	return errors.is_empty()


func _is_selected(zone: TrackSurfaceZone) -> bool:
	return not _selected.is_empty() and _selected.node_path == _track.get_path_to(zone)
