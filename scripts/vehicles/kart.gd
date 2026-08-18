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
var item_catalog: ItemCatalog
var item_rng: RandomNumberGenerator
var race_manager: RaceManager
var driving_tuning := DrivingTuningDefinition.new()
var _surface_controller := KartSurfaceController.new()
var _input_controller := KartInputController.new()
var _motor := KartMotor.new()
var _drive_controller := KartDriveController.new()
var current_surface: SurfaceDefinition:
	get:
		return _surface_controller.get_surface()
	set(value):
		_surface_controller.set_surface(value)

var _drive_state := DriveState.AIR
var _recovery_controller := KartRecoveryController.new()
var _collision_response := KartCollisionResponse.new()
var _hit_controller := KartHitController.new()
var _shield_controller: KartShieldController
var _drift_controller := KartDriftController.new()
var _boost_controller := KartBoostController.new()
var _status_timers := KartStatusTimerController.new()
var _item_controller := KartItemController.new()
var _launch_controller := KartLaunchController.new()
var _visual_builder := KartVisualBuilder.new()
var held_item: ItemDefinition:
	get:
		return _item_controller.item
	set(value):
		_item_controller.item = value
var recovery_count: int:
	get:
		return _recovery_controller.recovery_count
var last_recovery_position: Vector3:
	get:
		return _recovery_controller.last_recovery_position
var last_recovery_reason: String:
	get:
		return _recovery_controller.last_recovery_reason
var _visual_root: Node3D
var visual_variant: KartVariantDefinition


func _ready() -> void:
	collision_layer = PhysicsLayers.KARTS
	collision_mask = (
		PhysicsLayers.WORLD
		| PhysicsLayers.MAIN_BARRIERS
		| PhysicsLayers.SHORTCUT_BARRIERS
	)
	floor_snap_length = FLOOR_SNAP_DISTANCE
	floor_max_angle = deg_to_rad(52.0)
	_recovery_controller.setup(self)
	_collision_response.setup(self)
	_hit_controller.setup(self)
	_shield_controller = KartShieldController.new()
	add_child(_shield_controller)
	_shield_controller.setup(self)
	_drift_controller.setup(self)
	_boost_controller.setup(self)
	_input_controller.setup(self)
	_motor.setup(self)
	_drive_controller.setup(self)
	_item_controller.setup(self)
	_launch_controller.setup(self)
	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	_drive_controller.physics_step(delta)


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
	return _drift_controller.get_side()


func get_landing_compression_ratio() -> float:
	return _status_timers.get_landing_compression_ratio(LANDING_COMPRESSION_DURATION)


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func is_boost_active() -> bool:
	return _boost_controller.is_active()

func get_boost_power_ratio() -> float:
	return clampf(_boost_controller.get_power() / maxf(stats.max_speed * 0.5, 0.1), 0.0, 1.0) if is_boost_active() else 0.0

func get_current_surface() -> SurfaceDefinition:
	return current_surface

func get_throttle_input() -> float:
	return _input_controller.get_throttle()

func get_brake_input() -> float:
	return _input_controller.get_brake()

func is_launch_bogged() -> bool:
	return _status_timers.is_launch_bogged()

func get_drift_quality() -> float:
	return _drift_controller.get_presentation_quality()

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
	return KartMotor.get_steering_factor(speed, maximum_speed)


static func get_acceleration_factor(speed: float, maximum_speed: float) -> float:
	return KartMotor.get_acceleration_factor(speed, maximum_speed)


static func get_rolling_resistance(speed: float) -> float:
	return KartMotor.get_rolling_resistance(speed)


static func calculate_barrier_velocity(
	incoming_velocity: Vector3,
	collision_normal: Vector3
) -> Vector3:
	return KartMotor.calculate_barrier_velocity(incoming_velocity, collision_normal)


func _try_start_drift_hop(steer: float) -> bool:
	return _drift_controller.try_start_hop(steer)


func _apply_ground_drive(delta: float, throttle: float, brake: float, steer: float) -> void:
	_motor.apply_ground_drive(delta, throttle, brake, steer)


func _apply_air_drive(delta: float, steer: float, hop_started: bool) -> void:
	_motor.apply_air_drive(delta, steer, hop_started)


func _apply_soft_speed_limit(horizontal_velocity: Vector3, delta: float) -> Vector3:
	return _motor.apply_soft_speed_limit(horizontal_velocity, delta)


func _update_floor_snap() -> void:
	_motor.update_floor_snap()


func set_drive_input(
	throttle: float,
	brake: float,
	steer: float,
	drift: bool,
	use_item_now: bool
) -> void:
	_input_controller.set_frame(throttle, brake, steer, drift, use_item_now)


func get_drive_input_frame() -> Dictionary:
	return _input_controller.get_last_frame()


func grant_random_item() -> bool:
	return _item_controller.grant_random_item()


func use_item() -> void:
	_item_controller.use_item()


func receive_hit(duration: float, threat: Node = null) -> HitResult:
	return _hit_controller.receive_hit(duration, threat)


func activate_boost(duration: float, power: float) -> void:
	_activate_boost(duration, power * _get_boost_multiplier() * current_surface.boost_multiplier)


func set_surface(value: SurfaceDefinition) -> void:
	_surface_controller.set_surface(value)

func enter_surface_zone(zone: Node) -> void:
	_surface_controller.enter_zone(zone)

func exit_surface_zone(zone: Node) -> void:
	_surface_controller.exit_zone(zone)


func resolve_launch_boost(enabled: bool) -> int:
	return _launch_controller.resolve(enabled)

func register_launch_crossing(relative_time: float) -> void:
	_launch_controller.register_crossing(relative_time)

func can_receive_kart_interaction() -> bool:
	return is_control_enabled and not _status_timers.is_stunned() and not _status_timers.is_invulnerable()

func is_braking() -> bool:
	return _input_controller.get_brake() > 0.05


func activate_shield(item: ItemDefinition) -> void:
	_shield_controller.activate(item)


func get_shield_remaining() -> float:
	return _shield_controller.get_remaining() if _shield_controller != null else 0.0


func get_held_item_time() -> float:
	return _item_controller.elapsed


func request_straight_launch() -> void:
	_launch_controller.request_straight_launch()


func consume_straight_launch_request() -> bool:
	return _launch_controller.consume_straight_launch_request()


func clear_item_effects() -> void:
	_item_controller.clear()
	_boost_controller.clear()
	if _shield_controller != null:
		_shield_controller.clear_shield()
	item_changed.emit(null)


func set_respawn_transform(respawn_transform: Transform3D) -> void:
	_recovery_controller.set_respawn_transform(respawn_transform)


func _reset_recovery_sampling() -> void:
	if _recovery_controller != null:
		_recovery_controller.reset_sampling()


func set_shortcut_surface_enabled(is_enabled: bool) -> void:
	if is_enabled:
		collision_mask |= SHORTCUT_SURFACE_LAYER
	else:
		collision_mask &= ~SHORTCUT_SURFACE_LAYER


func reset_to_last_checkpoint(reason: String = "manual") -> void:
	_recovery_controller.reset_to_last_checkpoint(reason)


func is_drifting_for_ghost() -> bool:
	return _drive_state == DriveState.DRIFT


func is_boosting_for_ghost() -> bool:
	return _boost_controller.is_active()


func get_speed_kph() -> int:
	return roundi(Vector3(velocity.x, 0.0, velocity.z).length() * 7.2)


func _activate_boost(duration: float, power: float) -> void:
	_boost_controller.activate(duration, power)


func _release_drift() -> void:
	_drift_controller.release()


func _get_boost_multiplier() -> float:
	return race_class.boost_multiplier if race_class != null else 1.0


func _update_timers(delta: float) -> void:
	_boost_controller.update(delta)
	_drift_controller.update(delta)
	_status_timers.update(delta)
	_collision_response.update(delta)
	_item_controller.update(delta)
	_shield_controller.update(delta)
	if _drift_controller.get_charge() > 0.0:
		boost_changed.emit(_drift_controller.get_charge() / driving_tuning.drift_level_times[-1])


func _animate_visual(delta: float, steer: float, drifting: bool) -> void:
	for child in get_children():
		if child is KartVisualFeedback:
			child.animate_vehicle(
				_visual_root,
				delta,
				steer,
				drifting,
				get_landing_compression_ratio(),
				_status_timers.is_stunned()
			)
			return


func _build_collision() -> void:
	_visual_builder.build_collision(self)


func _build_visual() -> void:
	_visual_root = _visual_builder.build_visual(self)
