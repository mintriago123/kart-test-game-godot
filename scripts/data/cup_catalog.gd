@tool
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
		if errors.is_empty(): result.append(cup); ids[cup.id] = cup
		else:
			for error in errors: diagnostics.append("Excluded cup %s: %s" % [cup.id, error])
	for cup in result.duplicate():
		if cup.prerequisite_cup_id.is_empty(): continue
		var prerequisite := ids.get(cup.prerequisite_cup_id) as CupDefinition
		if prerequisite == null:
			diagnostics.append("Excluded cup %s: prerequisite cup %s does not exist." % [cup.id, cup.prerequisite_cup_id]); result.erase(cup); continue
		if not cup.prerequisite_difficulty_id.is_empty():
			var matches := prerequisite.difficulties.any(func(value: DifficultyDefinition): return value != null and value.id == cup.prerequisite_difficulty_id)
			if not matches: diagnostics.append("Excluded cup %s: prerequisite difficulty %s is not enabled by %s." % [cup.id, cup.prerequisite_difficulty_id, prerequisite.id]); result.erase(cup); continue
		var current := prerequisite
		var visited := {}
		while current != null and not current.prerequisite_cup_id.is_empty():
			if current.id == cup.id or visited.has(current.id):
				diagnostics.append("Excluded cup %s: cup prerequisites contain a cycle." % cup.id); result.erase(cup); break
			visited[current.id] = true
			current = ids.get(current.prerequisite_cup_id) as CupDefinition
	result.sort_custom(func(a: CupDefinition, b: CupDefinition) -> bool: return a.sort_order < b.sort_order)
	return result
