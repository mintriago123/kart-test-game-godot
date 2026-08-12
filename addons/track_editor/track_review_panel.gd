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
	var blocking_issue_count := 0
	for issue in issues:
		if issue.severity == TrackValidationIssue.Severity.ERROR:
			blocking_issue_count += 1
	if issues.is_empty():
		var ready := Label.new()
		ready.text = "✓ PISTA LISTA PARA PROBAR"
		ready.add_theme_color_override("font_color", EditorStyle.SUCCESS)
		ready.add_theme_font_size_override("font_size", 17)
		add_child(ready)
	else:
		if blocking_issue_count == 0:
			var warning_ready := Label.new()
			warning_ready.text = "✓ PISTA LISTA CON ADVERTENCIAS"
			warning_ready.add_theme_color_override("font_color", EditorStyle.FOCUS)
			warning_ready.add_theme_font_size_override("font_size", 17)
			add_child(warning_ready)
		for issue in issues:
			var is_warning := issue.severity == TrackValidationIssue.Severity.WARNING
			var issue_button := make_button(
				("△  " if is_warning else "⚠  ") + issue.message,
				func() -> void: issue_focus_requested.emit(issue),
				"Ir al elemento con este problema"
			)
			issue_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			issue_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			issue_button.add_theme_color_override(
				"font_color",
				EditorStyle.FOCUS if is_warning else EditorStyle.ERROR
			)
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
	test_button.disabled = blocking_issue_count > 0
	add_child(test_button)
	var publish_button := make_button(
		"PUBLICAR EN EL JUEGO",
		func() -> void: publish_requested.emit(),
		"",
		true
	)
	publish_button.disabled = blocking_issue_count > 0
	add_child(publish_button)
