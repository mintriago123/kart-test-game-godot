class_name CupCatalog
extends Resource
@export var cups: Array[CupDefinition] = []
var diagnostics := PackedStringArray()
func get_cup(id: StringName) -> CupDefinition:
	for cup in get_valid_cups():
		if cup.id == id: return cup
	return null
func get_valid_cups() -> Array[CupDefinition]:
	diagnostics.clear(); var result: Array[CupDefinition] = []; var ids := {}
	for cup in cups:
		if cup == null: diagnostics.append("Excluded missing cup definition."); continue
		var errors := cup.validate()
		if ids.has(cup.id): errors.append("Duplicate cup id: %s." % cup.id)
		if errors.is_empty(): result.append(cup); ids[cup.id] = true
		else:
			for error in errors: diagnostics.append("Excluded cup %s: %s" % [cup.id, error])
	result.sort_custom(func(a: CupDefinition, b: CupDefinition) -> bool: return a.sort_order < b.sort_order)
	return result
