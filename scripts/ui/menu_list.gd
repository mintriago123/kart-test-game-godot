class_name MenuList
extends VBoxContainer

func add_action(label: String, callback: Callable, primary := false) -> ActionButton:
	var button := ActionButton.new()
	button.text = label
	button.kind = ActionButton.Kind.PRIMARY if primary else ActionButton.Kind.SECONDARY
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	add_child(button)
	return button
