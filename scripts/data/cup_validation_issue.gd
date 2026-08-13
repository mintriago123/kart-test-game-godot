class_name CupValidationIssue
extends RefCounted

var field_path: StringName
var message: String


func _init(value_path: StringName = &"review", value_message := "") -> void:
	field_path = value_path
	message = value_message
