@tool
class_name TrackEditorPanel
extends VBoxContainer

const EditorStyle := preload("res://addons/track_editor/track_editor_style.gd")

var _button_factory: Callable


func configure_panel(title: String, button_factory: Callable) -> void:
	_button_factory = button_factory
	add_section_title(title)


func add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", EditorStyle.SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", EditorStyle.FOCUS)
	add_child(label)


func add_help(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", EditorStyle.TEXT_SECONDARY)
	add_child(label)


func add_field_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
	add_child(label)


func make_button(
	text: String,
	callback: Callable,
	tooltip := "",
	is_primary := false
) -> Button:
	return _button_factory.call(text, callback, tooltip, is_primary) as Button
