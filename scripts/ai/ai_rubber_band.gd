class_name AiRubberBand
extends RefCounted

var tuning: AiTuning
var bias: float = 0.0


func update(gap_to_target: float, assist_max: float, penalty_max: float, delta: float) -> float:
	var target_bias := 0.0
	if gap_to_target < 0.0:
		var behind_ratio := clampf(-gap_to_target / maxf(tuning.rubber_band_gap_assist_full, 0.01), 0.0, 1.0)
		target_bias = behind_ratio * assist_max
	elif gap_to_target > 0.0:
		var ahead_ratio := clampf(gap_to_target / maxf(tuning.rubber_band_gap_penalty_full, 0.01), 0.0, 1.0)
		target_bias = -ahead_ratio * penalty_max
	bias = move_toward(bias, target_bias, tuning.rubber_band_bias_rate * delta)
	return bias


func reset() -> void:
	bias = 0.0
