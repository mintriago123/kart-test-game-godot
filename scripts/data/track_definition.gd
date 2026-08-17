@tool
class_name TrackDefinition
extends Resource

enum Origin { BUNDLED, CUSTOM }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var origin: Origin = Origin.BUNDLED
@export var preview_color := Color("#167f93")
@export var preview_texture: Texture2D
@export var preview_map: TrackMinimapData
## Optional authoring hint for deterministic cover capture. Runtime ignores it.
@export var preview_camera_transform := Transform3D.IDENTITY
@export_range(20.0, 100.0, 1.0) var preview_camera_fov := 52.0
@export var scene: PackedScene
@export var music: AudioStream
@export_enum("Media", "Difícil") var difficulty := "Media"
@export_range(1, 9, 1) var laps := 3
@export_range(0.1, 99.0, 0.1, "suffix:km") var length_km := 1.0
@export_range(0, 12, 1) var shortcut_count := 0


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and scene != null
