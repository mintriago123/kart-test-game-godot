@tool
class_name TrackAssetEntry
extends Resource

@export var id: StringName
@export var display_name := ""
@export_enum("Naturaleza", "Carrera", "Arquitectura") var category := "Naturaleza"
@export var scene: PackedScene
@export var default_scale := Vector3.ONE


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and scene != null
