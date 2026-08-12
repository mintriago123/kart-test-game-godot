class_name TrackMinimapView
extends Control

const BACKGROUND_COLOR := Color("#101922")
const GRID_COLOR := Color(0.18, 0.27, 0.32, 0.35)
const ROAD_EDGE_COLOR := Color("#080d0f")
const ROAD_COLOR := Color("#FFF7DF")
const SHORTCUT_COLOR := Color("#39D9F5")
const DIRECTION_COLOR := Color("#ffd34e")
const ERROR_COLOR := Color("#ff8a6c")
const MUTED_TEXT_COLOR := Color("#d4dedb")
const MAP_PADDING := 18.0
const MINIMUM_WORLD_EXTENT := 24.0
const ROAD_EDGE_WIDTH := 12.0
const ROAD_WIDTH := 7.0
const SHORTCUT_EDGE_WIDTH := 10.0
const SHORTCUT_WIDTH := 5.0

var minimap_data: TrackMinimapData
var background_color := BACKGROUND_COLOR
var grid_visible := true
var map_padding := MAP_PADDING

var _map_bounds := Rect2(
	Vector2(-MINIMUM_WORLD_EXTENT * 0.5, -MINIMUM_WORLD_EXTENT * 0.5),
	Vector2.ONE * MINIMUM_WORLD_EXTENT
)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = (
		"Plano de la pista con ruta principal, atajos, sentido de carrera "
		+ "y línea de salida."
	)
	resized.connect(queue_redraw)


func set_minimap_data(data: TrackMinimapData) -> void:
	minimap_data = data
	_refresh_bounds()
	queue_redraw()


func is_map_available() -> bool:
	return minimap_data != null and minimap_data.is_valid()


func _draw() -> void:
	if background_color.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), background_color)
	if grid_visible:
		_draw_grid()
	if not is_map_available():
		_draw_unavailable_placeholder()
		return

	var route_points := _map_points(minimap_data.route_points)
	route_points.append(route_points[0])
	draw_polyline(route_points, ROAD_EDGE_COLOR, ROAD_EDGE_WIDTH, true)
	draw_polyline(route_points, ROAD_COLOR, ROAD_WIDTH, true)

	for shortcut_index in minimap_data.shortcut_count:
		var shortcut_points := _map_points(
			minimap_data.get_shortcut_points(shortcut_index)
		)
		if shortcut_points.size() < 2:
			continue
		draw_polyline(
			shortcut_points,
			ROAD_EDGE_COLOR,
			SHORTCUT_EDGE_WIDTH,
			true
		)
		draw_polyline(
			shortcut_points,
			SHORTCUT_COLOR,
			SHORTCUT_WIDTH,
			true
		)

	_draw_direction_arrows(route_points)
	_draw_finish_line()


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


func _draw_direction_arrows(route_points: PackedVector2Array) -> void:
	var route_size := route_points.size() - 1
	if route_size < 3:
		return
	var arrow_count := clampi(route_size / 5, 3, 5)
	for arrow_number in range(1, arrow_count + 1):
		var point_index := (
			arrow_number * route_size / (arrow_count + 1)
		)
		var previous := route_points[
			(point_index - 1 + route_size) % route_size
		]
		var next := route_points[(point_index + 1) % route_size]
		var forward := (next - previous).normalized()
		if forward.length_squared() < 0.0001:
			continue
		var position := route_points[point_index]
		var side := Vector2(-forward.y, forward.x)
		var outline := PackedVector2Array([
			position + forward * 13.0,
			position - forward * 10.0 + side * 9.0,
			position - forward * 5.0,
			position - forward * 10.0 - side * 9.0,
		])
		var arrow := PackedVector2Array([
			position + forward * 10.0,
			position - forward * 7.0 + side * 6.0,
			position - forward * 3.0,
			position - forward * 7.0 - side * 6.0,
		])
		draw_colored_polygon(outline, ROAD_EDGE_COLOR)
		draw_colored_polygon(arrow, DIRECTION_COLOR)


func _draw_finish_line() -> void:
	var center := _map_point_to_screen(minimap_data.start_position)
	var forward := minimap_data.start_direction.normalized()
	var mapped_forward := Vector2(forward.x, forward.y).normalized()
	var side := Vector2(-mapped_forward.y, mapped_forward.x)
	var columns := 6
	var rows := 2
	var cell_width := 5.0
	var cell_depth := 4.5
	var total_width := columns * cell_width
	for column in columns:
		for row in rows:
			var side_start := -total_width * 0.5 + column * cell_width
			var depth_start := -rows * cell_depth * 0.5 + row * cell_depth
			var top_left := (
				center + side * side_start + mapped_forward * depth_start
			)
			var cell := PackedVector2Array([
				top_left,
				top_left + side * cell_width,
				top_left + side * cell_width + mapped_forward * cell_depth,
				top_left + mapped_forward * cell_depth,
			])
			var cell_color := (
				Color.WHITE
				if (column + row) % 2 == 0
				else ROAD_EDGE_COLOR
			)
			draw_colored_polygon(cell, cell_color)
	draw_line(
		center - side * (total_width * 0.5 + 2.0),
		center + side * (total_width * 0.5 + 2.0),
		ROAD_EDGE_COLOR,
		2.0,
		true
	)


func _draw_unavailable_placeholder() -> void:
	var font := get_theme_default_font()
	var center := size * 0.5
	var icon_center := center + Vector2(0.0, -28.0)
	var triangle := PackedVector2Array([
		icon_center + Vector2(0.0, -25.0),
		icon_center + Vector2(-28.0, 23.0),
		icon_center + Vector2(28.0, 23.0),
	])
	draw_polyline(
		PackedVector2Array([
			triangle[0],
			triangle[1],
			triangle[2],
			triangle[0],
		]),
		ERROR_COLOR,
		4.0,
		true
	)
	draw_string(
		font,
		icon_center + Vector2(-8.0, 14.0),
		"!",
		HORIZONTAL_ALIGNMENT_CENTER,
		16.0,
		28,
		ERROR_COLOR
	)
	draw_string(
		font,
		Vector2(0.0, center.y + 35.0),
		"SIN MAPA DISPONIBLE",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		18,
		MUTED_TEXT_COLOR
	)


func _refresh_bounds() -> void:
	if not is_map_available():
		_map_bounds = Rect2(
			Vector2.ONE * -MINIMUM_WORLD_EXTENT * 0.5,
			Vector2.ONE * MINIMUM_WORLD_EXTENT
		)
		return
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in minimap_data.route_points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	for point in minimap_data.shortcut_points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	minimum = minimum.min(minimap_data.start_position)
	maximum = maximum.max(minimap_data.start_position)
	var bounds_size := maximum - minimum
	var center := (minimum + maximum) * 0.5
	bounds_size.x = maxf(bounds_size.x, MINIMUM_WORLD_EXTENT)
	bounds_size.y = maxf(bounds_size.y, MINIMUM_WORLD_EXTENT)
	_map_bounds = Rect2(center - bounds_size * 0.5, bounds_size)


func _map_points(points: PackedVector2Array) -> PackedVector2Array:
	var mapped := PackedVector2Array()
	for point in points:
		mapped.append(_map_point_to_screen(point))
	return mapped


func _map_point_to_screen(point: Vector2) -> Vector2:
	var available_size := (
		size - Vector2.ONE * map_padding * 2.0
	).max(Vector2.ONE)
	var map_scale := minf(
		available_size.x / _map_bounds.size.x,
		available_size.y / _map_bounds.size.y
	)
	var used_size := _map_bounds.size * map_scale
	var offset := (size - used_size) * 0.5
	return offset + (point - _map_bounds.position) * map_scale
