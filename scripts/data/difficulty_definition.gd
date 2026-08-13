class_name DifficultyDefinition
extends Resource

@export var id: StringName
@export var display_name := "Dificultad"
@export_multiline var description := ""
@export var precision_multiplier := 1.0
@export var reaction_time_multiplier := 1.0
@export var risk_multiplier := 1.0
@export var item_efficiency_multiplier := 1.0
@export_range(1, 3, 1) var progress_multiplier := 1
@export var sort_order := 0

func is_valid() -> bool:
	return (not id.is_empty() and precision_multiplier > 0.0
		and reaction_time_multiplier > 0.0 and risk_multiplier > 0.0
		and item_efficiency_multiplier > 0.0 and progress_multiplier > 0)

func apply_to(base: AiProfile) -> AiProfile:
	var source := base if base != null else AiProfile.new()
	return AiProfile.create(
		clampf(source.precision * precision_multiplier, 0.0, 1.0),
		source.aggression, source.drift_usage,
		clampf(source.risk_tolerance * risk_multiplier, 0.0, 1.0),
		clampf(source.shortcut_probability * risk_multiplier, 0.0, 1.0),
		clampf(source.item_efficiency * item_efficiency_multiplier, 0.0, 1.0),
		clampf(source.reaction_time * reaction_time_multiplier, 0.05, 0.5)
	)
