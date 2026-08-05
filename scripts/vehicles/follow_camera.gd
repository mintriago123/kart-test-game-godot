class_name FollowCamera
extends Node3D

const FOLLOW_DISTANCE := 7.2
const FOLLOW_HEIGHT := 3.4

var target: Kart
var _camera: Camera3D


func setup(follow_target: Kart) -> void:
	target = follow_target
	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.current = true
	add_child(_camera)
	_snap_to_target()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var target_basis := target.global_transform.basis
	var desired_position := (
		target.global_position
		+ Vector3.UP * FOLLOW_HEIGHT
		+ target_basis.z.normalized() * FOLLOW_DISTANCE
	)
	var follow_weight := 1.0 - exp(-7.5 * delta)
	global_position = global_position.lerp(desired_position, follow_weight)
	var look_target := target.global_position + Vector3.UP * 1.15 - target_basis.z * 1.2
	look_at(look_target, Vector3.UP)
	var speed_ratio := clampf(
		Vector2(target.velocity.x, target.velocity.z).length() / target.stats.max_speed,
		0.0,
		1.3
	)
	_camera.fov = lerpf(_camera.fov, 72.0 + speed_ratio * 7.0, delta * 4.0)


func _snap_to_target() -> void:
	if target == null:
		return
	global_position = (
		target.global_position
		+ Vector3.UP * FOLLOW_HEIGHT
		+ target.global_transform.basis.z.normalized() * FOLLOW_DISTANCE
	)
	look_at(target.global_position + Vector3.UP, Vector3.UP)
