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


func setup(controlled_kart: Kart, manager: RaceManager, offset: float) -> void:
	kart = controlled_kart
	race_manager = manager
	lane_offset = offset


func _physics_process(delta: float) -> void:
	if kart == null or race_manager == null or race_manager.route_points.is_empty():
		return
	_item_cooldown = maxf(_item_cooldown - delta, 0.0)
	var next_index := race_manager.get_next_checkpoint_index(kart)
	var next_checkpoint := race_manager.route_points[next_index]
	var checkpoint_distance := kart.global_position.distance_to(next_checkpoint)
	if _update_progress_recovery(delta, next_index, checkpoint_distance):
		return
	var lookahead_steps := 1 if checkpoint_distance > 11.0 else 3
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
	var speed := Vector2(kart.velocity.x, kart.velocity.z).length()
	var brake := 0.0
	var throttle := 1.0
	if alignment < -0.1:
		throttle = 0.0
		brake = 1.0 if speed > 2.0 else 0.7
		if speed <= 2.0:
			steer = -steer
	elif alignment < 0.65 and speed > 15.0 + caution * 4.0:
		brake = 0.55
		throttle = 0.25
	elif alignment < 0.82:
		throttle = 0.72
	var should_drift := (
		absf(steer) > 0.48
		and speed > 10.0
		and checkpoint_distance < 20.0
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
	kart.reset_to_last_checkpoint()
	_best_checkpoint_distance = INF
	_checkpoint_stall_time = 0.0
	return true


func _should_use_item(forward: Vector3) -> bool:
	if kart.held_item == null or _item_cooldown > 0.0:
		return false
	if kart.held_item.type == ItemDefinition.ItemType.BOOST:
		return absf(kart.velocity.length()) < kart.stats.max_speed * 0.9
	var target := race_manager.get_racer_ahead(kart)
	if target == null:
		return false
	var to_target: Vector3 = target.global_position - kart.global_position
	return to_target.length() < 22.0 and forward.dot(to_target.normalized()) > 0.82
