class_name ConfirmationModal
extends PanelContainer

signal confirmed
signal cancelled
var confirm_button: ActionButton

func configure(title: String, message: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var content := VBoxContainer.new(); add_child(content)
	var heading := Label.new(); heading.text = title; content.add_child(heading)
	var body := Label.new(); body.text = message; body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(body)
	confirm_button = ActionButton.new(); confirm_button.text = "CONFIRMAR"; confirm_button.kind = ActionButton.Kind.PRIMARY; confirm_button.pressed.connect(func(): confirmed.emit()); content.add_child(confirm_button)
	var cancel := ActionButton.new(); cancel.text = "CANCELAR"; cancel.pressed.connect(func(): cancelled.emit()); content.add_child(cancel)
	visibility_changed.connect(func(): if visible: confirm_button.grab_focus.call_deferred())
