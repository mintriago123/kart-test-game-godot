class_name UnlockDefinition
extends Resource

enum Medal { NONE, BRONZE, SILVER, GOLD }
const BRONZE := Medal.BRONZE
const SILVER := Medal.SILVER
const GOLD := Medal.GOLD

@export var id: StringName
@export var display_name := "Premio"
@export var preview: Texture2D
@export var cup_id: StringName
@export var difficulty_id: StringName
@export_enum("Bronce:1", "Plata:2", "Oro:3") var required_medal: int = Medal.BRONZE
@export var kart_variant: KartVariantDefinition

func is_valid() -> bool:
	return (not id.is_empty() and not cup_id.is_empty() and not difficulty_id.is_empty()
		and required_medal in [BRONZE, SILVER, GOLD] and kart_variant != null
		and kart_variant.is_valid())
