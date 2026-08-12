class_name UnlockCatalog
extends Resource
@export var unlocks: Array[UnlockDefinition] = []
func get_unlock(id: StringName) -> UnlockDefinition:
	for value in unlocks:
		if value != null and value.id == id: return value
	return null
func get_variant(id: StringName) -> KartVariantDefinition:
	for value in unlocks:
		if value != null and value.kart_variant != null and value.kart_variant.id == id: return value.kart_variant
	return null
func validate() -> PackedStringArray:
	var errors := PackedStringArray(); var ids := {}; var variants := {}
	for value in unlocks:
		if value == null or not value.is_valid(): errors.append("Missing or invalid unlock.")
		elif ids.has(value.id) or variants.has(value.kart_variant.id): errors.append("Duplicate unlock or variant id: %s." % value.id)
		else: ids[value.id] = true; variants[value.kart_variant.id] = true
	return errors
