extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")
const MAX_PHYSICS_FRAMES_PER_SHORTCUT := 720
const TARGET_DISTANCE := 5.0

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 3.0
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "Main scene loads for shortcut driving test.")
	if packed_scene == null:
		_finish(1)
		return

	for track_definition in TRACK_CATALOG.tracks:
		await _test_track_shortcuts(packed_scene, track_definition)

	_finish(1 if _has_failed else 0)


func _test_track_shortcuts(
	packed_scene: PackedScene,
	track_definition: TrackDefinition
) -> void:
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.settings.is_persistence_enabled = false
	main.start_game(track_definition.id, false)
	await process_frame
	await physics_frame
	var world: RaceWorld = main.race_world
	var player: Kart = world.player_kart
	var track: CoastalTrack = world._track
	world.race_manager.set_process(false)
	for racer in world.race_manager.racers:
		racer.is_control_enabled = false
		for child in racer.get_children():
			if child is AiDriver:
				child.set_physics_process(false)
	player.is_player = false
	player.is_control_enabled = true

	for shortcut_definition in track.shortcut_definitions:
		for approach in [
			{"lateral_offset": 0.0, "heading_offset": 0.0},
			{"lateral_offset": -3.0, "heading_offset": 8.0},
			{"lateral_offset": 3.0, "heading_offset": -8.0},
		]:
			await _drive_shortcut(
				player,
				track,
				shortcut_definition,
				track_definition,
				float(approach.lateral_offset),
				float(approach.heading_offset)
			)

	main.queue_free()
	await process_frame


func _drive_shortcut(
	player: Kart,
	track: CoastalTrack,
	shortcut_definition: Dictionary,
	track_definition: TrackDefinition,
	lateral_offset: float,
	heading_offset_degrees: float
) -> void:
	player.set_shortcut_surface_enabled(false)
	var drive_points := _build_drive_points(
		track,
		shortcut_definition,
		lateral_offset
	)
	var drive_label := (
		"centro"
		if is_zero_approx(lateral_offset)
		else "margen %+.1f m · entrada %+.0f°" % [
			lateral_offset,
			heading_offset_degrees,
		]
	)
	var first_forward := (drive_points[1] - drive_points[0]).normalized()
	first_forward = first_forward.rotated(
		Vector3.UP,
		deg_to_rad(heading_offset_degrees)
	)
	player.global_transform = Transform3D(
		Basis.looking_at(first_forward, Vector3.UP),
		drive_points[0] + Vector3.UP * 0.45
	)
	player.velocity = first_forward * 5.0
	player.set_respawn_transform(player.global_transform)
	var initial_recovery_count := player.recovery_count
	var target_index := 1
	var shortcut_surface_was_enabled := false
	for _physics_step in MAX_PHYSICS_FRAMES_PER_SHORTCUT:
		player.is_control_enabled = true
		while (
			target_index < drive_points.size() - 1
			and player.global_position.distance_to(drive_points[target_index])
			< TARGET_DISTANCE
		):
			target_index += 1
		var lookahead_index := mini(target_index + 2, drive_points.size() - 1)
		var target_direction := (
			drive_points[lookahead_index] - player.global_position
		)
		target_direction.y = 0.0
		target_direction = target_direction.normalized()
		var player_forward := -player.global_transform.basis.z.normalized()
		var steer := clampf(
			-player_forward.cross(target_direction).y * 2.4,
			-1.0,
			1.0
		)
		var alignment := player_forward.dot(target_direction)
		player.set_drive_input(
			0.65 if alignment < 0.7 else 1.0,
			0.35 if alignment < 0.35 else 0.0,
			steer,
			false,
			false
		)
		await physics_frame
		shortcut_surface_was_enabled = (
			shortcut_surface_was_enabled
			or (player.collision_mask & Kart.SHORTCUT_SURFACE_LAYER) != 0
		)
		if (
			target_index == drive_points.size() - 1
			and player.global_position.distance_to(drive_points.back())
			< TARGET_DISTANCE
		):
			break
	print(
		"INFO: %s / %s / %s target=%d/%d distance=%.2f speed=%.1f recoveries=%d"
		% [
			track_definition.display_name,
			shortcut_definition.name,
			drive_label,
			target_index,
			drive_points.size() - 1,
			player.global_position.distance_to(drive_points.back()),
			Vector2(player.velocity.x, player.velocity.z).length(),
			player.recovery_count - initial_recovery_count,
		]
	)
	_check(
		target_index == drive_points.size() - 1
		and player.global_position.distance_to(drive_points.back()) < TARGET_DISTANCE,
		"%s / %s / %s is traversable by the real player kart."
		% [track_definition.display_name, shortcut_definition.name, drive_label]
	)
	_check(
		player.recovery_count == initial_recovery_count,
		"%s / %s / %s does not trigger player recovery."
		% [track_definition.display_name, shortcut_definition.name, drive_label]
	)
	_check(
		shortcut_surface_was_enabled
		and (player.collision_mask & Kart.SHORTCUT_SURFACE_LAYER) == 0,
		"%s / %s / %s enables its floor only during traversal."
		% [track_definition.display_name, shortcut_definition.name, drive_label]
	)
	player.set_drive_input(0.0, 1.0, 0.0, false, false)


func _build_drive_points(
	track: CoastalTrack,
	shortcut_definition: Dictionary,
	lateral_offset := 0.0
) -> Array[Vector3]:
	var drive_points: Array[Vector3] = []
	var route_size := track.route_points.size()
	var entry_index: int = shortcut_definition.entry_index
	var exit_index: int = shortcut_definition.exit_index
	for route_offset in range(-3, 1):
		drive_points.append(
			track.route_points[(entry_index + route_offset + route_size) % route_size]
		)
	var shortcut_points: Array[Vector3] = shortcut_definition.points
	for shortcut_index in shortcut_points.size():
		var shortcut_point := shortcut_points[shortcut_index]
		if not is_zero_approx(lateral_offset):
			var previous_index := maxi(shortcut_index - 1, 0)
			var next_index := mini(shortcut_index + 1, shortcut_points.size() - 1)
			var forward := shortcut_points[next_index] - shortcut_points[previous_index]
			forward.y = 0.0
			var right := Vector3.UP.cross(forward.normalized()).normalized()
			var edge_distance := mini(
				shortcut_index,
				shortcut_points.size() - 1 - shortcut_index
			)
			var junction_weight := 1.0 - clampf(float(edge_distance) / 6.0, 0.0, 1.0)
			shortcut_point += right * lateral_offset * junction_weight
		if drive_points.back().distance_to(shortcut_point) > 0.01:
			drive_points.append(shortcut_point)
	for route_offset in range(1, 5):
		drive_points.append(track.route_points[(exit_index + route_offset) % route_size])
	return drive_points


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)


func _finish(exit_code: int) -> void:
	Engine.time_scale = 1.0
	quit(exit_code)
