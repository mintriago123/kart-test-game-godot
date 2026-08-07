@tool
class_name TrackReviewPanel
extends "res://addons/track_editor/track_editor_panel.gd"

signal issue_focus_requested(issue: TrackValidationIssue)
signal validate_requested
signal save_requested
signal test_requested
signal publish_requested


func configure(
	issues: Array[TrackValidationIssue],
	button_factory: Callable
) -> void:
	configure_panel("5  REVISAR", button_factory)
	add_help(
		"El editor revisa carretera, salida, cajas y atajos. "
		+ "Puedes guardar un borrador aunque todavía tenga errores."
	)
	if issues.is_empty():
		var ready := Label.new()
		ready.text = "✓ PISTA LISTA PARA PROBAR"
		ready.add_theme_color_override("font_color", Color("#42c7b9"))
		ready.add_theme_font_size_override("font_size", 17)
		add_child(ready)
	else:
		for issue in issues:
			var issue_button := make_button(
				"⚠  " + issue.message,
				func() -> void: issue_focus_requested.emit(issue),
				"Ir al elemento con este problema"
			)
			issue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			issue_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			issue_button.add_theme_color_override("font_color", Color("#ffd3c8"))
			add_child(issue_button)
	add_child(
		make_button(
			"VALIDAR DE NUEVO",
			func() -> void: validate_requested.emit()
		)
	)
	add_child(
		make_button(
			"GUARDAR BORRADOR",
			func() -> void: save_requested.emit()
		)
	)
	var test_button := make_button(
		"▶ PROBAR CON EL KART",
		func() -> void: test_requested.emit()
	)
	test_button.disabled = not issues.is_empty()
	add_child(test_button)
	var publish_button := make_button(
		"PUBLICAR EN EL JUEGO",
		func() -> void: publish_requested.emit(),
		"",
		true
	)
	publish_button.disabled = not issues.is_empty()
	add_child(publish_button)
