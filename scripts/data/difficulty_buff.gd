class_name DifficultyBuff
extends Resource

@export_range(0.5, 3.0) var response_multiplier := 1.0
@export_range(0.5, 2.0) var lookahead_max_multiplier := 1.0
@export_range(0.1, 1.0) var wall_recovery_speed_ratio := 0.3
@export var launch_aggression_bias := 0.0
@export_range(0.5, 1.0) var avoidance_weight_max := 0.9
@export_range(0.0, 0.2) var top_speed_bias := 0.0
@export_range(0.0, 0.15) var rubber_band_assist_max := 0.03
@export_range(0.0, 0.15) var rubber_band_penalty_max := 0.02
@export var allow_blocking := true


static func defaults() -> DifficultyBuff:
	return DifficultyBuff.new()
