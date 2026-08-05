class_name KartProjectile
extends Area3D

const SPEED := 31.0
const LIFE_TIME := 4.0

var owner_kart: Node3D
var _direction := Vector3.ZERO
var _remaining_life := LIFE_TIME


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	body_entered.connect(_handle_body_entered)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.48
	collision.shape = shape
	add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.48
	mesh.height = 0.96
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(Color("#ff784f"))
	add_child(mesh_instance)

	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.1
	crown_mesh.bottom_radius = 0.3
	crown_mesh.height = 0.35
	crown.mesh = crown_mesh
	crown.position.y = 0.58
	crown.material_override = _material(Color("#4fbb6a"))
	add_child(crown)


func setup(source_kart: Node3D, direction: Vector3) -> void:
	owner_kart = source_kart
	_direction = direction.normalized()


func _physics_process(delta: float) -> void:
	global_position += _direction * SPEED * delta
	rotate_y(delta * 7.0)
	_remaining_life -= delta
	if _remaining_life <= 0.0:
		queue_free()


func _handle_body_entered(body: Node3D) -> void:
	if body == owner_kart or not body.has_method("receive_hit"):
		return
	body.receive_hit(1.1)
	queue_free()


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
