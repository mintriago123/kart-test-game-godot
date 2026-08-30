@tool
class_name TrackEditorPreviewController
extends RefCounted

signal state_changed(state: StringName)

var container: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var is_showing_preview := false
var _preview_dirty := true
var request_version := 0
var applied_version := 0
var rebuild_count := 0
var preview_state: StringName = &"pendiente"
var _requested_signature := ""
var _applied_signature := ""
var _track_instance_id := 0
var discarded_rebuild_count := 0


func build(parent: Control) -> SubViewportContainer:
	container = SubViewportContainer.new()
	container.name = "TrackPreview3D"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.visible = false
	parent.add_child(container)

	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_build_world()
	return container


func set_track(track: TrackLevel) -> void:
	_preview_dirty = true
	_track_instance_id = track.get_instance_id() if track != null else 0
	_requested_signature = ""
	_applied_signature = ""
	request_version += 1
	applied_version = 0
	_set_state(&"pendiente")
	if viewport == null:
		return
	for child in viewport.get_children():
		if child is TrackLevel and child != track:
			viewport.remove_child(child)
			child.queue_free()
	if track == null:
		return
	if track.get_parent() != null:
		track.get_parent().remove_child(track)
	viewport.add_child(track)


func dispose() -> void:
	if viewport != null:
		for child in viewport.get_children():
			if child is TrackLevel:
				viewport.remove_child(child)
				child.queue_free()
	container = null
	viewport = null
	camera = null
	_preview_dirty = true
	request_version += 1
	_set_state(&"sin_pista")


func rebuild(track: TrackLevel, map_view: TrackMapView) -> void:
	request_rebuild(track, map_view)
	flush_pending(track, map_view)


func request_rebuild(track: TrackLevel, map_view: TrackMapView = null) -> int:
	if track == null:
		_preview_dirty = false
		_set_state(&"sin_pista")
		return request_version
	var signature := _get_track_signature(track)
	var track_id := track.get_instance_id()
	if (
		track_id == _track_instance_id
		and signature == _requested_signature
		and _preview_dirty
	):
		return request_version
	if track_id == _track_instance_id and signature == _applied_signature:
		_preview_dirty = false
		_set_state(&"actualizado")
		return request_version
	_track_instance_id = track_id
	_requested_signature = signature
	request_version += 1
	_preview_dirty = true
	_set_state(&"pendiente")
	if map_view != null:
		map_view.queue_redraw()
	return request_version


func flush_pending(track: TrackLevel, map_view: TrackMapView = null) -> bool:
	if not _preview_dirty:
		return false
	if track == null or not track.is_inside_tree():
		return false
	if not is_showing_preview:
		_set_state(&"diferido")
		return false
	var version_at_start := request_version
	var signature_at_start := _requested_signature
	var errors := track.rebuild_preview()
	var signature_after_rebuild := _get_track_signature(track)
	if (
		version_at_start != request_version
		or signature_at_start != signature_after_rebuild
	):
		discarded_rebuild_count += 1
		_requested_signature = signature_after_rebuild
		request_version += 1
		_preview_dirty = true
		_set_state(&"pendiente")
		return false
	_applied_signature = signature_at_start
	applied_version = version_at_start
	_preview_dirty = false
	rebuild_count += 1
	var has_warnings := false
	for issue in track.inspect_track():
		if issue.severity == TrackValidationIssue.Severity.WARNING:
			has_warnings = true
			break
	_set_state(
		&"actualizado"
		if errors.is_empty() and not has_warnings
		else &"actualizado_con_advertencias"
	)
	if map_view != null:
		map_view.queue_redraw()
	if not track.route_points.is_empty():
		frame_camera(track.route_points)
	return true


func has_pending_rebuild() -> bool:
	return _preview_dirty


func is_preview_pending() -> bool:
	return _preview_dirty


func get_preview_status() -> Dictionary:
	return {
		"state": preview_state,
		"request_version": request_version,
		"applied_version": applied_version,
		"pending": _preview_dirty,
		"rebuild_count": rebuild_count,
		"discarded_rebuild_count": discarded_rebuild_count,
		"requested_signature": _requested_signature,
		"applied_signature": _applied_signature,
	}


func frame_camera(route: PackedVector3Array) -> void:
	if camera == null or route.is_empty():
		return
	var maximum_radius := 50.0
	var center := Vector3.ZERO
	for point in route:
		center += point
	center /= route.size()
	for point in route:
		maximum_radius = maxf(maximum_radius, center.distance_to(point))
	camera.position = center + Vector3(
		maximum_radius * 1.25,
		maximum_radius * 1.15,
		maximum_radius * 1.25
	)
	camera.look_at(center)


func toggle_view(
	map_view: TrackMapView,
	toggle_button: Button,
	track: TrackLevel
) -> bool:
	is_showing_preview = not is_showing_preview
	map_view.visible = not is_showing_preview
	container.visible = is_showing_preview
	toggle_button.text = "MAPA AÉREO" if is_showing_preview else "VISTA 3D"
	if is_showing_preview:
		request_rebuild(track, map_view)
		flush_pending(track, map_view)
	else:
		_set_state(&"diferido" if _preview_dirty else &"oculto")
	return is_showing_preview


func _set_state(new_state: StringName) -> void:
	if preview_state == new_state:
		return
	preview_state = new_state
	state_changed.emit(preview_state)


func _get_track_signature(track: TrackLevel) -> String:
	var values: Array[String] = []
	var route := track.get_main_route()
	if route != null and route.curve != null:
		for index in route.curve.point_count:
			values.append(str(route.curve.get_point_position(index)))
			values.append(str(route.curve.get_point_in(index)))
			values.append(str(route.curve.get_point_out(index)))
		values.append(str(route.curve.closed))
	values.append(str(track.start_point_index))
	values.append(str(track.route_subdivisions))
	values.append(str(track.shortcut_subdivisions))
	_append_resource_signature(values, track.track_theme)
	values.append(str(track.track_music.resource_path if track.track_music != null else ""))
	values.append(str(track.track_id))
	for shortcut in track.get_shortcuts():
		values.append(str(shortcut.name))
		values.append(str(shortcut.shortcut_id))
		if shortcut.curve != null:
			for index in shortcut.curve.point_count:
				values.append(str(shortcut.curve.get_point_position(index)))
				values.append(str(shortcut.curve.get_point_in(index)))
				values.append(str(shortcut.curve.get_point_out(index)))
	for container_name in ["ItemSpawns", "Props"]:
		var container := track.get_node_or_null(container_name)
		if container == null:
			continue
		for child in container.get_children():
			if child is Node3D:
				values.append("%s:%s:%s" % [container_name, child.name, child.transform])
				for metadata_key in [
					&"track_editor_anchor_progress",
					&"track_editor_anchor_lateral",
					&"track_editor_anchor_height",
					&"track_editor_anchor_rotation",
					&"track_editor_prop_scale_multiplier",
				]:
					values.append(str(child.get_meta(metadata_key, "")))
	for zone in track.get_surface_zones():
		values.append("surface:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [
			zone.name,
			zone.id,
			_surface_signature(zone.surface),
			zone.path_kind,
			zone.shortcut_id,
			zone.start_progress,
			zone.end_progress,
			zone.lateral_offset,
			zone.width,
			zone.surface_priority,
		])
	return str(hash("|".join(values)))


func _append_resource_signature(values: Array[String], resource: Resource) -> void:
	if resource == null:
		values.append("<none>")
		return
	values.append(resource.resource_path)
	if resource is TrackTheme:
		var theme := resource as TrackTheme
		values.append("%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
			theme.road_color,
			theme.curb_color,
			theme.terrain_color,
			theme.barrier_color,
			theme.shortcut_color,
			theme.water_color,
			theme.sky_color,
			theme.ambient_color,
			theme.banner_color,
		])


func _surface_signature(surface: SurfaceDefinition) -> String:
	if surface == null:
		return "<none>"
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		surface.resource_path,
		surface.id,
		surface.display_name,
		surface.color,
		surface.grip_multiplier,
		surface.drift_grip_multiplier,
		surface.rolling_resistance_multiplier,
		surface.acceleration_multiplier,
		surface.boost_multiplier,
		surface.effect_scene.resource_path
		if surface.effect_scene != null
		else "",
		surface.audio_pitch,
		surface.audio_volume,
		surface.audio_roughness,
		surface.particle_color,
	]


func _build_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#22343a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d8ece6")
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	viewport.add_child(light)

	camera = Camera3D.new()
	camera.position = Vector3(135.0, 150.0, 135.0)
	camera.fov = 58.0
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	viewport.add_child(camera)
