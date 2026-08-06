class_name RaceWorld
extends Node3D

signal retry_requested
signal menu_requested
signal race_completed(time: float)

var graphics_profile := "medium"
var vibration_enabled := true
var race_manager: RaceManager
var player_kart: Kart

var _track: CoastalTrack
var _hud: RaceHud
var _sound: SoundManager


func _ready() -> void:
	_build_environment()
	_build_track()
	_build_race()


func _build_environment() -> void:
	_sound = SoundManager.new()
	add_child(_sound)
	_sound.start_music()

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#58bfd0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d9f4df")
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
	_track = CoastalTrack.new()
	add_child(_track)


func _build_race() -> void:
	race_manager = RaceManager.new()
	add_child(race_manager)
	race_manager.configure(_track.route_points)
	_track.shortcut_completed.connect(race_manager.complete_shortcut)
	race_manager.shortcut_accepted.connect(_handle_shortcut_accepted)

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
		add_child(kart)
		var grid_slot := 3 if slot == 0 else slot - 1
		kart.global_transform = _track.get_spawn_transform(grid_slot)
		kart.set_respawn_transform(kart.global_transform)
		race_manager.register_kart(kart, slot == 0)
		if slot == 0:
			player_kart = kart
			_add_camera(kart)
			kart.hit_received.connect(_handle_player_hit)
		else:
			var ai := AiDriver.new()
			kart.add_child(ai)
			ai.setup(kart, race_manager, [-2.0, 0.0, 2.0][slot - 1])
			ai.caution = float(slot - 1) * 0.2

	for item_position in _track.item_spawn_points:
		var item_box := ItemBox.new()
		item_box.position = item_position
		item_box.collected.connect(_handle_item_collected)
		add_child(item_box)

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
	_hud.retry_requested.connect(func() -> void: retry_requested.emit())
	_hud.menu_requested.connect(func() -> void: menu_requested.emit())
	race_manager.countdown_changed.connect(_hud.show_countdown)
	race_manager.countdown_changed.connect(_sound.play_countdown)
	race_manager.race_info_changed.connect(_hud.update_race_info)
	race_manager.player_finished.connect(_hud.show_results)
	race_manager.player_finished.connect(_handle_player_finished)
	race_manager.begin.call_deferred()


func _add_camera(kart: Kart) -> void:
	var camera_rig := FollowCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(kart)


func _handle_item_collected(kart: Node) -> void:
	_sound.play_pickup()
	if kart == player_kart and vibration_enabled:
		Input.vibrate_handheld(35, 0.35)


func _handle_player_hit() -> void:
	_sound.play_hit()
	if vibration_enabled:
		Input.vibrate_handheld(120, 0.55)


func _handle_shortcut_accepted(kart: Node) -> void:
	if kart != player_kart:
		return
	_sound.play_pickup()
	if vibration_enabled:
		Input.vibrate_handheld(70, 0.42)


func _handle_player_finished(_position: int, time: float) -> void:
	_sound.play_finish()
	if vibration_enabled:
		Input.vibrate_handheld(220, 0.6)
	race_completed.emit(time)
