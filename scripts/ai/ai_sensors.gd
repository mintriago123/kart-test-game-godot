class_name AiSensors
extends RefCounted

var tuning: AiTuning
var kart: Kart


func sense(speed: float) -> Dictionary:
	if kart == null:
		return {"front": 1.0, "left": 1.0, "right": 1.0}
	var forward := -kart.global_transform.basis.z.normalized()
	var right := kart.global_transform.basis.x.normalized()
	var speed_ratio := clampf(speed / maxf(kart.stats.max_speed, 0.1), 0.0, 1.0)
	var sensor_range := lerpf(tuning.sensor_min_range, tuning.sensor_max_range, speed_ratio)
	var side_range := lerpf(tuning.sensor_side_range_min, tuning.sensor_side_range_max, speed_ratio)
	var origin := kart.global_position + Vector3.UP * tuning.sensor_origin_height
	return {
		"front": _cast(origin, forward, sensor_range),
		"left": _cast(origin - right * tuning.sensor_side_offset,
			(forward * tuning.sensor_side_forward_blend - right).normalized(), side_range),
		"right": _cast(origin + right * tuning.sensor_side_offset,
			(forward * tuning.sensor_side_forward_blend + right).normalized(), side_range),
	}


func _cast(origin: Vector3, direction: Vector3, length: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * length, PhysicsLayers.BARRIERS)
	query.exclude = [kart.get_rid()]
	var hit := kart.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	return clampf(origin.distance_to(hit.position) / length, 0.0, 1.0)
