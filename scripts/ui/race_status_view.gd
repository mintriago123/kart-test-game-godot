class_name RaceStatusView
extends Control

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")
const UiColorUtils = preload("res://scripts/ui/ui_color_utils.gd")
# Hysteresis band so "VELOCIDAD MÁXIMA" doesn't flicker as speed oscillates
# around the threshold under normal braking/cornering.
const MAX_SPEED_ENTER := 95
const MAX_SPEED_EXIT := 88

var lap_label: Label
var position_label: Label
var time_label: Label
var speed_value_label: Label
var speed_unit_label: Label
var speed_panel: PanelContainer
var speed_state_label: Label
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
var split_panel: PanelContainer
var split_label: Label
var delta_label: Label
var _split_generation := 0
var _game_mode := GameModeDefinition.RACE
var _has_item := false
var _track_accent := UiTokens.ELECTRIC_YELLOW
var _speed_state := &"normal"
var _density := &"full"
var _player_number := 0


func build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_bar := HBoxContainer.new()
	top_bar.name = "RaceInfo"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 24.0
	top_bar.offset_top = 18.0
	top_bar.offset_right = -24.0
	top_bar.offset_bottom = 76.0
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)
	race_elements.append(top_bar)

	position_label = RaceHudStyle.create_chip("1º / 4", 30)
	position_label.name = "Position"
	position_label.custom_minimum_size = Vector2(150.0, 58.0)
	top_bar.add_child(position_label)
	lap_label = RaceHudStyle.create_chip("VUELTA 1/3", 18)
	top_bar.add_child(lap_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	time_label = RaceHudStyle.create_chip("00:00.000", 18)
	top_bar.add_child(time_label)
	delta_label = RaceHudStyle.create_chip("FANTASMA  SIN REFERENCIA", 18)
	delta_label.visible = false
	top_bar.add_child(delta_label)
	_build_speed_instrument()

	item_chip = PanelContainer.new()
	item_chip.name = "ItemChip"
	item_chip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	item_chip.position = Vector2(24.0, -92.0)
	item_chip.size = Vector2(210.0, 58.0)
	item_chip.add_theme_stylebox_override(
		"panel",
		RaceHudStyle.style(UiTokens.surface_alpha(UiTokens.INK, 3), 14)
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
	item_label.custom_minimum_size = Vector2(154.0, 48.0)
	item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 16)
	item_label.add_theme_color_override("font_color", UiTokens.WARM_WHITE)
	item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_row.add_child(item_label)

	_build_shield_status()
	_build_split_status()

	drift_bar = ProgressBar.new()
	drift_bar.min_value = 0.0
	drift_bar.max_value = 1.0
	drift_bar.value = 0.0
	drift_bar.show_percentage = false
	drift_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	drift_bar.offset_left = -244.0
	drift_bar.offset_right = -24.0
	drift_bar.offset_top = -28.0
	drift_bar.offset_bottom = -18.0
	drift_bar.add_theme_stylebox_override(
		"background",
		RaceHudStyle.style(UiTokens.surface_alpha(UiTokens.GRAPHITE, 1), 8)
	)
	drift_bar.add_theme_stylebox_override(
		"fill",
		RaceHudStyle.style(UiTokens.ELECTRIC_YELLOW, 8)
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
		UiTokens.WARM_WHITE
	)
	countdown_label.add_theme_color_override(
		"font_outline_color",
		UiTokens.INK
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
	position_label.text = "%s%dº / %d" % ["J%d  ·  " % _player_number if _player_number > 0 else "", position, racers]
	time_label.text = RaceHudStyle.format_time(race_time)


func show_countdown(text: String, is_intro_visible: bool) -> void:
	countdown_label.text = text
	countdown_label.visible = (
		not is_intro_visible and not text.is_empty()
	)


func update_speed(speed_kph: float) -> void:
	var value := clampi(floori(speed_kph), 0, 999)
	speed_value_label.text = "%03d" % value
	_update_speed_state(value)


func _build_speed_instrument() -> void:
	speed_panel = PanelContainer.new()
	speed_panel.name = "SpeedInstrument"
	speed_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_panel.offset_left = -244.0
	speed_panel.offset_right = -24.0
	speed_panel.offset_top = -116.0
	speed_panel.offset_bottom = -30.0
	speed_panel.add_theme_stylebox_override("panel", RaceHudStyle.style(UiTokens.HUD_GRAPHITE, 12, 1))
	add_child(speed_panel)
	race_elements.append(speed_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	speed_panel.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	speed_value_label = RaceHudStyle.create_hud_label("000", 64)
	speed_value_label.name = "SpeedValue"
	speed_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(speed_value_label)
	speed_unit_label = RaceHudStyle.create_hud_label("KM/H", 15, UiTokens.TEXT_SECONDARY)
	speed_unit_label.name = "SpeedUnit"
	speed_unit_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	speed_unit_label.custom_minimum_size = Vector2(42.0, 34.0)
	row.add_child(speed_unit_label)
	speed_state_label = RaceHudStyle.create_hud_label("VELOCIDAD", 11, UiTokens.TEXT_TERTIARY)
	speed_state_label.name = "SpeedState"
	speed_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(speed_state_label)


func _update_speed_state(value: int) -> void:
	var state := &"normal"
	var color := UiTokens.SPEED_NORMAL
	if value == 0:
		state = &"stopped"
		color = UiTokens.TEXT_TERTIARY
	elif speed_panel != null and speed_panel.has_meta("turbo") and speed_panel.get_meta("turbo"):
		state = &"turbo"
		color = UiTokens.SPEED_TURBO
	elif value >= MAX_SPEED_ENTER or (_speed_state == &"max" and value >= MAX_SPEED_EXIT):
		state = &"max"
		color = UiTokens.SPEED_MAX
	_speed_state = state
	speed_value_label.add_theme_color_override("font_color", color)
	speed_state_label.text = {
		&"stopped": "DETENIDO",
		&"turbo": "TURBO ACTIVO",
		&"max": "VELOCIDAD MÁXIMA",
		&"normal": "VELOCIDAD",
	}.get(state, "VELOCIDAD")
	speed_state_label.add_theme_color_override("font_color", color if state != &"normal" else UiTokens.TEXT_TERTIARY)


func set_track_accent(accent: Color) -> void:
	_track_accent = accent
	drift_bar.add_theme_stylebox_override(
		"fill", RaceHudStyle.style(accent, 8)
	)
	speed_value_label.add_theme_color_override("font_color", UiColorUtils.readable_foreground(accent))


func show_item(item: ItemDefinition) -> void:
	_has_item = item != null
	item_label.text = (
		item.display_name.to_upper()
		if item != null
		else "SIN OBJETO"
	)
	item_icon.texture = item.icon if item != null else null
	item_icon.visible = item != null
	item_chip.visible = _has_item and _game_mode != GameModeDefinition.TIME_TRIAL


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
	if speed_panel != null:
		speed_panel.set_meta("turbo", charge_ratio >= 1.0)
		if charge_ratio >= 1.0:
			speed_state_label.text = "TURBO LISTO"
			speed_state_label.add_theme_color_override("font_color", UiTokens.SPEED_MAX)
		elif _speed_state == &"normal":
			speed_state_label.text = "DERRAPE %.0f%%" % (charge_ratio * 100.0)


func set_boost_active(active: bool) -> void:
	if speed_panel == null:
		return
	speed_panel.set_meta("turbo", active)
	if active:
		speed_value_label.add_theme_color_override("font_color", UiTokens.SPEED_TURBO)
		speed_state_label.text = "TURBO ACTIVO"
		speed_state_label.add_theme_color_override("font_color", UiTokens.SPEED_TURBO)


func set_speed_state(state: StringName) -> void:
	if speed_panel == null:
		return
	_speed_state = state
	var color := UiTokens.SPEED_NORMAL
	var caption := "VELOCIDAD"
	match state:
		&"max": color = UiTokens.SPEED_MAX; caption = "VELOCIDAD MÁXIMA"
		&"turbo": color = UiTokens.SPEED_TURBO; caption = "TURBO ACTIVO"
		&"hit": color = UiTokens.SPEED_HIT; caption = "GOLPE"
		&"danger": color = UiTokens.SPEED_DANGER; caption = "FUERA DE PISTA"
		&"stopped": color = UiTokens.TEXT_TERTIARY; caption = "DETENIDO"
	speed_value_label.add_theme_color_override("font_color", color)
	speed_state_label.text = caption
	speed_state_label.add_theme_color_override("font_color", color)


func show_hit_feedback() -> void:
	if speed_panel == null:
		return
	speed_value_label.add_theme_color_override("font_color", UiTokens.SPEED_HIT)
	speed_state_label.text = "GOLPE"
	speed_state_label.add_theme_color_override("font_color", UiTokens.SPEED_HIT)
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_update_speed_state(int(speed_value_label.text))
	)


func set_game_mode(game_mode: int) -> void:
	_game_mode = GameModeDefinition.sanitize(game_mode)
	var is_time_trial := game_mode == GameModeDefinition.TIME_TRIAL
	position_label.visible = not is_time_trial
	item_chip.visible = _has_item and not is_time_trial
	delta_label.visible = is_time_trial


func set_density(density: StringName) -> void:
	_density = density
	var scale := 1.0
	match density:
		&"split": scale = 0.82
		&"touch": scale = 0.92
	scale = maxf(scale, 0.7)
	speed_panel.scale = Vector2.ONE * scale
	item_chip.scale = Vector2.ONE * scale
	shield_panel.scale = Vector2.ONE * scale
	drift_bar.scale = Vector2.ONE * scale
	if density == &"touch":
		speed_panel.offset_top = -190.0
		speed_panel.offset_bottom = -104.0
	else:
		speed_panel.offset_top = -116.0
		speed_panel.offset_bottom = -30.0


func set_player_label(player_number: int) -> void:
	_player_number = maxi(player_number, 0)


func update_ghost_delta(delta: float) -> void:
	if not is_finite(delta):
		delta_label.text = "FANTASMA  SIN REFERENCIA"
		delta_label.add_theme_color_override("font_color", UiTokens.ELECTRIC_YELLOW)
		return
	delta_label.text = "FANTASMA  %s%s" % ["-" if delta < 0.0 else "+", RaceHudStyle.format_time(absf(delta))]
	delta_label.add_theme_color_override("font_color", UiTokens.SUCCESS if delta < 0.0 else UiTokens.CORAL)


func show_lap_split(lap_number: int, lap_time: float, previous_best: float) -> void:
	_split_generation += 1
	var generation := _split_generation
	var comparison := "PRIMER REGISTRO"
	var color := UiTokens.ELECTRIC_YELLOW
	if previous_best > 0.0:
		var delta := lap_time - previous_best
		comparison = "VS. MEJOR VUELTA  %+.3f s" % delta
		color = UiTokens.SUCCESS if delta < 0.0 else UiTokens.CORAL
	split_label.text = "VUELTA %d · %s\n%s" % [
		lap_number,
		RaceHudStyle.format_time(lap_time),
		comparison,
	]
	split_label.add_theme_color_override("font_color", color)
	split_panel.visible = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if generation == _split_generation and is_instance_valid(split_panel):
			split_panel.visible = false
	)


func set_race_elements_visible(
	is_visible: bool,
	has_active_shield: bool
) -> void:
	for element in race_elements:
		element.visible = is_visible
	# Transient panels must never be resurrected merely by leaving the intro.
	if is_visible:
		split_panel.visible = false
		countdown_label.visible = not countdown_label.text.is_empty()
	if _game_mode == GameModeDefinition.TIME_TRIAL:
		position_label.visible = false
		item_chip.visible = false
		delta_label.visible = is_visible
	elif is_visible:
		item_chip.visible = _has_item
	if is_visible and not has_active_shield:
		shield_panel.visible = false


func _build_shield_status() -> void:
	shield_panel = PanelContainer.new()
	shield_panel.name = "ShieldStatus"
	shield_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	shield_panel.position = Vector2(242.0, -92.0)
	shield_panel.size = Vector2(182.0, 58.0)
	shield_panel.visible = false
	shield_panel.add_theme_stylebox_override(
		"panel",
		RaceHudStyle.style(UiTokens.surface_alpha(UiTokens.SHIELD_SURFACE, 3), 12)
	)
	add_child(shield_panel)
	race_elements.append(shield_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	shield_panel.add_child(row)

	shield_icon = TextureRect.new()
	shield_icon.custom_minimum_size = Vector2(30.0, 30.0)
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
		UiTokens.SHIELD_TEXT
	)
	details.add_child(shield_label)

	shield_bar = ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(112.0, 8.0)
	shield_bar.show_percentage = false
	shield_bar.add_theme_stylebox_override(
		"background",
		RaceHudStyle.style(UiTokens.surface_alpha(UiTokens.SHIELD_TRACK, 1), 6)
	)
	shield_bar.add_theme_stylebox_override(
		"fill",
		RaceHudStyle.style(UiTokens.SHIELD_FILL, 6)
	)
	details.add_child(shield_bar)


func _build_split_status() -> void:
	split_panel = PanelContainer.new()
	split_panel.name = "LapSplit"
	split_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	split_panel.position = Vector2(-155.0, 228.0)
	split_panel.size = Vector2(310.0, 80.0)
	split_panel.visible = false
	split_panel.add_theme_stylebox_override(
		"panel", RaceHudStyle.style(UiTokens.surface_alpha(UiTokens.SPLIT_SURFACE, 4), 14)
	)
	add_child(split_panel)
	race_elements.append(split_panel)
	split_label = Label.new()
	split_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	split_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	split_label.add_theme_font_size_override("font_size", 18)
	split_panel.add_child(split_label)
