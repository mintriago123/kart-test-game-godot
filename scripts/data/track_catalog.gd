@tool
class_name TrackCatalog
extends Resource

@export var tracks: Array[TrackDefinition] = []


func get_default_track() -> TrackDefinition:
	return tracks[0] if not tracks.is_empty() else null


func get_track(track_id: StringName) -> TrackDefinition:
	for track_definition in tracks:
		if track_definition != null and track_definition.id == track_id:
			return track_definition
	return null


func get_valid_track(track_id: StringName) -> TrackDefinition:
	var track_definition := get_track(track_id)
	if track_definition != null and track_definition.is_valid():
		return track_definition
	return get_default_track()
