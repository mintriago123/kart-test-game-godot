class_name RaceResult
extends RefCounted

var track_id: StringName
var cc_id: StringName
var game_mode := GameModeDefinition.RACE
var run_id: StringName
var cup_id: StringName
var cup_race_index := -1
var standings: Array[RacerRaceResult] = []
var player_result: RacerRaceResult
var local_player_index := 0
var player_results: Array[RacerRaceResult] = []
var previous_best_time := -1.0
var previous_best_lap_time := -1.0
var is_new_best_time := false
var is_new_best_lap := false
var ghost_updated := false
var cup_summary: CupResultSummary


func finalize_records() -> void:
	if player_result == null and not player_results.is_empty():
		player_result = player_results[clampi(local_player_index, 0, player_results.size() - 1)]
	elif player_result != null and player_results.is_empty():
		player_results.append(player_result)
	if player_result == null:
		return
	is_new_best_time = (
		player_result.finish_time > 0.0
		and (
			previous_best_time <= 0.0
			or player_result.finish_time < previous_best_time
		)
	)
	is_new_best_lap = (
		player_result.best_lap_time > 0.0
		and (
			previous_best_lap_time <= 0.0
			or player_result.best_lap_time < previous_best_lap_time
		)
	)


func for_local_player(index: int) -> RaceResult:
	if player_results.is_empty():
		return self
	var view := RaceResult.new()
	view.track_id = track_id
	view.cc_id = cc_id
	view.game_mode = game_mode
	view.run_id = run_id
	view.cup_id = cup_id
	view.cup_race_index = cup_race_index
	view.standings.assign(standings)
	view.player_results.assign(player_results)
	view.local_player_index = clampi(index, 0, player_results.size() - 1)
	view.player_result = player_results[view.local_player_index]
	view.previous_best_time = previous_best_time
	view.previous_best_lap_time = previous_best_lap_time
	view.is_new_best_time = is_new_best_time
	view.is_new_best_lap = is_new_best_lap
	view.ghost_updated = ghost_updated
	view.cup_summary = cup_summary
	return view
