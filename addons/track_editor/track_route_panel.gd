@tool
class_name TrackRoutePanel
extends "res://addons/track_editor/track_editor_panel.gd"

signal add_point_requested
signal delete_point_requested
signal height_changed(value: float)
signal mark_start_requested
signal position_changed(position: Vector3)


func configure(
	track: TrackLevel,
	selected_point: int,
	button_factory: Callable
) -> void:
	configure_panel("2  CARRETERA", button_factory)
	add_help(
		"Selecciona un punto blanco y arrástralo. Las flechas del teclado "
		+ "también lo mueven con precisión."
	)
	var route := track.get_main_route()
	var point_count := (
		route.curve.point_count
		if route != null and route.curve != null
		else 0
	)
	var selected_label := Label.new()
	selected_label.text = (
		"Punto seleccionado: %d" % (selected_point + 1)
		if selected_point >= 0
		else "Selecciona un punto en el mapa"
	)
	selected_label.add_theme_color_override("font_color", EditorStyle.FOCUS)
	add_child(selected_label)
	if selected_point >= 0:
		var current_position := route.curve.get_point_position(selected_point)
		add_field_label("Posición precisa")
		var coordinates := HBoxContainer.new()
		var coordinate_inputs: Array[SpinBox] = []
		for coordinate_data in [
			{"label": "X", "value": current_position.x},
			{"label": "Y", "value": current_position.y},
			{"label": "Z", "value": current_position.z},
		]:
			var input := SpinBox.new()
			input.prefix = coordinate_data.label + " "
			input.min_value = -1000.0 if coordinate_data.label != "Y" else 0.0
			input.max_value = 1000.0 if coordinate_data.label != "Y" else 12.0
			input.step = 0.25
			input.value = coordinate_data.value
			input.custom_minimum_size = Vector2(86.0, 44.0)
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			coordinates.add_child(input)
			coordinate_inputs.append(input)
		add_child(coordinates)
		add_child(make_button(
			"APLICAR POSICIÓN",
			func() -> void:
				position_changed.emit(Vector3(
					coordinate_inputs[0].value,
					coordinate_inputs[1].value,
					coordinate_inputs[2].value
				))
		))

	var add_button := make_button(
		"＋ AÑADIR PUNTO DESPUÉS",
		func() -> void: add_point_requested.emit()
	)
	add_button.disabled = selected_point < 0
	add_child(add_button)
	var delete_button := make_button(
		"ELIMINAR PUNTO",
		func() -> void: delete_point_requested.emit()
	)
	delete_button.disabled = selected_point < 0 or point_count <= 4
	add_child(delete_button)

	add_field_label("Altura del punto")
	var height := SpinBox.new()
	height.min_value = 0.0
	height.max_value = 12.0
	height.step = 0.25
	height.custom_minimum_size.y = 44.0
	height.editable = selected_point >= 0
	if selected_point >= 0:
		height.value = route.curve.get_point_position(selected_point).y
	height.value_changed.connect(func(value: float) -> void:
		if height.editable:
			height_changed.emit(value)
	)
	add_child(height)

	var start_button := make_button(
		"MARCAR COMO SALIDA",
		func() -> void: mark_start_requested.emit()
	)
	start_button.disabled = selected_point < 0
	add_child(start_button)
