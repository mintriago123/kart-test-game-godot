@tool
class_name TrackEditorSession
extends RefCounted

signal track_changed(track: TrackLevel)
signal route_changed
signal dirty_changed(is_dirty: bool)
signal history_changed(can_undo: bool, can_redo: bool)

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
const META_ANCHOR_PROGRESS := AnchorService.META_ANCHOR_PROGRESS
const META_ANCHOR_LATERAL := AnchorService.META_ANCHOR_LATERAL
const META_ANCHOR_HEIGHT := AnchorService.META_ANCHOR_HEIGHT
const META_ANCHOR_ROTATION := AnchorService.META_ANCHOR_ROTATION
const HISTORY_LIMIT := HistoryService.HISTORY_LIMIT

var track: TrackLevel
var scene_path := ""
var is_dirty := false
var is_published := false
var catalog_path := CATALOG_PATH
var new_tracks_directory := NEW_TRACKS_DIRECTORY
var last_repair_summary := ""

var _persistence: RefCounted
var _history: RefCounted
var _anchors: RefCounted
var _entities: RefCounted


func _init() -> void:
	_persistence = PersistenceService.new(self)
	_history = HistoryService.new(self)
	_anchors = AnchorService.new(self)
	_entities = EntityService.new(self)


func load_track(path: String) -> Error:
	return _persistence.load_track(path)


func create_track(template_size: StringName, track_name: String) -> void:
	_persistence.create_track(template_size, track_name)


func save() -> Error:
	return _persistence.save()


func publish(laps: int, description: String) -> Error:
	return _persistence.publish(laps, description)


func snapshot_route_for_undo() -> void:
	snapshot_track_for_undo()


func snapshot_track_for_undo() -> void:
	_history.snapshot_track()


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
	rotation_degrees_y: float
) -> bool:
	return _entities.update_prop_anchor(
		selection,
		progress,
		lateral,
		height,
		rotation_degrees_y
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


func duplicate_entity(selection: RefCounted) -> RefCounted:
	return _entities.duplicate(selection)


func delete_entity(selection: RefCounted) -> bool:
	return _entities.delete(selection)


func migrate_legacy_anchors() -> Dictionary:
	return _anchors.migrate_legacy_anchors()


func mark_dirty() -> void:
	_persistence.mark_dirty()


func clear_recovery() -> void:
	_persistence.clear_recovery()


func _set_track(new_track: TrackLevel, path: String) -> void:
	track = new_track
	scene_path = path
	last_repair_summary = ""
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
