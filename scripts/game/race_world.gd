class_name RaceWorld
extends Node3D

const DEFAULT_ITEM_CATALOG: ItemCatalog = preload(
	"res://items/item_catalog.tres"
)

signal retry_requested
signal menu_requested
signal race_completed(time: float)

var graphics_profile := "medium"
var vibration_enabled := true
var play_intro := true
var track_definition: TrackDefinition
var race_manager: RaceManager
var player_kart: Kart
var item_catalog: ItemCatalog = DEFAULT_ITEM_CATALOG

var _track: CoastalTrack
var _hud: RaceHud
var _sound: SoundManager
var _follow_camera: FollowCamera
var _intro_camera: RaceIntroCamera
var _active_items: Node3D
var _projectiles: Node3D
var _traps: Node3D
var _effects: Node3D
var _item_executor: ItemExecutor
var _item_boxes: Array[ItemBox] = []
var _ai_drivers: Array[AiDriver] = []
var _has_begun_race := false
var _item_rng := RandomNumberGenerator.new()


func _ready() -> void:
	var catalog_errors := item_catalog.validate() if item_catalog != null else [
		"RaceWorld requires an item catalog."
	]
	if not catalog_errors.is_empty():
		push_error("Invalid RaceWorld item catalog: %s" % "; ".join(catalog_errors))
	_item_rng.randomize()
	_build_track()
	_build_environment()
	_build_active_item_container()
	_build_race()


func _build_environment() -> void:
	_sound = SoundManager.new()
	add_child(_sound)
	_sound.start_music()

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	var theme := _get_track_theme()
	environment.background_color = (
		theme.sky_color if theme != null else Color("#58bfd0")
	)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = (
		theme.ambient_color if theme != null else Color("#d9f4df")
	)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = graphics_profile == "medium"
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("#fff1c4")
	sun.light_energy = 1.25
	sun.shadow_enabled = graphics_profile == "medium"
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_track() -> void:
	if track_definition != null and track_definition.scene != null:
		_track = track_definition.scene.instantiate() as CoastalTrack
	if _track == null:
		_track = CoastalTrack.new()
	add_child(_track)


func _build_active_item_container() -> void:
	_active_items = Node3D.new()
	_active_items.name = "ActiveItems"
	add_child(_active_items)

	_projectiles = Node3D.new()
	_projectiles.name = "Projectiles"
	_active_items.add_child(_projectiles)

	_traps = Node3D.new()
	_traps.name = "Traps"
	_active_items.add_child(_traps)

	_effects = Node3D.new()
	_effects.name = "Effects"
	_active_items.add_child(_effects)


func _build_race() -> void:
	race_manager = RaceManager.new()
	add_child(race_manager)
	if track_definition != null:
		race_manager.total_laps = track_definition.laps
	race_manager.configure(_track.route_points)
	_track.shortcut_completed.connect(race_manager.complete_shortcut)
	race_manager.shortcut_accepted.connect(_handle_shortcut_accepted)

	_item_executor = ItemExecutor.new()
	_item_executor.name = "ItemExecutor"
	add_child(_item_executor)
	_item_executor.setup(race_manager, _projectiles, _traps, _effects)
	_item_executor.item_activated.connect(_handle_item_activated)
	_item_executor.kart_hit.connect(_handle_item_hit)
	_item_executor.projectile_bounced.connect(_sound.play_projectile_bounce)

	var colors := [
		Color("#ef684e"),
		Color("#76cc64"),
		Color("#ef78ad"),
		Color("#4aa5df"),
	]
	var names := ["Marea", "Lima", "Coral", "Brisa"]
	var stat_sets := [
		KartStats.create(25.0, 18.5, 2.25, 9.2),
		KartStats.create(24.0, 19.5, 2.32, 9.0),
		KartStats.create(26.0, 17.4, 2.12, 9.5),
		KartStats.create(25.2, 18.0, 2.4, 8.6),
	]
	for slot in 4:
		var kart := Kart.new()
		kart.racer_name = names[slot]
		kart.body_color = colors[slot]
		kart.is_player = slot == 0
		kart.stats = stat_sets[slot]
		kart.item_catalog = item_catalog
		kart.item_rng = _item_rng
		add_child(kart)
		var grid_slot := 3 if slot == 0 else slot - 1
		kart.global_transform = _track.get_spawn_transform(grid_slot)
		kart.set_respawn_transform(kart.global_transform)
		race_manager.register_kart(kart, slot == 0)
		kart.item_use_requested.connect(
			_handle_item_use_requested.bind(kart)
		)
		kart.hit_blocked.connect(_handle_shield_blocked.bind(kart))
		if slot == 0:
			player_kart = kart
			_add_camera(kart)
			kart.hit_received.connect(_handle_player_hit)
		else:
			var ai := AiDriver.new()
			kart.add_child(ai)
			ai.setup(kart, race_manager, [-2.0, 0.0, 2.0][slot - 1])
			ai.caution = float(slot - 1) * 0.2
			ai.set_physics_process(false)
			_ai_drivers.append(ai)

	for item_position in _track.item_spawn_points:
		var item_box := ItemBox.new()
		item_box.position = item_position
		item_box.collected.connect(_handle_item_collected)
		add_child(item_box)
		item_box.set_collection_enabled(false)
		_item_boxes.append(item_box)

	_hud = RaceHud.new()
	_hud.vibration_enabled = vibration_enabled
	_hud.mobile_controls_enabled = (
		OS.has_feature("android")
		or OS.has_feature("ios")
		or DisplayServer.is_touchscreen_available()
		or "--mobile-controls" in OS.get_cmdline_user_args()
	)
	add_child(_hud)
	_hud.bind_player(player_kart)
	_hud.update_race_info(1, race_manager.total_laps, race_manager.get_race_position(player_kart), 4, 0.0)
	_hud.retry_requested.connect(_handle_retry_requested)
	_hud.menu_requested.connect(_handle_menu_requested)
	_hud.intro_skip_requested.connect(_handle_intro_skip_requested)
	race_manager.countdown_changed.connect(_hud.show_countdown)
	race_manager.countdown_changed.connect(_sound.play_countdown)
	race_manager.race_info_changed.connect(_hud.update_race_info)
	race_manager.player_finished.connect(_hud.show_results)
	race_manager.player_finished.connect(_handle_player_finished)
	race_manager.race_started.connect(_handle_race_started)
	_start_pre_race.call_deferred()


func _get_track_theme() -> TrackTheme:
	if _track is TrackLevel:
		return (_track as TrackLevel).track_theme
	return null


func _add_camera(kart: Kart) -> void:
	_follow_camera = FollowCamera.new()
	_follow_camera.name = "CameraRig"
	add_child(_follow_camera)
	_follow_camera.setup(kart)


func _start_pre_race() -> void:
	if not play_intro:
		_begin_race()
		return

	_intro_camera = RaceIntroCamera.new()
	_intro_camera.name = "RaceIntroCamera"
	add_child(_intro_camera)
	_intro_camera.progress_changed.connect(_hud.update_intro_progress)
	_intro_camera.skip_available.connect(
		func() -> void: _hud.set_intro_skip_enabled(true)
	)
	_intro_camera.skip_started.connect(_handle_intro_skip_started)
	_intro_camera.finished.connect(_handle_intro_finished)
	if not _intro_camera.start_intro(
		race_manager.route_points,
		_follow_camera
	):
		_cleanup_intro()
		_begin_race()
		return
	var track_name := (
		track_definition.display_name
		if track_definition != null
		else "Circuito"
	)
	_hud.show_intro(track_name, race_manager.total_laps)


func _begin_race() -> void:
	if _has_begun_race:
		return
	_has_begun_race = true
	if _follow_camera != null:
		_follow_camera.activate()
	_hud.hide_intro()
	race_manager.begin()


func _handle_intro_skip_requested() -> void:
	if _intro_camera == null or not is_instance_valid(_intro_camera):
		return
	_intro_camera.request_skip()


func _handle_intro_skip_started() -> void:
	_hud.set_intro_skip_enabled(false)
	_hud.update_intro_progress(RaceIntroCamera.FLIGHT_DURATION)


func _handle_intro_finished() -> void:
	_cleanup_intro()
	_begin_race()


func _cleanup_intro() -> void:
	if _intro_camera != null and is_instance_valid(_intro_camera):
		_intro_camera.queue_free()
	_intro_camera = null
	if _hud != null:
		_hud.hide_intro()
	if _follow_camera != null:
		_follow_camera.activate()


func _handle_race_started() -> void:
	for ai_driver in _ai_drivers:
		ai_driver.set_physics_process(true)
	for item_box in _item_boxes:
		item_box.set_collection_enabled(true)


func _handle_item_collected(kart: Node) -> void:
	_sound.play_pickup()
	if kart == player_kart and vibration_enabled:
		Input.vibrate_handheld(35, 0.35)


func _handle_player_hit() -> void:
	if vibration_enabled:
		Input.vibrate_handheld(120, 0.55)


func _handle_item_use_requested(
	item: ItemDefinition,
	direction: Vector3,
	source_kart: Kart
) -> void:
	if _item_executor == null:
		return
	_item_executor.execute(
		item,
		source_kart,
		direction,
		not source_kart.consume_straight_launch_request()
	)


func _handle_item_activated(
	item: ItemDefinition,
	_source_kart: Kart
) -> void:
	match item.category:
		ItemDefinition.ItemCategory.PROJECTILE:
			_sound.play_item_launch()
		ItemDefinition.ItemCategory.TRAP:
			_sound.play_item_deploy()
		_:
			_sound.play_item_activation()


func _handle_item_hit(
	_item: ItemDefinition,
	_kart: Node3D,
	result: int
) -> void:
	if result != Kart.HitResult.BLOCKED:
		_sound.play_item_impact()


func _handle_shield_blocked(source_kart: Kart) -> void:
	_sound.play_shield_block()
	if source_kart == player_kart and vibration_enabled:
		Input.vibrate_handheld(85, 0.46)


func _handle_retry_requested() -> void:
	_clear_active_items()
	retry_requested.emit()


func _handle_menu_requested() -> void:
	_clear_active_items()
	menu_requested.emit()


func _clear_projectiles() -> void:
	_clear_container(_projectiles)


func _clear_active_items() -> void:
	_clear_container(_projectiles)
	_clear_container(_traps)
	_clear_container(_effects)
	if race_manager != null:
		for racer in race_manager.racers:
			if is_instance_valid(racer) and racer.has_method("clear_item_effects"):
				racer.clear_item_effects()


func _clear_container(container: Node3D) -> void:
	if container == null:
		return
	for active_item in container.get_children():
		container.remove_child(active_item)
		active_item.queue_free()


func _handle_shortcut_accepted(kart: Node) -> void:
	if kart != player_kart:
		return
	_sound.play_pickup()
	if vibration_enabled:
		Input.vibrate_handheld(70, 0.42)


func _handle_player_finished(_position: int, time: float) -> void:
	_clear_active_items()
	_sound.play_finish()
	if vibration_enabled:
		Input.vibrate_handheld(220, 0.6)
	race_completed.emit(time)


func _exit_tree() -> void:
	_clear_active_items()
