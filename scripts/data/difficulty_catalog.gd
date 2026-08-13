@tool
class_name DifficultyCatalog
extends Resource
@export var difficulties: Array[DifficultyDefinition] = []
func get_difficulty(id: StringName) -> DifficultyDefinition:
	for value in difficulties:
		if value != null and value.id == id: return value
	return null
func validate() -> PackedStringArray:
	var errors := PackedStringArray(); var ids := {}
	for value in difficulties:
		if value == null or not value.is_valid(): errors.append("Missing or invalid difficulty.")
		elif ids.has(value.id): errors.append("Duplicate difficulty id: %s." % value.id)
		else: ids[value.id] = true
	return errors
