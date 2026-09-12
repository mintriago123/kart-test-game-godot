class_name ProfileScreen
extends Control

signal back_requested
signal open_garage_requested

var progression_catalog: ProgressionCatalog
var player_progress: PlayerProgress
var best_times: Dictionary = {}

var _sidebar: PanelContainer
var _content_host: VBoxContainer
var _nav_buttons: Dictionary = {}
var _mobile_nav: HBoxContainer
var _active_section := &"summary"
var _cup_list: VBoxContainer
var _filter_buttons: Dictionary = {}
var _cup_filter := &"all"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = UiTokens.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.add_theme_constant_override("margin_left", 24); margin.add_theme_constant_override("margin_top", 20); margin.add_theme_constant_override("margin_right", 24); margin.add_theme_constant_override("margin_bottom", 20); add_child(margin)
	var shell := HBoxContainer.new(); shell.name = "ProfileShell"; shell.add_theme_constant_override("separation", UiTokens.SPACE_4); margin.add_child(shell)
	var sidebar := PanelContainer.new(); _sidebar = sidebar; sidebar.name = "ProfileNavigation"; sidebar.custom_minimum_size.x = 210; sidebar.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_LARGE)); shell.add_child(sidebar)
	var nav := VBoxContainer.new(); nav.add_theme_constant_override("separation", UiTokens.SPACE_2); sidebar.add_child(nav)
	var eyebrow := _value_label("PILOTO", UiTokens.CYAN, UiTokens.FONT_CAPTION); nav.add_child(eyebrow)
	var nav_title := _value_label("PASAPORTE\nCOMPETICIÓN", UiTokens.WARM_WHITE, UiTokens.FONT_H3); nav.add_child(nav_title)
	for section_data in [["RESUMEN", &"summary"], ["COPAS", &"cups"], ["RÉCORDS", &"records"], ["MULTIJUGADOR", &"multiplayer"], ["COLECCIÓN", &"collection"]]:
		var nav_button := _create_button(section_data[0], UiTokens.INK_RAISED, Vector2(0, UiTokens.TOUCH_TARGET)); nav_button.name = "ProfileNav_%s" % section_data[1]; nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT; nav_button.pressed.connect(_show_section.bind(section_data[1])); nav.add_child(nav_button); _nav_buttons[section_data[1]] = nav_button
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; nav.add_child(spacer)
	var close := _create_button("VOLVER", UiTokens.CORAL, Vector2(0, UiTokens.BUTTON_HEIGHT)); close.pressed.connect(func() -> void: back_requested.emit()); nav.add_child(close)
	_mobile_nav = HBoxContainer.new(); _mobile_nav.add_theme_constant_override("separation", UiTokens.SPACE_2); _mobile_nav.visible = false; nav.add_child(_mobile_nav)

	var content_panel := PanelContainer.new(); content_panel.name = "ProfileContent"; content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content_panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_LARGE)); shell.add_child(content_panel)
	var content_scroll := ScrollContainer.new(); content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; content_panel.add_child(content_scroll)
	_content_host = VBoxContainer.new(); _content_host.name = "ProfileContentHost"; _content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _content_host.add_theme_constant_override("separation", UiTokens.SPACE_4); content_scroll.add_child(_content_host)
	resized.connect(_update_layout)
	_update_layout()
	_show_section(_active_section)


func configure(catalog: ProgressionCatalog, progress: PlayerProgress, times: Dictionary) -> void:
	progression_catalog = catalog
	player_progress = progress
	best_times = times.duplicate(true)


func _section(title: String) -> PanelContainer:
	var panel := PanelContainer.new(); panel.custom_minimum_size.y = 116; panel.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_MEDIUM))
	var section := VBoxContainer.new(); section.add_theme_constant_override("separation", UiTokens.SPACE_2); panel.add_child(section)
	var heading := Label.new(); heading.text = title; heading.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION); heading.add_theme_color_override("font_color", UiTokens.MUTED); section.add_child(heading)
	return panel


func _section_content(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0) as VBoxContainer


func _show_section(section_id: StringName) -> void:
	if _content_host == null: return
	_active_section = section_id
	for child in _content_host.get_children(): child.queue_free()
	for id in _nav_buttons:
		var button := _nav_buttons[id] as Button
		var active: bool = id == section_id
		button.add_theme_stylebox_override("normal", _style(UiTokens.ELECTRIC_YELLOW if active else UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL))
		button.add_theme_color_override("font_color", UiTokens.GRAPHITE if active else UiTokens.TEXT_PRIMARY)
	var heading := _value_label(_section_title(section_id), UiTokens.WARM_WHITE, UiTokens.FONT_H1)
	heading.name = "ProfileSectionTitle"; _content_host.add_child(heading)
	var intro := _value_label(_section_intro(section_id), UiTokens.TEXT_TERTIARY, UiTokens.FONT_BODY); _content_host.add_child(intro)
	match section_id:
		&"summary": _build_summary()
		&"cups": _build_cups()
		&"records": _build_records()
		&"multiplayer": _build_multiplayer()
		&"collection": _build_collection()
	_nav_buttons[section_id].grab_focus.call_deferred()


func _section_title(section_id: StringName) -> String:
	return {&"summary": "RESUMEN", &"cups": "PALMARÉS", &"records": "RÉCORDS DE PISTA", &"multiplayer": "MULTIJUGADOR", &"collection": "COLECCIÓN"}.get(section_id, "PERFIL")


func _section_intro(section_id: StringName) -> String:
	return {&"summary": "Tu rendimiento en una sola mirada.", &"cups": "Medallas conseguidas por dificultad.", &"records": "Las marcas que definen tu vuelta más rápida.", &"multiplayer": "Resultados separados por tipo de partida.", &"collection": "Tus vehículos, recompensas y progreso de garaje."}.get(section_id, "")


func _build_summary() -> void:
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", UiTokens.SPACE_3); grid.add_theme_constant_override("v_separation", UiTokens.SPACE_3); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _content_host.add_child(grid)
	_add_metric(grid, str(player_progress.victories if player_progress else 0), "VICTORIAS", UiTokens.ELECTRIC_YELLOW)
	_add_metric(grid, str(player_progress.podiums if player_progress else 0), "PODIOS", UiTokens.CYAN)
	_add_metric(grid, str(player_progress.races_played if player_progress else 0), "CARRERAS", UiTokens.WARM_WHITE)
	_add_metric(grid, str(player_progress.best_finish_position if player_progress and player_progress.best_finish_position > 0 else "—"), "MEJOR POSICIÓN", UiTokens.SUCCESS)
	var career_points := player_progress.get_career_points(progression_catalog) if player_progress != null and progression_catalog != null else 0
	var career_max := player_progress.get_max_career_points(progression_catalog) if player_progress != null and progression_catalog != null else 0
	var next_reward: UnlockDefinition = player_progress.get_next_career_reward(progression_catalog) if player_progress != null and progression_catalog != null else null
	var progression := _section("PROGRESIÓN"); var progression_content := _section_content(progression); _content_host.add_child(progression)
	progression_content.add_child(_value_label("%d / %d PUNTOS DE CARRERA\n%s" % [career_points, career_max, "%d PTOS · %s" % [next_reward.required_points, next_reward.display_name.to_upper()] if next_reward != null else "TODOS LOS HITOS CONSEGUIDOS"], UiTokens.ELECTRIC_YELLOW, UiTokens.FONT_LABEL))
	var bar := ProgressBar.new(); bar.max_value = maxf(1.0, career_max); bar.value = career_points; bar.show_percentage = false; bar.custom_minimum_size.y = UiTokens.SPACE_3; bar.add_theme_stylebox_override("background", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_SMALL)); bar.add_theme_stylebox_override("fill", UiTokens.panel(UiTokens.ELECTRIC_YELLOW, UiTokens.RADIUS_SMALL)); progression_content.add_child(bar)


func _build_cups() -> void:
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation", UiTokens.SPACE_2); _content_host.add_child(header)
	var label := _value_label("FILTRAR POR MEDALLA", UiTokens.MUTED, UiTokens.FONT_CAPTION); label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(label)
	_filter_buttons.clear()
	for filter_data in [["TODAS", &"all"], ["BRONCE", &"bronze"], ["PLATA", &"silver"], ["ORO", &"gold"]]:
		var filter := _create_button(filter_data[0], UiTokens.INK_RAISED, Vector2(88, UiTokens.TOUCH_TARGET)); filter.name = "CupFilter_%s" % filter_data[1]; filter.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION); filter.pressed.connect(_set_cup_filter.bind(filter_data[1])); header.add_child(filter); _filter_buttons[filter_data[1]] = filter
	_cup_list = VBoxContainer.new(); _cup_list.add_theme_constant_override("separation", UiTokens.SPACE_2); _content_host.add_child(_cup_list); _refresh_cups()


func _build_records() -> void:
	var panel := _section("RÉCORDS GLOBALES"); var content := _section_content(panel); _content_host.add_child(panel)
	var best_time: float = float(best_times.values().min()) if not best_times.is_empty() else 0.0
	content.add_child(_value_label("MEJOR TIEMPO   %s\nTIEMPO CONDUCIDO   %s\nATAJOS   %d\nRECUPERACIONES   %d" % [_format_duration(best_time), _format_duration(player_progress.driving_time_seconds if player_progress else 0.0), player_progress.shortcuts_used if player_progress else 0, player_progress.recoveries if player_progress else 0], UiTokens.TEXT_PRIMARY, UiTokens.FONT_LABEL))
	var tracks := _section("MEJORES TIEMPOS POR PISTA"); var track_content := _section_content(tracks); _content_host.add_child(tracks)
	if best_times.is_empty(): track_content.add_child(_value_label("AÚN NO HAY TIEMPOS REGISTRADOS", UiTokens.TEXT_TERTIARY, UiTokens.FONT_BODY))
	else:
		for track_id in best_times:
			track_content.add_child(_value_label("%s    %s" % [str(track_id).to_upper(), _format_duration(best_times[track_id])], UiTokens.TEXT_SECONDARY, UiTokens.FONT_BODY))


func _build_multiplayer() -> void:
	for data in [["LOCAL", player_progress.local_multiplayer if player_progress else MultiplayerStatistics.new()], ["LAN", player_progress.lan_multiplayer if player_progress else MultiplayerStatistics.new()]]:
		var panel := _section(data[0]); var content := _section_content(panel); _content_host.add_child(panel); var stats: MultiplayerStatistics = data[1]
		content.add_child(_value_label("%d CARRERAS\n%d VICTORIAS   ·   %d PODIOS\nMEJOR POSICIÓN   %s" % [stats.races_played, stats.victories, stats.podiums, str(stats.best_finish_position) if stats.best_finish_position > 0 else "—"], UiTokens.CYAN, UiTokens.FONT_LABEL))


func _build_collection() -> void:
	var unlocked := player_progress.get_unlocked_variant_count(progression_catalog.unlocks) if player_progress != null and progression_catalog != null else 0
	var total := progression_catalog.unlocks.variants.size() if progression_catalog != null else 0
	var equipped_name := "—"
	if progression_catalog != null and player_progress != null:
		var equipped := progression_catalog.unlocks.get_variant(player_progress.equipped_kart_variant_id)
		if equipped != null: equipped_name = equipped.display_name
	var panel := _section("ESTADO DEL GARAJE"); var content := _section_content(panel); _content_host.add_child(panel)
	content.add_child(_value_label("COLECCIÓN   %d / %d\nEQUIPADO   %s\nNUEVOS   %d" % [unlocked, total, equipped_name.to_upper(), player_progress.get_new_reward_count() if player_progress else 0], UiTokens.TEXT_PRIMARY, UiTokens.FONT_LABEL))
	var garage := _create_button("ABRIR GARAJE", UiTokens.ELECTRIC_YELLOW, Vector2(240, UiTokens.BUTTON_HEIGHT)); garage.pressed.connect(func() -> void: open_garage_requested.emit()); garage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; _content_host.add_child(garage)


func _value_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _add_metric(parent: GridContainer, value: String, label_text: String, color: Color) -> void:
	var metric := VBoxContainer.new(); metric.custom_minimum_size.x = 132.0; metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL; metric.add_theme_constant_override("separation", 0)
	var value_label := _value_label(value, color, UiTokens.FONT_DISPLAY); value_label.add_theme_color_override("font_color", color); metric.add_child(value_label)
	var caption := _value_label(label_text, UiTokens.MUTED, UiTokens.FONT_CAPTION); caption.autowrap_mode = TextServer.AUTOWRAP_OFF; caption.clip_text = true; metric.add_child(caption); parent.add_child(metric)


func _set_cup_filter(filter_id: StringName) -> void:
	_cup_filter = filter_id
	_refresh_cups()


func _refresh_cups() -> void:
	if _cup_list == null: return
	for child in _cup_list.get_children(): child.queue_free()
	for filter_id in _filter_buttons:
		var button := _filter_buttons[filter_id] as Button
		var selected: bool = filter_id == _cup_filter
		button.add_theme_stylebox_override("normal", _style(UiTokens.ELECTRIC_YELLOW if selected else UiTokens.INK_RAISED, 12))
		button.add_theme_color_override("font_color", UiTokens.GRAPHITE if selected else UiTokens.TEXT_PRIMARY)
	if progression_catalog == null or progression_catalog.cups == null: return
	var medal_names := ["—", "BRONCE", "PLATA", "ORO"]
	var wanted := -1
	match _cup_filter:
		&"bronze": wanted = UnlockDefinition.BRONZE
		&"silver": wanted = UnlockDefinition.SILVER
		&"gold": wanted = UnlockDefinition.GOLD
	var visible_cups := 0
	for cup in progression_catalog.cups.get_valid_cups():
		var best := player_progress.get_best_cup_medal(cup.id) if player_progress else UnlockDefinition.Medal.NONE
		var difficulty_medals := PackedStringArray()
		var matches_filter := wanted <= 0
		for difficulty in cup.difficulties:
			var medal := player_progress.get_medal(cup.id, difficulty.id) if player_progress else UnlockDefinition.Medal.NONE
			difficulty_medals.append("%s %s" % [difficulty.display_name.to_upper(), medal_names[medal]])
			if medal == wanted: matches_filter = true
		if not matches_filter: continue
		visible_cups += 1
		var cup_card := PanelContainer.new(); cup_card.custom_minimum_size.y = 58; cup_card.add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_SMALL)); _cup_list.add_child(cup_card)
		var cup_info := Label.new(); cup_info.text = "%s\n%s" % [cup.display_name.to_upper(), "   ".join(difficulty_medals)]; cup_info.add_theme_color_override("font_color", UiTokens.ELECTRIC_YELLOW if best == UnlockDefinition.GOLD else (UiTokens.TEXT_PRIMARY if best > 0 else UiTokens.TEXT_TERTIARY)); cup_card.add_child(cup_info)
	if visible_cups == 0:
		_cup_list.add_child(_value_label("NO HAY MEDALLAS EN ESTE FILTRO", UiTokens.TEXT_TERTIARY, UiTokens.FONT_BODY))


func _update_layout() -> void:
	if _sidebar == null: return
	var compact := size.x < UiTokens.BREAKPOINT_TWO_PANEL_WIDTH
	_sidebar.custom_minimum_size.x = 168.0 if compact else 210.0
	if _content_host != null:
		_content_host.custom_minimum_size.x = maxf(300.0, size.x - (260.0 if compact else 300.0))


func _format_duration(seconds: float) -> String:
	var total := maxi(roundi(seconds), 0)
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func _create_button(text: String, color: Color, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", UiTokens.GRAPHITE)
	button.add_theme_color_override("font_focus_color", UiTokens.GRAPHITE)
	button.add_theme_stylebox_override("normal", _style(color, 18))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.1), 18))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.14), 18))
	button.add_theme_stylebox_override("focus", _style(UiTokens.WARM_WHITE, 18, 4))
	button.add_theme_stylebox_override("disabled", _style(UiTokens.BUTTON_DISABLED_BG, 18))
	return button


func _style(color: Color, radius: int, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = UiTokens.WARM_WHITE
	return style
