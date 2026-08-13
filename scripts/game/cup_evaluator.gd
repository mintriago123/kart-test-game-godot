class_name CupEvaluator
extends RefCounted


static func evaluate(
	cup: CupDefinition,
	difficulty: DifficultyDefinition,
	finish_orders: Array
) -> CupEvaluationResult:
	var result := CupEvaluationResult.new()
	if cup == null:
		result.errors.append("Missing cup.")
		return result
	if difficulty == null or not difficulty in cup.difficulties:
		result.errors.append("Difficulty is not enabled for this cup.")
	if finish_orders.size() != 3:
		result.errors.append("Exactly three race results are required.")
	var racers: Array[RacerDefinition] = [cup.player_racer]
	racers.append_array(cup.opponents)
	var racer_ids := PackedStringArray()
	var rows := {}
	for racer in racers:
		if racer == null:
			continue
		racer_ids.append(racer.id)
		rows[racer.id] = {
			"racer_id": racer.id, "points": 0, "victories": 0,
			"last_position": 999, "total_time": 0.0,
		}
	for race_index in finish_orders.size():
		var order: PackedStringArray = finish_orders[race_index]
		if order.size() != 4 or not _same_ids(order, racer_ids):
			result.errors.append("Race %d must rank every racer exactly once." % (race_index + 1))
			continue
		for position in order.size():
			var id := StringName(order[position])
			var row: Dictionary = rows[id]
			row.points += cup.scoring_table[position]
			row.victories += int(position == 0)
			row.last_position = position + 1
			rows[id] = row
	if not result.errors.is_empty():
		return result
	return evaluate_standings(cup, difficulty, rows)


static func evaluate_standings(
	cup: CupDefinition,
	difficulty: DifficultyDefinition,
	standings: Dictionary
) -> CupEvaluationResult:
	var result := CupEvaluationResult.new()
	if cup == null or difficulty == null:
		result.errors.append("Cup and difficulty are required.")
		return result
	for id in standings:
		var row: Dictionary = standings[id].duplicate()
		row.racer_id = StringName(row.get("racer_id", id))
		result.standings.append(row)
	result.standings.sort_custom(_ranks_before)
	for index in result.standings.size():
		if StringName(result.standings[index].racer_id) == cup.player_racer.id:
			result.player_position = index + 1
			result.player_points = int(result.standings[index].points)
			break
	result.medal = cup.medal_for_points(result.player_points)
	for unlock in cup.unlocks:
		if (unlock != null and unlock.requirement_type == UnlockDefinition.CUP_MEDAL
				and unlock.required_medal <= result.medal):
			result.eligible_rewards.append(unlock)
	return result


static func _same_ids(actual: PackedStringArray, expected: PackedStringArray) -> bool:
	var seen := {}
	for id in actual:
		if id not in expected or seen.has(id):
			return false
		seen[id] = true
	return seen.size() == expected.size()


static func _ranks_before(a: Dictionary, b: Dictionary) -> bool:
	if a.points != b.points: return a.points > b.points
	if a.victories != b.victories: return a.victories > b.victories
	if a.last_position != b.last_position: return a.last_position < b.last_position
	return str(a.racer_id) < str(b.racer_id)
