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
var previous_best_time := -1.0
var previous_best_lap_time := -1.0
var is_new_best_time := false
var is_new_best_lap := false
var ghost_updated := false
var cup_summary: CupResultSummary


func finalize_records() -> void:
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
