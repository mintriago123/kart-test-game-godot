class_name AiDriver
extends Node

@export var lane_offset := 0.0
@export var caution := 0.5

var kart: Kart
var race_manager: RaceManager
var _item_cooldown := 2.0
var _last_checkpoint_index := -1
var _best_checkpoint_distance := INF
var _checkpoint_stall_time := 0.0
var _observed_item: ItemDefinition
var _held_item_time := 0.0


func setup(controlled_kart: Kart, manager: RaceManager, offset: float) -> void:
	kart = controlled_kart
	race_manager = manager
	lane_offset = offset


func _physics_process(delta: float) -> void:
	if kart == null or race_manager == null or race_manager.route_points.is_empty():
		return
	_item_cooldown = maxf(_item_cooldown - delta, 0.0)
	_update_held_item_time(delta)
	var next_index := race_manager.get_next_checkpoint_index(kart)
	var next_checkpoint := race_manager.route_points[next_index]
	var checkpoint_distance := kart.global_position.distance_to(next_checkpoint)
	if _update_progress_recovery(delta, next_index, checkpoint_distance):
		return
	var speed := Vector2(kart.velocity.x, kart.velocity.z).length()
	var speed_ratio := clampf(speed / maxf(kart.stats.max_speed, 0.1), 0.0, 1.2)
	var high_speed_class := (
		kart.race_class != null and kart.race_class.id == &"200"
	)
	var lookahead_steps := clampi(
		2 + roundi(speed_ratio * 1.5) + (1 if high_speed_class else 0),
		2,
		5
	)
	var lookahead_index := (next_index + lookahead_steps) % race_manager.route_points.size()
	var target := race_manager.route_points[lookahead_index]
	var segment_direction := (
		race_manager.route_points[(lookahead_index + 1) % race_manager.route_points.size()]
		- race_manager.route_points[lookahead_index]
	).normalized()
	var right := Vector3.UP.cross(segment_direction).normalized()
	target += right * lane_offset

	var forward := -kart.global_transform.basis.z.normalized()
	var to_target := (target - kart.global_position).normalized()
	var steer := clampf(-forward.cross(to_target).y * 2.2, -1.0, 1.0)
	var alignment := forward.dot(to_target)
	var brake := 0.0
	var throttle := 1.0
	var corner_alignment_threshold := 0.69 + (0.06 if high_speed_class else 0.0)
	var corner_speed_ratio := 0.67 + caution * 0.1 - (0.07 if high_speed_class else 0.0)
	if alignment < -0.1:
		throttle = 0.0
		brake = 1.0 if speed > kart.stats.max_speed * 0.08 else 0.7
		if speed <= kart.stats.max_speed * 0.08:
			steer = -steer
	elif alignment < corner_alignment_threshold and speed > kart.stats.max_speed * corner_speed_ratio:
		brake = 0.7 if high_speed_class else 0.55
		throttle = 0.15 if high_speed_class else 0.25
	elif alignment < 0.82:
		throttle = 0.72
	var should_drift := (
		absf(steer) > 0.48
		and speed > kart.stats.max_speed * 0.38
		and checkpoint_distance < maxf(18.0, speed * (1.0 if high_speed_class else 0.8))
	)
	var should_use_item := _should_use_item(forward)
	if should_use_item:
		_item_cooldown = randf_range(2.5, 4.5)
	kart.set_drive_input(throttle, brake, steer, should_drift, should_use_item)


func _update_progress_recovery(
	delta: float,
	checkpoint_index: int,
	checkpoint_distance: float
) -> bool:
	if checkpoint_index != _last_checkpoint_index:
		_last_checkpoint_index = checkpoint_index
		_best_checkpoint_distance = checkpoint_distance
		_checkpoint_stall_time = 0.0
		return false
	if checkpoint_distance < _best_checkpoint_distance - 0.75:
		_best_checkpoint_distance = checkpoint_distance
		_checkpoint_stall_time = 0.0
		return false
	if not kart.is_control_enabled:
		return false
	_checkpoint_stall_time += delta
	if _checkpoint_stall_time < 5.0:
		return false
	kart.reset_to_last_checkpoint("navigation")
	_best_checkpoint_distance = INF
	_checkpoint_stall_time = 0.0
	return true


func _should_use_item(forward: Vector3) -> bool:
	if kart.held_item == null or _item_cooldown > 0.0:
		return false
	match kart.held_item.type:
		ItemDefinition.ItemType.BOOST:
			return _horizontal_speed() < kart.stats.max_speed * 0.9
		ItemDefinition.ItemType.TURBO_COCONUT:
			return _has_aligned_racer_ahead(forward, 22.0, 0.82)
		ItemDefinition.ItemType.SEA_BUBBLE:
			return true
		ItemDefinition.ItemType.SLIPPERY_PEEL:
			return _has_racer_behind(forward, 14.0) or _held_item_time >= 4.0
		ItemDefinition.ItemType.HOMING_PINEAPPLE:
			if _has_aligned_racer_ahead(forward, 40.0, 0.2):
				return true
			if _held_item_time >= 6.0:
				kart.request_straight_launch()
				return true
		ItemDefinition.ItemType.TROPICAL_WAVE:
			return (
				_has_visible_racer_in_range(kart.held_item.area_radius)
				or _held_item_time >= 6.0
			)
	return false


func _update_held_item_time(delta: float) -> void:
	if kart.held_item == null:
		_observed_item = null
		_held_item_time = 0.0
		return
	if kart.held_item != _observed_item:
		_observed_item = kart.held_item
		_held_item_time = 0.0
		return
	_held_item_time += delta


func _horizontal_speed() -> float:
	return Vector2(kart.velocity.x, kart.velocity.z).length()


func _has_aligned_racer_ahead(
	forward: Vector3,
	max_distance: float,
	minimum_alignment: float
) -> bool:
	var target := race_manager.get_racer_ahead(kart) as Node3D
	if target == null:
		return false
	var to_target := target.global_position - kart.global_position
	to_target.y = 0.0
	return (
		to_target.length() < max_distance
		and not to_target.is_zero_approx()
		and forward.dot(to_target.normalized()) > minimum_alignment
	)


func _has_racer_behind(forward: Vector3, max_distance: float) -> bool:
	for racer in race_manager.racers:
		var target := racer as Node3D
		if target == null or target == kart:
			continue
		var to_target := target.global_position - kart.global_position
		to_target.y = 0.0
		if (
			to_target.length() < max_distance
			and not to_target.is_zero_approx()
			and forward.dot(to_target.normalized()) < -0.55
		):
			return true
	return false


func _has_visible_racer_in_range(max_distance: float) -> bool:
	var origin := kart.global_position + Vector3.UP * 0.65
	for racer in race_manager.racers:
		var target := racer as Node3D
		if target == null or target == kart:
			continue
		var target_point := target.global_position + Vector3.UP * 0.65
		if (
			origin.distance_to(target_point) <= max_distance
			and ItemExecutor.has_clear_line_of_sight(
				kart.get_world_3d(),
				origin,
				target_point
			)
		):
			return true
	return false
