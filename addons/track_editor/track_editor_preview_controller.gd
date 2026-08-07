@tool
class_name TrackEditorPreviewController
extends RefCounted

var container: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var is_showing_preview := false


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


func rebuild(track: TrackLevel, map_view: TrackMapView) -> void:
	if track == null or not track.is_inside_tree():
		return
	track.rebuild_preview()
	if map_view != null:
		map_view.queue_redraw()
	if not track.route_points.is_empty():
		frame_camera(track.route_points)


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
		rebuild(track, map_view)
	return is_showing_preview


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
