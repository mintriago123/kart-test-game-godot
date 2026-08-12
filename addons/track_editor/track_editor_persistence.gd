@tool
class_name TrackEditorPersistence
extends RefCounted

const CATALOG_PATH := "res://levels/track_catalog.tres"
const NEW_TRACKS_DIRECTORY := "res://levels/tracks"
const RECOVERY_PATH := "user://coastal_karts_track_recovery.tscn"
const ENVIRONMENT_MARGIN := 60.0
const TEMPLATE_SPECS := {
	&"small": {
		"radius": 42.0,
		"positions": [
			Vector3(0.0, 0.25, 31.08),
			Vector3(34.44, 0.35, 18.48),
			Vector3(38.64, 0.50, -15.12),
			Vector3(10.50, 0.60, -36.12),
			Vector3(-31.50, 0.35, -21.84),
			Vector3(-35.28, 0.25, 15.12),
		],
	},
	&"medium": {
		"radius": 62.0,
		"positions": [
			Vector3(0.0, 0.25, 44.64),
			Vector3(38.44, 0.25, 34.10),
			Vector3(62.0, 0.50, 0.0),
			Vector3(43.40, 0.75, -38.44),
			Vector3(0.0, 0.25, -48.36),
			Vector3(-43.40, 0.50, -38.44),
			Vector3(-62.0, 0.75, 0.0),
			Vector3(-38.44, 0.25, 34.10),
		],
	},
	&"large": {
		"radius": 84.0,
		"positions": [
			Vector3(-8.40, 0.25, 63.00),
			Vector3(31.92, 0.40, 69.72),
			Vector3(72.24, 0.65, 42.00),
			Vector3(84.00, 0.90, 5.04),
			Vector3(63.84, 1.10, -38.64),
			Vector3(24.36, 0.80, -68.88),
			Vector3(-15.12, 0.45, -73.92),
			Vector3(-52.92, 0.30, -55.44),
			Vector3(-79.80, 0.55, -20.16),
			Vector3(-72.24, 0.85, 21.84),
			Vector3(-45.36, 0.60, 50.40),
			Vector3(-21.00, 0.35, 42.00),
		],
	},
}

var _session_ref: WeakRef
var _session: RefCounted:
	get:
		return _session_ref.get_ref()
var _last_recovery_msec := 0


func _init(session: RefCounted) -> void:
	_session_ref = weakref(session)


func load_track(path: String) -> Error:
	if not ResourceLoader.exists(path):
		return ERR_FILE_NOT_FOUND
	var packed_scene := load(path) as PackedScene
	if packed_scene == null:
		return ERR_FILE_CORRUPT
	var loaded_track := packed_scene.instantiate() as TrackLevel
	if loaded_track == null:
		return ERR_INVALID_DATA
	_session._set_track(loaded_track, path)
	_session.is_published = _catalog_contains(loaded_track.track_id)
	var repair_counts: Dictionary = _session.migrate_legacy_anchors()
	_session.last_repair_summary = _format_repair_summary(repair_counts)
	if not _session.last_repair_summary.is_empty():
		_session._set_dirty(true)
		_session.route_changed.emit()
	return OK


func create_track(template_size: StringName, track_name: String) -> void:
	var new_track := TrackLevel.new()
	new_track.name = "TrackLevel"
	new_track.display_name = (
		track_name.strip_edges()
		if not track_name.strip_edges().is_empty()
		else "Nueva pista"
	)
	new_track.track_id = _make_unique_id(new_track.display_name)
	new_track.start_banner_text = new_track.display_name.to_upper()
	new_track.track_theme = load(
		"res://levels/themes/coastal_theme.tres"
	) as TrackTheme

	var main_route := Path3D.new()
	main_route.name = "MainRoute"
	main_route.curve = _create_template_curve(template_size)
	new_track.environment_size = _get_template_metrics_from_curve(
		main_route.curve
	).environment_size
	new_track.add_child(main_route)
	main_route.owner = new_track

	var shortcuts := Node3D.new()
	shortcuts.name = "Shortcuts"
	new_track.add_child(shortcuts)
	shortcuts.owner = new_track

	var props := Node3D.new()
	props.name = "Props"
	new_track.add_child(props)
	props.owner = new_track

	var item_spawns := Node3D.new()
	item_spawns.name = "ItemSpawns"
	new_track.add_child(item_spawns)
	item_spawns.owner = new_track
	for marker_index in 4:
		var marker := Marker3D.new()
		marker.name = "ItemSpawn%d" % (marker_index + 1)
		var marker_progress := 0.18 + marker_index * 0.03
		marker.position = main_route.curve.sample_baked(
			main_route.curve.get_baked_length() * marker_progress,
			true
		)
		_session._set_route_anchor_metadata(
			marker,
			marker_progress,
			0.0,
			0.0,
			0.0
		)
		item_spawns.add_child(marker)
		marker.owner = new_track

	_session._set_track(new_track, "")
	_session.is_published = false
	mark_dirty()


func save() -> Error:
	if _session.track == null:
		return ERR_DOES_NOT_EXIST
	if _session.scene_path.is_empty():
		var directory_error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(_session.new_tracks_directory)
		)
		if directory_error != OK:
			return directory_error
		_session.scene_path = "%s/%s.tscn" % [
			_session.new_tracks_directory,
			_session.track.track_id,
		]
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(_session.track)
	if pack_error != OK:
		return pack_error
	var save_error := ResourceSaver.save(packed_scene, _session.scene_path)
	if save_error == OK:
		_session._set_dirty(false)
	return save_error


func publish(laps: int, description: String) -> Error:
	if (
		_session.track == null
		or not _session.track.validate_track().is_empty()
	):
		return ERR_INVALID_DATA
	var save_error := save()
	if save_error != OK:
		return save_error
	var catalog := load(_session.catalog_path) as TrackCatalog
	if catalog == null:
		return ERR_FILE_CORRUPT
	var definition := catalog.get_track(_session.track.track_id)
	if definition == null:
		definition = TrackDefinition.new()
		catalog.tracks.append(definition)
	definition.id = _session.track.track_id
	definition.display_name = _session.track.display_name
	definition.description = description
	definition.scene = ResourceLoader.load(
		_session.scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE
	) as PackedScene
	definition.laps = clampi(laps, 1, 9)
	definition.preview_map = TrackMinimapBuilder.build(_session.track)
	if definition.preview_map == null:
		return ERR_INVALID_DATA
	var catalog_error := ResourceSaver.save(catalog, _session.catalog_path)
	if catalog_error == OK:
		_session.is_published = true
	return catalog_error


func mark_dirty() -> void:
	_session._set_dirty(true)
	var now := Time.get_ticks_msec()
	if now - _last_recovery_msec >= 750:
		_save_recovery()
		_last_recovery_msec = now


func clear_recovery() -> void:
	if FileAccess.file_exists(RECOVERY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVERY_PATH))


func _format_repair_summary(counts: Dictionary) -> String:
	var shortcut_count := int(counts.get("shortcuts", 0))
	var item_count := int(counts.get("items", 0))
	if shortcut_count == 0 and item_count == 0:
		return ""
	var shortcut_label := "atajo" if shortcut_count == 1 else "atajos"
	var item_label := "caja" if item_count == 1 else "cajas"
	return "%d %s y %d %s reparados" % [
		shortcut_count,
		shortcut_label,
		item_count,
		item_label,
	]


func _save_recovery() -> void:
	if _session.track == null:
		return
	var packed_scene := PackedScene.new()
	if packed_scene.pack(_session.track) == OK:
		ResourceSaver.save(packed_scene, RECOVERY_PATH)


func _catalog_contains(track_id: StringName) -> bool:
	var catalog := load(_session.catalog_path) as TrackCatalog
	return catalog != null and catalog.get_track(track_id) != null


func _make_unique_id(track_name: String) -> StringName:
	var candidate := track_name.to_lower().strip_edges().replace(" ", "_")
	var valid_characters := ""
	for character in candidate:
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_":
			valid_characters += character
	if valid_characters.is_empty():
		valid_characters = "nueva_pista"
	var unique_candidate := valid_characters
	var suffix := 2
	while (
		_catalog_contains(StringName(unique_candidate))
		or ResourceLoader.exists(
			"%s/%s.tscn" % [
				_session.new_tracks_directory,
				unique_candidate,
			]
		)
	):
		unique_candidate = "%s_%d" % [valid_characters, suffix]
		suffix += 1
	return StringName(unique_candidate)


func _create_template_curve(template_size: StringName) -> Curve3D:
	var spec: Dictionary = TEMPLATE_SPECS.get(
		template_size,
		TEMPLATE_SPECS[&"medium"]
	)
	var positions: Array[Vector3] = []
	for raw_position in spec.positions as Array:
		positions.append(raw_position as Vector3)
	var curve := Curve3D.new()
	for position in positions:
		curve.add_point(position)
	curve.closed = true
	for point_index in curve.point_count:
		var previous := positions[
			(point_index - 1 + positions.size()) % positions.size()
		]
		var next := positions[(point_index + 1) % positions.size()]
		var tangent := (next - previous) / 6.0
		curve.set_point_in(point_index, -tangent)
		curve.set_point_out(point_index, tangent)
	return curve


func get_template_metrics(template_size: StringName) -> Dictionary:
	var spec: Dictionary = TEMPLATE_SPECS.get(
		template_size,
		TEMPLATE_SPECS[&"medium"]
	)
	var metrics := _get_template_metrics_from_curve(
		_create_template_curve(template_size)
	)
	metrics.radius = float(spec.radius)
	return metrics


func _get_template_metrics_from_curve(curve: Curve3D) -> Dictionary:
	var bounds := _get_curve_bounds(curve)
	return {
		"dimensions": bounds.size,
		"environment_size": (
			bounds.size + Vector2.ONE * ENVIRONMENT_MARGIN * 2.0
		),
		"length": curve.get_baked_length(),
		"point_count": curve.point_count,
	}


func _get_curve_bounds(curve: Curve3D) -> Rect2:
	if curve == null or curve.point_count == 0:
		return Rect2()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var points := curve.get_baked_points()
	for point_index in curve.point_count:
		points.append(curve.get_point_position(point_index))
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.z)
	return Rect2(minimum, maximum - minimum)
