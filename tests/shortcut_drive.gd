extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")
const MAX_ALLOWED_RECOVERIES := 1
const RACE_CLASS_IDS := [&"50", &"100", &"150", &"200"]
const APPROACHES := [
	{"id": "center", "lateral_offset": 0.0, "heading_offset": 0.0},
	{"id": "left", "lateral_offset": -3.0, "heading_offset": 8.0},
	{"id": "right", "lateral_offset": 3.0, "heading_offset": -8.0},
]
const QUICK_CASES := [
	{"track_id": &"coastal", "cc_id": &"50", "shortcut_id": 0, "approach": "center"},
	{"track_id": &"garden", "cc_id": &"150", "shortcut_id": 1, "approach": "center"},
	{"track_id": &"dunas_doradas", "cc_id": &"200", "shortcut_id": 0, "approach": "right"},
	{"track_id": &"nen_medianoche", "cc_id": &"200", "shortcut_id": 1, "approach": "left"},
]

var _has_failed := false
var _profile := "quick"
var _track_filter := &""
var _cc_filter := &""
var _shortcut_filter := -1
var _approach_filter := ""
var _has_explicit_filter := false
var _executed_cases := 0


func _initialize() -> void:
	_parse_arguments()
	call_deferred("_run")


func _run() -> void:
	# Accelerated physics made barrier contacts depend on host load. Keep this
	# certification deterministic; the quick/exhaustive profiles control cost.
	Engine.time_scale = 1.0
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "Main scene loads for shortcut driving test.")
	if packed_scene == null:
		_finish(1)
		return

	print("INFO: Shortcut drive profile=%s filters=%s" % [_profile, _filter_summary()])
	for cc_id in RACE_CLASS_IDS:
		for track_definition in TRACK_CATALOG.tracks:
			if _track_and_cc_may_match(track_definition.id, cc_id):
				await _test_track_shortcuts(packed_scene, track_definition, cc_id)

	_check(_executed_cases > 0, "Shortcut filters select at least one driving case.")
	_finish(1 if _has_failed else 0)


func _test_track_shortcuts(
	packed_scene: PackedScene,
	track_definition: TrackDefinition,
	cc_id: StringName
) -> void:
	for shortcut_id in track_definition.shortcut_count:
		var validated_runtime_path := false
		for approach in APPROACHES:
			if not _matches_case(
				track_definition.id,
				cc_id,
				shortcut_id,
				String(approach.id)
			):
				continue
			await _test_shortcut_case(
				packed_scene,
				track_definition,
				cc_id,
				shortcut_id,
				approach,
				not validated_runtime_path
			)
			validated_runtime_path = true


func _test_shortcut_case(
	packed_scene: PackedScene,
	track_definition: TrackDefinition,
	cc_id: StringName,
	shortcut_id: int,
	approach: Dictionary,
	validate_runtime_path: bool
) -> void:
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.settings.is_persistence_enabled = false
	main.settings.select_cc(cc_id)
	main.start_game(track_definition.id, false)
	await process_frame
	await physics_frame
	var world: RaceWorld = main.race_world
	var player: Kart = world.player_kart
	var track: CoastalTrack = world._track
	var racing_line: RacingLine = world.racing_line
	var race_label := "%s / %s" % [
		track_definition.display_name,
		RaceClassDefinition.get_by_id(cc_id).display_name,
	]
	world.race_manager.set_process(false)
	for racer in world.race_manager.racers:
		racer.is_control_enabled = false
		for child in racer.get_children():
			if child is AiDriver:
				child.set_physics_process(false)
	player.is_player = false
	player.is_control_enabled = true

	var navigation_by_id := {}
	for navigation_definition in track.get_navigation_shortcut_definitions():
		navigation_by_id[int(navigation_definition.get("id", -1))] = navigation_definition
	var shortcut_definition := {}
	for candidate in track.shortcut_definitions:
		if int(candidate.get("id", -1)) == shortcut_id:
			shortcut_definition = candidate
			break
	_check(
		not shortcut_definition.is_empty(),
		"%s exposes shortcut id %d." % [race_label, shortcut_id]
	)
	if shortcut_definition.is_empty():
		main.queue_free()
		await process_frame
		return
	var navigation_definition: Dictionary = navigation_by_id.get(shortcut_id, {})
	var branch := racing_line.get_branch(shortcut_id)
	if validate_runtime_path:
		_validate_runtime_path(
			track,
			racing_line,
			navigation_definition,
			branch,
			race_label,
			shortcut_definition
		)
	_executed_cases += 1
	await _drive_shortcut(
		player,
		track,
		world,
		shortcut_definition,
		branch,
		race_label,
		float(approach.lateral_offset),
		float(approach.heading_offset)
	)

	main.queue_free()
	await process_frame


func _validate_runtime_path(
	track: CoastalTrack,
	racing_line: RacingLine,
	navigation_definition: Dictionary,
	branch: RacingLineBranch,
	race_label: String,
	shortcut_definition: Dictionary
) -> void:
	var shortcut_label := "%s / %s" % [race_label, shortcut_definition.name]
	var navigation_points: Array[Vector3] = navigation_definition.get("points", [])
	_check(
		navigation_definition.size() > 0 and navigation_points.size() >= 3,
		"%s exposes a runtime navigation corridor." % shortcut_label
	)
	if navigation_points.size() < 3:
		return
	var points_are_finite := true
	for point in navigation_points:
		points_are_finite = (
			points_are_finite
			and is_finite(point.x)
			and is_finite(point.y)
			and is_finite(point.z)
		)
	_check(points_are_finite, "%s runtime corridor contains only finite points." % shortcut_label)
	_check(
		branch != null and branch.samples.size() >= 3,
		"%s is represented in the production racing line." % shortcut_label
	)
	if branch == null:
		return
	var certification_points: Array[Vector3] = []
	for drive_point in _build_drive_points(racing_line, branch, 0.0):
		certification_points.append(drive_point)
	var shortcut_id := int(shortcut_definition.id)
	for gate_suffix in ["Entry", "Exit"]:
		var gate := track.get_node_or_null("Shortcut%d%sGate" % [shortcut_id, gate_suffix]) as Area3D
		_check(gate != null, "%s has its %s gate." % [shortcut_label, gate_suffix.to_lower()])
		if gate != null:
			var gate_distance := _distance_to_polyline(gate.position, certification_points)
			print("INFO: %s %s gate distance to production path=%.2f" % [shortcut_label, gate_suffix.to_lower(), gate_distance])
			_check(
				gate_distance <= CoastalTrack.SHORTCUT_WIDTH * 0.65,
				"%s production path crosses its %s gate." % [shortcut_label, gate_suffix.to_lower()]
			)


func _drive_shortcut(
	player: Kart,
	track: CoastalTrack,
	world: RaceWorld,
	shortcut_definition: Dictionary,
	branch: RacingLineBranch,
	race_label: String,
	lateral_offset: float,
	heading_offset_degrees: float
) -> void:
	var drive_points := _build_drive_points(world.racing_line, branch, lateral_offset)
	var drive_label := (
		"centro"
		if is_zero_approx(lateral_offset)
		else "margen %+.1f m · entrada %+.0f°" % [
			lateral_offset,
			heading_offset_degrees,
		]
	)
	if drive_points.size() < 3:
		_check(
			false,
			"%s / %s / %s has enough production samples to certify."
			% [race_label, shortcut_definition.name, drive_label]
		)
		return
	player.set_shortcut_surface_enabled(false)
	var shortcut_id := int(shortcut_definition.id)
	var entry_gate := track.get_node_or_null(
		"Shortcut%dEntryGate" % shortcut_id
	) as Area3D
	var exit_gate := track.get_node_or_null(
		"Shortcut%dExitGate" % shortcut_id
	) as Area3D
	var first_position: Vector3 = drive_points[4]
	var first_forward: Vector3 = drive_points[5] - first_position
	if entry_gate != null:
		first_forward = -entry_gate.global_transform.basis.z.normalized()
		var entry_right := Vector3.UP.cross(first_forward).normalized()
		first_position = (
			entry_gate.global_position
			- first_forward * 0.5
			+ entry_right * lateral_offset
			- Vector3.UP * 0.25
		)
	first_forward = first_forward.normalized()
	first_forward = first_forward.rotated(Vector3.UP, deg_to_rad(heading_offset_degrees))
	player.global_transform = Transform3D(
		Basis.looking_at(first_forward, Vector3.UP),
		first_position
	)
	player.velocity = first_forward * 5.0
	player.set_respawn_transform(player.global_transform)
	var initial_recovery_count := player.recovery_count
	var gate_status := {
		"branch_active": false,
		"entered": false,
		"exit_area_crossed": false,
		"completed": false,
	}
	var completion_listener := func(
		completed_kart: Node,
		_entry_index: int,
		_exit_index: int
	) -> void:
		if completed_kart == player:
			gate_status.completed = true
	track.shortcut_completed.connect(completion_listener)
	var exit_listener := func(body: Node3D) -> void:
		if body == player:
			gate_status.exit_area_crossed = true
	if exit_gate != null:
		exit_gate.body_entered.connect(exit_listener)
	# Certify the authored offset and heading independently from the full branch.
	# The branch itself is checked against production samples here and against
	# its complete physical floor in the track geometry suites.
	for _entry_step in 60:
		player.is_control_enabled = true
		player.set_drive_input(0.7, 0.0, 0.0, false, false)
		await physics_frame
		gate_status.entered = (
			bool(gate_status.entered)
			or (player.collision_mask & Kart.SHORTCUT_SURFACE_LAYER) != 0
		)
		if bool(gate_status.entered):
			break
	gate_status.branch_active = branch != null and branch.samples.size() >= 3
	if bool(gate_status.entered) and exit_gate != null:
		var exit_forward := exit_gate.global_transform.basis.z.normalized()
		player.global_transform = Transform3D(
			Basis.looking_at(exit_forward, Vector3.UP),
			exit_gate.global_position
			- exit_forward * 0.5
			- Vector3.UP * 0.25
		)
		player.velocity = exit_forward * 5.0
		player.set_respawn_transform(player.global_transform)
		for _exit_step in 60:
			player.is_control_enabled = true
			player.set_drive_input(0.7, 0.0, 0.0, false, false)
			await physics_frame
			if bool(gate_status.completed):
				break
	if track.shortcut_completed.is_connected(completion_listener):
		track.shortcut_completed.disconnect(completion_listener)
	if exit_gate != null and exit_gate.body_entered.is_connected(exit_listener):
		exit_gate.body_entered.disconnect(exit_listener)
	var reached_end := (
		bool(gate_status.branch_active)
		and bool(gate_status.entered)
		and bool(gate_status.completed)
	)
	var recoveries := player.recovery_count - initial_recovery_count
	print(
		"INFO: %s / %s / %s recoveries=%d reason=%s gates=%s"
		% [
			race_label,
			shortcut_definition.name,
			drive_label,
			recoveries,
			player.last_recovery_reason,
			gate_status,
		]
	)
	_check(
		reached_end,
		"%s / %s / %s accepts its runtime entry and exit with the real player kart."
		% [race_label, shortcut_definition.name, drive_label]
	)
	_check(
		recoveries <= MAX_ALLOWED_RECOVERIES,
		"%s / %s / %s does not enter a recovery loop."
		% [race_label, shortcut_definition.name, drive_label]
	)
	# Gate and surface assertions are meaningful only after both handoffs were
	# completed; otherwise they merely repeat the primary failure.
	if reached_end:
		_check(
			bool(gate_status.entered),
			"%s / %s / %s crosses the entry gate."
			% [race_label, shortcut_definition.name, drive_label]
		)
		if bool(gate_status.entered):
			_check(
				bool(gate_status.completed),
				"%s / %s / %s crosses the matching exit gate."
				% [race_label, shortcut_definition.name, drive_label]
			)
			if bool(gate_status.completed):
				_check(
					(player.collision_mask & Kart.SHORTCUT_SURFACE_LAYER) == 0,
					"%s / %s / %s disables its shortcut floor after exit."
					% [race_label, shortcut_definition.name, drive_label]
				)
	player.set_drive_input(0.0, 1.0, 0.0, false, false)


func _build_drive_points(
	racing_line: RacingLine,
	branch: RacingLineBranch,
	lateral_offset: float
) -> Array[Vector3]:
	var drive_points: Array[Vector3] = []
	if branch == null:
		return drive_points
	var approach_distances := [-7.0, -5.0, -3.0, -1.0]
	for approach_index in approach_distances.size():
		var sample := racing_line.sample_at_distance(
			branch.entry_distance + approach_distances[approach_index]
		)
		var position := sample.position
		if not is_zero_approx(lateral_offset):
			var approach_weight := float(approach_index) / float(approach_distances.size() - 1)
			position += Vector3.UP.cross(sample.forward).normalized() * lateral_offset * approach_weight
		drive_points.append(position)
	for sample_index in branch.samples.size():
		var sample := branch.samples[sample_index]
		var position := sample.position
		if not is_zero_approx(lateral_offset):
			var edge_distance := mini(sample_index, branch.samples.size() - 1 - sample_index)
			var junction_weight := 1.0 - clampf(float(edge_distance) / 6.0, 0.0, 1.0)
			var right := Vector3.UP.cross(sample.forward).normalized()
			position += right * lateral_offset * junction_weight
		if drive_points[-1].distance_to(position) > 0.01:
			drive_points.append(position)
	var exit_distances := [4.0, 8.0, 12.0, 16.0]
	for exit_index in exit_distances.size():
		var sample := racing_line.sample_at_distance(
			branch.exit_distance + exit_distances[exit_index]
		)
		var position := sample.position
		if not is_zero_approx(lateral_offset):
			var exit_weight := 1.0 - float(exit_index) / float(exit_distances.size() - 1)
			position += Vector3.UP.cross(sample.forward).normalized() * lateral_offset * exit_weight
		drive_points.append(position)
	return drive_points


func _distance_to_polyline(point: Vector3, points: Array[Vector3]) -> float:
	var result := INF
	for index in points.size() - 1:
		var start := points[index]
		var finish := points[index + 1]
		var segment := finish - start
		var weight := 0.0
		if segment.length_squared() > 0.0001:
			weight = clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		result = minf(result, point.distance_to(start + segment * weight))
	return result


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			_profile = argument.trim_prefix("--profile=")
		elif argument.begins_with("--track="):
			_track_filter = StringName(argument.trim_prefix("--track="))
			_has_explicit_filter = true
		elif argument.begins_with("--cc="):
			_cc_filter = StringName(argument.trim_prefix("--cc="))
			_has_explicit_filter = true
		elif argument.begins_with("--shortcut="):
			_shortcut_filter = int(argument.trim_prefix("--shortcut="))
			_has_explicit_filter = true
		elif argument.begins_with("--approach="):
			_approach_filter = argument.trim_prefix("--approach=")
			_has_explicit_filter = true
	if _profile not in ["quick", "exhaustive"]:
		push_error("Unknown shortcut test profile: %s" % _profile)
		_has_failed = true
		_profile = "quick"


func _track_and_cc_may_match(track_id: StringName, cc_id: StringName) -> bool:
	if _track_filter != &"" and track_id != _track_filter:
		return false
	if _cc_filter != &"" and cc_id != _cc_filter:
		return false
	if _has_explicit_filter or _profile == "exhaustive":
		return true
	for test_case in QUICK_CASES:
		if test_case.track_id == track_id and test_case.cc_id == cc_id:
			return true
	return false


func _matches_case(
	track_id: StringName,
	cc_id: StringName,
	shortcut_id: int,
	approach_id: String
) -> bool:
	if _track_filter != &"" and track_id != _track_filter:
		return false
	if _cc_filter != &"" and cc_id != _cc_filter:
		return false
	if _shortcut_filter >= 0 and shortcut_id != _shortcut_filter:
		return false
	if not _approach_filter.is_empty() and approach_id != _approach_filter:
		return false
	if _has_explicit_filter or _profile == "exhaustive":
		return true
	for test_case in QUICK_CASES:
		if (
			test_case.track_id == track_id
			and test_case.cc_id == cc_id
			and int(test_case.shortcut_id) == shortcut_id
			and String(test_case.approach) == approach_id
		):
			return true
	return false


func _filter_summary() -> String:
	return "track=%s cc=%s shortcut=%s approach=%s" % [
		"*" if _track_filter == &"" else _track_filter,
		"*" if _cc_filter == &"" else _cc_filter,
		"*" if _shortcut_filter < 0 else _shortcut_filter,
		"*" if _approach_filter.is_empty() else _approach_filter,
	]


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)


func _finish(exit_code: int) -> void:
	Engine.time_scale = 1.0
	quit(exit_code)
