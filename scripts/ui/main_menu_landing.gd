class_name MainMenuLanding
extends MenuShell

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")

signal play_requested
signal continue_requested
signal garage_requested
signal profile_requested
signal settings_requested

@export var has_active_cup := false

var main_actions: MenuList
var play_button: ActionButton
var continue_button: ActionButton
var showroom: VehicleViewport
var compact := false

var _content: VBoxContainer
var _wordmark: Control
var _context_panel: PanelContainer
var _context_badge: Label
var _context_title: Label
var _context_detail: Label
var _sun: ColorRect
var _stripe: ColorRect
var _route_visible := true


func set_context(title: String, detail: String, badge: String = "CONFIGURACIÓN ACTUAL") -> void:
	if _context_title == null:
		return
	_context_badge.text = badge
	_context_title.text = title
	_context_detail.text = detail


func set_route_visible(value: bool) -> void:
	_route_visible = value
	if showroom != null:
		showroom.visible = value and not compact


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := ColorRect.new()
	background.name = "LandingBackground"
	background.color = UiTokens.GRAPHITE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_sun = ColorRect.new()
	_sun.name = "ShowroomLight"
	_sun.color = UiTokens.ELECTRIC_YELLOW
	_sun.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sun)

	_stripe = ColorRect.new()
	_stripe.name = "ShowroomStripe"
	_stripe.color = UiTokens.CORAL
	_stripe.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stripe)

	_content = VBoxContainer.new()
	_content.name = "MainContent"
	_content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_content.custom_minimum_size.x = 610.0
	_content.add_theme_constant_override("separation", UiTokens.SPACE_3)
	add_child(_content)

	var eyebrow := Label.new()
	eyebrow.text = "CAMPEONATO ARCADE"
	eyebrow.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	eyebrow.add_theme_font_size_override("font_size", UiTokens.FONT_LABEL)
	eyebrow.add_theme_color_override("font_color", UiTokens.CYAN)
	_content.add_child(eyebrow)

	_wordmark = UiTokens.wordmark(510.0, 104.0, 72)
	_content.add_child(_wordmark)

	_context_panel = PanelContainer.new()
	_context_panel.name = "RaceContext"
	_context_panel.custom_minimum_size = Vector2(460.0, 74.0)
	_context_panel.add_theme_stylebox_override(
		"panel",
		UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_MEDIUM, Color(0.38, 0.85, 0.75, 0.26))
	)
	_content.add_child(_context_panel)
	var context := VBoxContainer.new()
	context.add_theme_constant_override("separation", UiTokens.SPACE_1)
	_context_panel.add_child(context)
	_context_badge = Label.new()
	_context_badge.text = "CONFIGURACIÓN ACTUAL"
	_context_badge.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	_context_badge.add_theme_font_size_override("font_size", UiTokens.FONT_CAPTION)
	_context_badge.add_theme_color_override("font_color", UiTokens.CYAN)
	context.add_child(_context_badge)
	_context_title = Label.new()
	_context_title.text = "SEDAN · COSTA TURBO"
	_context_title.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	_context_title.add_theme_font_size_override("font_size", UiTokens.FONT_LABEL)
	_context_title.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	context.add_child(_context_title)
	_context_detail = Label.new()
	_context_detail.text = "CARRERA · 150 CC"
	_context_detail.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
	_context_detail.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	context.add_child(_context_detail)

	main_actions = MenuList.new()
	main_actions.name = "MainActions"
	main_actions.custom_minimum_size.x = 360.0
	main_actions.add_theme_constant_override("separation", UiTokens.SPACE_3)
	_content.add_child(main_actions)
	if has_active_cup:
		continue_button = main_actions.add_action("CONTINUAR COPA", continue_requested.emit, true)
		continue_button.name = "ContinueCup"
		play_button = main_actions.add_action("JUGAR", play_requested.emit, false)
	else:
		play_button = main_actions.add_action("JUGAR", play_requested.emit, true)
	play_button.name = "Play"
	var garage := main_actions.add_action("GARAJE", garage_requested.emit, false)
	garage.name = "Garage"
	var profile := main_actions.add_action("PERFIL", profile_requested.emit, false)
	profile.name = "Profile"
	var settings := main_actions.add_action("AJUSTES", settings_requested.emit, false)
	settings.name = "Settings"
	_style_secondary_action(garage)
	_style_secondary_action(profile)
	_style_secondary_action(settings)

	showroom = VehicleViewport.new()
	showroom.name = "MainShowroom"
	showroom.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	showroom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(showroom)


func _style_secondary_action(button: ActionButton) -> void:
	button.add_theme_color_override("font_color", UiTokens.TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", UiTokens.TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", UiTokens.GRAPHITE)
	button.add_theme_color_override("font_focus_color", UiTokens.TEXT_PRIMARY)
	button.add_theme_stylebox_override("normal", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM))
	button.add_theme_stylebox_override("hover", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM, UiTokens.CYAN))
	button.add_theme_stylebox_override("pressed", UiTokens.panel(UiTokens.INK, UiTokens.RADIUS_MEDIUM))
	button.add_theme_stylebox_override("focus", UiTokens.panel(UiTokens.INK_RAISED, UiTokens.RADIUS_MEDIUM, UiTokens.ELECTRIC_YELLOW))


func _update_layout() -> void:
	var layout_size := size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	compact = layout_size.x < UiTokens.BREAKPOINT_TWO_PANEL_WIDTH or layout_size.y < UiTokens.BREAKPOINT_TWO_PANEL_HEIGHT
	var button_height := UiTokens.TOUCH_TARGET if compact else UiTokens.BUTTON_HEIGHT
	main_actions.add_theme_constant_override("separation", UiTokens.SPACE_2 if compact else UiTokens.SPACE_3)
	for button in main_actions.get_children():
		(button as Control).custom_minimum_size.y = button_height
	_wordmark.custom_minimum_size.y = 84.0 if compact else 104.0
	_context_panel.custom_minimum_size.y = 64.0 if compact else 74.0
	var required_height := maxf(1.0, _content.get_combined_minimum_size().y)
	_content.size = Vector2(610.0, required_height)
	if compact:
		var scale_factor := minf(0.84, minf((layout_size.x - 32.0) / 610.0, (layout_size.y - 24.0) / required_height))
		scale_factor = maxf(0.42, scale_factor)
		_content.scale = Vector2.ONE * scale_factor
		_content.position = Vector2(16.0, maxf(12.0, (layout_size.y - required_height * scale_factor) * 0.5))
		_sun.offset_left = -112.0
		_sun.offset_right = 0.0
		_stripe.offset_left = -128.0
		_stripe.offset_right = -111.0
		showroom.visible = false
	else:
		_content.scale = Vector2.ONE
		_content.position = Vector2(72.0, maxf(32.0, (layout_size.y - required_height) * 0.5))
		_sun.offset_left = -330.0
		_sun.offset_right = 0.0
		_sun.offset_top = 0.0
		_sun.offset_bottom = 0.0
		_stripe.offset_left = -365.0
		_stripe.offset_right = -329.0
		_stripe.offset_top = 0.0
		_stripe.offset_bottom = 0.0
		showroom.visible = _route_visible
		showroom.offset_left = -540.0
		showroom.offset_right = -32.0
		showroom.offset_top = 74.0
		showroom.offset_bottom = -74.0
