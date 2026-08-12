class_name TrackTestDiagnostics
extends RefCounted

const CORRIDOR_TOLERANCE := 1.5
const OUTSIDE_CONFIRMATION_SECONDS := 0.5

var elapsed_time := 0.0
var recovery_count := 0
var off_route_count := 0
var shortcut_count := 0
var completed := false
var recovery_reasons: Dictionary = {}

var _main_route: Array[Vector3] = []
var _shortcut_routes: Array[Array] = []
var _outside_elapsed := 0.0
var _outside_latched := false


func configure(track: CoastalTrack) -> void:
	_main_route.clear()
	_shortcut_routes.clear()
	if track == null:
		return
	_main_route.assign(track.route_points)
	for definition in track.shortcut_definitions:
		var points: Array[Vector3] = []
		points.assign(definition.get("points", []))
		if points.size() >= 2:
			_shortcut_routes.append(points)


func observe_position(position: Vector3, delta: float) -> void:
	if _is_inside_valid_corridor(position):
		_outside_elapsed = 0.0
		_outside_latched = false
		return
	_outside_elapsed += delta
	if (
		_outside_elapsed >= OUTSIDE_CONFIRMATION_SECONDS
		and not _outside_latched
	):
		off_route_count += 1
		_outside_latched = true


func record_recovery(reason: String) -> void:
	recovery_count += 1
	var safe_reason := reason if not reason.is_empty() else "unknown"
	recovery_reasons[safe_reason] = int(recovery_reasons.get(safe_reason, 0)) + 1


func record_shortcut() -> void:
	shortcut_count += 1


func to_dictionary(track_id: StringName, token: String) -> Dictionary:
	return {
		"token": token,
		"track_id": str(track_id),
		"elapsed_time": elapsed_time,
		"recovery_count": recovery_count,
		"recovery_reasons": recovery_reasons,
		"off_route_count": off_route_count,
		"shortcut_count": shortcut_count,
		"completed": completed,
	}


func _is_inside_valid_corridor(position: Vector3) -> bool:
	if _distance_to_polyline(position, _main_route, true) <= (
		CoastalTrack.ROAD_WIDTH * 0.5 + CORRIDOR_TOLERANCE
	):
		return true
	for shortcut_points in _shortcut_routes:
		if _distance_to_polyline(position, shortcut_points, false) <= (
			CoastalTrack.SHORTCUT_WIDTH * 0.5 + CORRIDOR_TOLERANCE
		):
			return true
	return false


func _distance_to_polyline(
	position: Vector3,
	points: Array,
	is_closed: bool
) -> float:
	if points.size() < 2:
		return INF
	var minimum := INF
	var segment_count := points.size() if is_closed else points.size() - 1
	var point_2d := Vector2(position.x, position.z)
	for point_index in segment_count:
		var start: Vector3 = points[point_index]
		var finish: Vector3 = points[(point_index + 1) % points.size()]
		minimum = minf(
			minimum,
			_point_to_segment_distance(
				point_2d,
				Vector2(start.x, start.z),
				Vector2(finish.x, finish.z)
			)
		)
	return minimum


func _point_to_segment_distance(
	point: Vector2,
	start: Vector2,
	finish: Vector2
) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var weight := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * weight)

