class_name DrivingTuningDefinition
extends Resource

@export_group("Derrape")
@export var drift_level_times := PackedFloat32Array([0.65, 1.25, 1.90])
@export var mini_turbo_durations := PackedFloat32Array([0.67, 0.89, 1.11])
@export var mini_turbo_powers := PackedFloat32Array([5.5, 7.5, 9.5])
@export var hop_grace := 0.30
@export var minimum_drift_quality := 0.25
@export var low_quality_grace := 0.45
@export var low_quality_cancel := 1.20
@export var charge_loss_per_second := 0.60

@export_group("Salida")
@export var launch_throttle_threshold := 0.65
@export var launch_early_limit := -0.75
@export var launch_good_start := -0.45
@export var launch_perfect_start := -0.18
@export var launch_bog_duration := 0.55
@export var launch_good_duration := 0.55
@export var launch_perfect_duration := 0.80
@export var launch_boost_power := 7.0

@export_group("Interaccion")
@export var bump_cooldown := 0.18
@export var bump_max_impulse := 3.0
@export var slipstream_min_distance := 2.5
@export var slipstream_max_distance := 11.0
@export var slipstream_alignment := 0.88
@export var slipstream_lateral_distance := 2.2
@export var slipstream_charge_duration := 0.75
@export var slipstream_boost_duration := 0.65
@export var slipstream_boost_power := 6.0
@export var slipstream_cooldown := 1.5
