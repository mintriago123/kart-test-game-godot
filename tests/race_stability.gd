extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")
const BASE_SIMULATION_SECONDS_PER_TRACK := 45.0
const RACE_CLASS_IDS := [&"50", &"100", &"150", &"200"]
const MAX_ALLOWED_RECOVERIES := 4
const QUICK_CASES := [
	{"track_id": &"coastal", "cc_id": &"50"},
	{"track_id": &"garden", "cc_id": &"150"},
	{"track_id": &"dunas_doradas", "cc_id": &"200"},
	{"track_id": &"nen_medianoche", "cc_id": &"200"},
]

var _has_failed := false
var _profile := "quick"
var _track_filter := &""
var _cc_filter := &""
var _has_explicit_filter := false
var _executed_cases := 0


func _initialize() -> void:
	_parse_arguments()
	call_deferred("_run")


func _run() -> void:
	Engine.time_scale = 4.0
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "Main scene loads for stability test.")
	if packed_scene == null:
		_finish(1)
		return

	print("INFO: Race stability profile=%s filters=%s" % [_profile, _filter_summary()])
	for cc_id in RACE_CLASS_IDS:
		for track_definition in TRACK_CATALOG.tracks:
			if _matches_case(track_definition.id, cc_id):
				_executed_cases += 1
				await _test_track_stability(packed_scene, track_definition, cc_id)

	_check(_executed_cases > 0, "Stability filters select at least one race case.")
	_finish(1 if _has_failed else 0)


func _test_track_stability(
	packed_scene: PackedScene,
	track_definition: TrackDefinition,
	cc_id: StringName
) -> void:
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	main.settings.is_persistence_enabled = false
	main.settings.select_cc(cc_id)
	main.start_game(track_definition.id, false)
	await process_frame
	var manager: RaceManager = main.race_world.race_manager
	var race_class := RaceClassDefinition.get_by_id(cc_id)
	var race_label := "%s / %s" % [
		track_definition.display_name,
		race_class.display_name,
	]
	for racer_index in range(1, manager.racers.size()):
		var observed_racer: Kart = manager.racers[racer_index]
		observed_racer.recovered.connect(
			_log_recovery.bind(observed_racer, manager, race_label)
		)
	var simulation_seconds := maxf(
		BASE_SIMULATION_SECONDS_PER_TRACK,
		BASE_SIMULATION_SECONDS_PER_TRACK
		* RaceClassDefinition.get_default().speed_multiplier
		/ race_class.speed_multiplier
	)
	# Long authored tracks need a duration derived from their physical route,
	# rather than the original fixed budget calibrated for the first two tracks.
	var route_length := 0.0
	for index in manager.route_points.size():
		route_length += manager.route_points[index].distance_to(manager.route_points[(index + 1) % manager.route_points.size()])
	var expected_minimum_speed := 25.0 * race_class.speed_multiplier * 0.42
	simulation_seconds = maxf(simulation_seconds, route_length / maxf(expected_minimum_speed, 1.0))
	await create_timer(simulation_seconds).timeout
	# A recovery near the sampling boundary can leave a healthy racer a handful
	# of checkpoints short. Extend only while progress is still incomplete, with
	# a hard cap so a genuinely stuck field still fails promptly.
	var extension_remaining := maxf(15.0, simulation_seconds * 0.3)
	while extension_remaining > 0.0 and not _all_rivals_completed_lap(manager):
		await create_timer(1.0).timeout
		extension_remaining -= 1.0

	for racer_index in range(1, manager.racers.size()):
		var racer: Kart = manager.racers[racer_index]
		var completed_checkpoints := manager.get_completed_checkpoint_count(racer)
		print(
			"INFO: %s / %s progress=%d/%d recoveries=%d speed=%.1f" % [
				race_label,
				racer.racer_name,
				completed_checkpoints,
				manager.route_points.size(),
				racer.recovery_count,
				Vector2(racer.velocity.x, racer.velocity.z).length(),
			]
		)
		_check(
			completed_checkpoints >= manager.route_points.size(),
			"%s / %s completes at least one lap without getting stuck."
			% [race_label, racer.racer_name]
		)
		_check(
			racer.recovery_count <= MAX_ALLOWED_RECOVERIES,
			"%s / %s does not enter a recovery loop."
			% [race_label, racer.racer_name]
		)
		_check(
			racer.global_position.y > -2.5,
			"%s / %s remains on a recoverable driving surface."
			% [race_label, racer.racer_name]
		)

	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout


func _all_rivals_completed_lap(manager: RaceManager) -> bool:
	for racer_index in range(1, manager.racers.size()):
		if (
			manager.get_completed_checkpoint_count(manager.racers[racer_index])
			< manager.route_points.size()
		):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)


func _log_recovery(
	racer: Kart,
	manager: RaceManager,
	race_label: String
) -> void:
	print(
		"RECOVERY: %s / %s checkpoint=%d from=%s reason=%s" % [
			race_label,
			racer.racer_name,
			manager.get_next_checkpoint_index(racer),
			racer.last_recovery_position,
			racer.last_recovery_reason,
		]
	)


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
	if _profile not in ["quick", "exhaustive"]:
		push_error("Unknown race stability profile: %s" % _profile)
		_has_failed = true
		_profile = "quick"


func _matches_case(track_id: StringName, cc_id: StringName) -> bool:
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


func _filter_summary() -> String:
	return "track=%s cc=%s" % [
		"*" if _track_filter == &"" else _track_filter,
		"*" if _cc_filter == &"" else _cc_filter,
	]


func _finish(exit_code: int) -> void:
	Engine.time_scale = 1.0
	quit(exit_code)
