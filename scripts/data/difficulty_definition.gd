class_name DifficultyDefinition
extends Resource

@export var id: StringName
@export var display_name := "Dificultad"
@export_multiline var description := ""
@export var precision_multiplier := 1.0
@export var reaction_time_multiplier := 1.0
@export var risk_multiplier := 1.0
@export var item_efficiency_multiplier := 1.0
@export var aggression_multiplier := 1.0
@export var drift_usage_multiplier := 1.0
@export var top_speed_bias := 0.0
@export var kart_stat_multiplier := 1.0
@export var kart_handling_multiplier := 1.0
@export var response_multiplier := 1.0
@export var lookahead_max_multiplier := 1.0
@export var wall_recovery_speed_ratio := 0.3
@export var launch_aggression_bias := 0.0
@export var avoidance_weight_max := 0.9
@export_range(1, 3, 1) var progress_multiplier := 1
@export var sort_order := 0

func is_valid() -> bool:
	return (not id.is_empty() and precision_multiplier > 0.0
		and reaction_time_multiplier > 0.0 and risk_multiplier > 0.0
		and item_efficiency_multiplier > 0.0 and progress_multiplier > 0)

func apply_to(base: AiProfile) -> AiProfile:
	var source := base if base != null else AiProfile.new()
	var profile := AiProfile.new()
	profile.personality.precision = clampf(source.personality.precision * precision_multiplier, 0.0, 1.0)
	profile.personality.aggression = clampf(source.personality.aggression * aggression_multiplier, 0.0, 1.0)
	profile.personality.drift_usage = clampf(source.personality.drift_usage * drift_usage_multiplier, 0.0, 1.0)
	profile.personality.risk_tolerance = clampf(source.personality.risk_tolerance * risk_multiplier, 0.0, 1.0)
	profile.personality.shortcut_probability = clampf(source.personality.shortcut_probability * risk_multiplier, 0.0, 1.0)
	profile.personality.item_efficiency = clampf(source.personality.item_efficiency * item_efficiency_multiplier, 0.0, 1.0)
	profile.personality.reaction_time = clampf(source.personality.reaction_time * reaction_time_multiplier, 0.05, 0.5)
	profile.buff.top_speed_bias = clampf(source.buff.top_speed_bias + top_speed_bias, 0.0, 0.15)
	profile.buff.response_multiplier = response_multiplier
	profile.buff.lookahead_max_multiplier = lookahead_max_multiplier
	profile.buff.wall_recovery_speed_ratio = wall_recovery_speed_ratio
	profile.buff.launch_aggression_bias = launch_aggression_bias
	profile.buff.avoidance_weight_max = avoidance_weight_max
	return profile
