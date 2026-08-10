@tool
class_name TrackAssetEntry
extends Resource

const Bounds := preload("res://scripts/visual/node_3d_bounds.gd")

@export var id: StringName
@export var display_name := ""
@export_enum("Naturaleza", "Carrera", "Arquitectura") var category := "Naturaleza"
@export var scene: PackedScene
@export var default_scale := Vector3.ONE
@export_range(0.0, 20.0, 0.1) var target_height_meters := 0.0
@export var base_scale := Vector3.ZERO


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and scene != null


func resolve_base_scale() -> Dictionary:
	if _is_valid_scale(base_scale):
		return {"scale": base_scale, "used_fallback": false}
	var calculated_scale := calculate_base_scale()
	if _is_valid_scale(calculated_scale):
		return {"scale": calculated_scale, "used_fallback": false}
	return {
		"scale": default_scale if _is_valid_scale(default_scale) else Vector3.ONE,
		"used_fallback": true,
	}


func calculate_base_scale() -> Vector3:
	if (
		scene == null
		or not is_finite(target_height_meters)
		or target_height_meters <= 0.0
	):
		return Vector3.ZERO
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return Vector3.ZERO
	var bounds_result := get_node_aabb(instance)
	var calculated_scale := Vector3.ZERO
	if bool(bounds_result.valid):
		var bounds: AABB = bounds_result.aabb
		if is_finite(bounds.size.y) and bounds.size.y > 0.0001:
			calculated_scale = (
				instance.scale * (target_height_meters / bounds.size.y)
			)
	instance.free()
	return calculated_scale


static func get_node_aabb(root: Node3D) -> Dictionary:
	return Bounds.get_node_aabb(root)


func _is_valid_scale(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
		and absf(value.x) > 0.000001
		and absf(value.y) > 0.000001
		and absf(value.z) > 0.000001
	)
