class_name CupRunState
extends RefCounted
const SCHEMA_VERSION := 1
var schema_version := SCHEMA_VERSION
var run_id: StringName
var cup_id: StringName
var difficulty_id: StringName
var cc_id: StringName
var race_seed := 0
var current_race_index := 0
var standings: Dictionary = {}
var committed_races := PackedStringArray()
var is_completed := false
func to_dict() -> Dictionary:
	return {"schema_version": schema_version, "run_id": str(run_id), "cup_id": str(cup_id), "difficulty_id": str(difficulty_id), "cc_id": str(cc_id), "race_seed": race_seed, "current_race_index": current_race_index, "standings": standings.duplicate(true), "committed_races": Array(committed_races), "is_completed": is_completed}
static func from_dict(data: Dictionary) -> CupRunState:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION: return null
	var state := CupRunState.new()
	state.run_id = StringName(data.get("run_id", ""))
	state.cup_id = StringName(data.get("cup_id", ""))
	state.difficulty_id = StringName(data.get("difficulty_id", ""))
	state.cc_id = StringName(data.get("cc_id", ""))
	state.race_seed = int(data.get("race_seed", 0))
	state.current_race_index = int(data.get("current_race_index", 0))
	state.standings = data.get("standings", {}).duplicate(true)
	state.committed_races = PackedStringArray(data.get("committed_races", []))
	state.is_completed = bool(data.get("is_completed", false))
	return state
