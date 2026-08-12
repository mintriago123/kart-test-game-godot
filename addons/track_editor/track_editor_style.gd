class_name TrackEditorStyle
extends RefCounted

const CANVAS_BACKGROUND := Color("#151b1f")
const PANEL_BACKGROUND := Color("#20282d")
const BUTTON_BACKGROUND := Color("#2a343a")
const BUTTON_HOVER_BACKGROUND := Color("#364249")
const BUTTON_PRESSED_BACKGROUND := Color("#1c2428")
const DISABLED_BACKGROUND := Color("#242c30")
const BORDER := Color("#536269")
const TEXT_PRIMARY := Color("#f4f1e8")
const TEXT_SECONDARY := Color("#cbd4d7")
const TEXT_MUTED := Color("#b8c3c7")
const TEXT_DISABLED := Color("#aab5b9")
const FOCUS := Color("#f6c344")
const SUCCESS := Color("#52d6c8")
const ERROR := Color("#ffd3c8")
const BODY_FONT_SIZE := 16
const SECTION_FONT_SIZE := 18
const TITLE_FONT_SIZE := 20


static func create_theme() -> Theme:
	var workshop_theme := Theme.new()
	workshop_theme.default_font_size = BODY_FONT_SIZE
	for type_name in ["Label", "Button", "LineEdit", "TextEdit", "OptionButton"]:
		workshop_theme.set_font_size("font_size", type_name, BODY_FONT_SIZE)
		workshop_theme.set_color("font_color", type_name, TEXT_PRIMARY)
	workshop_theme.set_color("font_hover_color", "Button", Color.WHITE)
	workshop_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	workshop_theme.set_color("font_focus_color", "Button", Color.WHITE)
	workshop_theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	workshop_theme.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	workshop_theme.set_color("font_placeholder_color", "TextEdit", TEXT_MUTED)
	workshop_theme.set_stylebox(
		"normal", "PanelContainer", style_box(PANEL_BACKGROUND, BORDER)
	)
	workshop_theme.set_stylebox(
		"normal", "Button", style_box(BUTTON_BACKGROUND, BORDER)
	)
	workshop_theme.set_stylebox(
		"hover", "Button", style_box(BUTTON_HOVER_BACKGROUND, FOCUS, 2)
	)
	workshop_theme.set_stylebox(
		"pressed", "Button", style_box(BUTTON_PRESSED_BACKGROUND, FOCUS, 2)
	)
	workshop_theme.set_stylebox(
		"focus", "Button", style_box(BUTTON_BACKGROUND, FOCUS, 3)
	)
	workshop_theme.set_stylebox(
		"disabled", "Button", style_box(DISABLED_BACKGROUND, BORDER)
	)
	for type_name in ["LineEdit", "TextEdit"]:
		workshop_theme.set_stylebox(
			"normal", type_name, style_box(CANVAS_BACKGROUND, BORDER)
		)
		workshop_theme.set_stylebox(
			"focus", type_name, style_box(CANVAS_BACKGROUND, FOCUS, 2)
		)
	workshop_theme.set_constant("separation", "VBoxContainer", 8)
	workshop_theme.set_constant("separation", "HBoxContainer", 8)
	return workshop_theme


static func style_box(
	background: Color,
	border: Color,
	border_width := 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


static func background_for_type(type_name: String) -> Color:
	if type_name in ["LineEdit", "TextEdit"]:
		return CANVAS_BACKGROUND
	if type_name in ["Button", "OptionButton"]:
		return BUTTON_BACKGROUND
	return PANEL_BACKGROUND


static func contrast_ratio(foreground: Color, background: Color) -> float:
	var foreground_luminance := _relative_luminance(foreground)
	var background_luminance := _relative_luminance(background)
	return (
		(maxf(foreground_luminance, background_luminance) + 0.05)
		/ (minf(foreground_luminance, background_luminance) + 0.05)
	)


static func _relative_luminance(color: Color) -> float:
	return (
		_linear_channel(color.r) * 0.2126
		+ _linear_channel(color.g) * 0.7152
		+ _linear_channel(color.b) * 0.0722
	)


static func _linear_channel(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
