class_name HomingProjectile
extends KartProjectile

var target_kart: Node3D


func setup_homing(
	source_kart: Node3D,
	definition: ItemDefinition,
	direction: Vector3,
	target: Node3D
) -> void:
	target_kart = target
	setup(source_kart, definition, direction)


func _physics_process(delta: float) -> void:
	_update_homing(delta)
	super._physics_process(delta)


func get_target() -> Node3D:
	return target_kart


static func rotate_direction_toward(
	current_direction: Vector3,
	desired_direction: Vector3,
	max_angle: float
) -> Vector3:
	var current := Vector3(
		current_direction.x,
		0.0,
		current_direction.z
	).normalized()
	var desired := Vector3(
		desired_direction.x,
		0.0,
		desired_direction.z
	).normalized()
	if current.is_zero_approx() or desired.is_zero_approx():
		return current
	var angle := current.angle_to(desired)
	if angle <= 0.00001:
		return desired
	return current.slerp(desired, minf(maxf(max_angle, 0.0) / angle, 1.0)).normalized()


func _update_homing(delta: float) -> void:
	if target_kart == null:
		return
	if not is_instance_valid(target_kart) or not target_kart.is_inside_tree():
		target_kart = null
		return
	var to_target := target_kart.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var updated_direction := rotate_direction_toward(
		velocity,
		to_target,
		item_definition.projectile_max_turn_rate * delta
	)
	velocity.x = updated_direction.x * speed
	velocity.z = updated_direction.z * speed
