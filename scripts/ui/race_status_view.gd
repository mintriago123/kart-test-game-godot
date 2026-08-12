class_name RaceStatusView
extends Control

var lap_label: Label
var position_label: Label
var time_label: Label
var speed_label: Label
var item_label: Label
var item_chip: PanelContainer
var item_icon: TextureRect
var shield_panel: PanelContainer
var shield_icon: TextureRect
var shield_label: Label
var shield_bar: ProgressBar
var countdown_label: Label
var drift_bar: ProgressBar
var race_elements: Array[CanvasItem] = []


func build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_bar := HBoxContainer.new()
	top_bar.name = "RaceInfo"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 24.0
	top_bar.offset_top = 18.0
	top_bar.offset_right = -24.0
	top_bar.offset_bottom = 92.0
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)
	race_elements.append(top_bar)

	position_label = RaceHudStyle.create_chip("1º / 4", 28)
	top_bar.add_child(position_label)
	lap_label = RaceHudStyle.create_chip("VUELTA 1/3", 22)
	top_bar.add_child(lap_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	time_label = RaceHudStyle.create_chip("00:00.000", 22)
	top_bar.add_child(time_label)
	speed_label = RaceHudStyle.create_chip("000 km/h", 20)
	top_bar.add_child(speed_label)

	item_chip = PanelContainer.new()
	item_chip.name = "ItemChip"
	item_chip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	item_chip.position = Vector2(-150.0, 102.0)
	item_chip.size = Vector2(300.0, 58.0)
	item_chip.add_theme_stylebox_override(
		"panel",
		RaceHudStyle.style(Color(0.03, 0.16, 0.18, 0.92), 14)
	)
	add_child(item_chip)
	race_elements.append(item_chip)

	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 8)
	item_chip.add_child(item_row)

	item_icon = TextureRect.new()
	item_icon.name = "Icon"
	item_icon.custom_minimum_size = Vector2(44.0, 44.0)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_row.add_child(item_icon)

	item_label = Label.new()
	item_label.text = "SIN OBJETO"
	item_label.custom_minimum_size = Vector2(212.0, 48.0)
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 16)
	item_label.add_theme_color_override("font_color", Color("#fff6d7"))
	item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_row.add_child(item_label)

	_build_shield_status()

	drift_bar = ProgressBar.new()
	drift_bar.min_value = 0.0
	drift_bar.max_value = 1.0
	drift_bar.value = 0.0
	drift_bar.show_percentage = false
	drift_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	drift_bar.position = Vector2(-90.0, -52.0)
	drift_bar.size = Vector2(180.0, 13.0)
	drift_bar.add_theme_stylebox_override(
		"background",
		RaceHudStyle.style(Color(0.02, 0.08, 0.1, 0.76), 8)
	)
	drift_bar.add_theme_stylebox_override(
		"fill",
		RaceHudStyle.style(Color("#f5d66f"), 8)
	)
	add_child(drift_bar)
	race_elements.append(drift_bar)

	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 78)
	countdown_label.add_theme_color_override(
		"font_color",
		Color("#fff4c7")
	)
	countdown_label.add_theme_color_override(
		"font_outline_color",
		Color("#13373d")
	)
	countdown_label.add_theme_constant_override("outline_size", 14)
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.position = Vector2(-180.0, -100.0)
	countdown_label.size = Vector2(360.0, 200.0)
	countdown_label.visible = false
	add_child(countdown_label)
	race_elements.append(countdown_label)


func update_race_info(
	lap: int,
	total_laps: int,
	position: int,
	racers: int,
	race_time: float
) -> void:
	lap_label.text = "VUELTA %d/%d" % [lap, total_laps]
	position_label.text = "%dº / %d" % [position, racers]
	time_label.text = RaceHudStyle.format_time(race_time)


func show_countdown(text: String, is_intro_visible: bool) -> void:
	countdown_label.text = text
	countdown_label.visible = (
		not is_intro_visible and not text.is_empty()
	)


func update_speed(speed_kph: float) -> void:
	speed_label.text = "%03d km/h" % speed_kph


func show_item(item: ItemDefinition) -> void:
	item_label.text = (
		item.display_name.to_upper()
		if item != null
		else "SIN OBJETO"
	)
	item_icon.texture = item.icon if item != null else null
	item_icon.visible = item != null


func show_shield(
	item: ItemDefinition,
	remaining: float,
	total: float,
	is_intro_visible: bool
) -> void:
	var is_active := (
		item != null
		and remaining > 0.0
		and total > 0.0
		and not is_intro_visible
	)
	shield_panel.visible = is_active
	if not is_active:
		return
	shield_icon.texture = item.icon
	shield_label.text = "BURBUJA · %.1f s" % remaining
	shield_bar.max_value = total
	shield_bar.value = remaining


func show_boost(charge_ratio: float) -> void:
	drift_bar.value = charge_ratio


func set_race_elements_visible(
	is_visible: bool,
	has_active_shield: bool
) -> void:
	for element in race_elements:
		element.visible = is_visible
	if is_visible and not has_active_shield:
		shield_panel.visible = false


func _build_shield_status() -> void:
	shield_panel = PanelContainer.new()
	shield_panel.name = "ShieldStatus"
	shield_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	shield_panel.position = Vector2(-136.0, 166.0)
	shield_panel.size = Vector2(272.0, 50.0)
	shield_panel.visible = false
	shield_panel.add_theme_stylebox_override(
		"panel",
		RaceHudStyle.style(Color(0.03, 0.16, 0.18, 0.92), 12)
	)
	add_child(shield_panel)
	race_elements.append(shield_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	shield_panel.add_child(row)

	shield_icon = TextureRect.new()
	shield_icon.custom_minimum_size = Vector2(34.0, 34.0)
	shield_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shield_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(shield_icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)

	shield_label = Label.new()
	shield_label.text = "BURBUJA 7.0 s"
	shield_label.add_theme_font_size_override("font_size", 13)
	shield_label.add_theme_color_override(
		"font_color",
		Color("#e9fffa")
	)
	details.add_child(shield_label)

	shield_bar = ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(176.0, 9.0)
	shield_bar.show_percentage = false
	shield_bar.add_theme_stylebox_override(
		"background",
		RaceHudStyle.style(Color(0.01, 0.08, 0.1, 0.8), 6)
	)
	shield_bar.add_theme_stylebox_override(
		"fill",
		RaceHudStyle.style(Color("#77d9df"), 6)
	)
	details.add_child(shield_bar)
