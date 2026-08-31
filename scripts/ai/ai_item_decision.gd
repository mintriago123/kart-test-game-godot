class_name AiItemDecision
extends RefCounted

var tuning: AiTuning
var kart: Kart
var race_manager: RaceManager

var held_item_time: float = 0.0
var observed_item: ItemDefinition = null
var per_item_cooldown: Dictionary = {}


func update(delta: float) -> void:
	if kart == null or kart.held_item == null:
		observed_item = null
		held_item_time = 0.0
		_decay_cooldowns(delta)
		return
	if kart.held_item != observed_item:
		observed_item = kart.held_item
		held_item_time = 0.0
	else:
		held_item_time += delta
	_decay_cooldowns(delta)


func _decay_cooldowns(delta: float) -> void:
	if per_item_cooldown.is_empty():
		return
	for item_id in per_item_cooldown.keys():
		per_item_cooldown[item_id] = maxf(float(per_item_cooldown[item_id]) - delta, 0.0)


func should_use(forward: Vector3, drive_state: int) -> bool:
	if kart == null or kart.held_item == null or drive_state == AiRecoveryState.DriveState.WALL_RECOVERY:
		return false
	if not _can_use(kart.held_item):
		return false
	match kart.held_item.type:
		ItemDefinition.ItemType.BOOST:
			return kart.get_horizontal_speed() < kart.stats.max_speed * tuning.item_boost_speed_ratio_threshold
		ItemDefinition.ItemType.TURBO_COCONUT:
			return _has_aligned_racer_ahead(forward, tuning.item_turbo_coconut_distance, tuning.item_turbo_coconut_alignment)
		ItemDefinition.ItemType.SEA_BUBBLE:
			return true
		ItemDefinition.ItemType.SLIPPERY_PEEL:
			return _has_racer_behind(forward, tuning.item_slippery_peel_distance) or held_item_time >= tuning.item_slippery_peel_max_hold_time
		ItemDefinition.ItemType.HOMING_PINEAPPLE:
			if _has_aligned_racer_ahead(forward, tuning.item_homing_pineapple_distance, tuning.item_homing_pineapple_alignment):
				return true
			if held_item_time >= tuning.item_homing_pineapple_max_hold_time:
				kart.request_straight_launch()
				return true
		ItemDefinition.ItemType.TROPICAL_WAVE:
			return (
				_has_visible_racer_in_range(kart.held_item.area_radius)
				or held_item_time >= tuning.item_tropical_wave_max_hold_time
			)
	return false


func notify_item_used(item: ItemDefinition, base_cooldown: float) -> void:
	if item == null:
		return
	per_item_cooldown[item.id] = base_cooldown


func _can_use(item: ItemDefinition) -> bool:
	return float(per_item_cooldown.get(item.id, 0.0)) <= 0.0


func _has_aligned_racer_ahead(forward: Vector3, max_distance: float, minimum_alignment: float) -> bool:
	if race_manager == null:
		return false
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
	if race_manager == null:
		return false
	for racer in race_manager.racers:
		var target := racer as Node3D
		if target == null or target == kart:
			continue
		var to_target := target.global_position - kart.global_position
		to_target.y = 0.0
		if (
			to_target.length() < max_distance
			and not to_target.is_zero_approx()
			and forward.dot(to_target.normalized()) < tuning.racer_ahead_behind_dot
		):
			return true
	return false


func _has_visible_racer_in_range(max_distance: float) -> bool:
	if kart == null:
		return false
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
