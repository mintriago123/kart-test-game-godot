@tool
class_name TrackEditorPanel
extends VBoxContainer

var _button_factory: Callable


func configure_panel(title: String, button_factory: Callable) -> void:
	_button_factory = button_factory
	add_section_title(title)


func add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#f6c344"))
	add_child(label)


func add_help(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#c4ced1"))
	add_child(label)


func add_field_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#aab5b9"))
	add_child(label)


func make_button(
	text: String,
	callback: Callable,
	tooltip := "",
	is_primary := false
) -> Button:
	return _button_factory.call(text, callback, tooltip, is_primary) as Button
