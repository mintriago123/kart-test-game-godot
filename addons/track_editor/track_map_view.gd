@tool
class_name TrackMapView
extends Control

signal point_selected(point_index: int)
signal edit_started
signal route_edited
signal edit_finished

const BACKGROUND_COLOR := Color("#151b1f")
const GRID_COLOR := Color("#293238")
const ROAD_COLOR := Color("#eef1e8")
const ROAD_EDGE_COLOR := Color("#59666d")
const ACCENT_COLOR := Color("#f6c344")
const SHORTCUT_COLOR := Color("#42c7b9")
const ERROR_COLOR := Color("#ef7656")
const MAP_PADDING := 54.0
const POINT_RADIUS := 9.0

var track: TrackLevel
var selected_point := -1

var _is_dragging := false
var _map_bounds := Rect2(Vector2(-100.0, -100.0), Vector2(200.0, 200.0))


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	tooltip_text = (
		"Arrastra los puntos para mover la carretera. "
		+ "También puedes usar las flechas del teclado."
	)
	resized.connect(queue_redraw)


func set_track(new_track: TrackLevel) -> void:
	track = new_track
	selected_point = -1
	_refresh_bounds()
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
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			grab_focus()
			var hit_index := _find_point_at(mouse_button.position)
			if hit_index >= 0:
				selected_point = hit_index
				_is_dragging = true
				edit_started.emit()
				point_selected.emit(selected_point)
				queue_redraw()
				accept_event()
		elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if _is_dragging:
				_is_dragging = false
				_smooth_curve(curve)
				route_edited.emit()
				edit_finished.emit()
				_refresh_bounds()
				queue_redraw()
				accept_event()
	elif event is InputEventMouseMotion and _is_dragging and selected_point >= 0:
		var mouse_motion := event as InputEventMouseMotion
		var position := curve.get_point_position(selected_point)
		var mapped_position := _screen_to_world(mouse_motion.position)
		position.x = mapped_position.x
		position.z = mapped_position.z
		curve.set_point_position(selected_point, position)
		route_edited.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo or selected_point < 0:
			return
		var movement := Vector3.ZERO
		match key_event.keycode:
			KEY_LEFT:
				movement.x = -1.0
			KEY_RIGHT:
				movement.x = 1.0
			KEY_UP:
				movement.z = -1.0
			KEY_DOWN:
				movement.z = 1.0
			KEY_DELETE:
				delete_selected_point()
				accept_event()
				return
			_:
				return
		edit_started.emit()
		curve.set_point_position(
			selected_point,
			curve.get_point_position(selected_point) + movement
		)
		_smooth_curve(curve)
		_finish_discrete_edit()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	_draw_grid()
	var curve := _get_curve()
	if curve == null:
		_draw_centered_message("Abre o crea una pista para comenzar")
		return
	_refresh_bounds()
	var baked_points := curve.get_baked_points()
	if baked_points.size() >= 2:
		var screen_points := PackedVector2Array()
		for baked_point in baked_points:
			screen_points.append(_world_to_screen(baked_point))
		screen_points.append(screen_points[0])
		draw_polyline(screen_points, ROAD_EDGE_COLOR, 18.0, true)
		draw_polyline(screen_points, ROAD_COLOR, 11.0, true)
		_draw_direction_arrows(screen_points)
	_draw_shortcuts()
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


func _draw_grid() -> void:
	var grid_step := 32.0
	var x := fmod(size.x * 0.5, grid_step)
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), GRID_COLOR, 1.0)
		x += grid_step
	var y := fmod(size.y * 0.5, grid_step)
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), GRID_COLOR, 1.0)
		y += grid_step


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
			draw_polyline(shortcut_points, SHORTCUT_COLOR, 8.0, true)


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
	for point_index in curve.point_count:
		var point := curve.get_point_position(point_index)
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.z)
	if maximum.x - minimum.x < 10.0:
		maximum.x = minimum.x + 10.0
	if maximum.y - minimum.y < 10.0:
		maximum.y = minimum.y + 10.0
	_map_bounds = Rect2(minimum, maximum - minimum).grow(12.0)


func _world_to_screen(position: Vector3) -> Vector2:
	var available_size := (size - Vector2.ONE * MAP_PADDING * 2.0).max(Vector2.ONE)
	var scale := minf(
		available_size.x / _map_bounds.size.x,
		available_size.y / _map_bounds.size.y
	)
	var used_size := _map_bounds.size * scale
	var offset := (size - used_size) * 0.5
	return offset + (Vector2(position.x, position.z) - _map_bounds.position) * scale


func _screen_to_world(screen_position: Vector2) -> Vector3:
	var available_size := (size - Vector2.ONE * MAP_PADDING * 2.0).max(Vector2.ONE)
	var scale := minf(
		available_size.x / _map_bounds.size.x,
		available_size.y / _map_bounds.size.y
	)
	var used_size := _map_bounds.size * scale
	var offset := (size - used_size) * 0.5
	var mapped := (screen_position - offset) / scale + _map_bounds.position
	return Vector3(mapped.x, 0.0, mapped.y)


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
