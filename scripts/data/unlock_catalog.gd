@tool
class_name UnlockCatalog
extends Resource
@export var initial_variant: KartVariantDefinition
@export var variants: Array[KartVariantDefinition] = []
@export var unlocks: Array[UnlockDefinition] = []
func get_unlock(id: StringName) -> UnlockDefinition:
	for value in unlocks:
		if value != null and value.id == id: return value
	return null
func get_variant(id: StringName) -> KartVariantDefinition:
	for value in variants:
		if value != null and value.id == id: return value
	# Compatibility with catalogs authored before variants became explicit.
	for unlock in unlocks:
		if unlock != null and unlock.kart_variant != null and unlock.kart_variant.id == id: return unlock.kart_variant
	return null
func get_unlock_for_variant(id: StringName) -> UnlockDefinition:
	for value in unlocks:
		if value != null and value.kart_variant != null and value.kart_variant.id == id: return value
	return null
func is_initial_variant(id: StringName) -> bool:
	return initial_variant != null and initial_variant.id == id
func get_career_rewards() -> Array[UnlockDefinition]:
	var result: Array[UnlockDefinition] = []
	for value in unlocks:
		if value != null and value.requirement_type == UnlockDefinition.CAREER_POINTS: result.append(value)
	result.sort_custom(func(a: UnlockDefinition, b: UnlockDefinition) -> bool: return a.required_points < b.required_points)
	return result
func validate() -> PackedStringArray:
	var errors := PackedStringArray(); var ids := {}; var variant_ids := {}; var rewarded_variants := {}
	if initial_variant == null or not initial_variant.is_valid(): errors.append("Missing or invalid initial variant.")
	for variant in variants:
		if variant == null or not variant.is_valid(): errors.append("Missing or invalid variant.")
		elif variant_ids.has(variant.id): errors.append("Duplicate variant id: %s." % variant.id)
		else: variant_ids[variant.id] = true
	if initial_variant != null and not variant_ids.has(initial_variant.id): errors.append("Initial variant is not part of the variant catalog.")
	for value in unlocks:
		if value == null or not value.is_valid(): errors.append("Missing or invalid unlock.")
		elif ids.has(value.id) or rewarded_variants.has(value.kart_variant.id): errors.append("Duplicate unlock or rewarded variant id: %s." % value.id)
		elif not variant_ids.is_empty() and not variant_ids.has(value.kart_variant.id): errors.append("Unlock %s references a variant outside the catalog." % value.id)
		elif initial_variant != null and value.kart_variant.id == initial_variant.id: errors.append("Initial variant cannot require an unlock.")
		else: ids[value.id] = true; rewarded_variants[value.kart_variant.id] = true
	return errors
