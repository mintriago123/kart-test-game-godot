class_name UiTokens
extends RefCounted

const GRAPHITE := Color("#12181F")
const INK := Color("#172A3A")
const INK_RAISED := Color("#203B4D")
const WARM_WHITE := Color("#FFF7DF")
const MUTED := Color("#A9BEC7")
const ELECTRIC_YELLOW := Color("#FFD928")
const CORAL := Color("#FF647C")
const CYAN := Color("#39D9F5")
const SUCCESS := Color("#66E39A")
const SCRIM := Color(0.025, 0.045, 0.065, 0.88)

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_6 := 24
const SPACE_8 := 32
const RADIUS_SMALL := 8
const RADIUS_MEDIUM := 14
const RADIUS_LARGE := 22
const TOUCH_TARGET := 48
const BODY_FONT = preload("res://assets/fonts/Inter.ttf")
const DISPLAY_FONT = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")


static func panel(color := INK, radius := RADIUS_MEDIUM, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = SPACE_4
	box.content_margin_right = SPACE_4
	box.content_margin_top = SPACE_3
	box.content_margin_bottom = SPACE_3
	if border_color.a > 0.0:
		box.set_border_width_all(2)
		box.border_color = border_color
	return box


static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = BODY_FONT
	result.default_font_size = 18
	result.set_font("font", "Button", DISPLAY_FONT)
	result.set_font("font", "HeaderLarge", DISPLAY_FONT)
	result.set_font("font", "HeaderMedium", DISPLAY_FONT)
	result.set_color("font_color", "Label", WARM_WHITE)
	result.set_color("font_color", "Button", GRAPHITE)
	result.set_color("font_hover_color", "Button", GRAPHITE)
	result.set_color("font_pressed_color", "Button", GRAPHITE)
	result.set_color("font_focus_color", "Button", GRAPHITE)
	result.set_constant("separation", "VBoxContainer", SPACE_3)
	result.set_constant("separation", "HBoxContainer", SPACE_3)
	result.set_stylebox("normal", "Button", panel(WARM_WHITE, RADIUS_MEDIUM))
	result.set_stylebox("hover", "Button", panel(Color("#FFFFFF"), RADIUS_MEDIUM, CYAN))
	result.set_stylebox("pressed", "Button", panel(ELECTRIC_YELLOW.darkened(0.12), RADIUS_MEDIUM))
	result.set_stylebox("focus", "Button", panel(Color.TRANSPARENT, RADIUS_MEDIUM, ELECTRIC_YELLOW))
	result.set_stylebox("disabled", "Button", panel(Color("#52616A"), RADIUS_MEDIUM))
	result.set_stylebox("panel", "PanelContainer", panel(INK, RADIUS_LARGE))
	return result
