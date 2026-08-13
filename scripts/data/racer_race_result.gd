class_name RacerRaceResult
extends RefCounted

var racer_name := ""
var racer_id: StringName
var is_player := false
var local_player_index := -1
var participant_slot := -1
var start_position := 0
var finish_position := 0
var laps_completed := 0
var lap_times: Array[float] = []
var finish_time := -1.0
var is_dnf := false
var best_lap_time := -1.0
var items_collected := 0
var items_used := 0
var hits_landed := 0
var hits_blocked := 0
var shortcuts_used := 0
var recoveries := 0


func get_position_delta() -> int:
	if finish_position <= 0:
		return 0
	return start_position - finish_position


func duplicate_result() -> RacerRaceResult:
	var copy := RacerRaceResult.new()
	copy.racer_id = racer_id
	copy.racer_name = racer_name
	copy.is_player = is_player
	copy.local_player_index = local_player_index
	copy.participant_slot = participant_slot
	copy.start_position = start_position
	copy.finish_position = finish_position
	copy.laps_completed = laps_completed
	copy.lap_times = lap_times.duplicate()
	copy.finish_time = finish_time
	copy.is_dnf = is_dnf
	copy.best_lap_time = best_lap_time
	copy.items_collected = items_collected
	copy.items_used = items_used
	copy.hits_landed = hits_landed
	copy.hits_blocked = hits_blocked
	copy.shortcuts_used = shortcuts_used
	copy.recoveries = recoveries
	return copy
