@tool
class_name TrackSetupPanel
extends "res://addons/track_editor/track_editor_panel.gd"

signal name_changed(value: String)
signal laps_changed(value: int)
signal description_changed(value: String)


func configure(
	track: TrackLevel,
	laps: int,
	description: String,
	button_factory: Callable
) -> void:
	configure_panel("1  CONFIGURACIÓN", button_factory)
	add_help("Ponle identidad a la pista. Las opciones técnicas se configuran solas.")
	add_field_label("Nombre visible")
	var name_edit := LineEdit.new()
	name_edit.text = track.display_name
	name_edit.custom_minimum_size.y = 44.0
	name_edit.text_changed.connect(
		func(value: String) -> void: name_changed.emit(value)
	)
	add_child(name_edit)

	add_field_label("Identificador")
	var id_label := Label.new()
	id_label.text = str(track.track_id)
	id_label.add_theme_color_override("font_color", Color("#aab5b9"))
	add_child(id_label)

	add_field_label("Vueltas")
	var laps_input := SpinBox.new()
	laps_input.min_value = 1.0
	laps_input.max_value = 9.0
	laps_input.value = laps
	laps_input.custom_minimum_size.y = 44.0
	laps_input.value_changed.connect(
		func(value: float) -> void: laps_changed.emit(int(value))
	)
	add_child(laps_input)

	add_field_label("Descripción para el menú")
	var description_input := TextEdit.new()
	description_input.text = description
	description_input.custom_minimum_size.y = 100.0
	description_input.text_changed.connect(
		func() -> void: description_changed.emit(description_input.text)
	)
	add_child(description_input)
