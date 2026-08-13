class_name CupManager
extends RefCounted
var catalog: ProgressionCatalog
var progress: PlayerProgress
var active_run: CupRunState
var last_granted_rewards := PackedStringArray()
var last_medal := UnlockDefinition.Medal.NONE
func _init(value_catalog: ProgressionCatalog = null, value_progress: PlayerProgress = null) -> void:
	catalog = value_catalog
	progress = value_progress
func start(cup_id: StringName, difficulty_id: StringName, cc_id: StringName, seed: int = 0) -> bool:
	var cup := catalog.cups.get_cup(cup_id)
	var difficulty := catalog.difficulties.get_difficulty(difficulty_id)
	if cup == null or difficulty == null or not difficulty in cup.difficulties: return false
	active_run = CupRunState.new()
	active_run.run_id = StringName("%s-%s" % [Time.get_unix_time_from_system(), randi()])
	active_run.cup_id = cup_id
	active_run.difficulty_id = difficulty_id
	active_run.cc_id = cc_id
	active_run.variant_id = progress.equipped_kart_variant_id
	active_run.race_seed = seed if seed != 0 else randi()
	_initialize_standings(cup)
	_save()
	return true
func restore() -> bool:
	active_run = CupRunState.from_dict(progress.active_cup)
	if active_run == null: return false
	var cup := catalog.cups.get_cup(active_run.cup_id)
	if cup == null or active_run.current_race_index < 0 or active_run.current_race_index >= cup.tracks.size() or active_run.is_completed:
		active_run = null
		return false
	return true
func abandon() -> void:
	active_run = null
	progress.active_cup = {}
	progress.save_to_disk()
func create_session() -> RaceSessionConfig:
	if active_run == null: return null
	var cup := catalog.cups.get_cup(active_run.cup_id)
	if cup == null: return null
	var session := RaceSessionConfig.new()
	session.track = cup.tracks[active_run.current_race_index]
	session.race_class = RaceClassDefinition.get_by_id(active_run.cc_id)
	session.game_mode = GameModeDefinition.CUP
	session.racers.append(cup.player_racer)
	session.racers.append_array(cup.opponents)
	session.player_racer_id = cup.player_racer.id
	session.difficulty = catalog.difficulties.get_difficulty(active_run.difficulty_id)
	session.race_seed = active_run.race_seed + active_run.current_race_index
	session.run_id = active_run.run_id
	session.cup_id = cup.id
	session.cup_race_index = active_run.current_race_index
	var fixed_variant_id := active_run.variant_id if not active_run.variant_id.is_empty() else progress.equipped_kart_variant_id
	session.equipped_variant = catalog.unlocks.get_variant(fixed_variant_id)
	return session
func commit_race_result(result: RaceResult) -> bool:
	last_granted_rewards.clear()
	last_medal = UnlockDefinition.Medal.NONE
	if active_run == null or result.run_id != active_run.run_id or result.cup_id != active_run.cup_id or result.cup_race_index != active_run.current_race_index: return false
	var cup := catalog.cups.get_cup(active_run.cup_id)
	if cup == null or result.track_id != cup.tracks[active_run.current_race_index].id: return false
	var key := "%s:%s" % [active_run.run_id, active_run.current_race_index]
	if key in active_run.committed_races: return false
	for race_result in result.standings:
		if not active_run.standings.has(race_result.racer_id): continue
		var row: Dictionary = active_run.standings[race_result.racer_id]
		var position := clampi(race_result.finish_position, 1, 4)
		row.points += cup.scoring_table[position - 1]
		row.victories += int(position == 1)
		row.last_position = position
		row.total_time += maxf(race_result.finish_time, 0.0)
		active_run.standings[race_result.racer_id] = row
	active_run.committed_races.append(key)
	active_run.current_race_index += 1
	active_run.is_completed = active_run.current_race_index >= 3
	var summary := CupResultSummary.new()
	summary.cup_id = cup.id
	summary.difficulty_id = active_run.difficulty_id
	summary.race_index = result.cup_race_index
	summary.completed = active_run.is_completed
	summary.standings = get_ordered_standings()
	if active_run.is_completed:
		var player_points := int(active_run.standings[cup.player_racer.id].points)
		last_medal = cup.medal_for_points(player_points)
		summary.previous_best_medal = progress.get_medal(cup.id, active_run.difficulty_id)
		last_granted_rewards = progress.record_medal(cup, catalog.difficulties.get_difficulty(active_run.difficulty_id), last_medal)
		summary.medal = last_medal
		summary.new_reward_ids = last_granted_rewards
		progress.active_cup = {}
	else: progress.active_cup = active_run.to_dict()
	result.cup_summary = summary
	progress.save_to_disk()
	return true
func get_ordered_standings() -> Array[Dictionary]:
	if active_run == null: return []
	var rows: Array[Dictionary] = []
	for id in active_run.standings:
		var row: Dictionary = active_run.standings[id].duplicate()
		row.racer_id = id
		rows.append(row)
	rows.sort_custom(func(a, b):
		if a.points != b.points: return a.points > b.points
		if a.victories != b.victories: return a.victories > b.victories
		if a.last_position != b.last_position: return a.last_position < b.last_position
		if not is_equal_approx(a.total_time, b.total_time): return a.total_time < b.total_time
		return str(a.racer_id) < str(b.racer_id))
	return rows
func _initialize_standings(cup: CupDefinition) -> void:
	var racers: Array[RacerDefinition] = [cup.player_racer]
	racers.append_array(cup.opponents)
	for racer in racers:
		active_run.standings[racer.id] = {"points": 0, "victories": 0, "last_position": 999, "total_time": 0.0}
func _save() -> void:
	progress.active_cup = active_run.to_dict()
	progress.save_to_disk()
