class_name GameModeDefinition
extends RefCounted

enum GameMode { RACE, TIME_TRIAL, CUP, LOCAL_MULTIPLAYER, LAN_MULTIPLAYER }

const RACE := GameMode.RACE
const TIME_TRIAL := GameMode.TIME_TRIAL
const CUP := GameMode.CUP
const LOCAL_MULTIPLAYER := GameMode.LOCAL_MULTIPLAYER
const LAN_MULTIPLAYER := GameMode.LAN_MULTIPLAYER


static func to_id(game_mode: int) -> StringName:
	match game_mode:
		TIME_TRIAL: return &"time_trial"
		CUP: return &"cup"
		LOCAL_MULTIPLAYER: return &"local_multiplayer"
		LAN_MULTIPLAYER: return &"lan_multiplayer"
		_: return &"race"


static func sanitize(game_mode: int) -> int:
	return game_mode if game_mode in [RACE, TIME_TRIAL, CUP, LOCAL_MULTIPLAYER, LAN_MULTIPLAYER] else RACE


static func has_rivals(game_mode: int) -> bool:
	return game_mode in [RACE, CUP, LOCAL_MULTIPLAYER, LAN_MULTIPLAYER]


static func has_items(game_mode: int) -> bool:
	return game_mode in [RACE, CUP, LOCAL_MULTIPLAYER, LAN_MULTIPLAYER]


static func records_track_time(game_mode: int) -> bool:
	return game_mode in [RACE, TIME_TRIAL]


static func is_multiplayer(game_mode: int) -> bool:
	return game_mode in [LOCAL_MULTIPLAYER, LAN_MULTIPLAYER]


static func records_progression_rewards(game_mode: int) -> bool:
	return game_mode in [RACE, TIME_TRIAL, CUP]
