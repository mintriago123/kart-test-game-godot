class_name SurfaceDefinition
extends Resource

@export var id: StringName = &"asphalt"
@export var display_name := "Asfalto"
@export var grip_multiplier := 1.0
@export var drift_grip_multiplier := 1.0
@export var rolling_resistance_multiplier := 1.0
@export var acceleration_multiplier := 1.0
@export var boost_multiplier := 1.0
@export var color := Color("#69747a")
@export var effect_scene: PackedScene
@export_group("Presentation")
@export_range(0.5, 1.5, 0.01) var audio_pitch := 1.0
@export_range(0.0, 1.5, 0.01) var audio_volume := 0.75
@export_range(0.0, 1.0, 0.01) var audio_roughness := 0.15
@export var particle_color := Color("#b8c2c6")

static func asphalt() -> SurfaceDefinition:
	return SurfaceDefinition.new()
