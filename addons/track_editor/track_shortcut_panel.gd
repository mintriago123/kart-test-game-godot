@tool
class_name TrackShortcutPanel
extends "res://addons/track_editor/track_editor_panel.gd"

const Selection := preload(
	"res://addons/track_editor/track_editor_selection.gd"
)

signal create_shortcut_requested(entry_index: int, exit_index: int)
signal delete_shortcut_requested(shortcut: TrackShortcut)
signal shortcut_selection_requested(selection: RefCounted)
signal shortcut_shape_changed(selection: RefCounted, shape: Dictionary)
signal shortcut_rename_requested(selection: RefCounted, display_name: String)
signal shortcut_reset_requested(selection: RefCounted)
signal midpoint_changed(
	selection: RefCounted,
	longitudinal: float,
	lateral: float,
	height: float
)


func configure(
	track: TrackLevel,
	button_factory: Callable,
	selection: RefCounted = null
) -> void:
	configure_panel("3  ATAJOS", button_factory)
	add_help(
		"El corredor coloreado muestra la seguridad. Entrada y salida se "
		+ "deslizan sobre MainRoute; cada tangente conserva su dirección."
	)
	add_field_label("LISTA DE ATAJOS")
	_build_shortcut_list(track, selection)
	if selection != null and selection.is_shortcut_control():
		_build_shortcut_inspector(track, selection)
	add_child(HSeparator.new())
	_build_create_section(track)


func _build_shortcut_list(
	track: TrackLevel,
	selection: RefCounted
) -> void:
	var shortcuts := track.get_shortcuts()
	if shortcuts.is_empty():
		add_help("Todavía no hay atajos en esta pista.")
		return
	for shortcut in shortcuts:
		var shortcut_path := track.get_path_to(shortcut)
		var safety := TrackLevelValidator.get_shortcut_safety(track, shortcut)
		var state_text := "✓ SEGURO" if bool(safety.safe) else "⚠ REVISAR"
		var row_button := make_button(
			"%s  ·  %s" % [shortcut.display_name, state_text],
			func() -> void:
				shortcut_selection_requested.emit(
					Selection.node(
						Selection.Kind.SHORTCUT_MIDPOINT,
						shortcut_path
					)
				),
			"Editar %s" % shortcut.display_name
		)
		row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_button.button_pressed = (
			selection != null
			and selection.is_shortcut_control()
			and selection.node_path == shortcut_path
		)
		add_child(row_button)


func _build_shortcut_inspector(
	track: TrackLevel,
	selection: RefCounted
) -> void:
	var shortcut := track.get_node_or_null(selection.node_path) as TrackShortcut
	if shortcut == null:
		return
	add_child(HSeparator.new())
	add_field_label(
		"DETALLE · %s" % _get_control_label(selection.kind)
	)
	var name_input := LineEdit.new()
	name_input.name = "ShortcutName"
	name_input.text = shortcut.display_name
	name_input.custom_minimum_size.y = 44.0
	name_input.focus_mode = Control.FOCUS_ALL
	name_input.tooltip_text = "Nombre visible del atajo"
	add_field_label("Nombre")
	add_child(name_input)
	add_child(make_button(
		"RENOMBRAR",
		func() -> void:
			shortcut_rename_requested.emit(selection, name_input.text)
	))

	var safety := TrackLevelValidator.get_shortcut_safety(track, shortcut)
	var state_label := Label.new()
	state_label.name = "ShortcutSafetyState"
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if bool(safety.safe):
		var is_comfortable := (
			float(safety.turn_radius)
			>= TrackLevelValidator.SHORTCUT_MINIMUM_TURN_RADIUS * 1.25
			and float(safety.clearance)
			>= TrackLevelValidator.SHORTCUT_ROUTE_CLEARANCE * 1.25
		)
		state_label.text = (
			"✓ SEGURIDAD · CÓMODA"
			if is_comfortable
			else "✓ SEGURIDAD · AJUSTADA"
		)
		state_label.add_theme_color_override(
			"font_color",
			EditorStyle.SUCCESS if is_comfortable else EditorStyle.FOCUS
		)
	else:
		state_label.text = "⚠ SEGURIDAD · REQUIERE CORRECCIÓN"
		state_label.add_theme_color_override("font_color", EditorStyle.ERROR)
	add_child(state_label)
	add_help(String(safety.message))

	var inputs := {}
	inputs.entry_progress = _add_number_field(
		"Progreso de entrada",
		shortcut.entry_progress * 100.0,
		0.0,
		100.0,
		0.1,
		" %"
	)
	inputs.exit_progress = _add_number_field(
		"Progreso de salida",
		shortcut.exit_progress * 100.0,
		0.0,
		100.0,
		0.1,
		" %"
	)
	inputs.midpoint_longitudinal = _add_number_field(
		"Desplazamiento longitudinal",
		shortcut.midpoint_longitudinal_offset,
		-100.0,
		100.0,
		0.25,
		" m"
	)
	inputs.midpoint_lateral = _add_number_field(
		"Desplazamiento lateral",
		shortcut.midpoint_lateral_offset,
		-100.0,
		100.0,
		0.25,
		" m"
	)
	inputs.midpoint_height = _add_number_field(
		"Desplazamiento vertical",
		shortcut.midpoint_height_offset,
		-20.0,
		30.0,
		0.25,
		" m"
	)

	var tangent_toggle := make_button(
		"TANGENTES · AVANZADO",
		func() -> void: pass,
		"Mostrar las cuatro longitudes de tangente"
	)
	tangent_toggle.toggle_mode = true
	add_child(tangent_toggle)
	var tangent_fields := VBoxContainer.new()
	tangent_fields.name = "ShortcutAdvancedTangents"
	tangent_fields.visible = false
	tangent_fields.add_theme_constant_override("separation", 8)
	add_child(tangent_fields)
	tangent_toggle.toggled.connect(func(is_open: bool) -> void:
		tangent_fields.visible = is_open
	)
	inputs.entry_handle = _add_number_field_to(
		tangent_fields,
		"Tangente de entrada",
		shortcut.entry_handle_length
	)
	inputs.exit_handle = _add_number_field_to(
		tangent_fields,
		"Tangente de salida",
		shortcut.exit_handle_length
	)
	inputs.midpoint_in_handle = _add_number_field_to(
		tangent_fields,
		"Tangente media de llegada",
		shortcut.midpoint_in_handle_length
	)
	inputs.midpoint_out_handle = _add_number_field_to(
		tangent_fields,
		"Tangente media de partida",
		shortcut.midpoint_out_handle_length
	)

	add_child(make_button(
		"APLICAR FORMA SEGURA",
		func() -> void:
			shortcut_shape_changed.emit(selection, {
				"entry_progress": inputs.entry_progress.value / 100.0,
				"exit_progress": inputs.exit_progress.value / 100.0,
				"midpoint_longitudinal": inputs.midpoint_longitudinal.value,
				"midpoint_lateral": inputs.midpoint_lateral.value,
				"midpoint_height": inputs.midpoint_height.value,
				"entry_handle": inputs.entry_handle.value,
				"exit_handle": inputs.exit_handle.value,
				"midpoint_in_handle": inputs.midpoint_in_handle.value,
				"midpoint_out_handle": inputs.midpoint_out_handle.value,
			})
	))

	add_field_label("MÉTRICAS")
	var metrics := _get_shortcut_metrics(track, shortcut, safety)
	var metric_label := Label.new()
	metric_label.name = "ShortcutMetrics"
	metric_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	metric_label.text = (
		"Longitud: %.1f m\nTramo evitado: %.1f m\nAhorro: %.1f m\n"
		+ "Radio mínimo: %.1f m\nSeparación: %.1f m"
	) % [
		metrics.length,
		metrics.avoided,
		metrics.savings,
		metrics.turn_radius,
		metrics.clearance,
	]
	add_child(metric_label)

	add_child(make_button(
		"RESTAURAR FORMA SEGURA",
		func() -> void: shortcut_reset_requested.emit(selection),
		"Buscar la forma segura más cercana para estos anclajes"
	))
	add_child(make_button(
		"ELIMINAR ATAJO",
		func() -> void: delete_shortcut_requested.emit(shortcut),
		"Eliminar %s" % shortcut.display_name
	))


func _build_create_section(track: TrackLevel) -> void:
	add_field_label("NUEVO ATAJO")
	var route := track.get_main_route()
	var point_count := (
		route.curve.point_count
		if route != null and route.curve != null
		else 0
	)
	var entry := OptionButton.new()
	var exit := OptionButton.new()
	for point_index in point_count:
		entry.add_item("Entrada en punto %d" % (point_index + 1))
		exit.add_item("Salida en punto %d" % (point_index + 1))
	entry.custom_minimum_size.y = 44.0
	exit.custom_minimum_size.y = 44.0
	entry.focus_mode = Control.FOCUS_ALL
	exit.focus_mode = Control.FOCUS_ALL
	exit.select(mini(3, maxi(0, exit.item_count - 1)))
	add_child(entry)
	add_child(exit)
	add_child(make_button(
		"＋ CREAR ATAJO",
		func() -> void:
			create_shortcut_requested.emit(entry.selected, exit.selected)
	))


func _add_number_field(
	label_text: String,
	value: float,
	minimum: float,
	maximum: float,
	step: float,
	suffix: String
) -> SpinBox:
	add_field_label(label_text)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.suffix = suffix
	input.value = value
	input.custom_minimum_size.y = 44.0
	input.focus_mode = Control.FOCUS_ALL
	input.tooltip_text = label_text
	add_child(input)
	return input


func _add_number_field_to(
	container: VBoxContainer,
	label_text: String,
	value: float
) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	container.add_child(label)
	var input := SpinBox.new()
	input.min_value = 0.0
	input.max_value = 100.0
	input.step = 0.25
	input.suffix = " m"
	input.value = value
	input.custom_minimum_size.y = 44.0
	input.focus_mode = Control.FOCUS_ALL
	input.tooltip_text = label_text
	container.add_child(input)
	return input


func _get_shortcut_metrics(
	track: TrackLevel,
	shortcut: TrackShortcut,
	safety: Dictionary
) -> Dictionary:
	var route := track.get_main_route()
	var route_length := (
		route.curve.get_baked_length()
		if route != null and route.curve != null
		else 0.0
	)
	var start_progress := 0.0
	if route_length > 0.001 and track.start_point_index in range(route.curve.point_count):
		start_progress = (
			route.curve.get_closest_offset(
				route.curve.get_point_position(track.start_point_index)
			) / route_length
		)
	var entry_from_start := fposmod(shortcut.entry_progress - start_progress, 1.0)
	var exit_from_start := fposmod(shortcut.exit_progress - start_progress, 1.0)
	var avoided := maxf(exit_from_start - entry_from_start, 0.0) * route_length
	var shortcut_length := shortcut.curve.get_baked_length() if shortcut.curve != null else 0.0
	return {
		"length": shortcut_length,
		"avoided": avoided,
		"savings": avoided - shortcut_length,
		"turn_radius": float(safety.get("turn_radius", 0.0)),
		"clearance": float(safety.get("clearance", -1.0)),
	}


func _get_control_label(kind: int) -> String:
	match kind:
		Selection.Kind.SHORTCUT_ENTRY:
			return "ENTRADA"
		Selection.Kind.SHORTCUT_EXIT:
			return "SALIDA"
		Selection.Kind.SHORTCUT_ENTRY_TANGENT:
			return "TANGENTE DE ENTRADA"
		Selection.Kind.SHORTCUT_EXIT_TANGENT:
			return "TANGENTE DE SALIDA"
		Selection.Kind.SHORTCUT_MIDPOINT_IN_TANGENT:
			return "TANGENTE MEDIA DE LLEGADA"
		Selection.Kind.SHORTCUT_MIDPOINT_OUT_TANGENT:
			return "TANGENTE MEDIA DE PARTIDA"
		_:
			return "PUNTO MEDIO"
