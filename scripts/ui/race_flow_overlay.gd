class_name RaceFlowOverlay
extends Control

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")
const RESUME_DELAY := 0.5

signal retry_requested
signal menu_requested
signal intro_skip_requested
signal resume_requested
signal restart_requested
signal settings_requested
signal controls_requested
signal quit_requested

var intro_overlay: Control
var intro_content: Control
var intro_title: Label
var intro_laps: Label
var intro_skip_button: Button
var pause_overlay: Control
var results_panel: Control
var results_title: Label
var results_details: VBoxContainer
var retry_button: Button
var provisional_panel: Control
var provisional_title: Label
var provisional_details: VBoxContainer
var is_intro_visible := false
var pause_title: Label
var _is_resuming := false
var reduced_motion := false
var _primary_result_action: StringName = &"menu"
var _resume_progress: ProgressBar
var _cup_result: RaceResult
var _cup_stage := -1
var _cup_transitioning := false
var _result_menu_button: Button
var progression_catalog: ProgressionCatalog = preload("res://progression/progression_catalog.tres")


func build_interface() -> void:
	name = "RaceFlow"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pausa"
	pause_button.custom_minimum_size = Vector2(64.0, 64.0)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-88.0, 278.0)
	pause_button.size = Vector2(64.0, 64.0)
	pause_button.pressed.connect(_toggle_pause)
	RaceHudStyle.apply_button_style(
		pause_button,
		Color("#f5d66f")
	)
	add_child(pause_button)

	intro_overlay = _build_intro_overlay()
	add_child(intro_overlay)
	pause_overlay = _build_pause_overlay()
	add_child(pause_overlay)
	results_panel = _build_results_panel()
	add_child(results_panel)
	provisional_panel = _build_provisional_panel()
	add_child(provisional_panel)


func show_provisional(standings: Array[RacerRaceResult], remaining: float) -> void:
	provisional_title.text = "RESULTADOS EN %d…" % ceili(maxf(remaining, 0.0))
	update_provisional_standings(standings)
	provisional_panel.visible = true


func update_provisional_standings(standings: Array[RacerRaceResult]) -> void:
	for child in provisional_details.get_children():
		child.queue_free()
	for standing in standings:
		_add_label_to(
			provisional_details,
			"%dº  %-12s  %s" % [
				standing.finish_position,
				standing.racer_name,
				RaceHudStyle.format_time(standing.finish_time)
				if standing.finish_time >= 0.0 else "EN PISTA",
			],
			17,
			Color("#fff1b5") if standing.is_player else Color("#c5e4de")
		)


func hide_provisional() -> void:
	provisional_panel.visible = false


func show_intro(track_name: String, total_laps: int) -> void:
	is_intro_visible = true
	intro_title.text = track_name.to_upper()
	intro_laps.text = "%d VUELTAS" % total_laps
	intro_content.modulate.a = 0.0
	intro_overlay.visible = true
	set_intro_skip_enabled(false)


func update_intro_progress(elapsed: float) -> void:
	if not is_intro_visible:
		return
	var fade_in := smoothstep(0.0, 0.75, elapsed)
	var fade_out := 1.0 - smoothstep(4.8, 6.0, elapsed)
	intro_content.modulate.a = minf(fade_in, fade_out)


func set_intro_skip_enabled(enabled: bool) -> void:
	if intro_skip_button == null:
		return
	intro_skip_button.visible = enabled
	intro_skip_button.disabled = not enabled
	if enabled:
		intro_skip_button.grab_focus.call_deferred()


func hide_intro() -> void:
	if not is_intro_visible:
		return
	is_intro_visible = false
	intro_overlay.visible = false
	set_intro_skip_enabled(false)


func show_results(result_or_position: Variant, legacy_time: float = -1.0) -> void:
	hide_provisional()
	_cup_result = null
	_cup_stage = -1
	_cup_transitioning = false
	results_details.modulate.a = 1.0
	if _result_menu_button != null: _result_menu_button.visible = true
	var result: RaceResult = null
	if result_or_position is RaceResult:
		result = result_or_position
	elif result_or_position is int:
		result = _build_legacy_result(int(result_or_position), legacy_time)
	if result == null or result.player_result == null:
		return
	var player := result.player_result
	if result.game_mode == GameModeDefinition.TIME_TRIAL:
		_show_time_trial_results(result)
		return
	if result.game_mode == GameModeDefinition.CUP:
		_show_cup_results(result)
		return
	results_title.text = "%s · %dº LUGAR\n%s" % [
		"¡PODIO!" if player.finish_position <= 3 else "¡META!",
		player.finish_position,
		RaceHudStyle.format_time(player.finish_time),
	]
	# Preserve the public retry contract used by the existing race flow.
	_primary_result_action = &"retry"
	retry_button.text = "OTRA CARRERA"
	for child in results_details.get_children():
		child.queue_free()
	_add_result_label(
		("NUEVO RÉCORD · " if result.is_new_best_time else "TIEMPO · ")
		+ RaceHudStyle.format_time(player.finish_time),
		26,
		Color("#75e6a4") if result.is_new_best_time else Color("#fff1b5")
	)
	_add_result_label(
		("MEJOR VUELTA · " if result.is_new_best_lap else "VUELTA RÁPIDA · ")
		+ RaceHudStyle.format_time(player.best_lap_time),
		20,
		Color("#75e6a4") if result.is_new_best_lap else Color("#d8f4e8")
	)
	var laps := ""
	for index in player.lap_times.size():
		laps += "%sV%d  %s" % [
			"  ·  " if index > 0 else "",
			index + 1,
			RaceHudStyle.format_time(player.lap_times[index]),
		]
	_add_result_label(laps, 16, Color("#b9ddd6"))
	_add_result_label(
		"Posiciones %s%d  ·  Objetos %d/%d  ·  Aciertos %d  ·  Bloqueos %d" % [
			"+" if player.get_position_delta() >= 0 else "",
			player.get_position_delta(), player.items_collected, player.items_used,
			player.hits_landed, player.hits_blocked,
		], 16, Color("#d8f4e8")
	)
	_add_result_label(
		"Atajos %d  ·  Recuperaciones %d" % [player.shortcuts_used, player.recoveries],
		16, Color("#d8f4e8")
	)
	_add_result_label("CLASIFICACIÓN", 18, Color("#f5d66f"))
	for standing in result.standings:
		_add_result_label(
			"%dº  %-12s  %s" % [
				standing.finish_position,
				standing.racer_name,
				"DNF" if standing.is_dnf else RaceHudStyle.format_time(standing.finish_time),
			], 17, Color("#fff1b5") if standing.is_player else Color("#c5e4de")
		)
	results_panel.visible = true
	retry_button.grab_focus()


func _show_cup_results(result: RaceResult) -> void:
	var summary := result.cup_summary
	var completed := summary != null and summary.completed
	results_title.text = "CLASIFICACIÓN DE COPA"
	for child in results_details.get_children():
		child.queue_free()
	for row in summary.standings if summary != null else []:
		_add_result_label("%s  ·  %d PTOS  ·  %d VICT." % [str(row.racer_id).to_upper(), int(row.points), int(row.victories)], 19, Color("#fff1b5") if row.racer_id == result.player_result.racer_id else Color("#c5e4de"))
	if completed:
		_cup_result = result
		_cup_stage = 0
		_primary_result_action = &"cup_next"
		retry_button.text = "CONTINUAR"
		if _result_menu_button != null: _result_menu_button.visible = false
		_render_cup_stage()
	else:
		_add_result_label("Carrera %d/3 completada" % (result.cup_race_index + 1), 18, Color("#7be0d0"))
		retry_button.text = "SIGUIENTE CARRERA"
		_primary_result_action = &"retry"
	results_panel.visible = true
	retry_button.grab_focus()

func _render_cup_stage() -> void:
	if _cup_result == null or _cup_result.cup_summary == null: return
	var summary := _cup_result.cup_summary
	for child in results_details.get_children(): child.queue_free()
	match _cup_stage:
		0:
			results_title.text = "CLASIFICACIÓN FINAL"
			for index in summary.standings.size():
				var row: Dictionary = summary.standings[index]
				var racer_name := _racer_name(StringName(row.get("racer_id", &"")))
				_add_result_label("%dº  %s  ·  %d PTOS  ·  %d VICT." % [index + 1, racer_name, int(row.get("points", 0)), int(row.get("victories", 0))], 20, Color("#fff1b5") if index + 1 == summary.player_position else Color("#c5e4de"))
			_add_result_label("TU RESULTADO · %dº · %d PUNTOS" % [summary.player_position, summary.player_points], 24, Color("#f5d66f"))
		1:
			results_title.text = "RESULTADO DE COPA"
			var names := ["SIN MEDALLA", "BRONCE", "PLATA", "ORO"]
			_add_result_label(names[int(summary.medal)], 42, Color("#f5d66f") if int(summary.medal) > 0 else Color("#ef8b78"))
			_add_result_label("MEJOR ANTERIOR · %s" % names[int(summary.previous_best_medal)], 20, Color("#7be0d0"))
		2:
			results_title.text = "RECOMPENSAS"
			if summary.new_reward_ids.is_empty():
				_add_result_label("NO HAY VEHÍCULOS NUEVOS ESTA VEZ", 24, Color("#c5e4de"))
			else:
				for reward_id in summary.new_reward_ids:
					var unlock := progression_catalog.unlocks.get_unlock(reward_id) if progression_catalog != null else null
					var reveal := RewardReveal.new(); results_details.add_child(reveal)
					reveal.reveal(unlock.display_name.to_upper() if unlock != null else "NUEVO VEHÍCULO", reduced_motion)
			retry_button.text = "IR AL MENÚ"
			_primary_result_action = &"menu"
	if _cup_stage < 2:
		retry_button.text = "CONTINUAR"

func _racer_name(racer_id: StringName) -> String:
	if progression_catalog != null and progression_catalog.racers != null:
		var racer := progression_catalog.racers.get_racer(racer_id)
		if racer != null: return racer.display_name.to_upper()
	return str(racer_id).to_upper()

func _advance_cup_stage() -> void:
	if _cup_transitioning or _cup_stage < 0 or _cup_stage >= 2: return
	_cup_transitioning = true
	var duration := 0.01 if reduced_motion else 0.11
	var tween := create_tween()
	tween.tween_property(results_details, "modulate:a", 0.0, duration)
	await tween.finished
	_cup_stage += 1
	_render_cup_stage()
	var enter := create_tween(); enter.tween_property(results_details, "modulate:a", 1.0, duration)
	await enter.finished
	_cup_transitioning = false


func _show_time_trial_results(result: RaceResult) -> void:
	var player := result.player_result
	results_title.text = "CONTRARRELOJ\n%s" % RaceHudStyle.format_time(player.finish_time)
	for child in results_details.get_children():
		child.queue_free()
	_add_result_label(("NUEVO RÉCORD TOTAL · " if result.is_new_best_time else "TIEMPO TOTAL · ") + RaceHudStyle.format_time(player.finish_time), 25, Color("#75e6a4") if result.is_new_best_time else Color("#fff1b5"))
	if result.previous_best_time > 0.0:
		var delta := player.finish_time - result.previous_best_time
		_add_result_label("DIFERENCIA · %+.3f" % delta, 19, Color("#75e6a4") if delta < 0.0 else Color("#ef8b78"))
	_add_result_label(("NUEVA MEJOR VUELTA · " if result.is_new_best_lap else "MEJOR VUELTA · ") + RaceHudStyle.format_time(player.best_lap_time), 20, Color("#75e6a4") if result.is_new_best_lap else Color("#d8f4e8"))
	for index in player.lap_times.size():
		_add_result_label("VUELTA %d · %s" % [index + 1, RaceHudStyle.format_time(player.lap_times[index])], 17, Color("#b9ddd6"))
	if result.ghost_updated:
		_add_result_label("FANTASMA ACTUALIZADO", 20, Color("#53e8f2"))
	results_panel.visible = true
	retry_button.text = "OTRO INTENTO"
	_primary_result_action = &"retry"
	retry_button.grab_focus()


func _build_legacy_result(position: int, race_time: float) -> RaceResult:
	var result := RaceResult.new()
	var player := RacerRaceResult.new()
	player.racer_name = "Piloto"
	player.is_player = true
	player.start_position = position
	player.finish_position = position
	player.finish_time = race_time
	player.best_lap_time = race_time
	player.lap_times = [race_time]
	result.player_result = player
	result.standings = [player]
	return result


func _add_result_label(text: String, size: int, color: Color) -> void:
	_add_label_to(results_details, text, size, color)


func _add_label_to(container: VBoxContainer, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	container.add_child(label)


func update_pause_visibility(is_paused: bool) -> void:
	pause_overlay.visible = is_paused and not results_panel.visible


func handle_input(event: InputEvent) -> bool:
	if results_panel != null and results_panel.visible and _cup_stage >= 0 and _cup_stage < 2 and event.is_action_pressed(&"ui_accept"):
		_advance_cup_stage()
		return true
	if (
		not is_intro_visible
		or intro_skip_button == null
		or not intro_skip_button.visible
		or intro_skip_button.disabled
	):
		return false
	if event.is_action_pressed(&"ui_accept"):
		_request_intro_skip()
		return true
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if (
		key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		or key_event.physical_keycode in [
			KEY_ENTER,
			KEY_KP_ENTER,
			KEY_SPACE,
		]
	):
		_request_intro_skip()
		return true
	return false


func request_intro_skip() -> void:
	_request_intro_skip()


func _build_intro_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "RaceIntro"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false

	intro_content = VBoxContainer.new()
	intro_content.name = "Presentation"
	intro_content.set_anchors_preset(Control.PRESET_CENTER_TOP)
	intro_content.position = Vector2(-360.0, 66.0)
	intro_content.size = Vector2(720.0, 180.0)
	intro_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_content.add_theme_constant_override("separation", 6)
	overlay.add_child(intro_content)
	var band := ColorRect.new()
	band.color = Color(0.05, 0.1, 0.15, 0.88)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_top = 52.0
	band.offset_bottom = 232.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(band)
	overlay.move_child(band, 0)

	intro_title = Label.new()
	intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_title.add_theme_font_size_override("font_size", 48)
	intro_title.add_theme_color_override(
		"font_color",
		Color("#fff4c7")
	)
	intro_title.add_theme_color_override(
		"font_outline_color",
		Color("#13373d")
	)
	intro_title.add_theme_constant_override("outline_size", 12)
	intro_content.add_child(intro_title)

	intro_laps = Label.new()
	intro_laps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_laps.add_theme_font_size_override("font_size", 23)
	intro_laps.add_theme_color_override(
		"font_color",
		Color("#d8f4e8")
	)
	intro_laps.add_theme_color_override(
		"font_outline_color",
		Color("#13373d")
	)
	intro_laps.add_theme_constant_override("outline_size", 7)
	intro_content.add_child(intro_laps)

	intro_skip_button = Button.new()
	intro_skip_button.name = "SkipIntro"
	intro_skip_button.text = "OMITIR"
	intro_skip_button.tooltip_text = (
		"Omitir introducción (Enter o Espacio)"
	)
	intro_skip_button.custom_minimum_size = Vector2(180.0, 64.0)
	intro_skip_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	intro_skip_button.position = Vector2(-90.0, -102.0)
	intro_skip_button.size = Vector2(180.0, 64.0)
	intro_skip_button.visible = false
	intro_skip_button.disabled = true
	intro_skip_button.pressed.connect(_request_intro_skip)
	RaceHudStyle.apply_button_style(
		intro_skip_button,
		Color("#f5d66f")
	)
	overlay.add_child(intro_skip_button)
	return overlay


func _build_pause_overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "PauseMenu"
	overlay.color = UiTokens.SCRIM
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-220, -270)
	card.size = Vector2(440, 540)
	card.theme = UiTokens.create_theme()
	overlay.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(content)
	pause_title = Label.new()
	pause_title.text = "CARRERA EN PAUSA"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 34)
	content.add_child(pause_title)
	var resume := _pause_action("CONTINUAR", UiTokens.ELECTRIC_YELLOW)
	resume.name = "Resume"
	resume.pressed.connect(request_resume)
	content.add_child(resume)
	_resume_progress = ProgressBar.new()
	_resume_progress.max_value = RESUME_DELAY
	_resume_progress.show_percentage = false
	_resume_progress.visible = false
	content.add_child(_resume_progress)
	var restart := _pause_action("REINICIAR CARRERA", UiTokens.WARM_WHITE)
	restart.pressed.connect(func() -> void: _show_confirmation("¿REINICIAR LA CARRERA?", restart_requested))
	content.add_child(restart)
	var settings := _pause_action("AJUSTES", UiTokens.CYAN)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	content.add_child(settings)
	var controls := _pause_action("CONTROLES", UiTokens.CYAN)
	controls.pressed.connect(func() -> void: controls_requested.emit())
	content.add_child(controls)
	var quit := _pause_action("SALIR AL MENÚ", UiTokens.CORAL)
	quit.pressed.connect(func() -> void: _show_confirmation("¿SALIR AL MENÚ?", quit_requested))
	content.add_child(quit)
	return overlay


func _pause_action(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 58)
	RaceHudStyle.apply_button_style(button, color)
	return button


func _show_confirmation(title: String, confirmed_signal: Signal) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = "Esta acción no se puede deshacer."
	dialog.ok_button_text = "CONFIRMAR"
	dialog.cancel_button_text = "CANCELAR"
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.confirmed.connect(func() -> void:
		confirmed_signal.emit()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 190))


func _build_results_panel() -> Control:
	var overlay := ColorRect.new()
	overlay.name = "Results"
	overlay.color = Color(0.01, 0.06, 0.08, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	var card := VBoxContainer.new()
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 20.0
	card.offset_top = 15.0
	card.offset_right = -20.0
	card.offset_bottom = -15.0
	card.custom_minimum_size = Vector2(0.0, 0.0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 22)
	card.add_theme_stylebox_override(
		"panel",
		RaceHudStyle.style(Color("#123b42"), 24)
	)
	var card_panel := PanelContainer.new()
	card_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_panel.add_theme_stylebox_override(
		"panel",
		RaceHudStyle.style(Color("#123b42"), 24)
	)
	overlay.add_child(card_panel)
	card_panel.add_child(card)

	results_title = Label.new()
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_title.add_theme_font_size_override("font_size", 36)
	results_title.add_theme_color_override(
		"font_color",
		Color("#fff1b5")
	)
	card.add_child(results_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 100.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	results_details = VBoxContainer.new()
	results_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_details.add_theme_constant_override("separation", 8)
	scroll.add_child(results_details)

	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	card.add_child(actions)

	retry_button = Button.new()
	retry_button.name = "Retry"
	retry_button.text = "OTRA CARRERA"
	retry_button.custom_minimum_size = Vector2(190.0, 72.0)
	retry_button.pressed.connect(_activate_primary_result)
	RaceHudStyle.apply_button_style(
		retry_button,
		Color("#f2c958")
	)
	actions.add_child(retry_button)

	var menu := Button.new()
	_result_menu_button = menu
	menu.text = "MENÚ"
	menu.custom_minimum_size = Vector2(140.0, 72.0)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	RaceHudStyle.apply_button_style(menu, Color("#ef7656"))
	actions.add_child(menu)
	return overlay


func _build_provisional_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "ProvisionalResults"
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-210.0, 24.0)
	panel.size = Vector2(420.0, 0.0)
	panel.add_theme_stylebox_override(
		"panel", RaceHudStyle.style(Color(0.02, 0.12, 0.14, 0.92), 14)
	)
	panel.visible = false
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	provisional_title = Label.new()
	provisional_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	provisional_title.add_theme_font_size_override("font_size", 22)
	provisional_title.add_theme_color_override("font_color", Color("#f5d66f"))
	content.add_child(provisional_title)
	provisional_details = VBoxContainer.new()
	provisional_details.add_theme_constant_override("separation", 3)
	content.add_child(provisional_details)
	return panel


func _toggle_pause() -> void:
	if results_panel.visible or is_intro_visible:
		return
	get_tree().paused = true
	update_pause_visibility(true)
	var resume := pause_overlay.find_child("Resume", true, false) as Button
	if resume != null:
		resume.grab_focus.call_deferred()


func request_resume() -> void:
	if _is_resuming or not get_tree().paused:
		return
	_is_resuming = true
	pause_title.text = "REANUDANDO…"
	_resume_progress.value = 0.0
	_resume_progress.visible = true
	var progress_tween := create_tween()
	progress_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	progress_tween.tween_property(_resume_progress, "value", RESUME_DELAY, RESUME_DELAY)
	for button in pause_overlay.find_children("*", "Button", true, false):
		(button as Button).disabled = true
	await get_tree().create_timer(RESUME_DELAY, true).timeout
	if not is_inside_tree():
		return
	get_tree().paused = false
	_is_resuming = false
	pause_title.text = "CARRERA EN PAUSA"
	_resume_progress.visible = false
	for button in pause_overlay.find_children("*", "Button", true, false):
		(button as Button).disabled = false
	resume_requested.emit()

func _activate_primary_result() -> void:
	if _primary_result_action == &"retry":
		retry_requested.emit()
	elif _primary_result_action == &"cup_next":
		_advance_cup_stage()
	else:
		menu_requested.emit()


func _request_intro_skip() -> void:
	if (
		not is_intro_visible
		or intro_skip_button == null
		or not intro_skip_button.visible
		or intro_skip_button.disabled
	):
		return
	intro_skip_requested.emit()
