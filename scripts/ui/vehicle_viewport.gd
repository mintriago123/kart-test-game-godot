class_name VehicleViewport
extends SubViewportContainer

enum Framing { COVER, MENU, GARAGE }

const COLORMAP: Texture2D = preload("res://assets/vendor/kenney/car-kit/Textures/colormap.png")

var viewport: SubViewport
var stage: Node3D
var model_holder: Node3D
var platform: MeshInstance3D
var camera: Camera3D
var model: Node3D
var framing := Framing.MENU
var reduced_motion := false
var _pending_variant: KartVariantDefinition
var _requested_variant: KartVariantDefinition
var _swap_scheduled := false

func _ready() -> void:
	stretch = false
	viewport = SubViewport.new()
	# Every showroom must render an isolated 3D world. Without this, the menu
	# and garage SubViewports inherit the same World3D and each camera can draw
	# both vehicle stages, producing apparently duplicated/overlapping karts.
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	stage = Node3D.new(); viewport.add_child(stage)
	model_holder = Node3D.new(); model_holder.name = "ModelHolder"; stage.add_child(model_holder)
	var environment := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = UiTokens.INK; env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("#b9d9d5"); env.ambient_light_energy = 0.48; environment.environment = env; stage.add_child(environment)
	platform = MeshInstance3D.new(); var mesh := CylinderMesh.new(); mesh.top_radius = 2.2; mesh.bottom_radius = 2.2; mesh.height = 0.18; platform.mesh = mesh; platform.position.y = -0.15; var platform_material := StandardMaterial3D.new(); platform_material.albedo_color = UiTokens.GRAPHITE; platform_material.roughness = 0.9; platform.material_override = platform_material; stage.add_child(platform)
	var key := OmniLight3D.new(); key.position = Vector3(-3, 4, 3); key.light_color = Color("#ffd9a3"); key.omni_range = 10; key.light_energy = 2.3; stage.add_child(key)
	var fill := OmniLight3D.new(); fill.position = Vector3(3, 2, 2); fill.light_color = Color("#60e8f2"); fill.omni_range = 9; fill.light_energy = 1.4; stage.add_child(fill)
	camera = Camera3D.new(); stage.add_child(camera); set_framing(framing)
	resized.connect(_resize_viewport); _resize_viewport()
	if _pending_variant != null:
		show_variant(_pending_variant)

func show_variant(variant: KartVariantDefinition) -> void:
	if stage == null:
		_pending_variant = variant
		return
	_pending_variant = null
	_requested_variant = variant
	# Empty the holder first. RenderingServer can retain freed mesh RIDs until
	# the frame boundary, so the replacement is instantiated on the next frame.
	for previous in model_holder.get_children():
		if previous is Node3D:
			(previous as Node3D).visible = false
		previous.queue_free()
	model = null
	if not _swap_scheduled:
		_swap_scheduled = true
		_commit_requested_variant.call_deferred()

func _commit_requested_variant() -> void:
	await get_tree().process_frame
	_swap_scheduled = false
	var variant := _requested_variant
	if variant == null or variant.visual_scene == null:
		return
	model = variant.visual_scene.instantiate() as Node3D
	if model != null:
		model_holder.add_child(model)
		_hide_showroom_driver(model)
		_apply_colormap(model)
		_frame_model()

func _hide_showroom_driver(root: Node3D) -> void:
	# Kenney's kart scenes include a generic mannequin mesh. The garage presents
	# the vehicle itself; keeping the mannequin makes the body read as a second
	# overlapping kart, especially from the rear three-quarter angle.
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		if str(candidate.name).to_lower() == "character":
			(candidate as MeshInstance3D).visible = false

func set_framing(value: Framing) -> void:
	framing = value
	if camera == null: return
	var distance: float = [6.2, 5.2, 4.3][framing]
	camera.position = Vector3(0, 2.2, distance); camera.look_at(Vector3(0, 0.6, 0))

func set_quality(profile: String) -> void:
	if viewport == null: return
	var scale := 0.6 if profile == "low" else (0.8 if profile == "medium" else 1.0)
	viewport.size = Vector2i(Vector2(size) * scale).max(Vector2i(320, 180))

func _process(delta: float) -> void:
	if model != null and visible and not reduced_motion: model.rotate_y(delta * 0.25)
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _resize_viewport() -> void:
	if viewport != null: viewport.size = Vector2i(size).max(Vector2i(320, 180))

func _apply_colormap(root: Node3D) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null: continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
			var material := source.duplicate() as BaseMaterial3D if source != null else StandardMaterial3D.new()
			material.albedo_texture = COLORMAP; material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS; material.roughness = 0.78
			mesh_instance.set_surface_override_material(surface_index, material)

func _frame_model() -> void:
	var result := Node3DBounds.get_node_aabb(model)
	if not bool(result.valid): return
	var bounds: AABB = result.aabb
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if extent <= 0.001: return
	var target_size: float = [2.7, 3.1, 3.4][framing]
	model.scale = Vector3.ONE * (target_size / extent)
	var center := bounds.get_center() * model.scale.x
	model.position = Vector3(-center.x, -bounds.position.y * model.scale.y, -center.z)
	var distance := target_size * (1.8 if framing == Framing.GARAGE else 2.0)
	camera.position = Vector3(0, target_size * 0.62, distance); camera.look_at(Vector3(0, target_size * 0.32, 0))
