class_name RaceIntroCamera
extends Node3D

signal progress_changed(elapsed: float)
signal skip_available
signal skip_started
signal finished

const INTRO_DURATION := 10.0
const FLIGHT_DURATION := 6.0
const GRID_END_TIME := 8.5
const SKIP_AVAILABLE_TIME := 2.0
const SKIP_TRANSITION_DURATION := 0.65
const MIN_ROUTE_LENGTH := 1.0
const MIN_SEGMENT_LENGTH := 0.01

var elapsed := 0.0

var _camera: Camera3D
var _follow_camera: FollowCamera
var _route_points: Array[Vector3] = []
var _segment_lengths: Array[float] = []
var _route_length := 0.0
var _route_span := 0.0
var _aerial_height := 0.0
var _side_distance := 0.0
var _grid_distance := 0.0
var _lookahead_distance := 0.0
var _is_running := false
var _is_skip_available := false
var _is_skipping := false
var _skip_elapsed := 0.0
var _skip_start_transform := Transform3D.IDENTITY
var _skip_start_fov := 72.0


func start_intro(points: Array[Vector3], follow_camera: FollowCamera) -> bool:
	if not _prepare_route(points):
		return false
	if follow_camera == null or not is_instance_valid(follow_camera):
		return false
	if not follow_camera.is_ready():
		return false

	_follow_camera = follow_camera
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 66.0
	add_child(_camera)
	_follow_camera.deactivate()
	_camera.current = true
	_is_running = true
	set_process(true)
	_apply_normal_pose(0.0)
	progress_changed.emit(0.0)
	return true


func request_skip() -> bool:
	if not _is_running or not _is_skip_available or _is_skipping:
		return false
	_is_skipping = true
	_skip_elapsed = 0.0
	_skip_start_transform = global_transform
	_skip_start_fov = _camera.fov
	skip_started.emit()
	return true


func is_running() -> bool:
	return _is_running


func _process(delta: float) -> void:
	if not _is_running:
		return
	if _is_skipping:
		_process_skip(delta)
		return

	elapsed = minf(elapsed + delta, INTRO_DURATION)
	if not _is_skip_available and elapsed >= SKIP_AVAILABLE_TIME:
		_is_skip_available = true
		skip_available.emit()
	_apply_normal_pose(elapsed)
	progress_changed.emit(elapsed)
	if elapsed >= INTRO_DURATION:
		_finish_intro()


func _process_skip(delta: float) -> void:
	_skip_elapsed = minf(
		_skip_elapsed + delta,
		SKIP_TRANSITION_DURATION
	)
	var transition_weight := smoothstep(
		0.0,
		1.0,
		_skip_elapsed / SKIP_TRANSITION_DURATION
	)
	global_transform = _skip_start_transform.interpolate_with(
		_follow_camera.get_target_transform(),
		transition_weight
	)
	_camera.fov = lerpf(
		_skip_start_fov,
		_follow_camera.get_target_fov(),
		transition_weight
	)
	progress_changed.emit(FLIGHT_DURATION)
	if _skip_elapsed >= SKIP_TRANSITION_DURATION:
		_finish_intro()


func _apply_normal_pose(intro_time: float) -> void:
	if intro_time <= FLIGHT_DURATION:
		var flight_weight := intro_time / FLIGHT_DURATION
		global_transform = _get_flight_transform(flight_weight)
		_camera.fov = lerpf(64.0, 69.0, flight_weight)
		return

	var grid_end_transform := _get_grid_end_transform()
	if intro_time <= GRID_END_TIME:
		var grid_weight := smoothstep(
			0.0,
			1.0,
			(intro_time - FLIGHT_DURATION)
			/ (GRID_END_TIME - FLIGHT_DURATION)
		)
		global_transform = _get_flight_transform(1.0).interpolate_with(
			grid_end_transform,
			grid_weight
		)
		_camera.fov = lerpf(69.0, 62.0, grid_weight)
		return

	var follow_weight := smoothstep(
		0.0,
		1.0,
		(intro_time - GRID_END_TIME)
		/ (INTRO_DURATION - GRID_END_TIME)
	)
	global_transform = grid_end_transform.interpolate_with(
		_follow_camera.get_target_transform(),
		follow_weight
	)
	_camera.fov = lerpf(
		62.0,
		_follow_camera.get_target_fov(),
		follow_weight
	)


func _get_flight_transform(weight: float) -> Transform3D:
	var route_distance := _route_length * clampf(weight, 0.0, 1.0)
	var route_position := _sample_route(route_distance)
	var ahead := _sample_route(route_distance + _lookahead_distance)
	var behind := _sample_route(route_distance - _lookahead_distance * 0.35)
	var forward := ahead - behind
	forward.y = 0.0
	if forward.length_squared() <= MIN_SEGMENT_LENGTH * MIN_SEGMENT_LENGTH:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var orbit := sin(weight * TAU * 2.0)
	var position := (
		route_position
		+ Vector3.UP * _aerial_height * (1.0 + orbit * 0.08)
		+ right * _side_distance * (0.62 + orbit * 0.18)
	)
	var look_target := ahead + Vector3.UP * minf(_aerial_height * 0.08, 2.0)
	return _view_transform(position, look_target)


func _get_grid_end_transform() -> Transform3D:
	var start := _sample_route(0.0)
	var ahead := _sample_route(_lookahead_distance)
	var forward := ahead - start
	forward.y = 0.0
	if forward.length_squared() <= MIN_SEGMENT_LENGTH * MIN_SEGMENT_LENGTH:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var position := (
		start
		+ forward * _grid_distance
		- right * _side_distance * 0.42
		+ Vector3.UP * clampf(_aerial_height * 0.24, 3.4, 6.5)
	)
	var grid_center := (
		start
		- forward * minf(_grid_distance * 0.28, 4.0)
		+ Vector3.UP * 1.15
	)
	return _view_transform(position, grid_center)


func _prepare_route(points: Array[Vector3]) -> bool:
	if points.size() < 3:
		return false
	for point in points:
		if not point.is_finite():
			return false

	_route_points = points.duplicate()
	_segment_lengths.clear()
	_route_length = 0.0
	var minimum := _route_points[0]
	var maximum := _route_points[0]
	for point_index in _route_points.size():
		var point := _route_points[point_index]
		minimum = minimum.min(point)
		maximum = maximum.max(point)
		var next_point := _route_points[
			(point_index + 1) % _route_points.size()
		]
		var segment_length := point.distance_to(next_point)
		_segment_lengths.append(segment_length)
		_route_length += segment_length
	if _route_length < MIN_ROUTE_LENGTH:
		return false

	_route_span = Vector2(
		maximum.x - minimum.x,
		maximum.z - minimum.z
	).length()
	_aerial_height = clampf(maxf(_route_span * 0.12, 7.0), 7.0, 34.0)
	_side_distance = clampf(maxf(_route_span * 0.075, 4.5), 4.5, 22.0)
	_grid_distance = clampf(maxf(_route_span * 0.055, 7.0), 7.0, 17.0)
	_lookahead_distance = clampf(_route_length * 0.045, 3.0, 26.0)
	return true


func _sample_route(distance: float) -> Vector3:
	var wrapped_distance := fposmod(distance, _route_length)
	var traversed := 0.0
	for segment_index in _segment_lengths.size():
		var segment_length := _segment_lengths[segment_index]
		if segment_length <= MIN_SEGMENT_LENGTH:
			continue
		if wrapped_distance <= traversed + segment_length:
			var segment_weight := (
				(wrapped_distance - traversed) / segment_length
			)
			return _route_points[segment_index].lerp(
				_route_points[
					(segment_index + 1) % _route_points.size()
				],
				segment_weight
			)
		traversed += segment_length
	return _route_points[0]


func _view_transform(position: Vector3, target: Vector3) -> Transform3D:
	if position.distance_squared_to(target) <= 0.001:
		target += Vector3.FORWARD
	return Transform3D(Basis.IDENTITY, position).looking_at(
		target,
		Vector3.UP
	)


func _finish_intro() -> void:
	if not _is_running:
		return
	_is_running = false
	set_process(false)
	global_transform = _follow_camera.get_target_transform()
	_camera.fov = _follow_camera.get_target_fov()
	_camera.current = false
	_follow_camera.activate()
	finished.emit()
