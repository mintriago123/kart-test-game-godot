class_name RaceHudStyle
extends RefCounted


static func create_chip(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(122.0, 58.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff6d7"))
	label.add_theme_stylebox_override(
		"normal",
		style(Color(0.03, 0.16, 0.18, 0.86), 14)
	)
	return label


static func apply_button_style(button: Button, color: Color) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#102d32"))
	button.add_theme_color_override("font_focus_color", Color("#102d32"))
	button.add_theme_stylebox_override("normal", style(color, 16))
	button.add_theme_stylebox_override(
		"hover",
		style(color.lightened(0.1), 16)
	)
	button.add_theme_stylebox_override(
		"pressed",
		style(color.darkened(0.13), 16)
	)
	button.add_theme_stylebox_override(
		"focus",
		style(Color("#ffffff"), 16, 4)
	)
	button.add_theme_stylebox_override(
		"disabled",
		style(Color(0.3, 0.36, 0.37, 0.62), 16)
	)


static func style(
	color: Color,
	radius: int,
	border_width: int = 0
) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.corner_radius_top_left = radius
	style_box.corner_radius_top_right = radius
	style_box.corner_radius_bottom_left = radius
	style_box.corner_radius_bottom_right = radius
	if border_width > 0:
		style_box.border_width_left = border_width
		style_box.border_width_top = border_width
		style_box.border_width_right = border_width
		style_box.border_width_bottom = border_width
		style_box.border_color = Color.WHITE
	style_box.content_margin_left = 14.0
	style_box.content_margin_right = 14.0
	return style_box


static func format_time(time: float) -> String:
	var minutes := floori(time / 60.0)
	var seconds := floori(fmod(time, 60.0))
	var milliseconds := floori(fmod(time * 1000.0, 1000.0))
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
