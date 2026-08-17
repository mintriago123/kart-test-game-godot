class_name KartCollisionResponse
extends Node

var kart: Kart
var _contact_remaining := 0.0
var _last_normal := Vector3.ZERO


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func update(delta: float) -> void:
	_contact_remaining = maxf(_contact_remaining - delta, 0.0)


func reset() -> void:
	_contact_remaining = 0.0
	_last_normal = Vector3.ZERO


func process(incoming_velocity: Vector3) -> void:
	var strongest_incident_ratio := -1.0
	var strongest_normal := Vector3.ZERO
	var horizontal_incoming := Vector3(incoming_velocity.x, 0.0, incoming_velocity.z)
	if horizontal_incoming.is_zero_approx():
		return
	var resolved_vertical_velocity := kart.velocity.y
	for collision_index in kart.get_slide_collision_count():
		var collision := kart.get_slide_collision(collision_index)
		var collider := collision.get_collider() as CollisionObject3D
		if collider == null or (collider.collision_layer & PhysicsLayers.BARRIERS) == 0:
			continue
		var collision_normal := collision.get_normal()
		if absf(collision_normal.y) > 0.45:
			continue
		var wall_normal := Vector3(collision_normal.x, 0.0, collision_normal.z).normalized()
		var incident_ratio := clampf(-horizontal_incoming.normalized().dot(wall_normal), 0.0, 1.0)
		if incident_ratio > strongest_incident_ratio:
			strongest_incident_ratio = incident_ratio
			strongest_normal = collision_normal
	if strongest_incident_ratio < 0.0:
		return
	var normalized_wall := Vector3(strongest_normal.x, 0.0, strongest_normal.z).normalized()
	var continuing := _contact_remaining > 0.0 and normalized_wall.dot(_last_normal) > 0.82
	if continuing:
		var tangent := horizontal_incoming.slide(normalized_wall)
		if not tangent.is_zero_approx():
			var horizontal_speed := horizontal_incoming.length()
			var guided_tangent := (tangent.normalized() + normalized_wall * 0.08).normalized()
			kart.velocity.x = guided_tangent.x * horizontal_speed
			kart.velocity.z = guided_tangent.z * horizontal_speed
	else:
		kart.velocity = Kart.calculate_barrier_velocity(incoming_velocity, strongest_normal)
		kart.velocity.y = resolved_vertical_velocity
	var slide_speed := Vector2(kart.velocity.x, kart.velocity.z).length()
	var minimum_slide_speed := minf(kart.stats.max_speed * 0.2, 6.0)
	if continuing and maxf(kart.get_throttle_input(), kart.get_brake_input()) > 0.5 and slide_speed < minimum_slide_speed:
		var escape_tangent := normalized_wall.cross(Vector3.UP).normalized()
		var forward := -kart.global_transform.basis.z.normalized()
		var powered_direction := forward if kart.get_throttle_input() >= kart.get_brake_input() else -forward
		if escape_tangent.dot(powered_direction) < 0.0:
			escape_tangent = -escape_tangent
		kart.velocity.x = escape_tangent.x * minimum_slide_speed
		kart.velocity.z = escape_tangent.z * minimum_slide_speed
		_align_with_tangent(0.5)
	else:
		_align_with_tangent(0.18 if continuing else 0.08)
	_last_normal = normalized_wall
	_contact_remaining = Kart.BARRIER_CONTACT_MEMORY
	kart.barrier_contact.emit(normalized_wall, strongest_incident_ratio, continuing)


func _align_with_tangent(weight: float) -> void:
	var travel_direction := Vector3(kart.velocity.x, 0.0, kart.velocity.z)
	if travel_direction.length_squared() <= 0.01:
		return
	var target_yaw := atan2(-travel_direction.normalized().x, -travel_direction.normalized().z)
	kart.rotation.y = lerp_angle(kart.rotation.y, target_yaw, clampf(weight, 0.0, 1.0))
