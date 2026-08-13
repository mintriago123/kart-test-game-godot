class_name MusicCatalog
extends Resource

const MENU_THEME: AudioStream = preload("res://assets/music/menu_theme.ogg")
const CUP_VICTORY_STING: AudioStream = preload("res://assets/music/cup_victory.ogg")
const TRACK_THEMES := {
	&"coastal": preload("res://assets/music/coastal.ogg"),
	&"garden": preload("res://assets/music/garden.ogg"),
	&"bahia_turbo": preload("res://assets/music/bahia_turbo.ogg"),
}

var menu_theme: AudioStream = MENU_THEME
var cup_victory_sting: AudioStream = CUP_VICTORY_STING
var track_themes: Dictionary = TRACK_THEMES

func get_track_theme(track_id: StringName) -> AudioStream:
	return track_themes.get(track_id) as AudioStream
