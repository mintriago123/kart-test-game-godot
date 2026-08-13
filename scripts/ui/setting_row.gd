class_name SettingRow
extends HBoxContainer

var title_label: Label
var description_label: Label
var value_container: Control

func configure(title: String, description: String, control: Control) -> void:
	custom_minimum_size.y = maxf(UiTokens.TOUCH_TARGET, 64)
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL; add_child(copy)
	title_label = Label.new(); title_label.text = title; copy.add_child(title_label)
	description_label = Label.new(); description_label.text = description; description_label.add_theme_color_override("font_color", UiTokens.MUTED); copy.add_child(description_label)
	value_container = control; add_child(control)
