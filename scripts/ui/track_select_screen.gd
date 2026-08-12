class_name TrackSelectScreen
extends Control

signal race_requested(track_id: StringName, cc_id: StringName)
signal back_requested
signal track_selected(track_id: StringName)
signal race_class_selected(cc_id: StringName)

var track_catalog: TrackCatalog
var track_buttons: Dictionary = {}
var race_class_buttons: Dictionary = {}

var _best_times: Dictionary = {}
var _selected_track_id: StringName
var _selected_cc_id: StringName = RaceClassDefinition.DEFAULT_ID
var _title_label: Label
var _description_label: Label
var _details_label: Label
var _best_time_label: Label
var _race_class_description_label: Label
var _preview_panel: PanelContainer
var _preview_texture: TextureRect
var _minimap_view: TrackMinimapView
var _race_button: Button
var _back_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_interface()


func configure(
	catalog: TrackCatalog,
	best_times: Dictionary,
	selected_track_id: StringName,
	selected_cc_id: StringName = RaceClassDefinition.DEFAULT_ID
) -> void:
	track_catalog = catalog
	_best_times = best_times.duplicate(true)
	_build_track_list()
	select_track(selected_track_id, false)
	select_cc(selected_cc_id, false)


func update_best_times(best_times: Dictionary) -> void:
	_best_times = best_times.duplicate(true)
	_update_details()


func show_screen() -> void:
	visible = true
	var selected_button := track_buttons.get(_selected_track_id) as Button
	if selected_button != null:
		selected_button.grab_focus.call_deferred()
	elif _back_button != null:
		_back_button.grab_focus.call_deferred()


func select_track(track_id: StringName, should_emit := true) -> void:
	var definition := (
		track_catalog.get_track(track_id) if track_catalog != null else null
	)
	if definition == null and track_catalog != null:
		definition = track_catalog.get_default_track()
	if definition == null:
		_selected_track_id = &""
		_update_details()
		return
	_selected_track_id = definition.id
	for button_id in track_buttons:
		var track_button := track_buttons[button_id] as Button
		track_button.set_pressed_no_signal(button_id == _selected_track_id)
	_update_details()
	if should_emit:
		track_selected.emit(_selected_track_id)


func get_selected_track_id() -> StringName:
	return _selected_track_id


func select_cc(cc_id: StringName, should_emit := true) -> void:
	_selected_cc_id = RaceClassDefinition.get_by_id(cc_id).id
	for button_id in race_class_buttons:
		var race_class_button := race_class_buttons[button_id] as Button
		race_class_button.set_pressed_no_signal(button_id == _selected_cc_id)
	_update_race_class_description()
	_update_details()
	if should_emit:
		race_class_selected.emit(_selected_cc_id)


func get_selected_cc_id() -> StringName:
	return _selected_cc_id


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#082d37")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var sun_stripe := ColorRect.new()
	sun_stripe.color = Color("#f2b84d")
	sun_stripe.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	sun_stripe.offset_left = -245.0
	sun_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sun_stripe)

	var coral_stripe := ColorRect.new()
	coral_stripe.color = Color("#ef7151")
	coral_stripe.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	coral_stripe.offset_left = -278.0
	coral_stripe.offset_right = -244.0
	coral_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coral_stripe)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 48.0
	page.offset_top = 30.0
	page.offset_right = -48.0
	page.offset_bottom = -34.0
	page.add_theme_constant_override("separation", 14)
	add_child(page)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 72.0
	header.add_theme_constant_override("separation", 18)
	page.add_child(header)

	_back_button = _create_button("‹  VOLVER", Color("#74d3c4"), Vector2(160.0, 60.0))
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(_back_button)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var eyebrow := Label.new()
	eyebrow.text = "PARRILLA DE SALIDA"
	eyebrow.add_theme_font_size_override("font_size", 15)
	eyebrow.add_theme_color_override("font_color", Color("#7be0d0"))
	heading.add_child(eyebrow)
	var page_title := Label.new()
	page_title.text = "SELECCIONA PISTA"
	page_title.add_theme_font_size_override("font_size", 36)
	page_title.add_theme_color_override("font_color", Color("#fff0b1"))
	heading.add_child(page_title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	page.add_child(body)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size.x = 370.0
	list_panel.add_theme_stylebox_override("panel", _style(Color("#12404a"), 22))
	body.add_child(list_panel)
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 18)
	list_margin.add_theme_constant_override("margin_right", 18)
	list_margin.add_theme_constant_override("margin_top", 18)
	list_margin.add_theme_constant_override("margin_bottom", 18)
	list_panel.add_child(list_margin)
	var scroll := ScrollContainer.new()
	scroll.name = "TrackScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_margin.add_child(scroll)
	var track_list := VBoxContainer.new()
	track_list.name = "TrackList"
	track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_list.add_theme_constant_override("separation", 10)
	scroll.add_child(track_list)

	var detail_panel := VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_constant_override("separation", 8)
	body.add_child(detail_panel)

	_preview_panel = PanelContainer.new()
	_preview_panel.custom_minimum_size = Vector2(0.0, 150.0)
	_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_panel.clip_contents = true
	detail_panel.add_child(_preview_panel)
	var preview_stack := Control.new()
	preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_panel.add_child(preview_stack)
	_preview_texture = TextureRect.new()
	_preview_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stack.add_child(_preview_texture)
	_minimap_view = TrackMinimapView.new()
	_minimap_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_stack.add_child(_minimap_view)

	_title_label = Label.new()
	_title_label.text = "SIN PISTAS"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color("#fff0b1"))
	detail_panel.add_child(_title_label)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 17)
	_description_label.add_theme_color_override("font_color", Color("#d8f4e8"))
	detail_panel.add_child(_description_label)

	_details_label = Label.new()
	_details_label.add_theme_font_size_override("font_size", 16)
	_details_label.add_theme_color_override("font_color", Color("#7be0d0"))
	detail_panel.add_child(_details_label)

	_best_time_label = Label.new()
	_best_time_label.add_theme_font_size_override("font_size", 18)
	_best_time_label.add_theme_color_override("font_color", Color("#f5d66f"))
	detail_panel.add_child(_best_time_label)

	var race_class_label := Label.new()
	race_class_label.text = "CLASE DE MOTOR"
	race_class_label.add_theme_font_size_override("font_size", 15)
	race_class_label.add_theme_color_override("font_color", Color("#7be0d0"))
	detail_panel.add_child(race_class_label)

	var race_class_row := HBoxContainer.new()
	race_class_row.add_theme_constant_override("separation", 8)
	detail_panel.add_child(race_class_row)
	var race_class_group := ButtonGroup.new()
	race_class_group.allow_unpress = false
	for definition in RaceClassDefinition.get_all():
		var race_class_button := _create_button(
			str(definition.id),
			Color("#74d3c4"),
			Vector2(78.0, 48.0)
		)
		race_class_button.toggle_mode = true
		race_class_button.button_group = race_class_group
		race_class_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		race_class_button.tooltip_text = "%s: %s" % [
			definition.display_name,
			definition.description,
		]
		race_class_button.pressed.connect(select_cc.bind(definition.id))
		race_class_row.add_child(race_class_button)
		race_class_buttons[definition.id] = race_class_button

	_race_class_description_label = Label.new()
	_race_class_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_race_class_description_label.add_theme_font_size_override("font_size", 15)
	_race_class_description_label.add_theme_color_override(
		"font_color",
		Color("#d8f4e8")
	)
	detail_panel.add_child(_race_class_description_label)

	_race_button = _create_button("CORRER", Color("#f5d25f"), Vector2(240.0, 64.0))
	_race_button.pressed.connect(func() -> void:
		if not _selected_track_id.is_empty():
			race_requested.emit(_selected_track_id, _selected_cc_id)
	)
	detail_panel.add_child(_race_button)


func _build_track_list() -> void:
	var track_list := find_child("TrackList", true, false) as VBoxContainer
	if track_list == null:
		return
	for child in track_list.get_children():
		child.queue_free()
	track_buttons.clear()
	if track_catalog == null or track_catalog.tracks.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No hay pistas publicadas."
		empty_label.add_theme_color_override("font_color", Color("#d8f4e8"))
		track_list.add_child(empty_label)
		return

	var official_tracks: Array[TrackDefinition] = []
	var custom_tracks: Array[TrackDefinition] = []
	for definition in track_catalog.tracks:
		if definition == null or not definition.is_valid():
			continue
		if definition.scene.resource_path.begins_with("res://levels/tracks/"):
			custom_tracks.append(definition)
		else:
			official_tracks.append(definition)
	_add_track_group(track_list, "PISTAS OFICIALES", official_tracks)
	_add_track_group(track_list, "MIS PISTAS", custom_tracks)


func _add_track_group(
	container: VBoxContainer,
	group_name: String,
	definitions: Array[TrackDefinition]
) -> void:
	if definitions.is_empty():
		return
	var group_label := Label.new()
	group_label.text = group_name
	group_label.add_theme_font_size_override("font_size", 14)
	group_label.add_theme_color_override("font_color", Color("#7be0d0"))
	container.add_child(group_label)
	var button_group := ButtonGroup.new()
	for definition in definitions:
		var track_button := _create_button(
			definition.display_name.to_upper(),
			definition.preview_color,
			Vector2(330.0, 64.0)
		)
		track_button.toggle_mode = true
		track_button.button_group = button_group
		track_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		track_button.tooltip_text = definition.description
		track_button.pressed.connect(select_track.bind(definition.id))
		container.add_child(track_button)
		track_buttons[definition.id] = track_button


func _update_details() -> void:
	if _title_label == null:
		return
	var definition := (
		track_catalog.get_track(_selected_track_id)
		if track_catalog != null
		else null
	)
	if definition == null:
		_title_label.text = "SIN PISTAS"
		_description_label.text = "Publica una pista desde el editor para comenzar."
		_details_label.text = ""
		_best_time_label.text = ""
		_preview_texture.texture = null
		_preview_texture.visible = false
		_minimap_view.visible = true
		_minimap_view.set_minimap_data(null)
		_preview_panel.tooltip_text = "Sin mapa disponible."
		_race_button.disabled = true
		return
	_title_label.text = definition.display_name.to_upper()
	_description_label.text = (
		definition.description
		if not definition.description.strip_edges().is_empty()
		else "Circuito listo para competir."
	)
	var preview_map := _resolve_preview_map(definition)
	_details_label.text = _format_track_details(definition, preview_map)
	var best_time := _get_best_time(definition.id, _selected_cc_id)
	_best_time_label.text = (
		"MEJOR TIEMPO %s  ·  %s" % [
			RaceClassDefinition.get_by_id(_selected_cc_id).display_name,
			_format_time(best_time),
		]
		if best_time > 0.0
		else "MEJOR TIEMPO %s  ·  SIN REGISTRO" % (
			RaceClassDefinition.get_by_id(_selected_cc_id).display_name
		)
	)
	_preview_texture.texture = definition.preview_texture
	_preview_texture.visible = definition.preview_texture != null
	_minimap_view.visible = definition.preview_texture == null
	_minimap_view.set_minimap_data(preview_map)
	_preview_panel.tooltip_text = (
		"Portada de %s." % definition.display_name
		if definition.preview_texture != null
		else (
			"Plano de %s: %d metros y %d atajos."
			% [
				definition.display_name,
				roundi(preview_map.length_meters),
				preview_map.shortcut_count,
			]
			if preview_map != null and preview_map.is_valid()
			else "%s. Sin mapa disponible." % definition.display_name
		)
	)
	_preview_panel.add_theme_stylebox_override(
		"panel",
		_style(definition.preview_color.darkened(0.28), 24, 3, definition.preview_color)
	)
	_race_button.disabled = false


func _update_race_class_description() -> void:
	if _race_class_description_label == null:
		return
	var definition := RaceClassDefinition.get_by_id(_selected_cc_id)
	_race_class_description_label.text = "%s - %s" % [
		definition.display_name,
		definition.description,
	]


func _get_best_time(track_id: StringName, cc_id: StringName) -> float:
	var record_key := GameSettings.get_record_key(track_id, cc_id)
	if _best_times.has(record_key):
		return maxf(float(_best_times[record_key]), -1.0)
	var legacy_value: Variant = _best_times.get(track_id, -1.0)
	if legacy_value is Dictionary:
		return maxf(float(legacy_value.get(cc_id, -1.0)), -1.0)
	if cc_id == RaceClassDefinition.DEFAULT_ID:
		return maxf(float(legacy_value), -1.0)
	return -1.0


func _resolve_preview_map(
	definition: TrackDefinition
) -> TrackMinimapData:
	if definition.preview_map != null and definition.preview_map.is_valid():
		return definition.preview_map
	if definition.scene == null:
		return null
	var scene_root := definition.scene.instantiate()
	if scene_root == null:
		return null
	var track := scene_root as TrackLevel
	if track == null:
		scene_root.free()
		return null
	var generated_map := TrackMinimapBuilder.build(track)
	track.free()
	if generated_map != null:
		definition.preview_map = generated_map
	return generated_map


func _format_track_details(
	definition: TrackDefinition,
	preview_map: TrackMinimapData
) -> String:
	if preview_map == null or not preview_map.is_valid():
		return "%d VUELTAS  ·  DISTANCIA NO DISPONIBLE" % definition.laps
	var shortcut_label := (
		"1 ATAJO"
		if preview_map.shortcut_count == 1
		else "%d ATAJOS" % preview_map.shortcut_count
	)
	return "%d VUELTAS  ·  %d M  ·  %s" % [
		definition.laps,
		roundi(preview_map.length_meters),
		shortcut_label,
	]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _create_button(text: String, color: Color, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color("#102d32"))
	button.add_theme_color_override("font_focus_color", Color("#102d32"))
	button.add_theme_stylebox_override("normal", _style(color, 16))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.1), 16))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.14), 16))
	button.add_theme_stylebox_override("focus", _style(Color("#ffffff"), 16, 4, Color("#ffffff")))
	button.add_theme_stylebox_override(
		"disabled",
		_style(Color(0.32, 0.37, 0.38, 0.65), 16)
	)
	return button


func _style(
	color: Color,
	radius: int,
	border_width := 0,
	border_color := Color("#ffffff")
) -> StyleBoxFlat:
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
		style.set_border_width_all(border_width)
		style.border_color = border_color
	return style


func _format_time(time: float) -> String:
	var minutes := floori(time / 60.0)
	var seconds := floori(fmod(time, 60.0))
	var milliseconds := floori(fmod(time * 1000.0, 1000.0))
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
