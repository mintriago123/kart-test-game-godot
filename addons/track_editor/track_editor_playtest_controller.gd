@tool
class_name TrackEditorPlaytestController
extends RefCounted

signal state_changed(state: StringName)

var state: StringName = &"iniciando"
var state_reason := ""
var latest_summary: Dictionary = {}
var summaries: Dictionary = {}


func set_state(new_state: StringName, reason := "") -> void:
	if state == new_state and state_reason == reason:
		return
	state = new_state
	state_reason = reason
	state_changed.emit(state)


func fail(reason: String) -> void:
	set_state(&"fallido", reason)


func record_summary(summary: Dictionary) -> void:
	latest_summary = summary.duplicate(true)
	var key := "%s|%s" % [
		str(summary.get("track_id", "")),
		str(summary.get("configuration", "")),
	]
	summaries[key] = latest_summary.duplicate(true)


func get_summary(track_id: String, configuration: String) -> Dictionary:
	return summaries.get("%s|%s" % [track_id, configuration], {}).duplicate(true)


func get_state_label() -> String:
	match state:
		&"iniciando":
			return "INICIANDO"
		&"listo":
			return "LISTO"
		&"ejecutando":
			return "EJECUTANDO"
		&"completado":
			return "COMPLETADO"
		&"fallido":
			return "FALLIDO"
	return String(state).to_upper()
