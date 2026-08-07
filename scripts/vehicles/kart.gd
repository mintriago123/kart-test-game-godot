class_name Kart
extends CharacterBody3D

signal item_changed(item: ItemDefinition)
signal boost_changed(charge_ratio: float)
signal hit_received
signal hit_blocked
signal recovered
signal item_use_requested(item: ItemDefinition, direction: Vector3)
signal shield_state_changed(
	item: ItemDefinition,
	remaining: float,
	total: float
)

enum HitResult {
	IGNORED,
	BLOCKED,
	APPLIED,
}

const GRAVITY := 28.0
const DRIFT_LEVEL_TIMES := [0.65, 1.25, 1.9]
const SHORTCUT_SURFACE_LAYER := PhysicsLayers.SHORTCUTS

@export var racer_name := "Piloto"
@export var is_player := false
@export var body_color := Color("#ff6b4a")

var stats := KartStats.new()
var is_control_enabled := false
var held_item: ItemDefinition
var item_catalog: ItemCatalog
var item_rng: RandomNumberGenerator
var race_manager: RaceManager
var recovery_count := 0
var last_recovery_position := Vector3.ZERO
var last_recovery_reason := ""

var _throttle_input := 0.0
var _brake_input := 0.0
var _steer_input := 0.0
var _drift_input := false
var _use_item_requested := false
var _drift_charge := 0.0
var _boost_remaining := 0.0
var _stun_remaining := 0.0
var _invulnerable_remaining := 0.0
var _held_item_elapsed := 0.0
var _shield_item: ItemDefinition
var _shield_remaining := 0.0
var _shield_visual: Node3D
var _straight_launch_requested := false
var _last_valid_transform := Transform3D.IDENTITY
var _stuck_time := 0.0
var _movement_sample_time := 0.0
var _movement_sample_distance := 0.0
var _last_motion_position := Vector3.ZERO
var _visual_root: Node3D


func _ready() -> void:
	collision_layer = PhysicsLayers.KARTS
	collision_mask = (
		PhysicsLayers.WORLD
		| PhysicsLayers.MAIN_BARRIERS
		| PhysicsLayers.SHORTCUT_BARRIERS
	)
	floor_snap_length = 1.1
	floor_max_angle = deg_to_rad(52.0)
	_last_valid_transform = global_transform
	_last_motion_position = global_position
	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	if is_player:
		_read_player_input()
	if _use_item_requested:
		_use_item_requested = false
		use_item()

	var forward := -global_transform.basis.z.normalized()
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed := horizontal_velocity.dot(forward)
	var can_drive := is_control_enabled and _stun_remaining <= 0.0
	var throttle := _throttle_input if can_drive else 0.0
	var brake := _brake_input if can_drive else 0.35
	var steer := _steer_input if can_drive else 0.0
	var drifting := _drift_input and can_drive and absf(forward_speed) > 7.0

	if is_on_floor():
		if throttle > 0.0:
			velocity += forward * stats.acceleration * throttle * delta
		if brake > 0.0:
			if forward_speed > 1.0:
				velocity -= forward * stats.braking * brake * delta
			else:
				velocity += forward * stats.braking * 0.36 * brake * delta

		var speed_limit := stats.max_speed + (stats.boost_power if _boost_remaining > 0.0 else 0.0)
		var updated_forward_speed := velocity.dot(forward)
		if updated_forward_speed > speed_limit:
			velocity -= forward * (updated_forward_speed - speed_limit) * minf(delta * 7.0, 1.0)
		elif updated_forward_speed < -stats.reverse_speed:
			velocity -= forward * (updated_forward_speed + stats.reverse_speed)

		var steering_factor := clampf(absf(forward_speed) / 8.0, 0.2, 1.0)
		var drift_multiplier := 1.42 if drifting else 1.0
		rotation.y -= steer * stats.steering_speed * steering_factor * drift_multiplier * delta

		forward = -global_transform.basis.z.normalized()
		var lateral := velocity - forward * velocity.dot(forward)
		var traction := stats.drift_grip if drifting else stats.grip
		velocity -= lateral * minf(traction * delta, 1.0)
		velocity *= 1.0 - minf(delta * (0.45 if throttle > 0.0 else 1.5), 0.16)

		if drifting and absf(steer) > 0.12:
			_drift_charge = minf(_drift_charge + delta, DRIFT_LEVEL_TIMES.back())
		elif _drift_charge > 0.0:
			_release_drift()
		velocity.y = -1.0
	else:
		velocity.y -= GRAVITY * delta
		if _drift_charge > 0.0:
			_release_drift()

	move_and_slide()
	_animate_visual(delta, steer, drifting)
	_check_recovery(delta)


func set_drive_input(
	throttle: float,
	brake: float,
	steer: float,
	drift: bool,
	use_item_now: bool
) -> void:
	_throttle_input = clampf(throttle, 0.0, 1.0)
	_brake_input = clampf(brake, 0.0, 1.0)
	_steer_input = clampf(steer, -1.0, 1.0)
	_drift_input = drift
	_use_item_requested = _use_item_requested or use_item_now


func grant_random_item() -> bool:
	if held_item != null or item_catalog == null or item_rng == null:
		return false
	var position := 1
	var total_racers := 1
	if race_manager != null:
		position = race_manager.get_race_position(self)
		total_racers = race_manager.racers.size()
	held_item = item_catalog.draw_item(position, total_racers, item_rng)
	_held_item_elapsed = 0.0
	item_changed.emit(held_item)
	return held_item != null


func use_item() -> void:
	if held_item == null or not is_control_enabled:
		return
	var item_to_use := held_item
	held_item = null
	_held_item_elapsed = 0.0
	item_changed.emit(null)
	var forward := -global_transform.basis.z.normalized()
	var direction := (
		-forward
		if item_to_use.category == ItemDefinition.ItemCategory.TRAP
		else forward
	)
	item_use_requested.emit(item_to_use, direction)


func receive_hit(duration: float) -> HitResult:
	if _invulnerable_remaining > 0.0:
		return HitResult.IGNORED
	if _shield_remaining > 0.0:
		_clear_shield()
		hit_blocked.emit()
		return HitResult.BLOCKED
	_stun_remaining = duration
	_invulnerable_remaining = duration + 1.0
	velocity *= 0.45
	rotation.y += PI * 0.3
	hit_received.emit()
	return HitResult.APPLIED


func activate_boost(duration: float, power: float) -> void:
	_activate_boost(duration, power)


func activate_shield(item: ItemDefinition) -> void:
	if item == null or item.shield_duration <= 0.0:
		return
	_clear_shield()
	_shield_item = item
	_shield_remaining = item.shield_duration
	if item.visual_scene != null:
		_shield_visual = item.visual_scene.instantiate() as Node3D
		if _shield_visual != null:
			add_child(_shield_visual)
	shield_state_changed.emit(
		_shield_item,
		_shield_remaining,
		_shield_item.shield_duration
	)


func get_shield_remaining() -> float:
	return _shield_remaining


func get_held_item_time() -> float:
	return _held_item_elapsed


func request_straight_launch() -> void:
	_straight_launch_requested = true


func consume_straight_launch_request() -> bool:
	var was_requested := _straight_launch_requested
	_straight_launch_requested = false
	return was_requested


func clear_item_effects() -> void:
	held_item = null
	_held_item_elapsed = 0.0
	_straight_launch_requested = false
	_boost_remaining = 0.0
	_clear_shield()
	item_changed.emit(null)


func set_respawn_transform(respawn_transform: Transform3D) -> void:
	_last_valid_transform = respawn_transform


func set_shortcut_surface_enabled(is_enabled: bool) -> void:
	if is_enabled:
		collision_mask |= SHORTCUT_SURFACE_LAYER
	else:
		collision_mask &= ~SHORTCUT_SURFACE_LAYER


func reset_to_last_checkpoint(reason: String = "manual") -> void:
	last_recovery_position = global_position
	last_recovery_reason = reason
	set_shortcut_surface_enabled(false)
	global_transform = _last_valid_transform
	velocity = Vector3.ZERO
	_stuck_time = 0.0
	_movement_sample_time = 0.0
	_movement_sample_distance = 0.0
	_last_motion_position = global_position
	recovery_count += 1
	recovered.emit()


func get_speed_kph() -> int:
	return roundi(Vector3(velocity.x, 0.0, velocity.z).length() * 7.2)


func _read_player_input() -> void:
	set_drive_input(
		Input.get_action_strength(&"accelerate"),
		Input.get_action_strength(&"brake"),
		Input.get_axis(&"steer_left", &"steer_right"),
		Input.is_action_pressed(&"drift"),
		Input.is_action_just_pressed(&"use_item")
	)


func _activate_boost(duration: float, power: float) -> void:
	_boost_remaining = maxf(_boost_remaining, duration)
	var forward := -global_transform.basis.z.normalized()
	velocity += forward * power


func _release_drift() -> void:
	var boost_level := 0
	for threshold in DRIFT_LEVEL_TIMES:
		if _drift_charge >= threshold:
			boost_level += 1
	if boost_level > 0:
		_activate_boost(0.45 + boost_level * 0.22, 3.5 + boost_level * 2.0)
	_drift_charge = 0.0
	boost_changed.emit(0.0)


func _update_timers(delta: float) -> void:
	_boost_remaining = maxf(_boost_remaining - delta, 0.0)
	_stun_remaining = maxf(_stun_remaining - delta, 0.0)
	_invulnerable_remaining = maxf(_invulnerable_remaining - delta, 0.0)
	if held_item != null:
		_held_item_elapsed += delta
	else:
		_held_item_elapsed = 0.0
	if _shield_remaining > 0.0:
		_shield_remaining = maxf(_shield_remaining - delta, 0.0)
		if _shield_remaining <= 0.0:
			_clear_shield()
		else:
			shield_state_changed.emit(
				_shield_item,
				_shield_remaining,
				_shield_item.shield_duration
			)
	if _drift_charge > 0.0:
		boost_changed.emit(_drift_charge / DRIFT_LEVEL_TIMES.back())


func _clear_shield() -> void:
	var previous_item := _shield_item
	_shield_item = null
	_shield_remaining = 0.0
	if _shield_visual != null and is_instance_valid(_shield_visual):
		_shield_visual.queue_free()
	_shield_visual = null
	shield_state_changed.emit(
		previous_item,
		0.0,
		previous_item.shield_duration if previous_item != null else 0.0
	)


func _check_recovery(delta: float) -> void:
	if global_position.y < -2.5:
		reset_to_last_checkpoint("fell")
		return
	var horizontal_motion := Vector2(
		global_position.x - _last_motion_position.x,
		global_position.z - _last_motion_position.z
	).length()
	_last_motion_position = global_position
	if not is_control_enabled or _throttle_input <= 0.5:
		_stuck_time = 0.0
		_movement_sample_time = 0.0
		_movement_sample_distance = 0.0
		return
	_movement_sample_time += delta
	_movement_sample_distance += horizontal_motion
	if _movement_sample_time < 1.25:
		return
	if _movement_sample_distance < 1.2:
		_stuck_time += _movement_sample_time
	else:
		_stuck_time = maxf(_stuck_time - _movement_sample_time * 1.5, 0.0)
	_movement_sample_time = 0.0
	_movement_sample_distance = 0.0
	if _stuck_time >= 3.0:
		reset_to_last_checkpoint("stalled")


func _animate_visual(delta: float, steer: float, drifting: bool) -> void:
	if _visual_root == null:
		return
	var target_roll := -steer * (0.12 if drifting else 0.06)
	_visual_root.rotation.z = lerpf(_visual_root.rotation.z, target_roll, delta * 8.0)
	_visual_root.position.y = sin(Time.get_ticks_msec() * 0.012) * 0.015
	if _stun_remaining > 0.0:
		_visual_root.rotation.y += delta * 8.0
	else:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, 0.0, delta * 10.0)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.55, 0.72, 2.35)
	collision.shape = shape
	collision.position.y = 0.55
	add_child(collision)


func _build_visual() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)

	_add_box(_visual_root, Vector3(1.55, 0.52, 2.2), Vector3(0.0, 0.62, 0.0), body_color)
	_add_box(_visual_root, Vector3(1.25, 0.48, 0.95), Vector3(0.0, 1.0, 0.28), body_color.lightened(0.12))
	_add_box(_visual_root, Vector3(1.15, 0.12, 0.45), Vector3(0.0, 0.88, -1.14), Color("#f5d66f"))

	var driver := MeshInstance3D.new()
	var driver_mesh := SphereMesh.new()
	driver_mesh.radius = 0.34
	driver_mesh.height = 0.68
	driver.mesh = driver_mesh
	driver.position = Vector3(0.0, 1.47, 0.25)
	driver.material_override = _material(Color("#fff0d0"))
	_visual_root.add_child(driver)

	for wheel_x in [-0.87, 0.87]:
		for wheel_z in [-0.68, 0.72]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.34
			wheel_mesh.bottom_radius = 0.34
			wheel_mesh.height = 0.28
			wheel.mesh = wheel_mesh
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(wheel_x, 0.48, wheel_z)
			wheel.material_override = _material(Color("#15282b"))
			_visual_root.add_child(wheel)


func _add_box(parent: Node, size: Vector3, box_position: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = box_position
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material
