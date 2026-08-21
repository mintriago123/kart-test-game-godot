class_name ActionButton
extends Button

enum Kind { PRIMARY, SECONDARY, DANGER }
@export var kind := Kind.SECONDARY:
	set(value):
		kind = value
		_refresh()

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
	add_theme_stylebox_override("focus", UiTokens.panel(Color.TRANSPARENT, UiTokens.RADIUS_MEDIUM, UiTokens.ELECTRIC_YELLOW))
	add_theme_stylebox_override("disabled", UiTokens.panel(UiTokens.BUTTON_DISABLED_BG, UiTokens.RADIUS_MEDIUM))

func _press_in() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.06)

func _press_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.06)
