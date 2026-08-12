class_name ItemTrap
extends Area3D

signal kart_hit(kart: Node3D, result: int)

const GROUND_PROBE_UP := 2.5
const GROUND_PROBE_DOWN := 5.0
const GROUND_CLEARANCE := 0.08
const VisualFactory := preload("res://scripts/items/item_visual_factory.gd")

var owner_kart: Node3D
var item_definition: ItemDefinition

var _remaining_life := 0.0
var _owner_immunity_remaining := 0.0
var _is_consumed := false


func setup(source_kart: Node3D, definition: ItemDefinition) -> void:
	owner_kart = source_kart
	item_definition = definition
	_remaining_life = maxf(definition.trap_duration, 0.0)
	_owner_immunity_remaining = maxf(definition.trap_owner_immunity, 0.0)


func _ready() -> void:
	if item_definition == null:
		item_definition = ItemDefinition.slippery_peel()
		_remaining_life = item_definition.trap_duration
		_owner_immunity_remaining = item_definition.trap_owner_immunity
	collision_layer = 0
	collision_mask = PhysicsLayers.KARTS
	monitorable = false
	monitoring = true
	body_entered.connect(_handle_body_entered)
	_build_collision()
	_build_visual()


func _physics_process(delta: float) -> void:
	_remaining_life = maxf(_remaining_life - delta, 0.0)
	_owner_immunity_remaining = maxf(
		_owner_immunity_remaining - delta,
		0.0
	)
	if _remaining_life <= 0.0:
		queue_free()


func place(trap_position: Vector3) -> bool:
	global_position = trap_position
	return snap_to_ground()


func snap_to_ground() -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * GROUND_PROBE_UP,
		global_position - Vector3.UP * GROUND_PROBE_DOWN,
		PhysicsLayers.DRIVABLE_SURFACES
	)
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var ground_position: Vector3 = result.position
	var ground_normal: Vector3 = result.normal
	if (
		not ground_position.is_finite()
		or not ground_normal.is_finite()
		or ground_normal.length_squared() < 0.25
	):
		return false
	ground_normal = ground_normal.normalized()
	var forward := -global_basis.z.slide(ground_normal).normalized()
	if forward.length_squared() < 0.25:
		forward = Vector3.FORWARD
	global_basis = Basis.looking_at(forward, ground_normal)
	global_position = ground_position + ground_normal * GROUND_CLEARANCE
	return true


func get_remaining_life() -> float:
	return _remaining_life


func _handle_body_entered(body: Node3D) -> void:
	if _is_consumed or body == null or not body.has_method("receive_hit"):
		return
	if body == owner_kart and _owner_immunity_remaining > 0.0:
		return
	_is_consumed = true
	var raw_result: Variant
	if body is Kart:
		raw_result = (body as Kart).receive_hit(item_definition.trap_impact_duration, self)
	else:
		raw_result = body.receive_hit(item_definition.trap_impact_duration)
	var hit_result := (
		int(raw_result)
		if raw_result != null
		else Kart.HitResult.APPLIED
	)
	kart_hit.emit(body, hit_result)
	queue_free()


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = item_definition.trap_radius
	collision.shape = shape
	collision.position.y = item_definition.trap_radius * 0.42
	add_child(collision)


func _build_visual() -> void:
	VisualFactory.attach_presentation(
		self,
		item_definition,
		item_definition.trap_radius,
		0.015
	)
