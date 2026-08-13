@tool
class_name UnlockDefinition
extends Resource

enum Medal { NONE, BRONZE, SILVER, GOLD }
enum RequirementType { CUP_MEDAL, CAREER_POINTS }
const BRONZE := Medal.BRONZE
const SILVER := Medal.SILVER
const GOLD := Medal.GOLD
const CUP_MEDAL := RequirementType.CUP_MEDAL
const CAREER_POINTS := RequirementType.CAREER_POINTS

@export var id: StringName
@export var display_name := "Premio"
@export var preview: Texture2D
@export var requirement_type: RequirementType = RequirementType.CUP_MEDAL
@export var cup_id: StringName
# Kept only so schema 1-3 resources and saves can still be resolved during migration.
@export var difficulty_id: StringName
@export_enum("Bronce:1", "Plata:2", "Oro:3") var required_medal: int = Medal.BRONZE
@export_range(0, 126, 1) var required_points := 0
@export var kart_variant: KartVariantDefinition

func is_valid() -> bool:
	if id.is_empty() or kart_variant == null or not kart_variant.is_valid():
		return false
	match requirement_type:
		RequirementType.CUP_MEDAL:
			return not cup_id.is_empty() and required_medal in [BRONZE, SILVER, GOLD]
		RequirementType.CAREER_POINTS:
			return required_points > 0
	return false

func requirement_text(catalog: ProgressionCatalog = null) -> String:
	if requirement_type == RequirementType.CAREER_POINTS:
		return "%d puntos de carrera" % required_points
	var cup_name := str(cup_id)
	if catalog != null and catalog.cups != null:
		var cup := catalog.cups.get_cup(cup_id)
		if cup != null: cup_name = cup.display_name
	return "%s · %s" % [cup_name, ["", "Bronce", "Plata", "Oro"][required_medal]]
