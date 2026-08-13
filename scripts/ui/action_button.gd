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
	add_theme_stylebox_override("normal", UiTokens.panel(color))

func _press_in() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.97, 0.97), 0.06)

func _press_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.06)
