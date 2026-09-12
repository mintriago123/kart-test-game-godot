class_name AiTuning
extends Resource

@export_group("Steering")
@export var steering_angular_gain := 1.9
@export var steering_curvature_gain := 2.4
@export var steering_lateral_gain_min := 0.09
@export var steering_lateral_gain_max := 0.16
@export var steering_lateral_recovery_start_ratio := 0.58
@export var steering_lateral_recovery_end_ratio := 0.9
@export var steering_lateral_recovery_gain := 0.65
@export var steer_response_min := 4.5
@export var steer_response_max := 8.5
@export var steering_target_response_hz := 8.0
@export var steering_straight_curvature_max := 0.015
@export var steering_straight_sensor_min := 0.38
@export var steering_straight_sign_deadband := 0.05
@export var line_steer_max_magnitude := 1.0

@export_group("Speed planning")
@export var lookahead_base := 5.5
@export var lookahead_speed_factor := 0.34
@export var lookahead_min := 7.0
@export var lookahead_max := 19.0
@export var throttle_speed_ratio := 0.16
@export var brake_speed_ratio := 0.13
@export var throttle_deadband := 0.4
@export var brake_deadband := 0.4
@export var throttle_smooth_rate := 2.8
@export var brake_smooth_rate := 3.8
@export var target_speed_deceleration_rate := 60.0
@export var target_speed_acceleration_rate := 12.0
@export var item_cooldown_min := 2.4
@export var item_cooldown_max := 4.8
@export var aggression_safe_speed_min := 0.96
@export var aggression_safe_speed_max := 1.0

@export_group("Safe speed")
@export var safe_speed_lateral_capacity_factor := 1.45
@export var safe_speed_barrier_brake_distance := 1.6
@export var safe_speed_barrier_activation_ratio := 0.3
@export var safe_speed_lateral_loss_floor := 0.58
@export var safe_speed_min_ratio := 0.22
@export var safe_speed_line_ratio_floor := 0.52

@export_group("Sensors")
@export var sensor_min_range := 5.0
@export var sensor_max_range := 14.0
@export var sensor_side_range_min := 3.5
@export var sensor_side_range_max := 5.0
@export var sensor_origin_height := 0.55
@export var sensor_side_offset := 0.55
@export var sensor_side_forward_blend := 0.35
@export var sensor_front_transition_start := 0.22
@export var sensor_front_transition_end := 0.38

@export_group("Wall contact")
@export var wall_recovery_contact_time := 0.4
@export var wall_recovery_reset_time := 2.0
@export var contact_grace := 0.16

@export_group("Section variation")
@export var section_offset_range := 1.25
@export var section_speed_min := -0.1
@export var section_speed_max := 0.06
@export var section_braking_range := 0.08
@export var section_reaction_max := 0.16

@export_group("Drift decision")
@export var drift_curvature_threshold := 0.018
@export var drift_curvature_release := 0.007
@export var drift_curvature_commit := 0.025
@export var drift_curvature_cancel := 0.005
@export var drift_steer_threshold := 0.32
@export var drift_steer_release := 0.12
@export var drift_steer_commit := 0.40
@export var drift_steer_cancel := 0.08
@export var drift_speed_ratio_threshold := 0.34
@export var drift_lateral_error_ratio := 0.55
@export var drift_sensor_front_min := 0.24
@export var drift_sensor_side_min := 0.14
@export var drift_lock_frames := 12
@export var drift_min_hold_frames := 6
@export var drift_extreme_front_min := 0.08
@export var drift_extreme_side_min := 0.05
@export var drift_extreme_lateral_error_ratio := 0.95

@export_group("Racer avoidance")
@export var racer_avoidance_distance := 10.0
@export var racer_avoidance_forward_min := 0.5
@export var racer_avoidance_lateral_max := 2.8
@export var racer_avoidance_forward_dot := 0.72
@export var racer_avoidance_lateral_sign_threshold := 0.25
@export var racer_avoidance_weight_floor := 0.0
@export var racer_avoidance_weight_ceiling := 0.9

@export_group("Barrier steering")
@export var barrier_threat_front_start := 0.30
@export var barrier_threat_front_range := 0.18
@export var barrier_threat_side_start := 0.16
@export var barrier_threat_side_range := 0.11
@export var barrier_threat_response_curve := 1.8
@export var barrier_threat_weight_min := 0.25
@export var barrier_steering_arc_gain := 2.4
@export var barrier_steering_contact_bias := 0.3

@export_group("Wall recovery throttle")
@export var wall_recovery_throttle_ceiling := 0.32
@export var wall_recovery_brake_min := 0.12
@export var wall_recovery_speed_ratio := 0.3

@export_group("Sensor / Throttle under threat")
@export var sensor_threat_throttle_ceiling := 0.18
@export var sensor_threat_brake_floor := 0.45
@export var brake_overrides_throttle_ceiling := 0.15
@export var brake_overrides_throttle_threshold := 0.08

@export_group("Progress recovery")
@export var progress_stall_seconds := 4.0
@export var progress_recovery_distance := 0.75
@export var impact_correction_seconds := 2.5
@export var recovery_correction_seconds := 4.5

@export_group("Strategy tick")
@export var strategy_tick_hz := 10.0

@export_group("Shortcut planning")
@export var shortcut_approach_distance := 18.0

@export_group("Item decision")
@export var item_boost_speed_ratio_threshold := 0.9
@export var item_turbo_coconut_distance := 22.0
@export var item_turbo_coconut_alignment := 0.82
@export var item_slippery_peel_distance := 14.0
@export var item_slippery_peel_max_hold_time := 4.0
@export var item_homing_pineapple_distance := 40.0
@export var item_homing_pineapple_alignment := 0.2
@export var item_homing_pineapple_max_hold_time := 6.0
@export var item_tropical_wave_max_hold_time := 6.0

@export_group("Racer detection helpers")
@export var racer_ahead_behind_dot := -0.55

@export_group("Rubber banding")
@export var rubber_band_gap_assist_full := 3.0
@export var rubber_band_gap_penalty_full := 3.0
@export var rubber_band_bias_rate := 0.05

@export_group("Racecraft")
@export var racecraft_forward_alignment := 0.75
@export var racecraft_draft_min_distance := 4.0
@export var racecraft_draft_max_distance := 9.0
@export var racecraft_draft_alignment := 0.85
@export var racecraft_draft_rate := 2.0
@export var racecraft_overtake_rate := 3.0
@export var racecraft_overtake_weight_ceiling := 1.0
@export var racecraft_overtake_speed_bias := 0.02
@export_range(0.0, 1.0) var racecraft_block_min_aggression := 0.55
@export var racecraft_block_distance := 6.0
@export var racecraft_block_max_offset := 1.2
@export var racecraft_block_rate := 2.5

@export_group("Debug")
@export var enable_debug_logging := false
@export var debug_log_interval := 1.0
@export var enable_telemetry_recording := false
@export var telemetry_flush_interval := 30


static func defaults() -> AiTuning:
	return AiTuning.new()
