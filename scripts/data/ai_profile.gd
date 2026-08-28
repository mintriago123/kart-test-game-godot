class_name AiProfile
extends Resource

var personality: AiPersonality
var buff: DifficultyBuff


func _init() -> void:
	if personality == null:
		personality = AiPersonality.new()
	if buff == null:
		buff = DifficultyBuff.new()


# Backward-compatible @export properties that delegate to personality/buff.
# Existing .tres files (8 rival profiles, all difficulty profiles) read and
# write these properties without modification.

@export_range(0.0, 1.0) var precision: float:
	get: return personality.precision if personality != null else 0.8
	set(value):
		if personality == null:
			personality = AiPersonality.new()
		personality.precision = value

@export_range(0.0, 1.0) var aggression: float:
	get: return personality.aggression if personality != null else 0.5
	set(value):
		if personality == null:
			personality = AiPersonality.new()
		personality.aggression = value

@export_range(0.0, 1.0) var drift_usage: float:
	get: return personality.drift_usage if personality != null else 0.6
	set(value):
		if personality == null:
			personality = AiPersonality.new()
		personality.drift_usage = value

@export_range(0.0, 1.0) var risk_tolerance: float:
	get: return personality.risk_tolerance if personality != null else 0.5
	set(value):
		if personality == null:
			personality = AiPersonality.new()
		personality.risk_tolerance = value

@export_range(0.0, 1.0) var shortcut_probability: float:
	get: return personality.shortcut_probability if personality != null else 0.5
	set(value):
		if personality == null:
			personality = AiPersonality.new()
		personality.shortcut_probability = value

@export_range(0.0, 1.0) var item_efficiency: float:
	get: return personality.item_efficiency if personality != null else 0.7
	set(value):
		if personality == null:
			personality = AiPersonality.new()
		personality.item_efficiency = value

@export_range(0.05, 0.5) var reaction_time: float:
	get: return personality.reaction_time if personality != null else 0.18
	set(value):
		if personality == null:
			personality = AiPersonality.new()
		personality.reaction_time = value

@export_range(0.0, 0.2) var top_speed_bias: float:
	get: return buff.top_speed_bias if buff != null else 0.0
	set(value):
		if buff == null:
			buff = DifficultyBuff.new()
		buff.top_speed_bias = value


# Convenience pass-throughs for the buff fields most used at runtime.
# These are not @export; new code reads them via `profile.buff.*` directly.

var response_multiplier: float:
	get: return buff.response_multiplier if buff != null else 1.0

var lookahead_max_multiplier: float:
	get: return buff.lookahead_max_multiplier if buff != null else 1.0

var wall_recovery_speed_ratio: float:
	get: return buff.wall_recovery_speed_ratio if buff != null else 0.3

var launch_aggression_bias: float:
	get: return buff.launch_aggression_bias if buff != null else 0.0

var avoidance_weight_max: float:
	get: return buff.avoidance_weight_max if buff != null else 0.9


static func create(
	precision_value: float,
	aggression_value: float,
	drift_value: float,
	risk_value: float,
	shortcut_value: float,
	item_value: float,
	reaction_value: float,
	top_speed_bias_value: float = 0.0,
	response_multiplier_value: float = 1.0,
	lookahead_max_multiplier_value: float = 1.0,
	wall_recovery_speed_ratio_value: float = 0.3,
	launch_aggression_bias_value: float = 0.0,
	avoidance_weight_max_value: float = 0.9
) -> AiProfile:
	var profile := AiProfile.new()
	profile.personality.precision = precision_value
	profile.personality.aggression = aggression_value
	profile.personality.drift_usage = drift_value
	profile.personality.risk_tolerance = risk_value
	profile.personality.shortcut_probability = shortcut_value
	profile.personality.item_efficiency = item_value
	profile.personality.reaction_time = reaction_value
	profile.buff.top_speed_bias = top_speed_bias_value
	profile.buff.response_multiplier = response_multiplier_value
	profile.buff.lookahead_max_multiplier = lookahead_max_multiplier_value
	profile.buff.wall_recovery_speed_ratio = wall_recovery_speed_ratio_value
	profile.buff.launch_aggression_bias = launch_aggression_bias_value
	profile.buff.avoidance_weight_max = avoidance_weight_max_value
	return profile
