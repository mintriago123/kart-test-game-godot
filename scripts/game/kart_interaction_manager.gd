class_name KartInteractionManager
extends Node

var race_manager: RaceManager
var tuning: DrivingTuningDefinition
var _pair_cooldowns := {}
var _slipstream := {}

func setup(manager: RaceManager, definition: DrivingTuningDefinition) -> void:
	race_manager = manager
	tuning = definition

func _physics_process(delta: float) -> void:
	if race_manager == null or race_manager.state not in [RaceManager.RaceState.RACING, RaceManager.RaceState.WAITING_FOR_RIVALS]:
		return
	for key in _pair_cooldowns.keys():
		_pair_cooldowns[key] = maxf(float(_pair_cooldowns[key]) - delta, 0.0)
	var racers := race_manager.racers
	for first_index in racers.size():
		for second_index in range(first_index + 1, racers.size()):
			_process_bump(racers[first_index] as Kart, racers[second_index] as Kart)
	for follower in racers:
		_process_slipstream(follower as Kart, delta)

func _process_bump(first: Kart, second: Kart) -> void:
	if first == null or second == null:
		return
	if not first.can_receive_kart_interaction() or not second.can_receive_kart_interaction():
		return
	var key := _pair_key(first, second)
	if float(_pair_cooldowns.get(key, 0.0)) > 0.0:
		return
	var normal := second.global_position - first.global_position
	normal.y = 0.0
	if normal.length_squared() < 0.001:
		return
	var center_distance := normal.length()
	normal = normal.normalized()
	if center_distance > _contact_distance(first, normal) + _contact_distance(second, -normal) + 0.04:
		return
	var relative_speed := absf((first.velocity - second.velocity).dot(normal))
	var impulse := minf(relative_speed * 0.32, tuning.bump_max_impulse)
	var first_forward := -first.global_transform.basis.z.normalized()
	if absf(first_forward.dot(normal)) > 0.72:
		impulse *= 0.35
	var total_weight := first.stats.weight + second.stats.weight
	first.velocity -= normal * impulse * second.stats.weight / total_weight
	second.velocity += normal * impulse * first.stats.weight / total_weight
	_pair_cooldowns[key] = tuning.bump_cooldown

func _contact_distance(kart: Kart, direction: Vector3) -> float:
	var right := kart.global_transform.basis.x.normalized()
	var forward := -kart.global_transform.basis.z.normalized()
	return (
		absf(right.dot(direction)) * Kart.COLLISION_SIZE.x * 0.5
		+ absf(forward.dot(direction)) * Kart.COLLISION_SIZE.z * 0.5
	)

func _process_slipstream(follower: Kart, delta: float) -> void:
	if follower == null:
		return
	var state: Dictionary = _slipstream.get(follower.get_instance_id(), {"charge": 0.0, "cooldown": 0.0})
	state.cooldown = maxf(float(state.cooldown) - delta, 0.0)
	var leader := _find_slipstream_leader(follower)
	if leader == null or follower.is_braking():
		state.charge = 0.0
	elif state.cooldown <= 0.0:
		state.charge = float(state.charge) + delta
		if state.charge >= tuning.slipstream_charge_duration:
			follower.activate_boost(tuning.slipstream_boost_duration, tuning.slipstream_boost_power)
			state.charge = 0.0
			state.cooldown = tuning.slipstream_cooldown
	_slipstream[follower.get_instance_id()] = state

func _find_slipstream_leader(follower: Kart) -> Kart:
	var forward := -follower.global_transform.basis.z.normalized()
	for candidate_value in race_manager.racers:
		var candidate := candidate_value as Kart
		if candidate == follower:
			continue
		var offset := candidate.global_position - follower.global_position
		var distance := offset.length()
		if distance < tuning.slipstream_min_distance or distance > tuning.slipstream_max_distance:
			continue
		if forward.dot(offset.normalized()) < tuning.slipstream_alignment:
			continue
		var lateral := offset - forward * offset.dot(forward)
		if lateral.length() > tuning.slipstream_lateral_distance:
			continue
		var candidate_forward := -candidate.global_transform.basis.z.normalized()
		if forward.dot(candidate_forward) >= tuning.slipstream_alignment:
			return candidate
	return null

func _pair_key(first: Kart, second: Kart) -> String:
	var low := mini(first.get_instance_id(), second.get_instance_id())
	var high := maxi(first.get_instance_id(), second.get_instance_id())
	return "%d:%d" % [low, high]
