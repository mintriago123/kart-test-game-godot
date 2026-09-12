@tool
class_name TrackEditorSession
extends RefCounted

signal track_changed(track: TrackLevel)
signal route_changed
signal dirty_changed(is_dirty: bool)
signal history_changed(can_undo: bool, can_redo: bool)
signal metadata_changed

const PersistenceService := preload(
	"res://addons/track_editor/track_editor_persistence.gd"
)
const HistoryService := preload(
	"res://addons/track_editor/track_editor_history.gd"
)
const AnchorService := preload(
	"res://addons/track_editor/track_anchor_service.gd"
)
const EntityService := preload(
	"res://addons/track_editor/track_editor_entity_service.gd"
)
const CATALOG_PATH := PersistenceService.CATALOG_PATH
const NEW_TRACKS_DIRECTORY := PersistenceService.NEW_TRACKS_DIRECTORY
const RECOVERY_PATH := PersistenceService.RECOVERY_PATH
const RECOVERY_META_PATH := PersistenceService.RECOVERY_META_PATH
const META_ANCHOR_PROGRESS := AnchorService.META_ANCHOR_PROGRESS
const META_ANCHOR_LATERAL := AnchorService.META_ANCHOR_LATERAL
const META_ANCHOR_HEIGHT := AnchorService.META_ANCHOR_HEIGHT
const META_ANCHOR_ROTATION := AnchorService.META_ANCHOR_ROTATION
const META_PROP_BASE_SCALE := EntityService.META_PROP_BASE_SCALE
const META_PROP_SCALE_MULTIPLIER := EntityService.META_PROP_SCALE_MULTIPLIER
const META_ASSET_ID := EntityService.META_ASSET_ID
const MIN_PROP_SCALE_MULTIPLIER := EntityService.MIN_PROP_SCALE_MULTIPLIER
const MAX_PROP_SCALE_MULTIPLIER := EntityService.MAX_PROP_SCALE_MULTIPLIER
const HISTORY_LIMIT := HistoryService.HISTORY_LIMIT

var track: TrackLevel
var scene_path := ""
var is_dirty := false
var is_published := false
var catalog_path := CATALOG_PATH
var new_tracks_directory := NEW_TRACKS_DIRECTORY
var last_repair_summary := ""
var last_persistence_error := ""
var laps := 3
var description := ""

var _persistence: RefCounted
var _history: RefCounted
var _anchors: RefCounted
var _entities: RefCounted
var _metadata_snapshot_active := false
var _observed_scene_path := ""
var _observed_scene_signature: Dictionary = {}
var _observed_catalog_path := ""
var _observed_catalog_signature: Dictionary = {}
var _file_signature_cache: Dictionary = {}


func _init() -> void:
	_persistence = PersistenceService.new(self)
	_history = HistoryService.new(self)
	_anchors = AnchorService.new(self)
	_entities = EntityService.new(self)


func load_track(path: String) -> Error:
	return _persistence.load_track(path)


func create_track(template_size: StringName, track_name: String) -> void:
	_persistence.create_track(template_size, track_name)


func get_template_metrics(template_size: StringName) -> Dictionary:
	return _persistence.get_template_metrics(template_size)


func save() -> Error:
	finish_metadata_edit()
	return _persistence.save()


func publish(laps: int, description: String) -> Error:
	return _persistence.publish(laps, description)


func inspect_track() -> Array[TrackValidationIssue]:
	if track == null:
		return []
	return track.inspect_track()


func has_blocking_validation_issues() -> bool:
	for issue in inspect_track():
		if issue.is_blocking():
			return true
	return false


func set_editor_metadata(new_laps: int, new_description: String) -> bool:
	var normalized_laps := clampi(new_laps, 1, 9)
	var normalized_description := new_description
	if laps == normalized_laps and description == normalized_description:
		return false
	laps = normalized_laps
	description = normalized_description
	if track != null:
		track.track_editor_laps = laps
		track.track_editor_description = description
	metadata_changed.emit()
	return true


func set_display_name(value: String) -> bool:
	if track == null or track.display_name == value:
		return false
	track.display_name = value
	track.start_banner_text = value.to_upper()
	metadata_changed.emit()
	return true


func snapshot_metadata_for_undo() -> void:
	if _metadata_snapshot_active:
		return
	_metadata_snapshot_active = true
	snapshot_track_for_undo()


func finish_metadata_edit() -> void:
	_metadata_snapshot_active = false


func snapshot_route_for_undo(selection: RefCounted = null) -> void:
	_history.snapshot_track(_scope_for_selection(selection))


func snapshot_track_for_undo() -> void:
	_history.snapshot_track()


func _scope_for_selection(selection: RefCounted) -> StringName:
	# Map-view drags only ever touch one kind of entity at a time, so the
	# pre-drag snapshot only needs to capture that entity's own data instead
	# of re-packing every prop/shortcut/surface zone on the track. Every
	# other call site (property panels, add/remove, publish) keeps calling
	# snapshot_track_for_undo() with no scope, so it is unaffected.
	var typed := selection as TrackEditorSelection
	if typed == null:
		return &"all"
	match typed.kind:
		TrackEditorSelection.Kind.ROUTE_POINT:
			return &"route"
		TrackEditorSelection.Kind.ITEM:
			return &"items"
		TrackEditorSelection.Kind.PROP:
			return &"props"
		TrackEditorSelection.Kind.SURFACE:
			return &"surface"
		_:
			return &"shortcuts" if typed.is_shortcut_control() else &"all"


func discard_latest_snapshot() -> void:
	_history.discard_latest_snapshot()


func undo_route() -> void:
	_history.undo()


func redo_route() -> void:
	_history.redo()


func can_undo() -> bool:
	return _history.can_undo()


func can_redo() -> bool:
	return _history.can_redo()


func recalculate_route_dependents() -> void:
	_anchors.recalculate_route_dependents()


func configure_shortcut_anchor(
	shortcut: TrackShortcut,
	preserve_curve := false
) -> bool:
	return _anchors.configure_shortcut_anchor(shortcut, preserve_curve)


func anchor_item_spawn(marker: Marker3D, progress: float) -> void:
	_anchors.anchor_item_spawn(marker, progress)


func anchor_prop(
	prop: Node3D,
	progress: float,
	lateral_offset: float,
	height_offset: float,
	rotation_degrees_y: float
) -> void:
	_anchors.anchor_prop(
		prop,
		progress,
		lateral_offset,
		height_offset,
		rotation_degrees_y
	)


func get_route_progress_for_control_point(point_index: int) -> float:
	return _anchors.get_route_progress_for_control_point(point_index)


func get_route_anchor_for_position(track_position: Vector3) -> Dictionary:
	return _anchors.get_route_anchor_for_position(track_position)


func get_selected_node(selection: RefCounted) -> Node3D:
	return _entities.get_node(selection)


func move_entity(
	selection: RefCounted,
	track_position: Vector3
) -> bool:
	return _entities.move_to_track_position(selection, track_position)


func update_route_point(index: int, position: Vector3) -> bool:
	return _entities.update_route_point(index, position)


func update_item_progress(
	selection: RefCounted,
	progress: float
) -> bool:
	return _entities.update_item_progress(selection, progress)


func update_prop_anchor(
	selection: RefCounted,
	progress: float,
	lateral: float,
	height: float,
	rotation_degrees_y: float,
	scale_multiplier: float = NAN
) -> bool:
	return _entities.update_prop_anchor(
		selection,
		progress,
		lateral,
		height,
		rotation_degrees_y,
		scale_multiplier
	)


func update_prop_scale(
	selection: RefCounted,
	scale_multiplier: float
) -> bool:
	return _entities.update_prop_scale(selection, scale_multiplier)


func initialize_prop_scale(
	prop: Node3D,
	base_scale: Vector3,
	scale_multiplier: float
) -> bool:
	return _entities.initialize_prop_scale(
		prop,
		base_scale,
		scale_multiplier
	)


func update_shortcut_midpoint(
	selection: RefCounted,
	longitudinal: float,
	lateral: float,
	height: float
) -> bool:
	return _entities.update_shortcut_midpoint(
		selection,
		longitudinal,
		lateral,
		height
	)


func fit_shortcut_midpoint(
	selection: RefCounted,
	longitudinal: float,
	lateral: float,
	height: float
) -> Dictionary:
	return _entities.fit_shortcut_midpoint(
		selection,
		longitudinal,
		lateral,
		height
	)


func fit_shortcut_shape(
	selection: RefCounted,
	requested_shape: Variant,
	exit_progress: float = NAN,
	midpoint_longitudinal: float = NAN,
	midpoint_lateral: float = NAN,
	midpoint_height: float = NAN,
	entry_handle: float = NAN,
	exit_handle: float = NAN,
	midpoint_in_handle: float = NAN,
	midpoint_out_handle: float = NAN
) -> Dictionary:
	if requested_shape is Dictionary:
		return _entities.fit_shortcut_shape(selection, requested_shape)
	return _entities.fit_shortcut_shape(selection, {
		"entry_progress": float(requested_shape),
		"exit_progress": exit_progress,
		"midpoint_longitudinal": midpoint_longitudinal,
		"midpoint_lateral": midpoint_lateral,
		"midpoint_height": midpoint_height,
		"entry_handle": entry_handle,
		"exit_handle": exit_handle,
		"midpoint_in_handle": midpoint_in_handle,
		"midpoint_out_handle": midpoint_out_handle,
	})


func reset_shortcut_safe(selection: RefCounted) -> Dictionary:
	return _entities.reset_shortcut_safe(selection)


func rename_shortcut(selection: RefCounted, display_name: String) -> bool:
	return _entities.rename_shortcut(selection, display_name)


func set_prop_asset_id(prop: Node3D, asset_id: StringName) -> void:
	_entities.set_prop_asset_id(prop, asset_id)


func get_prop_asset_entry(prop: Node3D) -> TrackAssetEntry:
	return _entities.get_prop_asset_entry(prop)


func restore_prop_recommended_scale(selection: RefCounted) -> bool:
	return _entities.restore_prop_recommended_scale(selection)


func calibrate_known_props() -> Dictionary:
	return _entities.calibrate_known_props()


func duplicate_entity(selection: RefCounted) -> RefCounted:
	return _entities.duplicate(selection)


func delete_entity(selection: RefCounted) -> bool:
	return _entities.delete(selection)


func create_surface_zone(data: Dictionary) -> TrackSurfaceZone:
	if track == null:
		return null
	var root := track.get_node_or_null("Surfaces") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "Surfaces"
		track.add_child(root)
		root.owner = track
	var zone := TrackSurfaceZone.new()
	var sequence := root.get_child_count() + 1
	zone.name = _get_unique_surface_name(root, sequence)
	zone.id = StringName("surface_zone_%d" % sequence)
	_apply_surface_zone_data(zone, data)
	root.add_child(zone)
	zone.owner = track
	return zone


func update_surface_zone(selection: RefCounted, data: Dictionary) -> bool:
	var zone := get_surface_zone(selection)
	if zone == null:
		return false
	var before := _surface_zone_state(zone)
	_apply_surface_zone_data(zone, data)
	return before != _surface_zone_state(zone)


func delete_surface_zone(selection: RefCounted) -> bool:
	var zone := get_surface_zone(selection)
	if zone == null or zone.get_parent() == null:
		return false
	zone.get_parent().remove_child(zone)
	zone.free()
	return true


func get_surface_zone(selection: RefCounted) -> TrackSurfaceZone:
	if track == null or selection == null or selection.kind != TrackEditorSelection.Kind.SURFACE:
		return null
	return track.get_node_or_null(selection.node_path) as TrackSurfaceZone


func _get_unique_surface_name(root: Node, sequence: int) -> StringName:
	var base := "SurfaceZone%d" % sequence
	var candidate := base
	var suffix := 2
	while root.get_node_or_null(NodePath(candidate)) != null:
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return StringName(candidate)


func _apply_surface_zone_data(zone: TrackSurfaceZone, data: Dictionary) -> void:
	var surface_id := StringName(str(data.get("surface_id", "asphalt")))
	zone.surface = _load_surface_definition(
		surface_id,
		str(data.get("surface_path", ""))
	)
	zone.path_kind = int(data.get("path_kind", TrackSurfaceZone.PathKind.MAIN))
	zone.shortcut_id = int(data.get("shortcut_id", -1))
	zone.start_progress = float(data.get("start_progress", 0.0))
	zone.end_progress = float(data.get("end_progress", 0.1))
	zone.lateral_offset = float(data.get("lateral_offset", 0.0))
	zone.width = float(data.get("width", 3.0))
	zone.surface_priority = clampi(
		int(data.get("surface_priority", data.get("priority", 0))),
		0,
		100
	)


func _load_surface_definition(
	surface_id: StringName,
	surface_path := ""
) -> SurfaceDefinition:
	var path := surface_path
	if path.is_empty():
		path = "res://levels/surfaces/%s.tres" % surface_id
	if path.is_empty():
		return null
	return ResourceLoader.load(path, "SurfaceDefinition") as SurfaceDefinition


func _surface_zone_state(zone: TrackSurfaceZone) -> Dictionary:
	return {
		"surface": zone.surface,
		"path_kind": zone.path_kind,
		"shortcut_id": zone.shortcut_id,
		"start_progress": zone.start_progress,
		"end_progress": zone.end_progress,
		"lateral_offset": zone.lateral_offset,
		"width": zone.width,
		"surface_priority": zone.surface_priority,
	}


func migrate_legacy_surface_priorities() -> Dictionary:
	var migrated := 0
	if track == null:
		return {"surface_priorities": migrated}
	var needs_snapshot := false
	for zone in track.get_surface_zones():
		if zone.surface_priority == 0 and not is_zero_approx(zone.priority):
			needs_snapshot = true
			break
	if needs_snapshot and not _history.can_undo():
		snapshot_track_for_undo()
	for zone in track.get_surface_zones():
		if zone.migrate_legacy_surface_priority():
			migrated += 1
	return {"surface_priorities": migrated}


func migrate_legacy_anchors() -> Dictionary:
	return _anchors.migrate_legacy_anchors()


func mark_dirty() -> void:
	_persistence.mark_dirty()


func clear_recovery() -> void:
	_persistence.clear_recovery()


func has_recovery() -> bool:
	return _persistence.has_recovery()


func get_recovery_info() -> Dictionary:
	return _persistence.get_recovery_info()


func load_recovery() -> Error:
	return _persistence.load_recovery()


func get_external_changes() -> Dictionary:
	var scene_changed := false
	if not _observed_scene_path.is_empty() and _observed_scene_path == scene_path:
		scene_changed = _signature_content_changed(
			_file_signature(scene_path),
			true,
			_observed_scene_signature
		)
	var catalog_changed := false
	if not _observed_catalog_path.is_empty() and _observed_catalog_path == catalog_path:
		catalog_changed = _signature_content_changed(
			_file_signature(catalog_path),
			true,
			_observed_catalog_signature
		)
	return {
		"scene": scene_changed,
		"catalog": catalog_changed,
	}


func get_external_change_summary() -> Dictionary:
	var scene_signature := _current_signature_for_summary(
		scene_path,
		_observed_scene_path == scene_path
	)
	var catalog_signature := _current_signature_for_summary(
		catalog_path,
		_observed_catalog_path == catalog_path
	)
	var scene_changed := _signature_content_changed(
		scene_signature,
		_observed_scene_path == scene_path,
		_observed_scene_signature
	)
	var catalog_changed := _signature_content_changed(
		catalog_signature,
		_observed_catalog_path == catalog_path,
		_observed_catalog_signature
	)
	return {
		"scene": {
			"changed": scene_changed,
			"path": scene_path,
			"observed": _observed_scene_signature.duplicate(true),
			"current": scene_signature,
		},
		"catalog": {
			"changed": catalog_changed,
			"path": catalog_path,
			"observed": _observed_catalog_signature.duplicate(true),
			"current": catalog_signature,
		},
	}


func acknowledge_external_changes(
	acknowledge_scene := false,
	acknowledge_catalog := false
) -> void:
	if acknowledge_scene:
		_observed_scene_path = scene_path
		_observed_scene_signature = _file_signature(scene_path)
	if acknowledge_catalog:
		_observed_catalog_path = catalog_path
		_observed_catalog_signature = _file_signature(catalog_path)


func _set_track(new_track: TrackLevel, path: String) -> void:
	track = new_track
	scene_path = path
	laps = 3
	description = ""
	_metadata_snapshot_active = false
	last_repair_summary = ""
	_observed_scene_path = ""
	_observed_scene_signature = {}
	_observed_catalog_path = ""
	_observed_catalog_signature = {}
	_file_signature_cache.clear()
	_history.reset()
	_set_dirty(false)
	track_changed.emit(track)
	history_changed.emit(false, false)


func _set_dirty(value: bool) -> void:
	if is_dirty == value:
		return
	is_dirty = value
	dirty_changed.emit(is_dirty)


func _set_route_anchor_metadata(
	node: Node3D,
	progress: float,
	lateral_offset: float,
	height_offset: float,
	rotation_degrees_y: float
) -> void:
	_anchors.set_route_anchor_metadata(
		node,
		progress,
		lateral_offset,
		height_offset,
		rotation_degrees_y
	)


func _observe_external_files() -> void:
	_observed_scene_path = scene_path
	_observed_scene_signature = _file_signature(scene_path)
	_observed_catalog_path = catalog_path
	_observed_catalog_signature = _file_signature(catalog_path)


func _file_signature(path: String) -> Dictionary:
	var metadata := _file_metadata(path)
	var cached: Dictionary = _file_signature_cache.get(path, {})
	if not cached.is_empty() and _metadata_matches(cached, metadata):
		return cached.duplicate(true)
	if not bool(metadata.get("exists", false)):
		_file_signature_cache[path] = metadata.duplicate(true)
		return metadata
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var unavailable := {"exists": false, "modified": 0, "size": 0}
		_file_signature_cache[path] = unavailable
		return unavailable
	var contents := file.get_buffer(file.get_length())
	file.close()
	var signature := metadata.duplicate(true)
	signature["hash"] = hash(contents)
	_file_signature_cache[path] = signature
	return signature.duplicate(true)


func _current_signature_for_summary(
	path: String,
	is_observed_path: bool
) -> Dictionary:
	if is_observed_path and not path.is_empty():
		return _file_signature(path)
	return _file_metadata(path)


func _file_metadata(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"exists": false, "modified": 0, "size": 0}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": false, "modified": 0, "size": 0}
	var size := file.get_length()
	file.close()
	return {
		"exists": true,
		"modified": FileAccess.get_modified_time(
			ProjectSettings.globalize_path(path)
		),
		"size": size,
	}


func _metadata_matches(signature: Dictionary, metadata: Dictionary) -> bool:
	return (
		bool(signature.get("exists", false)) == bool(metadata.get("exists", false))
		and int(signature.get("modified", 0)) == int(metadata.get("modified", 0))
		and int(signature.get("size", 0)) == int(metadata.get("size", 0))
	)


func _signature_content_changed(
	current: Dictionary,
	observed_path_matches: bool,
	observed: Dictionary
) -> bool:
	if not observed_path_matches or observed.is_empty():
		return false
	if bool(current.get("exists", false)) != bool(observed.get("exists", false)):
		return true
	if not bool(current.get("exists", false)):
		return false
	if int(current.get("size", 0)) != int(observed.get("size", 0)):
		return true
	return current.get("hash", null) != observed.get("hash", null)
