@tool
class_name TrackDefinition
extends Resource

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var preview_color := Color("#167f93")
@export var preview_texture: Texture2D
@export var preview_map: TrackMinimapData
@export var scene: PackedScene
@export_range(1, 9, 1) var laps := 3


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and scene != null
