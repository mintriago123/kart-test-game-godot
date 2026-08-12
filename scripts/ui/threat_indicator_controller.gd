class_name ThreatIndicatorController
extends Control

const MAX_INDICATORS := 6
const TRAP_DETECTION_RADIUS := 14.0
const PROJECTILE_CORRIDOR := 2.4
const MAX_ETA := 4.0

class ThreatMarker:
	extends Control
	var direction := Vector2.UP
	var urgency := 0.0
	func _ready() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var color := Color("#ffcc4d").lerp(Color("#ff3e52"), urgency)
		var angle := direction.angle() + PI * 0.5
		var points := PackedVector2Array([Vector2(0, -15), Vector2(11, 11), Vector2(0, 7), Vector2(-11, 11)])
		for index in points.size():
			points[index] = points[index].rotated(angle) + Vector2(20, 20)
		draw_colored_polygon(points, color)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color.WHITE, 2.0, true)

var player_kart: Kart
var active_items: Node3D
var camera: Camera3D
var enabled := true
var indicators: Dictionary = {}
var _seen_traps: Dictionary = {}

func setup(player: Kart, items: Node3D, view_camera: Camera3D) -> void:
	player_kart = player
	active_items = items
	camera = view_camera
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if not enabled or player_kart == null or active_items == null or camera == null:
		_clear_indicators()
		return
	var valid: Array[Node3D] = []
	for container in active_items.get_children():
		for item in container.get_children():
			if item is Node3D and is_valid_threat(item as Node3D):
				valid.append(item)
				if valid.size() >= MAX_INDICATORS: break
	_update_indicators(valid)

func estimate_impact_time(item: Node3D) -> float:
	if item is HomingProjectile:
		var speed := maxf((item as HomingProjectile).velocity.length(), 0.1)
		return item.global_position.distance_to(player_kart.global_position) / speed
	if item is KartProjectile:
		var relative_position := player_kart.global_position - item.global_position
		var relative_velocity := (item as KartProjectile).velocity - player_kart.velocity
		var speed_squared := relative_velocity.length_squared()
		if speed_squared <= 0.01: return INF
		var eta := relative_position.dot(relative_velocity) / speed_squared
		if eta <= 0.0: return INF
		return eta if (relative_position - relative_velocity * eta).length() <= PROJECTILE_CORRIDOR else INF
	return 0.0

func is_valid_threat(item: Node3D) -> bool:
	if item == null or not is_instance_valid(item) or item == player_kart: return false
	if not (item is KartProjectile) and not (item is ItemTrap): return false
	if item.get("owner_kart") == player_kart: return false
	if item.has_method("get_remaining_life") and float(item.call("get_remaining_life")) <= 0.0: return false
	if item is HomingProjectile:
		return (item as HomingProjectile).get_target() == player_kart and estimate_impact_time(item) <= MAX_ETA
	if item is KartProjectile:
		return estimate_impact_time(item) <= MAX_ETA
	var distance := item.global_position.distance_to(player_kart.global_position)
	var on_screen := not camera.is_position_behind(item.global_position) and _viewport_rect().has_point(camera.unproject_position(item.global_position))
	if on_screen: _seen_traps[item.get_instance_id()] = true
	return distance <= TRAP_DETECTION_RADIUS or _seen_traps.has(item.get_instance_id())

func remove_threat(item: Node) -> void:
	var id := item.get_instance_id() if item != null else 0
	if indicators.has(id):
		(indicators[id] as Control).queue_free()
		indicators.erase(id)
	_seen_traps.erase(id)

func _update_indicators(valid: Array[Node3D]) -> void:
	var alive := {}
	for item in valid:
		var id := item.get_instance_id()
		alive[id] = true
		if not indicators.has(id):
			var marker := ThreatMarker.new()
			add_child(marker)
			indicators[id] = marker
		var marker := indicators[id] as ThreatMarker
		var raw_screen := camera.unproject_position(item.global_position)
		if camera.is_position_behind(item.global_position): raw_screen = size - raw_screen
		var safe := _safe_rect()
		var center := safe.get_center()
		marker.direction = (raw_screen - center).normalized()
		var eta := estimate_impact_time(item)
		marker.urgency = 1.0 - clampf(eta / MAX_ETA, 0.0, 1.0) if is_finite(eta) else 0.35
		marker.scale = Vector2.ONE * lerpf(0.82, 1.25, marker.urgency) * (1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.08 * marker.urgency)
		marker.position = Vector2(clampf(raw_screen.x, safe.position.x, safe.end.x), clampf(raw_screen.y, safe.position.y, safe.end.y)) - Vector2(20, 20)
		marker.queue_redraw()
	for id in indicators.keys():
		if not alive.has(id):
			(indicators[id] as Control).queue_free()
			indicators.erase(id)

func _viewport_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func _safe_rect() -> Rect2:
	var margin := Vector2(48, 42)
	var bottom := 86.0
	# At the compact touch layout, keep both lower control clusters unobstructed.
	if size.x <= 700.0: bottom = 112.0
	return Rect2(margin, Vector2(maxf(size.x - margin.x * 2.0, 1.0), maxf(size.y - margin.y - bottom, 1.0)))

func _clear_indicators() -> void:
	for marker in indicators.values(): (marker as Control).queue_free()
	indicators.clear()

func clear_all() -> void:
	_clear_indicators()
