class_name FollowCamera
extends Node3D

const FOLLOW_DISTANCE := 7.2
const FOLLOW_HEIGHT := 3.4
const BASE_FOV := 72.0
const MAXIMUM_SPEED_PULLBACK := 1.3
const MAXIMUM_DRIFT_OFFSET := 0.62
const MAXIMUM_LANDING_DROP := 0.12

var target: Kart
var _camera: Camera3D
var motion_mode := "reduced"
var _impact := 0.0
var _previous_boost := false
var _boost_pulse := 0.0

const MAX_EFFECT_OFFSET := 0.8
const MAX_EFFECT_ROLL := 4.0
const MAX_FOV_PULSE := 4.0


func setup(follow_target: Kart) -> void:
	target = follow_target
	_camera = Camera3D.new()
	_camera.fov = BASE_FOV
	_camera.current = true
	add_child(_camera)
	_snap_to_target()


func set_target(follow_target: Kart, snap: bool = false) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	target = follow_target
	_previous_boost = target.is_boost_active()
	_boost_pulse = 0.0
	_impact = 0.0
	if snap:
		_snap_to_target()


func activate() -> void:
	if not is_ready():
		return
	global_transform = get_target_transform()
	_camera.fov = get_target_fov()
	set_physics_process(true)
	_camera.current = true


func deactivate() -> void:
	set_physics_process(false)
	if _camera != null:
		_camera.current = false


func is_active() -> bool:
	return _camera != null and _camera.current


func is_ready() -> bool:
	return target != null and _camera != null

func get_camera() -> Camera3D:
	return _camera


func get_target_transform() -> Transform3D:
	if target == null:
		return global_transform
	var target_basis := target.global_transform.basis
	var speed_ratio := _get_speed_ratio()
	var amplitude := _get_motion_amplitude()
	var drift_offset := 0.0
	if target.get_drive_state() in [Kart.DriveState.DRIFT, Kart.DriveState.DRIFT_HOP]:
		drift_offset = target.get_drift_side() * MAXIMUM_DRIFT_OFFSET * amplitude
	var landing_drop := target.get_landing_compression_ratio() * MAXIMUM_LANDING_DROP * amplitude
	var impact_offset := sin(_impact * 31.0) * minf(_impact, 1.0) * 0.38 * amplitude
	var desired_position := (
		target.global_position
		+ Vector3.UP * (FOLLOW_HEIGHT - landing_drop)
		+ target_basis.z.normalized() * (
			FOLLOW_DISTANCE + speed_ratio * MAXIMUM_SPEED_PULLBACK
		)
		+ target_basis.x.normalized() * clampf(drift_offset + impact_offset, -MAX_EFFECT_OFFSET, MAX_EFFECT_OFFSET)
	)
	var look_target := (
		target.global_position
		+ Vector3.UP * 1.15
		- target_basis.z * 1.2
	)
	return Transform3D(Basis.IDENTITY, desired_position).looking_at(
		look_target,
		Vector3.UP
	)


func get_target_fov() -> float:
	if target == null:
		return BASE_FOV
	var maximum_fov := (
		target.race_class.maximum_camera_fov
		if target.race_class != null
		else 85.0
	)
	var speed_weight := smoothstep(0.12, 1.0, _get_speed_ratio())
	var pulse := 0.0 if motion_mode == "off" else minf(_boost_pulse, MAX_FOV_PULSE)
	return clampf(lerpf(BASE_FOV, maximum_fov, speed_weight) + pulse, BASE_FOV, maximum_fov + MAX_FOV_PULSE)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var boosting := target.is_boost_active()
	if boosting and not _previous_boost:
		_boost_pulse = MAX_FOV_PULSE
	_previous_boost = boosting
	_boost_pulse = move_toward(_boost_pulse, 0.0, delta * 7.0)
	_impact = move_toward(_impact, 0.0, delta * 4.2)
	var target_transform := get_target_transform()
	var follow_weight := 1.0 - exp(-7.5 * delta)
	global_transform = global_transform.interpolate_with(
		target_transform,
		follow_weight
	)
	var fov_weight := 1.0 - exp(-4.0 * delta)
	_camera.fov = lerpf(_camera.fov, get_target_fov(), fov_weight)
	var desired_roll := 0.0
	if _get_motion_amplitude() > 0.0 and target.get_drive_state() in [Kart.DriveState.DRIFT, Kart.DriveState.DRIFT_HOP]:
		desired_roll = deg_to_rad(clampf(-target.get_drift_side() * MAX_EFFECT_ROLL * _get_motion_amplitude(), -MAX_EFFECT_ROLL, MAX_EFFECT_ROLL))
	_camera.rotation.z = lerp_angle(_camera.rotation.z, desired_roll, 1.0 - exp(-8.0 * delta))

func add_impact(strength: float) -> void:
	_impact = clampf(_impact + strength, 0.0, 1.0)

func _get_motion_amplitude() -> float:
	match motion_mode:
		"full": return 1.0
		"off": return 0.0
		_: return 0.4


func _snap_to_target() -> void:
	if target == null:
		return
	global_transform = get_target_transform()


func _get_speed_ratio() -> float:
	if target == null:
		return 0.0
	return clampf(
		target.get_horizontal_speed() / maxf(target.stats.max_speed, 0.1),
		0.0,
		1.0
	)
