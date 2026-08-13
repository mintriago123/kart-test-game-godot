class_name ActionPromptView
extends HBoxContainer

@export var action: StringName = &"ui_accept"
@export var caption := "ACEPTAR"
var prompt: ActionPrompt
var label: Label

func _ready() -> void:
	custom_minimum_size.y = UiTokens.TOUCH_TARGET
	prompt = ActionPrompt.new()
	prompt.custom_minimum_size = Vector2(38, 38)
	add_child(prompt)
	label = Label.new()
	add_child(label)
	_refresh()

func set_action(value: StringName) -> void:
	action = value
	if prompt != null:
		_refresh()

func _refresh() -> void:
	prompt.action = str(action)
	label.text = caption

func refresh() -> void:
	if prompt != null:
		prompt.refresh()
