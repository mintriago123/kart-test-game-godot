class_name RacerDefinition
extends Resource

@export var id: StringName
@export var display_name := "Rival"
@export var portrait: Texture2D
@export var body_color := Color.WHITE
@export var kart_stats: KartStats
@export var ai_profile: AiProfile
@export var default_kart_visual: KartVariantDefinition


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("Racer id is empty.")
	if display_name.strip_edges().is_empty(): errors.append("Racer %s has no display name." % id)
	if kart_stats == null: errors.append("Racer %s has no KartStats." % id)
	if ai_profile == null: errors.append("Racer %s has no AiProfile." % id)
	if default_kart_visual == null: errors.append("Racer %s has no default kart visual." % id)
	return errors


static func create(
	racer_id: StringName,
	racer_name: String,
	color: Color,
	stats: KartStats,
	profile: AiProfile
) -> RacerDefinition:
	var definition := RacerDefinition.new()
	definition.id = racer_id
	definition.display_name = racer_name
	definition.body_color = color
	definition.kart_stats = stats
	definition.ai_profile = profile
	return definition
