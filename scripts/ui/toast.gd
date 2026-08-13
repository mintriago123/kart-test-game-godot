class_name Toast
extends PanelContainer

func show_message(message: String, duration := 2.0) -> void:
	var label := get_node_or_null("Message") as Label
	if label == null: label = Label.new(); label.name = "Message"; add_child(label)
	label.text = message; show()
	var tween := create_tween(); tween.tween_interval(duration); tween.tween_callback(hide)
