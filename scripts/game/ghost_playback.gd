class_name GhostPlayback
extends Node3D

const TELEPORT_DISTANCE := 12.0

var recording: GhostRecording
var drive_state := GhostSample.DriveState.NORMAL

var _sample_index := 0
var _body_material: StandardMaterial3D


func _ready() -> void:
	_build_visual()
	visible = false


func setup(value: GhostRecording) -> void:
	recording = value
	_sample_index = 0


func update_for_time(race_time: float) -> void:
	if recording == null or recording.samples.is_empty():
		visible = false
		return
	if race_time < recording.samples[0].time or race_time > recording.samples[-1].time:
		visible = false
		return
	visible = true
	while _sample_index + 1 < recording.samples.size() and recording.samples[_sample_index + 1].time < race_time:
		_sample_index += 1
	while _sample_index > 0 and recording.samples[_sample_index].time > race_time:
		_sample_index -= 1
	var current := recording.samples[_sample_index]
	var next := recording.samples[mini(_sample_index + 1, recording.samples.size() - 1)]
	var duration := next.time - current.time
	var weight := clampf((race_time - current.time) / duration, 0.0, 1.0) if duration > 0.0001 else 0.0
	if next.discontinuity or current.position.distance_to(next.position) > TELEPORT_DISTANCE:
		weight = 1.0 if race_time >= next.time else 0.0
	global_position = current.position.lerp(next.position, weight)
	global_basis = Basis(current.rotation.slerp(next.rotation, weight).normalized())
	drive_state = current.drive_state if weight < 0.5 else next.drive_state
	_body_material.emission_energy_multiplier = 1.7 if drive_state in [GhostSample.DriveState.BOOSTING, GhostSample.DriveState.DRIFT_BOOSTING] else 0.8


func get_reference_time(progress: float) -> float:
	if recording == null or recording.samples.size() < 2 or not is_finite(progress):
		return -1.0
	var low := 0
	var high := recording.samples.size() - 1
	while low + 1 < high:
		var middle := (low + high) / 2
		if recording.samples[middle].progress <= progress:
			low = middle
		else:
			high = middle
	var first := recording.samples[low]
	var second := recording.samples[high]
	if progress < first.progress or progress > second.progress or second.progress <= first.progress:
		return -1.0
	return lerpf(first.time, second.time, (progress - first.progress) / (second.progress - first.progress))


func _build_visual() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.15, 0.95, 1.0, 0.38)
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body_material.emission_enabled = true
	_body_material.emission = Color("#53e8f2")
	for data in [[Vector3(1.55, 0.52, 2.2), Vector3(0, 0.62, 0)], [Vector3(1.25, 0.48, 0.95), Vector3(0, 1.0, 0.28)]]:
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = data[0]
		mesh_instance.mesh = mesh
		mesh_instance.position = data[1]
		mesh_instance.material_override = _body_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
