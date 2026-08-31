class_name EventCard
extends Button

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

var event_id: StringName
var subtitle := ""
var _title_label: Label
var _description_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(280, 180)
	text = ""
	focus_mode = Control.FOCUS_ALL
	# configure() may have built and populated the layout before this node was
	# added to the tree. Rebuilding here would replace its labels with blanks.
	if _title_label == null or _description_label == null:
		_build_layout()
	_apply_states()
	button_down.connect(_press_in)
	button_up.connect(_press_out)


func configure(id: StringName, title: String, description: String) -> void:
	event_id = id
	subtitle = description
	tooltip_text = description
	if _title_label == null:
		_build_layout()
	_title_label.text = title.to_upper()
	_description_label.text = description
	_apply_states()


func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = UiTokens.SPACE_4
	content.offset_right = -UiTokens.SPACE_4
	content.offset_top = UiTokens.SPACE_3
	content.offset_bottom = -UiTokens.SPACE_3
	content.add_theme_constant_override("separation", UiTokens.SPACE_2)
	add_child(content)
	_title_label = Label.new()
	_title_label.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	_title_label.add_theme_font_size_override("font_size", UiTokens.FONT_H3)
	_title_label.add_theme_color_override("font_color", UiTokens.WARM_WHITE)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_title_label)
	_description_label = Label.new()
	_description_label.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
	_description_label.add_theme_color_override("font_color", UiTokens.MUTED)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_description_label)


func _apply_states() -> void:
	add_theme_stylebox_override("normal", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM))
	add_theme_stylebox_override("hover", UiTokens.panel(UiTokens.INK_RAISED.lightened(0.06), UiTokens.RADIUS_MEDIUM, UiTokens.CYAN))
	add_theme_stylebox_override("pressed", UiTokens.panel(UiTokens.INK_RAISED.darkened(0.08), UiTokens.RADIUS_MEDIUM))
	add_theme_stylebox_override("focus", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM, UiTokens.ELECTRIC_YELLOW))
	add_theme_stylebox_override("disabled", UiTokens.panel(UiTokens.BUTTON_DISABLED_BG, UiTokens.RADIUS_MEDIUM))


func _press_in() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.06)


func _press_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.06)
