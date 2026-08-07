@tool
class_name TrackShortcutPanel
extends "res://addons/track_editor/track_editor_panel.gd"

signal create_shortcut_requested(entry_index: int, exit_index: int)
signal delete_shortcut_requested(shortcut: TrackShortcut)


func configure(track: TrackLevel, button_factory: Callable) -> void:
	configure_panel("3  ATAJOS", button_factory)
	add_help(
		"Elige dos puntos de la carretera. La entrada debe aparecer antes "
		+ "que la salida siguiendo las flechas."
	)
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
