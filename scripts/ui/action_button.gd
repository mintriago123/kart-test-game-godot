class_name ActionButton
extends Button

enum Kind { PRIMARY, SECONDARY, DANGER }
@export var kind := Kind.SECONDARY:
	set(value):
		kind = value
		_refresh()

var _press_tween: Tween

func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, UiTokens.TOUCH_TARGET)
	_refresh()
	button_down.connect(_press_in)
	button_up.connect(_press_out)

func _refresh() -> void:
	if not is_inside_tree(): return
	var color := UiTokens.ELECTRIC_YELLOW if kind == Kind.PRIMARY else UiTokens.WARM_WHITE
	if kind == Kind.DANGER: color = UiTokens.CORAL
	add_theme_font_size_override("font_size", UiTokens.FONT_LABEL)
	add_theme_color_override("font_color", UiTokens.GRAPHITE)
	add_theme_color_override("font_focus_color", UiTokens.GRAPHITE)
	add_theme_stylebox_override("normal", UiTokens.panel(color, UiTokens.RADIUS_MEDIUM))
	add_theme_stylebox_override("hover", UiTokens.panel(color.lightened(0.1), UiTokens.RADIUS_MEDIUM))
	add_theme_stylebox_override("pressed", UiTokens.panel(color.darkened(0.13), UiTokens.RADIUS_MEDIUM))
	# Every current kind (yellow, near-white, coral) is a light/warm fill, and
	# menu backgrounds are near-black (GRAPHITE/INK), so neither a yellow ring
	# nor a graphite one reads clearly in both places at once. CYAN contrasts
	# against the warm button fills AND the dark page background, and the
	# glow makes it visible even where the border happens to land on a
	# similarly-colored edge.
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.corner_radius_top_left = UiTokens.RADIUS_MEDIUM
	focus_style.corner_radius_top_right = UiTokens.RADIUS_MEDIUM
	focus_style.corner_radius_bottom_left = UiTokens.RADIUS_MEDIUM
	focus_style.corner_radius_bottom_right = UiTokens.RADIUS_MEDIUM
	focus_style.set_border_width_all(4)
	focus_style.border_color = UiTokens.CYAN
	focus_style.shadow_color = Color(UiTokens.CYAN, 0.55)
	focus_style.shadow_size = 6
	add_theme_stylebox_override("focus", focus_style)
	add_theme_stylebox_override("disabled", UiTokens.panel(UiTokens.BUTTON_DISABLED_BG, UiTokens.RADIUS_MEDIUM))

func _press_in() -> void:
	_kill_press_tween()
	_press_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", Vector2(0.97, 0.97), UiTokens.PRESS_DURATION * 0.5)

func _press_out() -> void:
	_kill_press_tween()
	_press_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", Vector2.ONE, UiTokens.PRESS_DURATION * 0.5)

func _kill_press_tween() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
