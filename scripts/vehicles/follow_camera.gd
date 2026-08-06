class_name FollowCamera
extends Node3D

const FOLLOW_DISTANCE := 7.2
const FOLLOW_HEIGHT := 3.4
const BASE_FOV := 72.0

var target: Kart
var _camera: Camera3D


func setup(follow_target: Kart) -> void:
	target = follow_target
	_camera = Camera3D.new()
	_camera.fov = BASE_FOV
	_camera.current = true
	add_child(_camera)
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


func get_target_transform() -> Transform3D:
	if target == null:
		return global_transform
	var target_basis := target.global_transform.basis
	var desired_position := (
		target.global_position
		+ Vector3.UP * FOLLOW_HEIGHT
		+ target_basis.z.normalized() * FOLLOW_DISTANCE
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
	return BASE_FOV


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var target_transform := get_target_transform()
	var follow_weight := 1.0 - exp(-7.5 * delta)
	global_transform = global_transform.interpolate_with(
		target_transform,
		follow_weight
	)
	var speed_ratio := clampf(
		Vector2(target.velocity.x, target.velocity.z).length() / target.stats.max_speed,
		0.0,
		1.3
	)
	_camera.fov = lerpf(
		_camera.fov,
		BASE_FOV + speed_ratio * 7.0,
		delta * 4.0
	)


func _snap_to_target() -> void:
	if target == null:
		return
	global_transform = get_target_transform()
