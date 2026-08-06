class_name ItemBox
extends Area3D

signal collected(kart: Node)

const RESPAWN_TIME := 5.0

var _base_height := 0.0
var _elapsed := 0.0
var _is_available := true
var _is_collection_enabled := true
var _visual: Node3D


func _ready() -> void:
	collision_layer = PhysicsLayers.ITEM_BOXES
	collision_mask = PhysicsLayers.KARTS
	monitoring = _is_collection_enabled
	body_entered.connect(_handle_body_entered)
	_base_height = position.y
	_build_visual()
	set_process(_is_collection_enabled)


func set_collection_enabled(enabled: bool) -> void:
	_is_collection_enabled = enabled
	set_process(enabled)
	if is_inside_tree():
		set_deferred("monitoring", enabled and _is_available)


func _process(delta: float) -> void:
	if not _is_available:
		return
	_elapsed += delta
	_visual.rotation.y += delta * 1.8
	position.y = _base_height + sin(_elapsed * 2.4) * 0.22


func _build_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.45, 1.45, 1.45)
	collision.shape = shape
	add_child(collision)

	_visual = Node3D.new()
	add_child(_visual)

	var cube := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(1.25, 1.25, 1.25)
	cube.mesh = cube_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ffd15a")
	material.emission_enabled = true
	material.emission = Color("#e46849")
	material.emission_energy_multiplier = 0.7
	cube.material_override = material
	_visual.add_child(cube)

	var marker := Label3D.new()
	marker.text = "?"
	marker.font_size = 80
	marker.modulate = Color("#12363c")
	marker.outline_size = 8
	marker.position.z = 0.64
	_visual.add_child(marker)


func _handle_body_entered(body: Node3D) -> void:
	if (
		not _is_collection_enabled
		or not _is_available
		or not body.has_method("grant_random_item")
	):
		return
	if not body.grant_random_item():
		return
	_is_available = false
	set_deferred("monitoring", false)
	_visual.visible = false
	collected.emit(body)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _respawn() -> void:
	if not is_inside_tree():
		return
	_is_available = true
	set_deferred("monitoring", _is_collection_enabled)
	_visual.visible = true
