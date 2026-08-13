class_name RewardReveal
extends PanelContainer

signal finished

func reveal(title: String, reduced_motion := false) -> void:
	var label := get_node_or_null("Reward") as Label
	if label == null: label = Label.new(); label.name = "Reward"; add_child(label)
	label.text = title; show(); modulate.a = 0.0
	var tween := create_tween(); tween.tween_property(self, "modulate:a", 1.0, 0.01 if reduced_motion else 0.35); tween.tween_callback(func(): finished.emit())
