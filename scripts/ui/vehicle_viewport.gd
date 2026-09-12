class_name VehicleViewport
extends SubViewportContainer

enum Framing { COVER, MENU, GARAGE, REWARD, PREPARATION }

const COLORMAP: Texture2D = preload("res://assets/vendor/kenney/car-kit/Textures/colormap.png")

var viewport: SubViewport
var stage: Node3D
var model_holder: Node3D
var platform: MeshInstance3D
var camera: Camera3D
var model: Node3D
var framing := Framing.MENU
var reduced_motion := false
var quality_profile := "medium"
## Capture-only options. The normal showroom keeps the driver hidden.
var show_driver := false
var driver_color := Color.WHITE
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
	var environment := WorldEnvironment.new(); var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = UiTokens.GRAPHITE; env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = UiTokens.CYAN; env.ambient_light_energy = 0.42; environment.environment = env; stage.add_child(environment)
	platform = MeshInstance3D.new(); var mesh := CylinderMesh.new(); mesh.top_radius = 2.2; mesh.bottom_radius = 2.2; mesh.height = 0.18; platform.mesh = mesh; platform.position.y = -0.15; var platform_material := StandardMaterial3D.new(); platform_material.albedo_color = UiTokens.GRAPHITE; platform_material.roughness = 0.9; platform.material_override = platform_material; stage.add_child(platform)
	var key := OmniLight3D.new(); key.position = Vector3(-3, 4, 3); key.light_color = UiTokens.ELECTRIC_YELLOW; key.omni_range = 10; key.light_energy = 2.1; stage.add_child(key)
	var fill := OmniLight3D.new(); fill.position = Vector3(3, 2, 2); fill.light_color = UiTokens.CYAN; fill.omni_range = 9; fill.light_energy = 1.2; stage.add_child(fill)
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
			var character := candidate as MeshInstance3D
			character.visible = show_driver
			if show_driver:
				_apply_driver_color(character)

func _apply_driver_color(character: MeshInstance3D) -> void:
	for surface_index in character.mesh.get_surface_count():
		var source := character.mesh.surface_get_material(surface_index) as BaseMaterial3D
		var material := source.duplicate() as BaseMaterial3D if source != null else StandardMaterial3D.new()
		material.albedo_color = driver_color
		character.set_surface_override_material(surface_index, material)

func set_framing(value: Framing) -> void:
	framing = value
	if camera == null: return
	var distance: float = [6.2, 5.2, 4.3, 4.7, 4.4][framing]
	camera.position = Vector3(0, 2.2, distance); camera.look_at(Vector3(0, 0.6, 0))

func set_quality(profile: String) -> void:
	quality_profile = PresentationQuality.sanitize(profile)
	_resize_viewport()

func _process(delta: float) -> void:
	if model != null and visible and not reduced_motion: model.rotate_y(delta * 0.25)
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func _resize_viewport() -> void:
	if viewport != null:
		var scale := float(PresentationQuality.get_budget(quality_profile).showroom_scale)
		viewport.size = Vector2i(size).max(Vector2i(320, 180))
		viewport.scaling_3d_scale = scale

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
	# Garage/preparation viewports can become short at 720p and on mobile.
	# Leave a real breathing margin so the lower body never sits behind the
	# container edge or the fixed action bar.
	var target_size: float = [2.7, 3.1, 2.9, 3.0, 2.55][framing]
	model.scale = Vector3.ONE * (target_size / extent)
	var center := bounds.get_center() * model.scale.x
	var vertical_margin := -0.06 if framing == Framing.PREPARATION else (0.0 if framing == Framing.GARAGE else target_size * 0.08)
	model.position = Vector3(
		-center.x,
		-bounds.position.y * model.scale.y + vertical_margin,
		-center.z
	)
	# The garage is a showcase, so the vehicle should own the left side of the
	# screen instead of reading as a tiny object inside an empty viewport.
	var distance := target_size * (1.72 if framing == Framing.GARAGE else 2.0)
	var look_height := target_size * (0.04 if framing == Framing.PREPARATION else (0.16 if framing == Framing.GARAGE else 0.27))
	camera.position = Vector3(0, target_size * 0.58, distance); camera.look_at(Vector3(0, look_height, 0))
