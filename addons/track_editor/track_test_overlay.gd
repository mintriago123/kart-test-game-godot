class_name TrackTestOverlay
extends CanvasLayer

signal return_requested

var _metrics: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var return_button := Button.new()
	return_button.name = "ReturnToTrackEditor"
	return_button.text = "← VOLVER AL EDITOR"
	return_button.tooltip_text = "Terminar la prueba y volver al editor (F8)"
	return_button.custom_minimum_size = Vector2(190.0, 48.0)
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.position = Vector2(18.0, 18.0)
	return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	return_button.pressed.connect(func() -> void: return_requested.emit())
	root.add_child(return_button)

	var panel := PanelContainer.new()
	panel.name = "TrackTestMetrics"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-265.0, 18.0)
	panel.custom_minimum_size = Vector2(245.0, 128.0)
	root.add_child(panel)
	_metrics = Label.new()
	_metrics.text = "DIAGNÓSTICO DE PISTA\n00:00.000\nRecuperaciones: 0\nFuera de ruta: 0\nAtajos: 0"
	_metrics.add_theme_constant_override("line_spacing", 4)
	panel.add_child(_metrics)


func update_metrics(diagnostics: RefCounted) -> void:
	if diagnostics == null or _metrics == null:
		return
	_metrics.text = (
		"DIAGNÓSTICO DE PISTA\n%s\nRecuperaciones: %d\nFuera de ruta: %d\nAtajos: %d"
		% [
			_format_time(diagnostics.elapsed_time),
			diagnostics.recovery_count,
			diagnostics.off_route_count,
			diagnostics.shortcut_count,
		]
	)


func _format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	var remaining := fmod(seconds, 60.0)
	return "%02d:%06.3f" % [minutes, remaining]
