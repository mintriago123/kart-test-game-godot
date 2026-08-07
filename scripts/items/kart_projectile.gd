class_name KartProjectile
extends CharacterBody3D

signal bounced(bounce_count: int)
signal kart_hit(kart: Node3D, result: int)

const MAX_COLLISIONS_PER_FRAME := 3
const MAX_TIME_WITHOUT_GROUND := 0.5
const GROUND_PROBE_UP := 1.4
const GROUND_PROBE_DOWN := 3.6
const SURFACE_SEPARATION := 0.015
const MIN_NORMAL_LENGTH_SQUARED := 0.25

var owner_kart: Node3D
var item_definition: ItemDefinition
var bounce_count := 0

var _remaining_life := 0.0
var _owner_immunity_remaining := 0.0
var _time_without_ground := 0.0
var _is_stuck := false
var _hit_karts: Dictionary = {}
var _bounce_flash: MeshInstance3D
var _bounce_flash_material: StandardMaterial3D
var _bounce_flash_tween: Tween


func setup(
	source_kart: Node3D,
	definition: ItemDefinition,
	direction: Vector3
) -> void:
	owner_kart = source_kart
	item_definition = definition
	_remaining_life = maxf(definition.projectile_duration, 0.0)
	_owner_immunity_remaining = maxf(
		definition.projectile_owner_immunity,
		0.0
	)
	var launch_direction := direction.normalized()
	velocity = launch_direction * maxf(definition.projectile_speed, 0.0)
	if (
		_owner_immunity_remaining > 0.0
		and owner_kart is PhysicsBody3D
	):
		add_collision_exception_with(owner_kart as PhysicsBody3D)


func _ready() -> void:
	if item_definition == null:
		item_definition = ItemDefinition.tropical_projectile()
		_remaining_life = item_definition.projectile_duration
	collision_layer = PhysicsLayers.PROJECTILES
	collision_mask = PhysicsLayers.KARTS
	if item_definition.barrier_response != ItemDefinition.BarrierResponse.IGNORE:
		collision_mask |= PhysicsLayers.BARRIERS
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.001
	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	if not _has_valid_state():
		queue_free()
		return
	_remaining_life -= delta
	if _remaining_life <= 0.0:
		queue_free()
		return
	if not _is_stuck and not _move_swept(delta):
		return
	if not _follow_ground(delta):
		return
	_update_owner_immunity(delta)
	rotate_y(delta * 7.0)


func get_remaining_life() -> float:
	return _remaining_life


static func calculate_bounce_velocity(
	incoming_velocity: Vector3,
	surface_normal: Vector3,
	speed_retention: float
) -> Vector3:
	return incoming_velocity.bounce(surface_normal.normalized()) * clampf(
		speed_retention,
		0.0,
		1.0
	)


func _move_swept(delta: float) -> bool:
	var remaining_motion := velocity * delta
	for _collision_index in MAX_COLLISIONS_PER_FRAME:
		if remaining_motion.length_squared() <= 0.000001:
			break
		var collision := move_and_collide(remaining_motion)
		if collision == null:
			break
		var collider := collision.get_collider() as Node3D
		if _is_kart_collider(collider):
			_hit_kart(collider)
			return false
		if _is_barrier_collider(collider):
			var normal := collision.get_normal()
			if not _handle_barrier_collision(normal):
				return false
			if _is_stuck:
				return true
			remaining_motion = calculate_bounce_velocity(
				collision.get_remainder(),
				normal,
				item_definition.projectile_speed_retention
			)
			continue
		queue_free()
		return false
	return true


func _handle_barrier_collision(normal: Vector3) -> bool:
	match item_definition.barrier_response:
		ItemDefinition.BarrierResponse.DESTROY:
			queue_free()
			return false
		ItemDefinition.BarrierResponse.BOUNCE:
			return _bounce_from_barrier(normal)
		ItemDefinition.BarrierResponse.STICK:
			velocity = Vector3.ZERO
			_is_stuck = true
			return true
		ItemDefinition.BarrierResponse.IGNORE:
			return true
	return false


func _bounce_from_barrier(normal: Vector3) -> bool:
	if (
		not normal.is_finite()
		or normal.length_squared() < MIN_NORMAL_LENGTH_SQUARED
		or bounce_count >= item_definition.projectile_max_bounces
	):
		queue_free()
		return false
	normal = normal.normalized()
	velocity = calculate_bounce_velocity(
		velocity,
		normal,
		item_definition.projectile_speed_retention
	)
	if not velocity.is_finite() or velocity.length_squared() <= 0.000001:
		queue_free()
		return false
	global_position += normal * SURFACE_SEPARATION
	bounce_count += 1
	_trigger_bounce_flash()
	bounced.emit(bounce_count)
	return true


func _follow_ground(delta: float) -> bool:
	var space_state := get_world_3d().direct_space_state
	var ray_start := global_position + Vector3.UP * GROUND_PROBE_UP
	var ray_end := global_position - Vector3.UP * GROUND_PROBE_DOWN
	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		PhysicsLayers.DRIVABLE_SURFACES,
		[get_rid()]
	)
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		_time_without_ground += delta
		if _time_without_ground > MAX_TIME_WITHOUT_GROUND:
			queue_free()
			return false
		return true
	var ground_position: Vector3 = result.position
	var ground_normal: Vector3 = result.normal
	if (
		not ground_position.is_finite()
		or not ground_normal.is_finite()
		or ground_normal.length_squared() < MIN_NORMAL_LENGTH_SQUARED
	):
		queue_free()
		return false
	_time_without_ground = 0.0
	global_position.y = ground_position.y + item_definition.projectile_radius
	return true


func _update_owner_immunity(delta: float) -> void:
	if _owner_immunity_remaining <= 0.0:
		return
	_owner_immunity_remaining = maxf(_owner_immunity_remaining - delta, 0.0)
	if (
		_owner_immunity_remaining <= 0.0
		and is_instance_valid(owner_kart)
		and owner_kart is PhysicsBody3D
	):
		remove_collision_exception_with(owner_kart as PhysicsBody3D)


func _is_kart_collider(collider: Node3D) -> bool:
	return (
		collider != null
		and collider.has_method("receive_hit")
		and (collider.collision_layer & PhysicsLayers.KARTS) != 0
	)


func _is_barrier_collider(collider: Node3D) -> bool:
	return (
		collider != null
		and (collider.collision_layer & PhysicsLayers.BARRIERS) != 0
	)


func _hit_kart(kart: Node3D) -> void:
	var kart_id := kart.get_instance_id()
	if kart_id in _hit_karts:
		return
	_hit_karts[kart_id] = true
	var raw_result: Variant = kart.receive_hit(
		item_definition.projectile_impact_duration
	)
	var hit_result := (
		int(raw_result)
		if raw_result != null
		else Kart.HitResult.APPLIED
	)
	kart_hit.emit(kart, hit_result)
	queue_free()


func _has_valid_state() -> bool:
	return (
		global_position.is_finite()
		and velocity.is_finite()
		and item_definition != null
	)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = item_definition.projectile_radius
	collision.shape = shape
	add_child(collision)


func _build_visual() -> void:
	if item_definition.visual_scene != null:
		var item_visual := item_definition.visual_scene.instantiate() as Node3D
		if item_visual != null:
			add_child(item_visual)
			_build_bounce_flash()
			return
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = item_definition.projectile_radius
	mesh.height = item_definition.projectile_radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(Color("#ff784f"))
	add_child(mesh_instance)

	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = item_definition.projectile_radius * 0.21
	crown_mesh.bottom_radius = item_definition.projectile_radius * 0.63
	crown_mesh.height = item_definition.projectile_radius * 0.73
	crown.mesh = crown_mesh
	crown.position.y = item_definition.projectile_radius * 1.2
	crown.material_override = _material(Color("#4fbb6a"))
	add_child(crown)

	_build_bounce_flash()


func _build_bounce_flash() -> void:
	_bounce_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = item_definition.projectile_radius * 1.18
	flash_mesh.height = item_definition.projectile_radius * 2.36
	_bounce_flash.mesh = flash_mesh
	_bounce_flash_material = _material(Color(1.0, 0.8, 0.28, 0.0))
	_bounce_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bounce_flash_material.emission_enabled = true
	_bounce_flash_material.emission = Color("#ffd15a")
	_bounce_flash_material.emission_energy_multiplier = 2.4
	_bounce_flash.material_override = _bounce_flash_material
	_bounce_flash.visible = false
	add_child(_bounce_flash)


func _trigger_bounce_flash() -> void:
	if _bounce_flash == null:
		return
	if _bounce_flash_tween != null:
		_bounce_flash_tween.kill()
	_bounce_flash.visible = true
	_bounce_flash.scale = Vector3.ONE
	_bounce_flash_material.albedo_color.a = 0.9
	_bounce_flash_tween = create_tween()
	_bounce_flash_tween.set_parallel(true)
	_bounce_flash_tween.tween_property(
		_bounce_flash,
		"scale",
		Vector3.ONE * 1.9,
		0.1
	)
	_bounce_flash_tween.tween_property(
		_bounce_flash_material,
		"albedo_color:a",
		0.0,
		0.1
	)
	_bounce_flash_tween.chain().tween_callback(
		func() -> void: _bounce_flash.visible = false
	)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
