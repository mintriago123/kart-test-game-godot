class_name SettingsScreen
extends Control

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

signal graphics_profile_changed(profile: String)
signal vibration_changed(enabled: bool)
signal volume_changed(value: float)
signal music_volume_changed(value: float)
signal effects_volume_changed(value: float)
signal camera_motion_changed(mode: String)
signal speed_lines_changed(enabled: bool)
signal threat_indicators_changed(enabled: bool)
signal vibration_intensity_changed(value: float)
signal reduced_motion_changed(enabled: bool)
signal restore_defaults_requested
signal back_requested

var _controls: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func apply_snapshot(settings: GameSettings) -> void:
	if settings == null or _controls.is_empty():
		return
	(_controls.profile as OptionButton).select(["low", "medium", "high", "ultra"].find(settings.graphics_profile))
	(_controls.vibration as CheckButton).set_pressed_no_signal(settings.vibration_enabled)
	(_controls.master as HSlider).set_value_no_signal(settings.master_volume)
	(_controls.music as HSlider).set_value_no_signal(settings.music_volume)
	(_controls.effects as HSlider).set_value_no_signal(settings.effects_volume)
	(_controls.camera as OptionButton).select(["reduced", "full", "off"].find(settings.camera_motion))
	(_controls.speed_lines as CheckButton).set_pressed_no_signal(settings.speed_lines_enabled)
	(_controls.threats as CheckButton).set_pressed_no_signal(settings.threat_indicators_enabled)
	(_controls.intensity as HSlider).set_value_no_signal(settings.vibration_intensity)
	(_controls.reduced_motion as CheckButton).set_pressed_no_signal(settings.ui_reduced_motion)


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = UiTokens.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-310, -320)
	card.size = Vector2(620, 640)
	card.theme = UiTokens.create_theme()
	scrim.add_child(card)
	resized.connect(func() -> void:
		card.size = Vector2(minf(620.0, size.x - 32.0), minf(640.0, size.y - 32.0))
		card.position = -card.size * 0.5
	)
	var scroll := ScrollContainer.new()
	card.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 560
	scroll.add_child(content)
	var title := Label.new()
	title.text = "AJUSTES"
	title.add_theme_font_size_override("font_size", 38)
	content.add_child(title)
	_controls.profile = _option_row(content, "CALIDAD", ["BAJA", "MEDIA", "ALTA", "ULTRA"], func(index: int) -> void: graphics_profile_changed.emit(["low", "medium", "high", "ultra"][index]))
	_controls.camera = _option_row(content, "MOVIMIENTO DE CÁMARA", ["REDUCIDO", "COMPLETO", "DESACTIVADO"], func(index: int) -> void: camera_motion_changed.emit(["reduced", "full", "off"][index]))
	_controls.master = _slider_row(content, "VOLUMEN GENERAL", func(value: float) -> void: volume_changed.emit(value))
	_controls.music = _slider_row(content, "MÚSICA", func(value: float) -> void: music_volume_changed.emit(value))
	_controls.effects = _slider_row(content, "EFECTOS", func(value: float) -> void: effects_volume_changed.emit(value))
	_controls.intensity = _slider_row(content, "INTENSIDAD DE VIBRACIÓN", func(value: float) -> void: vibration_intensity_changed.emit(value))
	_controls.vibration = _toggle_row(content, "VIBRACIÓN", func(value: bool) -> void: vibration_changed.emit(value))
	_controls.speed_lines = _toggle_row(content, "LÍNEAS DE VELOCIDAD", func(value: bool) -> void: speed_lines_changed.emit(value))
	_controls.threats = _toggle_row(content, "AVISOS DE AMENAZA", func(value: bool) -> void: threat_indicators_changed.emit(value))
	_controls.reduced_motion = _toggle_row(content, "REDUCIR MOVIMIENTO DE UI", func(value: bool) -> void: reduced_motion_changed.emit(value))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(actions)
	var defaults := Button.new()
	defaults.text = "RESTABLECER"
	defaults.custom_minimum_size = Vector2(150, UiTokens.TOUCH_TARGET)
	defaults.pressed.connect(func() -> void: restore_defaults_requested.emit())
	actions.add_child(defaults)
	var back := Button.new()
	back.text = "VOLVER"
	back.custom_minimum_size = Vector2(130, UiTokens.TOUCH_TARGET)
	back.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(back)


func _row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 54
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _toggle_row(parent: VBoxContainer, text: String, callback: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.custom_minimum_size = Vector2(96, UiTokens.TOUCH_TARGET)
	toggle.toggled.connect(callback)
	_row(parent, text).add_child(toggle)
	return toggle


func _slider_row(parent: VBoxContainer, text: String, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(240, UiTokens.TOUCH_TARGET)
	slider.value_changed.connect(callback)
	_row(parent, text).add_child(slider)
	return slider


func _option_row(parent: VBoxContainer, text: String, items: Array[String], callback: Callable) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(240, UiTokens.TOUCH_TARGET)
	for item in items:
		option.add_item(item)
	option.item_selected.connect(callback)
	_row(parent, text).add_child(option)
	return option
