extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")
const ASSET_LIBRARY: TrackAssetLibrary = preload(
	"res://assets/track/track_asset_library.tres"
)

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(TRACK_CATALOG.tracks.size() == 3, "Track catalog contains all three published entries.")
	_check(
		ASSET_LIBRARY.get_valid_entries().size() == 7,
		"Editor asset library exposes seven valid CC0 entries."
	)
	var observed_ids: Dictionary = {}
	for track_definition in TRACK_CATALOG.tracks:
		_check(track_definition.is_valid(), "%s definition is valid." % track_definition.display_name)
		_check(
			not observed_ids.has(track_definition.id),
			"%s uses a unique catalog id." % track_definition.display_name
		)
		observed_ids[track_definition.id] = true
		await _test_authored_track(track_definition)
	quit(1 if _has_failed else 0)


func _test_authored_track(track_definition: TrackDefinition) -> void:
	var track := track_definition.scene.instantiate() as TrackLevel
	_check(track != null, "%s instantiates TrackLevel." % track_definition.display_name)
	if track == null:
		return
	root.add_child(track)
	await process_frame
	_check(
		track.track_id == track_definition.id,
		"%s scene id matches its catalog entry." % track_definition.display_name
	)
	var validation_errors := track.validate_track()
	if not validation_errors.is_empty():
		print("INFO: %s validation errors: %s" % [
			track_definition.display_name,
			", ".join(validation_errors),
		])
	_check(
		validation_errors.is_empty(),
		"%s passes the editor validator." % track_definition.display_name
	)
	_check(
		track.get_main_route() != null and track.get_main_route().curve.closed,
		"%s keeps an editable closed Curve3D." % track_definition.display_name
	)
	_check(
		track.route_points.size() >= 40,
		"%s generates a complete runtime route." % track_definition.display_name
	)
	_check(
		track.get_node_or_null("MainRoadCollision") != null,
		"%s generates its continuous road collision." % track_definition.display_name
	)
	_test_official_tree_calibration(track)
	var source_child_count := track.get_child_count()
	track.clear_generated_track()
	_check(
		track.get_node_or_null("MainRoute") != null
		and track.get_node_or_null("Props") != null
		and track.get_node_or_null("MainRoadCollision") == null,
		"%s clears preview output without deleting authoring data."
		% track_definition.display_name
	)
	var rebuild_errors := track.rebuild_preview()
	_check(
		rebuild_errors.is_empty()
		and track.get_child_count() == source_child_count
		and track.get_node_or_null("MainRoadCollision") != null,
		"%s rebuilds deterministically from its authoring scene."
		% track_definition.display_name
	)
	track.queue_free()
	await process_frame


func _test_official_tree_calibration(track: TrackLevel) -> void:
	if track.track_id not in [&"coastal", &"garden"]:
		return
	var expected_prefix := "Palm" if track.track_id == &"coastal" else "Oak"
	var expected_asset_id := &"palm_tree" if track.track_id == &"coastal" else &"oak_tree"
	var expected_scale := 5.203778 if track.track_id == &"coastal" else 5.436674
	var expected_count := 6 if track.track_id == &"coastal" else 3
	var observed_count := 0
	var all_trees_are_calibrated := true
	var props := track.get_node_or_null("Props")
	if props != null:
		for child in props.get_children():
			var tree := child as Node3D
			if tree == null or not String(tree.name).begins_with(expected_prefix):
				continue
			observed_count += 1
			var bounds_result := TrackAssetEntry.get_node_aabb(tree)
			var measured_height := (
				(bounds_result.aabb as AABB).size.y
				if bool(bounds_result.valid)
				else 0.0
			)
			all_trees_are_calibrated = (
				all_trees_are_calibrated
				and absf(measured_height - 10.0) <= 1.0
				and tree.scale.is_equal_approx(Vector3.ONE * expected_scale)
				and StringName(tree.get_meta(
					TrackEditorSession.META_ASSET_ID,
					&""
				)) == expected_asset_id
				and is_equal_approx(float(tree.get_meta(
					TrackEditorSession.META_PROP_SCALE_MULTIPLIER,
					0.0
				)), 1.0)
			)
	_check(
		observed_count == expected_count and all_trees_are_calibrated,
		"%s keeps its %d official trees within 10%% of 10 m with explicit metadata."
		% [track.display_name, expected_count]
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
