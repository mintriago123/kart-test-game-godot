@tool
class_name TrackEditorSession
extends RefCounted

signal track_changed(track: TrackLevel)
signal route_changed
signal dirty_changed(is_dirty: bool)
signal history_changed(can_undo: bool, can_redo: bool)

const CATALOG_PATH := "res://levels/track_catalog.tres"
const NEW_TRACKS_DIRECTORY := "res://levels/tracks"
const RECOVERY_PATH := "user://coastal_karts_track_recovery.tscn"

var track: TrackLevel
var scene_path := ""
var is_dirty := false
var is_published := false
var catalog_path := CATALOG_PATH
var new_tracks_directory := NEW_TRACKS_DIRECTORY

var _undo_curves: Array[Curve3D] = []
var _redo_curves: Array[Curve3D] = []
var _last_recovery_msec := 0


func load_track(path: String) -> Error:
	if not ResourceLoader.exists(path):
		return ERR_FILE_NOT_FOUND
	var packed_scene := load(path) as PackedScene
	if packed_scene == null:
		return ERR_FILE_CORRUPT
	var loaded_track := packed_scene.instantiate() as TrackLevel
	if loaded_track == null:
		return ERR_INVALID_DATA
	_set_track(loaded_track, path)
	is_published = _catalog_contains(loaded_track.track_id)
	return OK


func create_track(template_size: StringName, track_name: String) -> void:
	var new_track := TrackLevel.new()
	new_track.name = "TrackLevel"
	new_track.display_name = track_name.strip_edges() if not track_name.strip_edges().is_empty() else "Nueva pista"
	new_track.track_id = _make_unique_id(new_track.display_name)
	new_track.start_banner_text = new_track.display_name.to_upper()
	new_track.track_theme = load("res://levels/themes/coastal_theme.tres") as TrackTheme

	var main_route := Path3D.new()
	main_route.name = "MainRoute"
	main_route.curve = _create_template_curve(template_size)
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
		marker.position = main_route.curve.sample_baked(
			main_route.curve.get_baked_length() * (0.18 + marker_index * 0.03),
			true
		)
		item_spawns.add_child(marker)
		marker.owner = new_track

	_set_track(new_track, "")
	is_published = false
	mark_dirty()


func save() -> Error:
	if track == null:
		return ERR_DOES_NOT_EXIST
	if scene_path.is_empty():
		var directory_error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(new_tracks_directory)
		)
		if directory_error != OK:
			return directory_error
		scene_path = "%s/%s.tscn" % [new_tracks_directory, track.track_id]
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(track)
	if pack_error != OK:
		return pack_error
	var save_error := ResourceSaver.save(packed_scene, scene_path)
	if save_error == OK:
		_set_dirty(false)
	return save_error


func publish(laps: int, description: String) -> Error:
	if track == null or not track.validate_track().is_empty():
		return ERR_INVALID_DATA
	var save_error := save()
	if save_error != OK:
		return save_error
	var catalog := load(catalog_path) as TrackCatalog
	if catalog == null:
		return ERR_FILE_CORRUPT
	var definition := catalog.get_track(track.track_id)
	if definition == null:
		definition = TrackDefinition.new()
		catalog.tracks.append(definition)
	definition.id = track.track_id
	definition.display_name = track.display_name
	definition.description = description
	definition.scene = ResourceLoader.load(
		scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE
	) as PackedScene
	definition.laps = clampi(laps, 1, 9)
	definition.preview_map = TrackMinimapBuilder.build(track)
	if definition.preview_map == null:
		return ERR_INVALID_DATA
	var catalog_error := ResourceSaver.save(catalog, catalog_path)
	if catalog_error == OK:
		is_published = true
	return catalog_error


func snapshot_route_for_undo() -> void:
	var route := track.get_main_route() if track != null else null
	if route == null or route.curve == null:
		return
	_undo_curves.append(route.curve.duplicate(true) as Curve3D)
	if _undo_curves.size() > 40:
		_undo_curves.pop_front()
	_redo_curves.clear()
	history_changed.emit(can_undo(), can_redo())


func undo_route() -> void:
	if not can_undo():
		return
	var route := track.get_main_route()
	_redo_curves.append(route.curve.duplicate(true) as Curve3D)
	route.curve = _undo_curves.pop_back()
	mark_dirty()
	route_changed.emit()
	history_changed.emit(can_undo(), can_redo())


func redo_route() -> void:
	if not can_redo():
		return
	var route := track.get_main_route()
	_undo_curves.append(route.curve.duplicate(true) as Curve3D)
	route.curve = _redo_curves.pop_back()
	mark_dirty()
	route_changed.emit()
	history_changed.emit(can_undo(), can_redo())


func can_undo() -> bool:
	return not _undo_curves.is_empty()


func can_redo() -> bool:
	return not _redo_curves.is_empty()


func mark_dirty() -> void:
	_set_dirty(true)
	var now := Time.get_ticks_msec()
	if now - _last_recovery_msec >= 750:
		_save_recovery()
		_last_recovery_msec = now


func clear_recovery() -> void:
	if FileAccess.file_exists(RECOVERY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVERY_PATH))


func _set_track(new_track: TrackLevel, path: String) -> void:
	track = new_track
	scene_path = path
	_undo_curves.clear()
	_redo_curves.clear()
	_set_dirty(false)
	track_changed.emit(track)
	history_changed.emit(false, false)


func _set_dirty(value: bool) -> void:
	if is_dirty == value:
		return
	is_dirty = value
	dirty_changed.emit(is_dirty)


func _save_recovery() -> void:
	if track == null:
		return
	var packed_scene := PackedScene.new()
	if packed_scene.pack(track) == OK:
		ResourceSaver.save(packed_scene, RECOVERY_PATH)


func _catalog_contains(track_id: StringName) -> bool:
	var catalog := load(catalog_path) as TrackCatalog
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
	while _catalog_contains(StringName(unique_candidate)) or ResourceLoader.exists(
		"%s/%s.tscn" % [new_tracks_directory, unique_candidate]
	):
		unique_candidate = "%s_%d" % [valid_characters, suffix]
		suffix += 1
	return StringName(unique_candidate)


func _create_template_curve(template_size: StringName) -> Curve3D:
	var scale_factor := {
		&"small": 42.0,
		&"medium": 62.0,
		&"large": 84.0,
	}.get(template_size, 62.0) as float
	var positions: Array[Vector3] = [
		Vector3(0.0, 0.25, scale_factor * 0.72),
		Vector3(scale_factor * 0.62, 0.25, scale_factor * 0.55),
		Vector3(scale_factor, 0.5, 0.0),
		Vector3(scale_factor * 0.7, 0.75, -scale_factor * 0.62),
		Vector3(0.0, 0.25, -scale_factor * 0.78),
		Vector3(-scale_factor * 0.7, 0.5, -scale_factor * 0.62),
		Vector3(-scale_factor, 0.75, 0.0),
		Vector3(-scale_factor * 0.62, 0.25, scale_factor * 0.55),
	]
	var curve := Curve3D.new()
	for position in positions:
		curve.add_point(position)
	curve.closed = true
	for point_index in curve.point_count:
		var previous := positions[(point_index - 1 + positions.size()) % positions.size()]
		var next := positions[(point_index + 1) % positions.size()]
		var tangent := (next - previous) / 6.0
		curve.set_point_in(point_index, -tangent)
		curve.set_point_out(point_index, tangent)
	return curve
