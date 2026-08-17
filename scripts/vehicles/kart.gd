class_name Kart
extends CharacterBody3D

signal item_changed(item: ItemDefinition)
signal boost_changed(charge_ratio: float)
signal drift_charge_changed(level: int, ratio: float, quality: float)
signal hit_received
signal barrier_contact(normal: Vector3, incident_ratio: float, continuing_contact: bool)
signal hit_blocked(threat: Node)
signal recovered
signal presentation_boost_started(power_ratio: float)
signal presentation_landed(intensity: float)
signal presentation_launch_bogged
signal mini_turbo_released(level: int)
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

enum DriveState {
	GROUND,
	DRIFT_HOP,
	DRIFT,
	AIR,
}

const GRAVITY := 22.0
const DRIFT_LEVEL_TIMES := [0.65, 1.25, 1.9] # Compatibilidad con pruebas y HUD antiguos.
const SHORTCUT_SURFACE_LAYER := PhysicsLayers.SHORTCUTS
const DRIFT_MINIMUM_SPEED := 7.0
const DRIFT_HOP_SPEED := 4.2
const FLOOR_SNAP_DISTANCE := 0.35
const MAXIMUM_SNAP_FALL_SPEED := 6.0
const AIR_STEERING_RATIO := 0.3
const LANDING_COMPRESSION_DURATION := 0.18
const SOFT_LIMIT_START_RATIO := 0.95
const SOFT_LIMIT_RESPONSE := 10.0
const ROLLING_RESISTANCE_BASE := 0.55
const ROLLING_RESISTANCE_SPEED_FACTOR := 0.035
const BARRIER_CONTACT_MEMORY := 0.14
const COLLISION_SIZE := Vector3(1.5, 0.74, 2.5)
const VEHICLE_COLORMAP: Texture2D = preload("res://assets/vendor/kenney/car-kit/Textures/colormap.png")

@export var racer_name := "Piloto"
@export var racer_id: StringName
@export var is_player := false
@export var body_color := Color("#ff6b4a")
var participant_slot := -1
var local_player_index := -1
var network_peer_id := 0
var input_source: RacerInputSource
var allow_item_execution := true

var stats := KartStats.new()
var race_class: RaceClassDefinition
var is_control_enabled := false
var held_item: ItemDefinition
var item_catalog: ItemCatalog
var item_rng: RandomNumberGenerator
var race_manager: RaceManager
var driving_tuning := DrivingTuningDefinition.new()
var current_surface := SurfaceDefinition.asphalt()
var _surface_zones := {}
var recovery_count := 0
var last_recovery_position := Vector3.ZERO
var last_recovery_reason := ""

var _throttle_input := 0.0
var _brake_input := 0.0
var _steer_input := 0.0
var _drift_input := false
var _previous_drift_input := false
var _use_item_requested := false
var _drift_charge := 0.0
var _drift_side := 0.0
var _drive_state := DriveState.AIR
var _boost_remaining := 0.0
var _boost_power := 0.0
var _drift_low_quality_time := 0.0
var _drift_grace_remaining := 0.0
var _launch_crossing := INF
var _launch_resolved := false
var _launch_bog_remaining := 0.0
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
var visual_variant: KartVariantDefinition
var _landing_compression_remaining := 0.0
var _barrier_contact_remaining := 0.0
var _last_barrier_normal := Vector3.ZERO
var _presentation_drift_quality := 0.0
var _last_input_frame := RacerInputSource.empty_frame()


func _ready() -> void:
	collision_layer = PhysicsLayers.KARTS
	collision_mask = (
		PhysicsLayers.WORLD
		| PhysicsLayers.MAIN_BARRIERS
		| PhysicsLayers.SHORTCUT_BARRIERS
	)
	floor_snap_length = FLOOR_SNAP_DISTANCE
	floor_max_angle = deg_to_rad(52.0)
	_last_valid_transform = global_transform
	_last_motion_position = global_position
	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	if input_source != null:
		_read_input_source()
	elif is_player:
		_read_player_input()
	if _use_item_requested:
		_use_item_requested = false
		if allow_item_execution:
			use_item()

	var can_drive := is_control_enabled and _stun_remaining <= 0.0
	_capture_launch_input()
	var throttle := _throttle_input if can_drive and _launch_bog_remaining <= 0.0 else 0.0
	var brake := _brake_input if can_drive else 0.0
	var steer := _steer_input if can_drive else 0.0
	var was_on_floor := is_on_floor()
	var drift_was_pressed := _drift_input and not _previous_drift_input
	_previous_drift_input = _drift_input
	if not can_drive and _drift_side != 0.0:
		_release_drift()
	if was_on_floor and _drive_state == DriveState.AIR:
		_drive_state = (
			DriveState.DRIFT
			if _drift_input and _drift_side != 0.0
			else DriveState.GROUND
		)

	var hop_started := false
	if was_on_floor and drift_was_pressed and can_drive:
		hop_started = _try_start_drift_hop(steer)
	if not _drift_input and _drift_side != 0.0:
		_release_drift()

	var is_ground_driving := was_on_floor and _drive_state != DriveState.DRIFT_HOP
	if is_ground_driving:
		_apply_ground_drive(delta, throttle, brake, steer)
	else:
		_apply_air_drive(delta, steer, hop_started)
	if _drive_state == DriveState.DRIFT and _drift_input:
		_update_drift_charge(delta, steer)

	_update_floor_snap()
	var velocity_before_move := velocity
	move_and_slide()
	_process_barrier_collisions(velocity_before_move)
	_update_drive_state_after_move(was_on_floor)
	var is_drifting := (
		_drive_state == DriveState.DRIFT
		or _drive_state == DriveState.DRIFT_HOP
	)
	_animate_visual(delta, steer, is_drifting)
	_check_recovery(delta)


func configure_for_race(
	base_stats: KartStats,
	definition: RaceClassDefinition,
	tuning: DrivingTuningDefinition = null
) -> void:
	race_class = definition if definition != null else RaceClassDefinition.get_default()
	stats = race_class.apply_to(base_stats)
	driving_tuning = tuning if tuning != null else DrivingTuningDefinition.new()


func get_drive_state() -> DriveState:
	return _drive_state


func get_drift_side() -> float:
	return _drift_side


func get_landing_compression_ratio() -> float:
	return clampf(
		_landing_compression_remaining / LANDING_COMPRESSION_DURATION,
		0.0,
		1.0
	)


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func is_boost_active() -> bool:
	return _boost_remaining > 0.0

func get_boost_power_ratio() -> float:
	return clampf(_boost_power / maxf(stats.max_speed * 0.5, 0.1), 0.0, 1.0) if is_boost_active() else 0.0

func get_current_surface() -> SurfaceDefinition:
	return current_surface

func get_throttle_input() -> float:
	return _throttle_input

func get_brake_input() -> float:
	return _brake_input

func is_launch_bogged() -> bool:
	return _launch_bog_remaining > 0.0

func get_drift_quality() -> float:
	return _presentation_drift_quality

func get_lateral_speed_ratio() -> float:
	var local_velocity := global_transform.basis.inverse() * velocity
	return clampf(absf(local_velocity.x) / maxf(stats.max_speed * 0.3, 0.1), 0.0, 1.0)

func get_surface_audio_pitch() -> float:
	return current_surface.audio_pitch if current_surface != null else 1.0

func get_surface_audio_volume() -> float:
	return current_surface.audio_volume if current_surface != null else 0.75

func get_surface_audio_roughness() -> float:
	return current_surface.audio_roughness if current_surface != null else 0.15

func get_surface_particle_color() -> Color:
	return current_surface.particle_color if current_surface != null else Color.WHITE


static func get_steering_factor(speed: float, maximum_speed: float) -> float:
	var speed_ratio := clampf(absf(speed) / maxf(maximum_speed, 0.1), 0.0, 1.0)
	if speed_ratio <= 0.4:
		return lerpf(0.45, 1.0, speed_ratio / 0.4)
	var high_speed_weight := (speed_ratio - 0.4) / 0.6
	return lerpf(1.0, 0.72, high_speed_weight)


static func get_acceleration_factor(speed: float, maximum_speed: float) -> float:
	var speed_ratio := clampf(maxf(speed, 0.0) / maxf(maximum_speed, 0.1), 0.0, 1.2)
	return maxf(1.0 - 0.82 * pow(speed_ratio, 1.5), 0.12)


static func get_rolling_resistance(speed: float) -> float:
	return ROLLING_RESISTANCE_BASE + maxf(speed, 0.0) * ROLLING_RESISTANCE_SPEED_FACTOR


static func calculate_barrier_velocity(
	incoming_velocity: Vector3,
	collision_normal: Vector3
) -> Vector3:
	var horizontal_velocity := Vector3(
		incoming_velocity.x,
		0.0,
		incoming_velocity.z
	)
	var incoming_speed := horizontal_velocity.length()
	var wall_normal := Vector3(collision_normal.x, 0.0, collision_normal.z).normalized()
	if incoming_speed <= 0.001 or wall_normal.is_zero_approx():
		return incoming_velocity
	var incident_ratio := clampf(
		-horizontal_velocity.normalized().dot(wall_normal),
		0.0,
		1.0
	)
	var retention := 1.0
	if incident_ratio <= 0.2:
		retention = lerpf(1.0, 0.85, incident_ratio / 0.2)
	else:
		var frontal_weight := clampf(
			inverse_lerp(0.2, 0.8, incident_ratio),
			0.0,
			1.0
		)
		retention = lerpf(0.85, 0.55, frontal_weight)
	var retained_speed := incoming_speed * retention
	var tangent := horizontal_velocity.slide(wall_normal)
	if tangent.length_squared() <= 0.0001:
		tangent = wall_normal.cross(Vector3.UP)
		if tangent.dot(horizontal_velocity) < 0.0:
			tangent = -tangent
	var result := tangent.normalized() * retained_speed
	result.y = incoming_velocity.y
	return result


func _try_start_drift_hop(steer: float) -> bool:
	var forward := -global_transform.basis.z.normalized()
	var forward_speed := Vector3(velocity.x, 0.0, velocity.z).dot(forward)
	if absf(forward_speed) <= DRIFT_MINIMUM_SPEED:
		return false
	_drift_side = 1.0 if steer >= 0.0 else -1.0
	_drive_state = DriveState.DRIFT_HOP
	_drift_grace_remaining = driving_tuning.hop_grace
	velocity.y = DRIFT_HOP_SPEED
	floor_snap_length = 0.0
	return true


func _apply_ground_drive(
	delta: float,
	throttle: float,
	brake: float,
	steer: float
) -> void:
	var forward := -global_transform.basis.z.normalized()
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed := horizontal_velocity.dot(forward)
	if brake > 0.0:
		if forward_speed > 0.5:
			var braked_speed := move_toward(
				forward_speed,
				0.0,
				stats.braking * brake * delta
			)
			velocity += forward * (braked_speed - forward_speed)
		else:
			velocity -= forward * stats.braking * 0.36 * brake * delta
	elif throttle > 0.0:
		var acceleration_factor := get_acceleration_factor(
			forward_speed,
			stats.max_speed
		)
		velocity += forward * stats.acceleration * current_surface.acceleration_multiplier * acceleration_factor * throttle * delta

	var speed := Vector2(velocity.x, velocity.z).length()
	var steering_factor := get_steering_factor(speed, stats.max_speed)
	var steering_command := steer
	var is_drifting := _drive_state == DriveState.DRIFT
	if is_drifting:
		var is_turning_inward := steer * _drift_side >= 0.0
		var countersteer_scale := 1.08 if is_turning_inward else 0.72
		steering_command = clampf(
			_drift_side * 0.3 + steer * countersteer_scale,
			-1.35,
			1.35
		)
	var yaw_change := (
		steering_command
		* stats.steering_speed
		* steering_factor
		* delta
	)
	rotation.y -= yaw_change

	forward = -global_transform.basis.z.normalized()
	horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	if not horizontal_velocity.is_zero_approx():
		var tire_response := (
			0.18
			if is_drifting
			else clampf(stats.grip / 9.2, 0.78, 1.08)
		)
		horizontal_velocity = horizontal_velocity.rotated(
			Vector3.UP,
			-yaw_change * tire_response
		)
	var lateral_velocity := horizontal_velocity - forward * horizontal_velocity.dot(forward)
	var traction := (
		stats.drift_grip * current_surface.drift_grip_multiplier
		if is_drifting else stats.grip * current_surface.grip_multiplier
	)
	horizontal_velocity -= lateral_velocity * minf(traction * delta, 1.0)

	var resistance_scale := 0.35 if throttle > 0.0 and brake <= 0.0 else 1.0
	var resistance := get_rolling_resistance(horizontal_velocity.length()) * resistance_scale * current_surface.rolling_resistance_multiplier
	horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, resistance * delta)
	horizontal_velocity = _apply_soft_speed_limit(horizontal_velocity, delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _apply_air_drive(delta: float, steer: float, hop_started: bool) -> void:
	if not hop_started:
		velocity.y -= GRAVITY * delta
	var speed := Vector2(velocity.x, velocity.z).length()
	var steering_factor := get_steering_factor(speed, stats.max_speed)
	var yaw_change := (
		steer
		* stats.steering_speed
		* steering_factor
		* AIR_STEERING_RATIO
		* delta
	)
	rotation.y -= yaw_change
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if not horizontal_velocity.is_zero_approx():
		horizontal_velocity = horizontal_velocity.rotated(Vector3.UP, -yaw_change)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z


func _apply_soft_speed_limit(
	horizontal_velocity: Vector3,
	delta: float
) -> Vector3:
	var speed_limit := stats.max_speed
	if _boost_remaining > 0.0:
		speed_limit += _boost_power
	var forward := -global_transform.basis.z.normalized()
	var forward_speed := horizontal_velocity.dot(forward)
	var soft_limit := speed_limit * SOFT_LIMIT_START_RATIO
	if forward_speed > soft_limit:
		var reduction := (
			(forward_speed - soft_limit)
			* minf(SOFT_LIMIT_RESPONSE * delta, 1.0)
		)
		horizontal_velocity -= forward * reduction
	elif forward_speed < -stats.reverse_speed:
		horizontal_velocity -= forward * (forward_speed + stats.reverse_speed)
	return horizontal_velocity


func _update_floor_snap() -> void:
	var can_snap := (
		_drive_state != DriveState.DRIFT_HOP
		and velocity.y <= 0.05
		and velocity.y >= -MAXIMUM_SNAP_FALL_SPEED
	)
	floor_snap_length = FLOOR_SNAP_DISTANCE if can_snap else 0.0


func _process_barrier_collisions(incoming_velocity: Vector3) -> void:
	var strongest_incident_ratio := -1.0
	var strongest_normal := Vector3.ZERO
	var horizontal_incoming := Vector3(
		incoming_velocity.x,
		0.0,
		incoming_velocity.z
	)
	if horizontal_incoming.is_zero_approx():
		return
	var resolved_vertical_velocity := velocity.y
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var collider := collision.get_collider() as CollisionObject3D
		if collider == null or (collider.collision_layer & PhysicsLayers.BARRIERS) == 0:
			continue
		var collision_normal := collision.get_normal()
		if absf(collision_normal.y) > 0.45:
			continue
		var wall_normal := Vector3(
			collision_normal.x,
			0.0,
			collision_normal.z
		).normalized()
		var incident_ratio := clampf(
			-horizontal_incoming.normalized().dot(wall_normal),
			0.0,
			1.0
		)
		if incident_ratio > strongest_incident_ratio:
			strongest_incident_ratio = incident_ratio
			strongest_normal = collision_normal
	if strongest_incident_ratio >= 0.0:
		var normalized_wall := Vector3(
			strongest_normal.x,
			0.0,
			strongest_normal.z
		).normalized()
		var is_continuing_contact := (
			_barrier_contact_remaining > 0.0
			and normalized_wall.dot(_last_barrier_normal) > 0.82
		)
		if is_continuing_contact:
			var tangent := horizontal_incoming.slide(normalized_wall)
			if not tangent.is_zero_approx():
				var horizontal_speed := horizontal_incoming.length()
				var guided_tangent := (
					tangent.normalized() + normalized_wall * 0.08
				).normalized()
				velocity.x = guided_tangent.x * horizontal_speed
				velocity.z = guided_tangent.z * horizontal_speed
		else:
			velocity = calculate_barrier_velocity(incoming_velocity, strongest_normal)
			velocity.y = resolved_vertical_velocity
		var slide_speed := Vector2(velocity.x, velocity.z).length()
		var minimum_slide_speed := minf(stats.max_speed * 0.2, 6.0)
		if (
			is_continuing_contact
			and maxf(_throttle_input, _brake_input) > 0.5
			and slide_speed < minimum_slide_speed
		):
			var escape_tangent := normalized_wall.cross(Vector3.UP).normalized()
			var forward := -global_transform.basis.z.normalized()
			var powered_direction := (
				forward if _throttle_input >= _brake_input else -forward
			)
			if escape_tangent.dot(powered_direction) < 0.0:
				escape_tangent = -escape_tangent
			velocity.x = escape_tangent.x * minimum_slide_speed
			velocity.z = escape_tangent.z * minimum_slide_speed
			_align_with_barrier_tangent(0.5)
		else:
			_align_with_barrier_tangent(0.18 if is_continuing_contact else 0.08)
		_last_barrier_normal = normalized_wall
		_barrier_contact_remaining = BARRIER_CONTACT_MEMORY
		barrier_contact.emit(
			normalized_wall,
			strongest_incident_ratio,
			is_continuing_contact
		)


func _align_with_barrier_tangent(weight: float) -> void:
	var travel_direction := Vector3(velocity.x, 0.0, velocity.z)
	if travel_direction.length_squared() <= 0.01:
		return
	travel_direction = travel_direction.normalized()
	var target_yaw := atan2(-travel_direction.x, -travel_direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(weight, 0.0, 1.0))


func _update_drive_state_after_move(was_on_floor: bool) -> void:
	if is_on_floor():
		if not was_on_floor:
			presentation_landed.emit(clampf(absf(velocity.y) / 12.0, 0.0, 1.0))
			var landed_from_drift_hop := _drive_state == DriveState.DRIFT_HOP
			_stabilize_landing()
			_landing_compression_remaining = LANDING_COMPRESSION_DURATION
			_drive_state = (
				DriveState.DRIFT
				if _drift_input and _drift_side != 0.0
				else DriveState.GROUND
			)
			if landed_from_drift_hop and _drive_state == DriveState.DRIFT:
				_drift_grace_remaining = driving_tuning.hop_grace
	elif _drive_state != DriveState.DRIFT_HOP:
		_drive_state = DriveState.AIR


func _stabilize_landing() -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal_velocity.length()
	if speed <= 0.1:
		return
	var forward := -global_transform.basis.z.normalized()
	if horizontal_velocity.normalized().dot(forward) <= 0.0:
		return
	var stable_direction := horizontal_velocity.normalized().slerp(forward, 0.14).normalized()
	velocity.x = stable_direction.x * speed
	velocity.z = stable_direction.z * speed


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
	_last_input_frame = {
		"throttle": _throttle_input,
		"brake": _brake_input,
		"steer": _steer_input,
		"drift": _drift_input,
		"use_item": use_item_now,
	}


func get_drive_input_frame() -> Dictionary:
	return _last_input_frame.duplicate()


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


func receive_hit(duration: float, threat: Node = null) -> HitResult:
	if _invulnerable_remaining > 0.0:
		return HitResult.IGNORED
	if _shield_remaining > 0.0:
		_clear_shield()
		hit_blocked.emit(threat)
		return HitResult.BLOCKED
	_stun_remaining = duration
	_invulnerable_remaining = duration + 1.0
	velocity *= 0.45
	rotation.y += PI * 0.3
	hit_received.emit()
	return HitResult.APPLIED


func activate_boost(duration: float, power: float) -> void:
	_activate_boost(duration, power * _get_boost_multiplier() * current_surface.boost_multiplier)


func set_surface(value: SurfaceDefinition) -> void:
	current_surface = value if value != null else SurfaceDefinition.asphalt()

func enter_surface_zone(zone: Node) -> void:
	_surface_zones[zone.get_instance_id()] = zone
	_refresh_surface()

func exit_surface_zone(zone: Node) -> void:
	_surface_zones.erase(zone.get_instance_id())
	_refresh_surface()

func _refresh_surface() -> void:
	var selected: Node
	for value in _surface_zones.values():
		var zone := value as Node
		if is_instance_valid(zone) and zone.is_better_than(selected):
			selected = zone
	set_surface(selected.get("surface") as SurfaceDefinition if selected != null else null)


func resolve_launch_boost(enabled: bool) -> int:
	if _launch_resolved or not enabled:
		_launch_resolved = true
		return 0
	_launch_resolved = true
	var crossing := _launch_crossing
	if crossing < driving_tuning.launch_early_limit:
		_launch_bog_remaining = driving_tuning.launch_bog_duration
		presentation_launch_bogged.emit()
		return -1
	if crossing >= driving_tuning.launch_perfect_start and crossing <= 0.0:
		_activate_boost(driving_tuning.launch_perfect_duration, driving_tuning.launch_boost_power)
		return 2
	if crossing >= driving_tuning.launch_good_start and crossing < driving_tuning.launch_perfect_start:
		_activate_boost(driving_tuning.launch_good_duration, driving_tuning.launch_boost_power)
		return 1
	return 0

func register_launch_crossing(relative_time: float) -> void:
	if is_inf(_launch_crossing):
		_launch_crossing = relative_time

func can_receive_kart_interaction() -> bool:
	return is_control_enabled and _stun_remaining <= 0.0 and _invulnerable_remaining <= 0.0

func is_braking() -> bool:
	return _brake_input > 0.05


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
	_boost_power = 0.0
	_clear_shield()
	item_changed.emit(null)


func set_respawn_transform(respawn_transform: Transform3D) -> void:
	_last_valid_transform = respawn_transform
	# A new checkpoint may be assigned immediately after a teleport (tests,
	# respawns and shortcut transitions). Do not carry motion samples from the
	# previous position into the new recovery window.
	_reset_recovery_sampling()


func _reset_recovery_sampling() -> void:
	_stuck_time = 0.0
	_movement_sample_time = 0.0
	_movement_sample_distance = 0.0
	_last_motion_position = global_position


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
	_drive_state = DriveState.AIR
	_drift_side = 0.0
	_drift_charge = 0.0
	_drift_low_quality_time = 0.0
	_previous_drift_input = _drift_input
	_landing_compression_remaining = 0.0
	_barrier_contact_remaining = 0.0
	_last_barrier_normal = Vector3.ZERO
	floor_snap_length = 0.0
	_reset_recovery_sampling()
	recovery_count += 1
	recovered.emit()


func is_drifting_for_ghost() -> bool:
	return _drive_state == DriveState.DRIFT


func is_boosting_for_ghost() -> bool:
	return _boost_remaining > 0.0


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


func _read_input_source() -> void:
	var frame := input_source.sample()
	set_drive_input(
		float(frame.get("throttle", 0.0)),
		float(frame.get("brake", 0.0)),
		float(frame.get("steer", 0.0)),
		bool(frame.get("drift", false)),
		bool(frame.get("use_item", false))
	)


func _activate_boost(duration: float, power: float) -> void:
	var previous_power := _boost_power if _boost_remaining > 0.0 else 0.0
	_boost_remaining = maxf(_boost_remaining, duration)
	_boost_power = maxf(_boost_power, power)
	var forward := -global_transform.basis.z.normalized()
	velocity += forward * maxf(power - previous_power, 0.0)
	if power > previous_power:
		presentation_boost_started.emit(clampf(power / maxf(stats.max_speed * 0.5, 0.1), 0.0, 1.0))


func _release_drift() -> void:
	var boost_level := _get_drift_level()
	if boost_level > 0:
		_activate_boost(
			driving_tuning.mini_turbo_durations[boost_level - 1] * stats.mini_turbo_duration_multiplier * _get_boost_multiplier(),
			driving_tuning.mini_turbo_powers[boost_level - 1] * _get_boost_multiplier() * current_surface.boost_multiplier
		)
		mini_turbo_released.emit(boost_level)
	_drift_charge = 0.0
	_drift_low_quality_time = 0.0
	_drift_side = 0.0
	_presentation_drift_quality = 0.0
	if _drive_state == DriveState.DRIFT:
		_drive_state = DriveState.GROUND
	boost_changed.emit(0.0)
	drift_charge_changed.emit(0, 0.0, 0.0)


func _update_drift_charge(delta: float, steer: float) -> void:
	var local_velocity := global_transform.basis.inverse() * velocity
	var steer_quality := clampf(inverse_lerp(0.12, 0.55, absf(steer)), 0.0, 1.0)
	var slip_quality := clampf(inverse_lerp(0.3, 1.8, absf(local_velocity.x)), 0.0, 1.0)
	var quality := minf(steer_quality, slip_quality)
	_presentation_drift_quality = quality
	if _drift_grace_remaining > 0.0:
		quality = maxf(quality, driving_tuning.minimum_drift_quality)
	if quality >= driving_tuning.minimum_drift_quality:
		_drift_low_quality_time = 0.0
		var rate := lerpf(0.5, 1.0, inverse_lerp(driving_tuning.minimum_drift_quality, 1.0, quality))
		_drift_charge = minf(_drift_charge + delta * rate, driving_tuning.drift_level_times[-1])
	else:
		_drift_low_quality_time += delta
		if _drift_low_quality_time > driving_tuning.low_quality_grace:
			_drift_charge = maxf(_drift_charge - driving_tuning.charge_loss_per_second * delta, 0.0)
		if _drift_low_quality_time >= driving_tuning.low_quality_cancel:
			_cancel_drift()
			return
	var level := _get_drift_level()
	var previous := 0.0 if level == 0 else driving_tuning.drift_level_times[level - 1]
	var next := driving_tuning.drift_level_times[min(level, driving_tuning.drift_level_times.size() - 1)]
	var ratio := clampf(inverse_lerp(previous, next, _drift_charge), 0.0, 1.0)
	drift_charge_changed.emit(level, ratio, quality)


func _get_drift_level() -> int:
	var level := 0
	for threshold in driving_tuning.drift_level_times:
		if _drift_charge >= threshold:
			level += 1
	return level


func _cancel_drift() -> void:
	_drift_charge = 0.0
	_drift_low_quality_time = 0.0
	_drift_side = 0.0
	_presentation_drift_quality = 0.0
	_drive_state = DriveState.GROUND if is_on_floor() else DriveState.AIR
	boost_changed.emit(0.0)
	drift_charge_changed.emit(0, 0.0, 0.0)


func _capture_launch_input() -> void:
	if race_manager == null or race_manager.state != RaceManager.RaceState.COUNTDOWN:
		return
	if is_inf(_launch_crossing) and _throttle_input > driving_tuning.launch_throttle_threshold:
		_launch_crossing = -race_manager.get_countdown_remaining()


func _get_boost_multiplier() -> float:
	return race_class.boost_multiplier if race_class != null else 1.0


func _update_timers(delta: float) -> void:
	_boost_remaining = maxf(_boost_remaining - delta, 0.0)
	if _boost_remaining <= 0.0:
		_boost_power = 0.0
	_launch_bog_remaining = maxf(_launch_bog_remaining - delta, 0.0)
	_drift_grace_remaining = maxf(_drift_grace_remaining - delta, 0.0)
	_stun_remaining = maxf(_stun_remaining - delta, 0.0)
	_invulnerable_remaining = maxf(_invulnerable_remaining - delta, 0.0)
	_landing_compression_remaining = maxf(
		_landing_compression_remaining - delta,
		0.0
	)
	_barrier_contact_remaining = maxf(_barrier_contact_remaining - delta, 0.0)
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
		boost_changed.emit(_drift_charge / driving_tuning.drift_level_times[-1])


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
	var landing_ratio := get_landing_compression_ratio()
	_visual_root.position.y = (
		sin(Time.get_ticks_msec() * 0.012) * 0.015
		- landing_ratio * 0.08
	)
	_visual_root.scale = Vector3(
		1.0 + landing_ratio * 0.025,
		1.0 - landing_ratio * 0.08,
		1.0 + landing_ratio * 0.025
	)
	if _stun_remaining > 0.0:
		_visual_root.rotation.y += delta * 8.0
	else:
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, 0.0, delta * 10.0)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = COLLISION_SIZE
	collision.shape = shape
	collision.position.y = 0.57
	add_child(collision)


func _build_visual() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)
	if visual_variant != null and visual_variant.visual_scene != null:
		var custom_visual := visual_variant.visual_scene.instantiate() as Node3D
		if custom_visual != null:
			_visual_root.add_child(custom_visual)
			_apply_vehicle_colormap(custom_visual)
			return

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


func _apply_vehicle_colormap(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
			var material := source.duplicate() as BaseMaterial3D if source != null else StandardMaterial3D.new()
			material.albedo_texture = VEHICLE_COLORMAP
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			material.roughness = 0.72
			mesh_instance.set_surface_override_material(surface_index, material)


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
