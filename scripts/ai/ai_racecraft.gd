class_name AiRacecraft
extends RefCounted

var tuning: AiTuning

var draft_focus := 0.0
var overtake_commit := 0.0
var block_offset := 0.0


func update(
	kart: Kart,
	race_manager: RaceManager,
	personality: AiPersonality,
	allow_blocking: bool,
	delta: float
) -> void:
	var leader := _find_forward_racer(kart, race_manager, tuning.racecraft_draft_max_distance)
	_update_draft(kart, leader, delta)
	_update_overtake(kart, race_manager, delta)
	_update_block(kart, race_manager, personality, allow_blocking, delta)


func _update_draft(kart: Kart, leader: Kart, delta: float) -> void:
	var target_focus := 0.0
	if leader != null:
		var offset: Vector3 = leader.global_position - kart.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance >= tuning.racecraft_draft_min_distance:
			var forward := -kart.global_transform.basis.z.normalized()
			if forward.dot(offset.normalized()) >= tuning.racecraft_draft_alignment:
				target_focus = 1.0
	draft_focus = move_toward(draft_focus, target_focus, tuning.racecraft_draft_rate * delta)


func _update_overtake(kart: Kart, race_manager: RaceManager, delta: float) -> void:
	var target_commit := 0.0
	if _find_forward_racer(kart, race_manager, tuning.racer_avoidance_distance) != null:
		target_commit = 1.0
	overtake_commit = move_toward(overtake_commit, target_commit, tuning.racecraft_overtake_rate * delta)


func _update_block(
	kart: Kart,
	race_manager: RaceManager,
	personality: AiPersonality,
	allow_blocking: bool,
	delta: float
) -> void:
	var target_offset := 0.0
	if allow_blocking and personality.aggression >= tuning.racecraft_block_min_aggression:
		var pursuer := _find_pursuing_human(kart, race_manager)
		if pursuer != null:
			var offset: Vector3 = pursuer.global_position - kart.global_position
			offset.y = 0.0
			var distance := offset.length()
			if distance <= tuning.racecraft_block_distance:
				# Approximation: the kart's own right vector stands in for the
				# track-frame right used by section_offset. The two are close
				# whenever the kart is roughly aligned with the line, which is
				# the only situation blocking should ever trigger in anyway.
				var right := kart.global_transform.basis.x.normalized()
				var lateral := offset.dot(right)
				var closeness := clampf(1.0 - distance / tuning.racecraft_block_distance, 0.0, 1.0)
				target_offset = signf(lateral) * tuning.racecraft_block_max_offset * closeness
	block_offset = move_toward(block_offset, target_offset, tuning.racecraft_block_rate * delta)


func _find_forward_racer(kart: Kart, race_manager: RaceManager, max_distance: float) -> Kart:
	var forward := -kart.global_transform.basis.z.normalized()
	var kart_pos := kart.global_position
	var best: Kart = null
	var best_distance := max_distance
	for candidate_value in race_manager.racers:
		var candidate := candidate_value as Kart
		if candidate == null or candidate == kart:
			continue
		var offset: Vector3 = candidate.global_position - kart_pos
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.1 or distance > best_distance:
			continue
		if forward.dot(offset.normalized()) < tuning.racecraft_forward_alignment:
			continue
		best_distance = distance
		best = candidate
	return best


func _find_pursuing_human(kart: Kart, race_manager: RaceManager) -> Kart:
	var best: Kart = null
	var best_distance := INF
	var kart_pos := kart.global_position
	for candidate_value in race_manager.human_karts:
		var candidate := candidate_value as Kart
		if candidate == null or candidate == kart:
			continue
		if race_manager.get_racer_ahead(candidate) != kart:
			continue
		var distance := kart_pos.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func reset() -> void:
	draft_focus = 0.0
	overtake_commit = 0.0
	block_offset = 0.0
