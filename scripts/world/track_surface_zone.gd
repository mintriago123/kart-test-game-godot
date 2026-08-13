@tool
class_name TrackSurfaceZone
extends Area3D

enum PathKind { MAIN, SHORTCUT }

@export var id: StringName
@export var surface: SurfaceDefinition
@export var path_kind := PathKind.MAIN
@export var shortcut_id := -1
@export_range(0.0, 1.0, 0.001) var start_progress := 0.0
@export_range(0.0, 1.0, 0.001) var end_progress := 0.1
@export var lateral_offset := 0.0
@export_range(0.25, 20.0, 0.25) var width := 3.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.KARTS
	body_entered.connect(_body_entered)
	body_exited.connect(_body_exited)
	if not Engine.is_editor_hint():
		_build_volume.call_deferred()

func _build_volume() -> void:
	if not is_inside_tree():
		return
	var ancestor := get_parent()
	while ancestor != null and not "route_points" in ancestor:
		ancestor = ancestor.get_parent()
	var track := ancestor
	if track == null:
		return
	var points: Array[Vector3] = track.get("route_points")
	if path_kind == PathKind.SHORTCUT:
		points = []
		for definition in track.get("shortcut_definitions"):
			if int(definition.get("id", -1)) == shortcut_id:
				points.assign(definition.get("points", []))
				break
	if points.size() < 2:
		return
	var start_index := clampi(floori(start_progress * points.size()), 0, points.size() - 1)
	var end_index := clampi(ceili(end_progress * points.size()), start_index + 1, points.size())
	for index in range(start_index, end_index):
		var next_index := (index + 1) % points.size()
		var start := points[index]
		var finish := points[next_index]
		var forward := finish - start
		var length := forward.length()
		if length < 0.05:
			continue
		var right := Vector3.UP.cross(forward.normalized())
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 1.2, length + 0.2)
		shape.shape = box
		shape.position = (start + finish) * 0.5 + right * lateral_offset + Vector3.UP * 0.35
		shape.basis = Basis.looking_at(forward.normalized(), Vector3.UP)
		add_child(shape)

func _body_entered(body: Node3D) -> void:
	if body.has_method("enter_surface_zone"):
		body.enter_surface_zone(self)

func _body_exited(body: Node3D) -> void:
	if body.has_method("exit_surface_zone"):
		body.exit_surface_zone(self)

func is_better_than(other: TrackSurfaceZone) -> bool:
	return other == null or priority > other.priority or (priority == other.priority and String(id) < String(other.id))

func validate(road_width: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("La zona necesita un ID.")
	if surface == null: errors.append("La zona necesita una superficie.")
	if is_equal_approx(start_progress, end_progress): errors.append("La zona necesita longitud.")
	if absf(lateral_offset) + width * 0.5 > road_width * 0.5:
		errors.append("La zona excede el ancho transitable.")
	if path_kind == PathKind.SHORTCUT and shortcut_id < 0:
		errors.append("La zona de atajo necesita un atajo válido.")
	return errors
