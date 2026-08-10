@tool
class_name TrackShortcutPanel
extends "res://addons/track_editor/track_editor_panel.gd"

const Selection := preload(
	"res://addons/track_editor/track_editor_selection.gd"
)

signal create_shortcut_requested(entry_index: int, exit_index: int)
signal delete_shortcut_requested(shortcut: TrackShortcut)
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
		"Elige dos puntos de la carretera. La entrada debe aparecer antes "
		+ "que la salida siguiendo las flechas."
	)
	if (
		selection != null
		and selection.kind == Selection.Kind.SHORTCUT_MIDPOINT
	):
		_build_midpoint_inspector(track, selection)
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
	exit.select(mini(3, maxi(0, exit.item_count - 1)))
	add_child(entry)
	add_child(exit)
	add_child(
		make_button(
			"＋ CREAR ATAJO",
			func() -> void: create_shortcut_requested.emit(
				entry.selected,
				exit.selected
			)
		)
	)
	for shortcut in track.get_shortcuts():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "✓ %s" % shortcut.display_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(
			make_button(
				"Eliminar",
				func() -> void: delete_shortcut_requested.emit(shortcut),
				"Eliminar %s" % shortcut.display_name
			)
		)
		add_child(row)


func _build_midpoint_inspector(
	track: TrackLevel,
	selection: RefCounted
) -> void:
	var shortcut := track.get_node_or_null(selection.node_path) as TrackShortcut
	if shortcut == null:
		return
	add_field_label("SELECCIÓN · %s" % shortcut.display_name)
	var safety := TrackLevelValidator.get_shortcut_safety(track, shortcut)
	var safety_label := "SEGURIDAD · "
	if bool(safety.safe):
		var is_comfortable := (
			float(safety.turn_radius)
			>= TrackLevelValidator.SHORTCUT_MINIMUM_TURN_RADIUS * 1.25
			and float(safety.clearance)
			>= TrackLevelValidator.SHORTCUT_ROUTE_CLEARANCE * 1.25
		)
		safety_label += "CÓMODA" if is_comfortable else "AJUSTADA"
	else:
		safety_label += "REQUIERE CORRECCIÓN"
	add_field_label(safety_label)
	add_help(String(safety.message))
	var values: Array[SpinBox] = []
	for value_data in [
		{"label": "Desplazamiento longitudinal", "value": shortcut.midpoint_longitudinal_offset},
		{"label": "Desplazamiento lateral", "value": shortcut.midpoint_lateral_offset},
		{"label": "Altura", "value": shortcut.midpoint_height_offset},
	]:
		add_field_label(value_data.label)
		var input := SpinBox.new()
		input.min_value = -100.0
		input.max_value = 100.0
		input.step = 0.25
		input.suffix = " m"
		input.value = value_data.value
		input.custom_minimum_size.y = 44.0
		add_child(input)
		values.append(input)
	add_child(make_button(
		"APLICAR FORMA",
		func() -> void:
			midpoint_changed.emit(
				selection,
				values[0].value,
				values[1].value,
				values[2].value
			)
	))
