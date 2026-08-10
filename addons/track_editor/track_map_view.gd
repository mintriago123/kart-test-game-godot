@tool
class_name TrackMapView
extends Control

signal point_selected(point_index: int)
signal selection_changed(selection: RefCounted)
signal edit_started
signal route_edited
signal edit_finished
signal entity_move_requested(selection: RefCounted, track_position: Vector3)
signal entity_delete_requested(selection: RefCounted)
signal entity_duplicate_requested(selection: RefCounted)

const Selection := preload(
	"res://addons/track_editor/track_editor_selection.gd"
)

const BACKGROUND_COLOR := Color("#151b1f")
const GRID_COLOR := Color("#293238")
const METRIC_BACKGROUND_COLOR := Color("#151b1fd9")
const METRIC_TEXT_COLOR := Color("#c7d0d2")
const ROAD_COLOR := Color("#eef1e8")
const ROAD_EDGE_COLOR := Color("#59666d")
const ACCENT_COLOR := Color("#f6c344")
const SHORTCUT_COLOR := Color("#42c7b9")
const SAFE_CORRIDOR_COLOR := Color("#55d68b80")
const TIGHT_CORRIDOR_COLOR := Color("#f6c34480")
const UNSAFE_CORRIDOR_COLOR := Color("#ef765680")
const ERROR_COLOR := Color("#ef7656")
const WARNING_COLOR := Color("#f6c344")
const MAP_PADDING := 54.0
const POINT_RADIUS := 9.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 8.0
const ZOOM_FACTOR := 1.15

var track: TrackLevel
var selected_point := -1
var selection: RefCounted = Selection.none()
var grid_step := 1.0

var _is_dragging := false
var _is_panning := false
var _space_pressed := false
var _last_pointer_position := Vector2.ZERO
var _zoom := 1.0
var _pan := Vector2.ZERO
var _issues: Array[TrackValidationIssue] = []
var _layers := {
	&"direction": true,
	&"objects": true,
	&"shortcuts": true,
	&"errors": true,
	&"slope": false,
	&"curvature": false,
	&"barriers": false,
}
var _map_bounds := Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0))
var _route_bounds := Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0))


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	tooltip_text = (
		"Arrastra los puntos para mover la carretera. "
		+ "También puedes usar las flechas del teclado."
	)
	resized.connect(_handle_resized)


func set_track(new_track: TrackLevel) -> void:
	track = new_track
	clear_selection()
	_refresh_bounds()
	frame_all()
	queue_redraw()


func set_issues(issues: Array[TrackValidationIssue]) -> void:
	_issues = issues
	queue_redraw()


func set_layer_enabled(layer: StringName, is_enabled: bool) -> void:
	if _layers.has(layer):
		_layers[layer] = is_enabled
		queue_redraw()


func is_layer_enabled(layer: StringName) -> bool:
	return bool(_layers.get(layer, false))


func set_grid_step(value: float) -> void:
	grid_step = value if value in [1.0, 2.0, 5.0] else 1.0


func frame_all() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	queue_redraw()


func refresh_view_bounds() -> void:
	_refresh_bounds()
	queue_redraw()


func zoom_in() -> void:
	_set_zoom(_zoom * ZOOM_FACTOR)


func zoom_out() -> void:
	_set_zoom(_zoom / ZOOM_FACTOR)


func clear_selection() -> void:
	selection = Selection.none()
	selected_point = -1
	queue_redraw()


func set_selection(new_selection: RefCounted, center := false) -> void:
	selection = new_selection if new_selection != null else Selection.none()
	selected_point = (
		selection.point_index
		if selection.kind == Selection.Kind.ROUTE_POINT
		else -1
	)
	if center and not selection.is_empty():
		_center_on_world_position(_get_selection_position(selection))
	selection_changed.emit(selection)
	if selected_point >= 0:
		point_selected.emit(selected_point)
	queue_redraw()


func insert_point_after_selected() -> bool:
	var curve := _get_curve()
	if curve == null:
		return false
	var index := selected_point if selected_point >= 0 else 0
	var next_index := (index + 1) % curve.point_count
	var midpoint := curve.get_point_position(index).lerp(
		curve.get_point_position(next_index),
		0.5
	)
	edit_started.emit()
	curve.add_point(midpoint, Vector3.ZERO, Vector3.ZERO, index + 1)
	selected_point = index + 1
	_smooth_curve(curve)
	_finish_discrete_edit()
	return true


func delete_selected_point() -> bool:
	var curve := _get_curve()
	if curve == null or selected_point < 0 or curve.point_count <= 4:
		return false
	edit_started.emit()
	curve.remove_point(selected_point)
	selected_point = mini(selected_point, curve.point_count - 1)
	_smooth_curve(curve)
	_finish_discrete_edit()
	return true


func set_selected_height(height: float) -> bool:
	var curve := _get_curve()
	if curve == null or selected_point < 0:
		return false
	edit_started.emit()
	var position := curve.get_point_position(selected_point)
	position.y = height
	curve.set_point_position(selected_point, position)
	_smooth_curve(curve)
	_finish_discrete_edit()
	return true


func mark_selected_as_start() -> bool:
	if track == null or selected_point < 0:
		return false
	track.start_point_index = selected_point
	route_edited.emit()
	edit_finished.emit()
	queue_redraw()
	return true


func _gui_input(event: InputEvent) -> void:
	var curve := _get_curve()
	if curve == null:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mouse_button.pressed:
				_set_zoom(
					_zoom * ZOOM_FACTOR
					if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP
					else _zoom / ZOOM_FACTOR
				)
				accept_event()
			return
		var pan_button: bool = (
			mouse_button.button_index == MOUSE_BUTTON_MIDDLE
			or (
				mouse_button.button_index == MOUSE_BUTTON_LEFT
				and _space_pressed
			)
		)
		if pan_button:
			_is_panning = mouse_button.pressed
			_last_pointer_position = mouse_button.position
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			grab_focus()
			var hit_selection := _find_selection_at(mouse_button.position)
			if not hit_selection.is_empty():
				set_selection(hit_selection)
				_is_dragging = true
				edit_started.emit()
				accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if _is_dragging:
				_is_dragging = false
				route_edited.emit()
				edit_finished.emit()
				_refresh_bounds()
				queue_redraw()
				accept_event()
	elif event is InputEventMouseMotion and _is_panning:
		var pan_motion := event as InputEventMouseMotion
		_pan += pan_motion.position - _last_pointer_position
		_last_pointer_position = pan_motion.position
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _is_dragging and not selection.is_empty():
		var mouse_motion := event as InputEventMouseMotion
		var mapped_position := _screen_to_world(mouse_motion.position)
		var current_position := _get_selection_position(selection)
		mapped_position.y = current_position.y
		if mouse_motion.ctrl_pressed:
			mapped_position.x = snappedf(mapped_position.x, grid_step)
			mapped_position.z = snappedf(mapped_position.z, grid_step)
		entity_move_requested.emit(selection, mapped_position)
		route_edited.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_SPACE:
			_space_pressed = key_event.pressed
			return
		if not key_event.pressed or key_event.echo or selection.is_empty():
			return
		var movement := Vector3.ZERO
		var movement_step := 0.25 if key_event.shift_pressed else 1.0
		match key_event.keycode:
			KEY_LEFT:
				movement.x = -movement_step
			KEY_RIGHT:
				movement.x = movement_step
			KEY_UP:
				movement.z = -movement_step
			KEY_DOWN:
				movement.z = movement_step
			KEY_DELETE:
				entity_delete_requested.emit(selection)
				accept_event()
				return
			KEY_D:
				if key_event.ctrl_pressed:
					entity_duplicate_requested.emit(selection)
					accept_event()
				return
			_:
				return
		edit_started.emit()
		var target_position := _get_selection_position(selection) + movement
		if key_event.ctrl_pressed:
			target_position.x = snappedf(target_position.x, grid_step)
			target_position.z = snappedf(target_position.z, grid_step)
		entity_move_requested.emit(selection, target_position)
		route_edited.emit()
		edit_finished.emit()
		_refresh_bounds()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_grid()
	var curve := _get_curve()
	if curve == null:
		_draw_centered_message("Abre o crea una pista para comenzar")
		return
	var baked_points := curve.get_baked_points()
	if baked_points.size() >= 2:
		var screen_points := PackedVector2Array()
		for baked_point in baked_points:
			screen_points.append(_world_to_screen(baked_point))
		screen_points.append(screen_points[0])
		var road_width_pixels := maxf(
			_world_distance_to_screen(CoastalTrack.ROAD_WIDTH),
			8.0
		)
		draw_polyline(screen_points, ROAD_EDGE_COLOR, road_width_pixels + 4.0, true)
		draw_polyline(screen_points, ROAD_COLOR, road_width_pixels, true)
		if is_layer_enabled(&"slope"):
			_draw_slope_overlay(baked_points)
		if is_layer_enabled(&"barriers"):
			_draw_barriers(screen_points, road_width_pixels)
		if is_layer_enabled(&"direction"):
			_draw_direction_arrows(screen_points)
	if is_layer_enabled(&"shortcuts"):
		_draw_shortcuts()
	if is_layer_enabled(&"objects"):
		_draw_objects()
	for point_index in curve.point_count:
		var point_position := _world_to_screen(curve.get_point_position(point_index))
		var point_color := ACCENT_COLOR if point_index == selected_point else Color("#f4f1e8")
		draw_circle(point_position, POINT_RADIUS + 3.0, BACKGROUND_COLOR)
		draw_circle(point_position, POINT_RADIUS, point_color)
		draw_string(
			get_theme_default_font(),
			point_position + Vector2(13.0, 5.0),
			str(point_index + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			point_color
		)
	if track.start_point_index >= 0 and track.start_point_index < curve.point_count:
		var start_position := _world_to_screen(
			curve.get_point_position(track.start_point_index)
		)
		draw_arc(start_position, 17.0, 0.0, TAU, 24, ERROR_COLOR, 3.0, true)
		draw_string(
			get_theme_default_font(),
			start_position + Vector2(-24.0, -22.0),
			"SALIDA",
			HORIZONTAL_ALIGNMENT_CENTER,
			48.0,
			12,
			ERROR_COLOR
		)
	if is_layer_enabled(&"curvature"):
		_draw_curvature_overlay(curve)
	if is_layer_enabled(&"errors"):
		_draw_issues()
	_draw_metric_overlay()


func _draw_grid() -> void:
	var world_grid_step := get_scale_bar_distance()
	var first_corner := _screen_to_world(Vector2.ZERO)
	var final_corner := _screen_to_world(size)
	var minimum_x := minf(first_corner.x, final_corner.x)
	var maximum_x := maxf(first_corner.x, final_corner.x)
	var minimum_z := minf(first_corner.z, final_corner.z)
	var maximum_z := maxf(first_corner.z, final_corner.z)
	var world_x := floorf(minimum_x / world_grid_step) * world_grid_step
	while world_x <= maximum_x:
		var screen_x := _world_to_screen(Vector3(world_x, 0.0, 0.0)).x
		draw_line(
			Vector2(screen_x, 0.0),
			Vector2(screen_x, size.y),
			GRID_COLOR,
			1.0
		)
		world_x += world_grid_step
	var world_z := floorf(minimum_z / world_grid_step) * world_grid_step
	while world_z <= maximum_z:
		var screen_y := _world_to_screen(Vector3(0.0, 0.0, world_z)).y
		draw_line(
			Vector2(0.0, screen_y),
			Vector2(size.x, screen_y),
			GRID_COLOR,
			1.0
		)
		world_z += world_grid_step


func _draw_metric_overlay() -> void:
	if _get_curve() == null:
		return
	var metrics := get_map_metrics()
	var panel_height := 48.0
	draw_rect(
		Rect2(Vector2(0.0, size.y - panel_height), Vector2(size.x, panel_height)),
		METRIC_BACKGROUND_COLOR
	)
	var dimensions: Vector2 = metrics.dimensions
	draw_string(
		get_theme_default_font(),
		Vector2(14.0, size.y - 27.0),
		"Circuito %d × %d m  ·  ≈%d m  ·  %d puntos"
		% [
			roundi(dimensions.x),
			roundi(dimensions.y),
			roundi(float(metrics.length)),
			int(metrics.point_count),
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(size.x - 175.0, 20.0),
		14,
		METRIC_TEXT_COLOR
	)
	draw_string(
		get_theme_default_font(),
		Vector2(14.0, size.y - 9.0),
		"Zoom %d%%" % roundi(float(metrics.zoom) * 100.0),
		HORIZONTAL_ALIGNMENT_LEFT,
		110.0,
		14,
		METRIC_TEXT_COLOR
	)
	var bar_pixels := float(metrics.scale_bar_pixels)
	var bar_end := Vector2(size.x - 18.0, size.y - 13.0)
	var bar_start := bar_end - Vector2(bar_pixels, 0.0)
	draw_line(bar_start, bar_end, ACCENT_COLOR, 3.0, true)
	draw_line(
		bar_start - Vector2(0.0, 5.0),
		bar_start + Vector2(0.0, 5.0),
		ACCENT_COLOR,
		2.0
	)
	draw_line(
		bar_end - Vector2(0.0, 5.0),
		bar_end + Vector2(0.0, 5.0),
		ACCENT_COLOR,
		2.0
	)
	draw_string(
		get_theme_default_font(),
		bar_start + Vector2(0.0, -7.0),
		"%d m" % int(metrics.scale_bar_meters),
		HORIZONTAL_ALIGNMENT_CENTER,
		bar_pixels,
		14,
		ACCENT_COLOR
	)


func _draw_direction_arrows(points: PackedVector2Array) -> void:
	for point_index in range(12, points.size() - 1, 24):
		var position := points[point_index]
		var forward := (points[point_index + 1] - points[point_index - 1]).normalized()
		var side := Vector2(-forward.y, forward.x)
		var arrow := PackedVector2Array([
			position + forward * 10.0,
			position - forward * 7.0 + side * 6.0,
			position - forward * 7.0 - side * 6.0,
		])
		draw_colored_polygon(arrow, ACCENT_COLOR)


func _draw_shortcuts() -> void:
	if track == null:
		return
	for shortcut in track.get_shortcuts():
		if shortcut.curve == null:
			continue
		var shortcut_points := PackedVector2Array()
		for point in shortcut.curve.get_baked_points():
			shortcut_points.append(_world_to_screen(point))
		if shortcut_points.size() >= 2:
			var corridor_width := maxf(
				_world_distance_to_screen(CoastalTrack.SHORTCUT_WIDTH),
				10.0
			)
			draw_polyline(
				shortcut_points,
				_get_shortcut_safety_color(shortcut),
				corridor_width,
				true
			)
			_draw_shortcut_junctions(shortcut)
			draw_polyline(shortcut_points, SHORTCUT_COLOR, 8.0, true)
			_draw_handle(shortcut_points[0], SHORTCUT_COLOR, false)
			_draw_handle(shortcut_points[-1], SHORTCUT_COLOR, false)


func get_shortcut_safety_state(shortcut: TrackShortcut) -> StringName:
	if track == null or shortcut == null:
		return &"unsafe"
	var safety := TrackLevelValidator.get_shortcut_safety(track, shortcut)
	if not bool(safety.safe):
		return &"unsafe"
	if (
		float(safety.turn_radius)
		>= TrackLevelValidator.SHORTCUT_MINIMUM_TURN_RADIUS * 1.25
		and float(safety.clearance)
		>= TrackLevelValidator.SHORTCUT_ROUTE_CLEARANCE * 1.25
	):
		return &"comfortable"
	return &"tight"


func _get_shortcut_safety_color(shortcut: TrackShortcut) -> Color:
	match get_shortcut_safety_state(shortcut):
		&"comfortable":
			return SAFE_CORRIDOR_COLOR
		&"tight":
			return TIGHT_CORRIDOR_COLOR
		_:
			return UNSAFE_CORRIDOR_COLOR
			var middle_index := shortcut.curve.point_count / 2
			var midpoint := _world_to_screen(
				shortcut.transform * shortcut.curve.get_point_position(middle_index)
			)
			var is_selected: bool = (
				selection.kind == Selection.Kind.SHORTCUT_MIDPOINT
				and selection.node_path == track.get_path_to(shortcut)
			)
			_draw_handle(midpoint, SHORTCUT_COLOR, is_selected)


func _draw_shortcut_junctions(shortcut: TrackShortcut) -> void:
	var junctions: Dictionary = track._shortcut_junctions.get(shortcut.shortcut_id, {})
	for junction_key in ["entry", "exit"]:
		var junction = junctions.get(junction_key)
		if junction == null or not junction.is_valid:
			continue
		var left_line := PackedVector2Array()
		var right_line := PackedVector2Array()
		for point in junction.left_boundary:
			left_line.append(_world_to_screen(point))
		for point in junction.right_boundary:
			right_line.append(_world_to_screen(point))
		for point_index in left_line.size() - 1:
			_draw_junction_triangle(
				left_line[point_index],
				left_line[point_index + 1],
				right_line[point_index + 1]
			)
			_draw_junction_triangle(
				left_line[point_index],
				right_line[point_index + 1],
				right_line[point_index]
			)
		draw_polyline(left_line, ROAD_EDGE_COLOR, 2.0, true)
		draw_polyline(right_line, ROAD_EDGE_COLOR, 2.0, true)
		if is_layer_enabled(&"barriers"):
			draw_polyline(left_line, ERROR_COLOR, 2.0, true)
			draw_polyline(right_line, ERROR_COLOR, 2.0, true)


func _draw_junction_triangle(first: Vector2, second: Vector2, third: Vector2) -> void:
	if absf((second - first).cross(third - first)) <= 0.001:
		return
	draw_colored_polygon(
		PackedVector2Array([first, second, third]),
		Color(SHORTCUT_COLOR, 0.32)
	)


func _draw_objects() -> void:
	if track == null:
		return
	var item_root := track.get_node_or_null("ItemSpawns")
	if item_root != null:
		for child in item_root.get_children():
			if child is Marker3D:
				var item_path := track.get_path_to(child)
				_draw_entity_marker(
					_get_node_track_position(child),
					Color("#ef7656"),
					selection.kind == Selection.Kind.ITEM
					and selection.node_path == item_path,
					false
				)
	var props := track.get_node_or_null("Props")
	if props != null:
		for child in props.get_children():
			if child is Node3D:
				var prop_path := track.get_path_to(child)
				_draw_entity_marker(
					_get_node_track_position(child),
					Color("#42c7b9"),
					selection.kind == Selection.Kind.PROP
					and selection.node_path == prop_path,
					true
				)


func _draw_entity_marker(
	world_position: Vector3,
	color: Color,
	is_selected: bool,
	is_diamond: bool
) -> void:
	var point := _world_to_screen(world_position)
	var radius := 10.0 if is_selected else 7.0
	if is_diamond:
		var diamond := PackedVector2Array([
			point + Vector2(0.0, -radius),
			point + Vector2(radius, 0.0),
			point + Vector2(0.0, radius),
			point + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(diamond, color)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), BACKGROUND_COLOR, 2.0)
	else:
		draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color)
		draw_rect(
			Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
			BACKGROUND_COLOR,
			false,
			2.0
		)


func _draw_handle(point: Vector2, color: Color, is_selected: bool) -> void:
	draw_circle(point, 10.0 if is_selected else 7.0, BACKGROUND_COLOR)
	draw_circle(point, 7.0 if is_selected else 5.0, color)


func _draw_slope_overlay(points: PackedVector3Array) -> void:
	for point_index in points.size():
		var next_index := (point_index + 1) % points.size()
		var delta := points[next_index] - points[point_index]
		var horizontal := Vector2(delta.x, delta.z).length()
		var grade := absf(delta.y) / maxf(horizontal, 0.01)
		var color := Color("#42c7b9").lerp(ERROR_COLOR, clampf(grade / 0.2, 0.0, 1.0))
		draw_line(
			_world_to_screen(points[point_index]),
			_world_to_screen(points[next_index]),
			color,
			3.0,
			true
		)


func _draw_curvature_overlay(curve: Curve3D) -> void:
	for point_index in curve.point_count:
		var previous := curve.get_point_position(
			(point_index - 1 + curve.point_count) % curve.point_count
		)
		var current := curve.get_point_position(point_index)
		var next := curve.get_point_position((point_index + 1) % curve.point_count)
		var first := Vector2(previous.x - current.x, previous.z - current.z).normalized()
		var second := Vector2(next.x - current.x, next.z - current.z).normalized()
		var sharpness := clampf((first.dot(second) + 1.0) * 0.5, 0.0, 1.0)
		var color := Color("#42c7b9").lerp(ERROR_COLOR, sharpness)
		draw_arc(_world_to_screen(current), 15.0, 0.0, TAU, 20, color, 3.0)


func _draw_barriers(points: PackedVector2Array, road_width_pixels: float) -> void:
	var half_width := road_width_pixels * 0.5
	for side_sign in [-1.0, 1.0]:
		var barrier := PackedVector2Array()
		for point_index in points.size() - 1:
			var previous := points[(point_index - 1 + points.size() - 1) % (points.size() - 1)]
			var next := points[(point_index + 1) % (points.size() - 1)]
			var forward := (next - previous).normalized()
			barrier.append(
				points[point_index]
				+ Vector2(-forward.y, forward.x) * half_width * side_sign
			)
		barrier.append(barrier[0])
		draw_polyline(barrier, ERROR_COLOR, 2.0, true)


func _draw_issues() -> void:
	for issue in _issues:
		var position := issue.world_position
		if position.is_zero_approx() and not issue.target_path.is_empty():
			var target := track.get_node_or_null(issue.target_path) as Node3D
			if target != null:
				position = _get_node_track_position(target)
		if position.is_zero_approx():
			continue
		var screen_position := _world_to_screen(position)
		var issue_color := (
			WARNING_COLOR
			if issue.severity == TrackValidationIssue.Severity.WARNING
			else ERROR_COLOR
		)
		draw_arc(screen_position, 14.0, 0.0, TAU, 20, issue_color, 3.0, true)
		draw_string(
			get_theme_default_font(),
			screen_position + Vector2(12.0, -10.0),
			"!",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			16,
			issue_color
		)


func _draw_centered_message(message: String) -> void:
	draw_string(
		get_theme_default_font(),
		Vector2(0.0, size.y * 0.5),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		18,
		Color("#aab5b9")
	)


func _find_point_at(screen_position: Vector2) -> int:
	var curve := _get_curve()
	var closest_index := -1
	var closest_distance := POINT_RADIUS * 2.2
	for point_index in curve.point_count:
		var distance := screen_position.distance_to(
			_world_to_screen(curve.get_point_position(point_index))
		)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = point_index
	return closest_index


func _refresh_bounds() -> void:
	var curve := _get_curve()
	if curve == null or curve.point_count == 0:
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var bound_points := curve.get_baked_points()
	for point_index in curve.point_count:
		bound_points.append(curve.get_point_position(point_index))
	if track != null:
		for shortcut in track.get_shortcuts():
			if shortcut.curve == null:
				continue
			for shortcut_point in shortcut.curve.get_baked_points():
				bound_points.append(shortcut.transform * shortcut_point)
	for point in bound_points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.z)
	if maximum.x - minimum.x < 10.0:
		maximum.x = minimum.x + 10.0
	if maximum.y - minimum.y < 10.0:
		maximum.y = minimum.y + 10.0
	_route_bounds = Rect2(minimum, maximum - minimum)
	_map_bounds = _route_bounds.grow(
		CoastalTrack.ROAD_WIDTH * 0.5 + 4.0
	)


func _handle_resized() -> void:
	frame_all()


func _world_to_screen(position: Vector3) -> Vector2:
	var scale := _get_screen_scale()
	var used_size := _map_bounds.size * scale
	var offset := (size - used_size) * 0.5 + _pan
	return offset + (Vector2(position.x, position.z) - _map_bounds.position) * scale


func _screen_to_world(screen_position: Vector2) -> Vector3:
	var scale := _get_screen_scale()
	var used_size := _map_bounds.size * scale
	var offset := (size - used_size) * 0.5 + _pan
	var mapped := (screen_position - offset) / scale + _map_bounds.position
	return Vector3(mapped.x, 0.0, mapped.y)


func _get_screen_scale() -> float:
	var available_size := (size - Vector2.ONE * MAP_PADDING * 2.0).max(Vector2.ONE)
	var fit_scale := minf(
		available_size.x / _map_bounds.size.x,
		available_size.y / _map_bounds.size.y
	)
	return maxf(fit_scale * _zoom, 0.0001)


func _world_distance_to_screen(distance: float) -> float:
	return distance * _get_screen_scale()


func get_scale_bar_distance() -> float:
	var best_distance := 5.0
	var best_difference := INF
	for candidate in [5.0, 10.0, 20.0, 50.0]:
		var difference := absf(
			_world_distance_to_screen(candidate) - 90.0
		)
		if difference < best_difference:
			best_difference = difference
			best_distance = candidate
	return best_distance


func get_map_metrics() -> Dictionary:
	var curve := _get_curve()
	var scale_bar_distance := get_scale_bar_distance()
	return {
		"dimensions": _route_bounds.size,
		"length": curve.get_baked_length() if curve != null else 0.0,
		"point_count": curve.point_count if curve != null else 0,
		"zoom": _zoom,
		"scale_bar_meters": scale_bar_distance,
		"scale_bar_pixels": _world_distance_to_screen(scale_bar_distance),
	}


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	queue_redraw()


func _center_on_world_position(world_position: Vector3) -> void:
	var current_screen := _world_to_screen(world_position)
	_pan += size * 0.5 - current_screen
	queue_redraw()


func _smooth_curve(curve: Curve3D) -> void:
	for point_index in curve.point_count:
		var previous := curve.get_point_position(
			(point_index - 1 + curve.point_count) % curve.point_count
		)
		var next := curve.get_point_position((point_index + 1) % curve.point_count)
		var tangent := (next - previous) / 6.0
		curve.set_point_in(point_index, -tangent)
		curve.set_point_out(point_index, tangent)


func _finish_discrete_edit() -> void:
	route_edited.emit()
	edit_finished.emit()
	_refresh_bounds()
	point_selected.emit(selected_point)
	queue_redraw()


func _get_curve() -> Curve3D:
	var route := track.get_main_route() if track != null else null
	return route.curve if route != null else null


func _find_selection_at(screen_position: Vector2) -> RefCounted:
	var best := Selection.none()
	var best_distance := POINT_RADIUS * 2.4
	var curve := _get_curve()
	if curve == null:
		return best
	for point_index in curve.point_count:
		var distance := screen_position.distance_to(
			_world_to_screen(curve.get_point_position(point_index))
		)
		if distance < best_distance:
			best_distance = distance
			best = Selection.route_point(point_index)
	if is_layer_enabled(&"objects"):
		for container_data in [
			{"path": NodePath("ItemSpawns"), "kind": Selection.Kind.ITEM},
			{"path": NodePath("Props"), "kind": Selection.Kind.PROP},
		]:
			var container := track.get_node_or_null(container_data.path)
			if container == null:
				continue
			for child in container.get_children():
				if not child is Node3D:
					continue
				var distance := screen_position.distance_to(
					_world_to_screen(_get_node_track_position(child))
				)
				if distance < best_distance:
					best_distance = distance
					best = Selection.node(
						int(container_data.kind),
						track.get_path_to(child)
					)
	if is_layer_enabled(&"shortcuts"):
		for shortcut in track.get_shortcuts():
			if shortcut.curve == null or shortcut.curve.point_count < 3:
				continue
			var midpoint := shortcut.transform * shortcut.curve.get_point_position(
				shortcut.curve.point_count / 2
			)
			var distance := screen_position.distance_to(_world_to_screen(midpoint))
			if distance < best_distance:
				best_distance = distance
				best = Selection.node(
					Selection.Kind.SHORTCUT_MIDPOINT,
					track.get_path_to(shortcut)
				)
	return best


func _get_selection_position(selected: RefCounted) -> Vector3:
	if track == null or selected == null:
		return Vector3.ZERO
	if selected.kind == Selection.Kind.ROUTE_POINT:
		var route := track.get_main_route() as Path3D
		if (
			route != null
			and route.curve != null
			and selected.point_index >= 0
			and selected.point_index < route.curve.point_count
		):
			return route.transform * route.curve.get_point_position(selected.point_index)
		return Vector3.ZERO
	var node := track.get_node_or_null(selected.node_path) as Node3D
	if node == null:
		return Vector3.ZERO
	if selected.kind == Selection.Kind.SHORTCUT_MIDPOINT:
		var shortcut := node as TrackShortcut
		if shortcut != null and shortcut.curve != null:
			return shortcut.transform * shortcut.curve.get_point_position(
				shortcut.curve.point_count / 2
			)
	return _get_node_track_position(node)


func _get_node_track_position(node: Node3D) -> Vector3:
	var relative_transform := Transform3D.IDENTITY
	var current := node
	while current != null and current != track:
		relative_transform = current.transform * relative_transform
		current = current.get_parent() as Node3D
	return relative_transform.origin
