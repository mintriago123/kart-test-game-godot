class_name MenuRoute
extends RefCounted

enum Id {
	TITLE,
	MAIN,
	PLAY_MODE,
	PLAY_TRACK,
	PLAY_CUP,
	PLAY_VEHICLE,
	PLAY_READY,
	PLAY_LOCAL_LOBBY,
	PLAY_LAN_LOBBY,
	GARAGE,
	PROFILE,
	SETTINGS,
	CONTROLS,
	PAUSE,
	RESULTS,
}

const NAMES := {
	Id.TITLE: &"title",
	Id.MAIN: &"main",
	Id.PLAY_MODE: &"play_mode",
	Id.PLAY_TRACK: &"play_track",
	Id.PLAY_CUP: &"play_cup",
	Id.PLAY_VEHICLE: &"play_vehicle",
	Id.PLAY_READY: &"play_ready",
	Id.PLAY_LOCAL_LOBBY: &"play_local_lobby",
	Id.PLAY_LAN_LOBBY: &"play_lan_lobby",
	Id.GARAGE: &"garage",
	Id.PROFILE: &"profile",
	Id.SETTINGS: &"settings",
	Id.CONTROLS: &"controls",
	Id.PAUSE: &"pause",
	Id.RESULTS: &"results",
}

static func is_valid(route: int) -> bool:
	return NAMES.has(route)

static func route_name(route: int) -> StringName:
	return NAMES.get(route, &"unknown")
