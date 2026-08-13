class_name GameModeDefinition
extends RefCounted

enum GameMode { RACE, TIME_TRIAL, CUP }

const RACE := GameMode.RACE
const TIME_TRIAL := GameMode.TIME_TRIAL
const CUP := GameMode.CUP


static func to_id(game_mode: int) -> StringName:
	match game_mode:
		TIME_TRIAL: return &"time_trial"
		CUP: return &"cup"
		_: return &"race"


static func sanitize(game_mode: int) -> int:
	return game_mode if game_mode in [RACE, TIME_TRIAL, CUP] else RACE


static func has_rivals(game_mode: int) -> bool:
	return game_mode in [RACE, CUP]


static func has_items(game_mode: int) -> bool:
	return game_mode in [RACE, CUP]


static func records_track_time(game_mode: int) -> bool:
	return game_mode in [RACE, TIME_TRIAL]
