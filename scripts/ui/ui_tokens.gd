class_name UiTokens
extends RefCounted

const GRAPHITE := Color("#0B1117")
const INK := Color("#151E27")
const INK_RAISED := Color("#202C36")
const WARM_WHITE := Color("#F4F0E6")
const MUTED := Color("#B5C0C4")
const TEXT_PRIMARY := WARM_WHITE
const TEXT_SECONDARY := Color("#D8D9D1")
const TEXT_TERTIARY := MUTED
const TEXT_DISABLED := Color("#718087")
const ELECTRIC_YELLOW := Color("#F5C542")
const CORAL := Color("#E86A5B")
const CYAN := Color("#61D8C0")
const SUCCESS := Color("#75C995")
const WARNING := Color("#E9A84A")
const DANGER := CORAL
const SPEED_NORMAL := WARM_WHITE
const SPEED_MAX := ELECTRIC_YELLOW
const SPEED_TURBO := CYAN
const SPEED_HIT := CORAL
const SPEED_DANGER := WARNING
const HUD_GRAPHITE := Color(0.043, 0.067, 0.09, 0.94)
const HUD_GRAPHITE_SOFT := Color(0.043, 0.067, 0.09, 0.78)
const SCRIM := Color(0.02, 0.035, 0.05, 0.9)
const SHIELD_SURFACE := Color(0.03, 0.16, 0.18)
const SHIELD_FILL := Color("#77d9df")
const SHIELD_TEXT := Color("#e9fffa")
const SHIELD_TRACK := Color(0.01, 0.08, 0.1)
const SPLIT_SURFACE := Color(0.02, 0.12, 0.14)
const BUTTON_DISABLED_BG := Color(0.23, 0.28, 0.31, 0.62)

const SURFACE_ALPHA_1 := 0.80
const SURFACE_ALPHA_2 := 0.88
const SURFACE_ALPHA_3 := 0.92
const SURFACE_ALPHA_4 := 0.94

const FONT_CAPTION := 12
const FONT_BODY := 15
const FONT_LABEL := 18
const FONT_H3 := 22
const FONT_H2 := 28
const FONT_H1 := 36
const FONT_DISPLAY := 48
const FONT_HERO := 72
# Responsive screen-title pair: shrink to FONT_TITLE_COMPACT below the
# screen's own compact breakpoint, FONT_TITLE_WIDE otherwise. Introduced
# from the pattern local/lan multiplayer lobby already used.
const FONT_TITLE_COMPACT := 32
const FONT_TITLE_WIDE := 42

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

# Shared responsive breakpoints (viewport size, px). Named by the layout
# tier they represent so screens with equivalent needs share one constant
# instead of a fresh magic number; a screen whose layout genuinely needs
# more or less room before collapsing uses a different tier on purpose.
const BREAKPOINT_FOCUSED_WIDTH := 760    # single carousel/list (cup select)
const BREAKPOINT_SHELL_WIDTH := 800      # MenuShell default (landing, most routed screens)
const BREAKPOINT_SHELL_HEIGHT := 500
const BREAKPOINT_TWO_PANEL_WIDTH := 900  # two side-by-side regions (mode select, vehicle gallery)
const BREAKPOINT_TWO_PANEL_HEIGHT := 560
const BREAKPOINT_ROSTER_WIDTH := 980     # local multiplayer roster + settings
const BREAKPOINT_ROSTER_HEIGHT := 620
const BREAKPOINT_COLUMNS_WIDTH := 1050   # preparation's 3-column grid
const BREAKPOINT_COLUMNS_HEIGHT := 600
const BREAKPOINT_NETWORK_WIDTH := 1120   # LAN lobby (host/join + room list + slots)
const BREAKPOINT_NETWORK_HEIGHT := 680
const BREAKPOINT_SHOWROOM_WIDTH := 1100  # garage overlay: hide the 3D showroom column
const BREAKPOINT_WIDE_WIDTH := 1600      # extra breathing room (MenuShell wide tier)
const BUTTON_HEIGHT := 56
const BUTTON_HEIGHT_LARGE := 64
const PRESS_DURATION := 0.12
const ENTER_DURATION := 0.18
const EXIT_DURATION := 0.12
const BODY_FONT = preload("res://assets/fonts/Inter.ttf")
const DISPLAY_FONT = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")


static func surface_alpha(color: Color, level: int) -> Color:
	var alpha := SURFACE_ALPHA_2
	match level:
		1: alpha = SURFACE_ALPHA_1
		2: alpha = SURFACE_ALPHA_2
		3: alpha = SURFACE_ALPHA_3
		4: alpha = SURFACE_ALPHA_4
	return Color(color.r, color.g, color.b, alpha)


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


static func room_row() -> StyleBoxFlat:
	return panel(INK, RADIUS_SMALL, Color(1, 1, 1, 0.07))


static func participant_row() -> StyleBoxFlat:
	return panel(GRAPHITE, RADIUS_SMALL, Color(1, 1, 1, 0.06))


static func status_badge(color: Color) -> StyleBoxFlat:
	var box := panel(color.darkened(0.58), RADIUS_SMALL)
	box.content_margin_left = SPACE_2
	box.content_margin_right = SPACE_2
	box.content_margin_top = SPACE_1
	box.content_margin_bottom = SPACE_1
	return box


static func kicker(color := CYAN) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = DISPLAY_FONT
	settings.font_size = FONT_CAPTION
	settings.font_color = color
	return settings


static func wordmark(width: float, height: float, font_size := FONT_HERO) -> Control:
	# Keep the title and landing mark on the same glyph-based implementation.
	var result := HBoxContainer.new()
	result.custom_minimum_size = Vector2(width, height)
	result.alignment = BoxContainer.ALIGNMENT_CENTER
	result.add_theme_constant_override("separation", 0)
	for part in [["MICH", ELECTRIC_YELLOW], ["I", CORAL], ["KART", WARM_WHITE], [" XD", ELECTRIC_YELLOW]]:
		var label := Label.new()
		label.text = part[0]
		label.add_theme_font_override("font", DISPLAY_FONT)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", part[1])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		result.add_child(label)
	return result


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
	result.set_stylebox("hover", "Button", panel(WARM_WHITE, RADIUS_MEDIUM, CYAN))
	result.set_stylebox("pressed", "Button", panel(ELECTRIC_YELLOW.darkened(0.12), RADIUS_MEDIUM))
	result.set_stylebox("focus", "Button", panel(Color.TRANSPARENT, RADIUS_MEDIUM, ELECTRIC_YELLOW))
	result.set_stylebox("disabled", "Button", panel(Color("#3A464E"), RADIUS_MEDIUM))
	result.set_stylebox("panel", "PanelContainer", panel(INK, RADIUS_LARGE))
	return result
