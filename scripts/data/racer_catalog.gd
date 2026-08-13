@tool
class_name RacerCatalog
extends Resource
@export var racers: Array[RacerDefinition] = []
func get_racer(id: StringName) -> RacerDefinition:
	for value in racers:
		if value != null and value.id == id: return value
	return null
func validate() -> PackedStringArray:
	return _validate_entries(racers, "racer")
func _validate_entries(entries: Array, kind: String) -> PackedStringArray:
	var errors := PackedStringArray(); var ids := {}
	for entry in entries:
		if entry == null: errors.append("Missing %s definition." % kind)
		elif entry.id.is_empty() or ids.has(entry.id): errors.append("Invalid or duplicate %s id: %s." % [kind, entry.id])
		else: ids[entry.id] = true; errors.append_array(entry.validate())
	return errors
