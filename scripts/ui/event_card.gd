class_name EventCard
extends Button

var event_id: StringName
var subtitle := ""

func configure(id: StringName, title: String, description: String) -> void:
	event_id = id
	text = title + ("\n" + description if not description.is_empty() else "")
	custom_minimum_size = Vector2(280, 180)
	tooltip_text = description
