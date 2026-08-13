class_name KartVariantDefinition
extends Resource

@export var id: StringName
@export var display_name := "Vehiculo"
@export var visual_scene: PackedScene
@export var preview: Texture2D
@export_range(0.5, 1.5, 0.01) var speed: float = 1.0
@export_range(0.5, 1.5, 0.01) var acceleration: float = 1.0
@export_range(0.5, 1.5, 0.01) var handling: float = 1.0
@export_range(0.5, 2.0, 0.01) var weight: float = 1.0
@export_range(0.5, 2.0, 0.01) var mini_turbo_duration_multiplier: float = 1.0

func is_valid() -> bool:
	return not id.is_empty() and not display_name.strip_edges().is_empty() and visual_scene != null
