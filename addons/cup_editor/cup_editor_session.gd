@tool
class_name CupEditorSession
extends RefCounted

signal cup_changed(cup: CupDefinition)
signal dirty_changed(is_dirty: bool)
signal history_changed(can_undo: bool, can_redo: bool)
signal published(cup: CupDefinition)

const CATALOG_PATH := "res://progression/progression_catalog.tres"
const DRAFT_DIRECTORY := "res://progression/cups/drafts"
const CUP_DIRECTORY := "res://progression/cups"
const UNLOCK_DIRECTORY := "res://progression/unlocks"
const RECOVERY_PATH := "user://michikart_cup_recovery.tres"
const HISTORY_LIMIT := 40

var cup: CupDefinition
var resource_path := ""
var is_dirty := false
var is_published := false
var catalog: ProgressionCatalog
var last_error := ""

var _undo: Array[CupDefinition] = []
var _redo: Array[CupDefinition] = []


func _init() -> void:
	catalog = load(CATALOG_PATH) as ProgressionCatalog


func create_cup(display_name := "Nueva Copa") -> void:
	cup = CupDefinition.new()
	cup.display_name = display_name
	cup.id = _unique_id(_slugify(display_name))
	resource_path = "%s/%s.tres" % [DRAFT_DIRECTORY, cup.id]
	is_published = false
	_undo.clear(); _redo.clear()
	_set_dirty(true)
	cup_changed.emit(cup)


func load_cup(path: String) -> Error:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CupDefinition
	if loaded == null:
		last_error = "No se pudo abrir %s." % path
		return ERR_CANT_OPEN
	cup = loaded.duplicate(true) as CupDefinition
	resource_path = path
	is_published = not path.begins_with(DRAFT_DIRECTORY + "/") and path != RECOVERY_PATH
	_undo.clear(); _redo.clear()
	_set_dirty(false)
	cup_changed.emit(cup)
	return OK


func recover() -> Error:
	if not FileAccess.file_exists(RECOVERY_PATH): return ERR_FILE_NOT_FOUND
	var error := load_cup(RECOVERY_PATH)
	if error == OK:
		resource_path = "%s/%s.tres" % [DRAFT_DIRECTORY, cup.id]
		is_published = false
		_set_dirty(true)
	return error


func snapshot() -> void:
	if cup == null: return
	_undo.append(cup.duplicate(true) as CupDefinition)
	if _undo.size() > HISTORY_LIMIT: _undo.pop_front()
	_redo.clear()
	history_changed.emit(can_undo(), can_redo())


func changed() -> void:
	_set_dirty(true)
	cup_changed.emit(cup)
	autosave()


func undo() -> void:
	if not can_undo(): return
	_redo.append(cup.duplicate(true) as CupDefinition)
	cup = _undo.pop_back()
	_set_dirty(true); cup_changed.emit(cup)
	history_changed.emit(can_undo(), can_redo())


func redo() -> void:
	if not can_redo(): return
	_undo.append(cup.duplicate(true) as CupDefinition)
	cup = _redo.pop_back()
	_set_dirty(true); cup_changed.emit(cup)
	history_changed.emit(can_undo(), can_redo())


func can_undo() -> bool: return not _undo.is_empty()
func can_redo() -> bool: return not _redo.is_empty()


func save_draft() -> Error:
	if cup == null: return ERR_INVALID_DATA
	if is_published: return _save_resource(cup, resource_path)
	_ensure_directory(DRAFT_DIRECTORY)
	resource_path = "%s/%s.tres" % [DRAFT_DIRECTORY, cup.id]
	var error := _save_resource(cup, resource_path)
	if error == OK: _set_dirty(false)
	return error


func autosave() -> Error:
	if cup == null: return ERR_INVALID_DATA
	return _save_resource(cup, RECOVERY_PATH)


func validate() -> Array[CupValidationIssue]:
	return CupEditorValidator.validate(cup, catalog)


func publish_cup() -> Error:
	last_error = ""
	var issues := validate()
	if not issues.is_empty():
		last_error = issues[0].message
		return ERR_INVALID_DATA
	if catalog == null or catalog.cups == null or catalog.unlocks == null:
		last_error = "El catálogo de progresión está incompleto."
		return ERR_INVALID_DATA
	var conflict := _reward_vehicle_conflict()
	if not conflict.is_empty():
		last_error = conflict
		return ERR_ALREADY_EXISTS
	_ensure_directory(CUP_DIRECTORY); _ensure_directory(UNLOCK_DIRECTORY)
	var cup_path := "%s/%s.tres" % [CUP_DIRECTORY, cup.id]
	var paths := PackedStringArray([CATALOG_PATH, cup_path])
	for reward in cup.unlocks:
		paths.append(_unlock_path(reward))
	var backup := _capture_files(paths)
	var previous_cup := catalog.cups.get_cup(cup.id)
	for reward in cup.unlocks:
		if reward.id.is_empty(): reward.id = _reward_id(reward)
		reward.cup_id = cup.id
		var error := _save_resource(reward, _unlock_path(reward))
		if error != OK: return _rollback(backup, error)
	# Removed rewards deliberately remain in the global catalog as an archive.
	for reward in cup.unlocks:
		var existing := catalog.unlocks.get_unlock(reward.id)
		if existing == null: catalog.unlocks.unlocks.append(reward)
		else: catalog.unlocks.unlocks[catalog.unlocks.unlocks.find(existing)] = reward
	var save_error := _save_resource(cup, cup_path)
	if save_error != OK: return _rollback(backup, save_error)
	if previous_cup == null: catalog.cups.cups.append(cup)
	else:
		var index := catalog.cups.cups.find(previous_cup)
		catalog.cups.cups[index] = cup
	save_error = _save_resource(catalog, CATALOG_PATH)
	if save_error != OK: return _rollback(backup, save_error)
	resource_path = cup_path
	is_published = true
	_set_dirty(false)
	if FileAccess.file_exists(RECOVERY_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVERY_PATH))
	published.emit(cup)
	return OK


func structural_changes_from_published() -> bool:
	if not is_published or catalog == null or cup == null: return false
	var original := catalog.cups.get_cup(cup.id)
	if original == null: return false
	return (_ids(original.tracks) != _ids(cup.tracks)
		or original.scoring_table != cup.scoring_table
		or original.medal_thresholds != cup.medal_thresholds
		or _ids(original.difficulties) != _ids(cup.difficulties)
		or _ids(original.unlocks) != _ids(cup.unlocks)
		or original.prerequisite_cup_id != cup.prerequisite_cup_id
		or original.prerequisite_difficulty_id != cup.prerequisite_difficulty_id
		or original.prerequisite_medal != cup.prerequisite_medal)


func _reward_vehicle_conflict() -> String:
	var local := {}
	for reward in cup.unlocks:
		if reward == null or reward.kart_variant == null: continue
		var variant_id := reward.kart_variant.id
		if local.has(variant_id): return "El vehículo %s se repite en esta Copa." % variant_id
		local[variant_id] = reward.id
		for existing in catalog.unlocks.unlocks:
			if (existing != null and existing.kart_variant != null
					and existing.kart_variant.id == variant_id
					and existing.id != reward.id and existing.cup_id != cup.id):
				return "El vehículo %s ya está asignado a %s." % [variant_id, existing.id]
	return ""


func _reward_id(reward: UnlockDefinition) -> StringName:
	var medal_names := ["none", "bronze", "silver", "gold"]
	return StringName("%s_%s" % [cup.id, medal_names[reward.required_medal]])


func _unlock_path(reward: UnlockDefinition) -> String:
	var id := reward.id if not reward.id.is_empty() else _reward_id(reward)
	return "%s/%s.tres" % [UNLOCK_DIRECTORY, id]


func _save_resource(resource: Resource, path: String) -> Error:
	var error := ResourceSaver.save(resource, path)
	if error != OK: last_error = "No se pudo guardar %s: %s" % [path, error_string(error)]
	return error


func _capture_files(paths: PackedStringArray) -> Dictionary:
	var result := {}
	for path in paths:
		var absolute := ProjectSettings.globalize_path(path)
		result[path] = FileAccess.get_file_as_bytes(absolute) if FileAccess.file_exists(absolute) else PackedByteArray()
	return result


func _rollback(backup: Dictionary, original_error: Error) -> Error:
	for path in backup:
		var absolute := ProjectSettings.globalize_path(path)
		var bytes: PackedByteArray = backup[path]
		if bytes.is_empty():
			if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
		else:
			var file := FileAccess.open(absolute, FileAccess.WRITE)
			if file != null: file.store_buffer(bytes)
	catalog = load(CATALOG_PATH) as ProgressionCatalog
	return original_error


func _set_dirty(value: bool) -> void:
	if is_dirty == value: return
	is_dirty = value
	dirty_changed.emit(value)


func _unique_id(base: String) -> StringName:
	var candidate := base if not base.is_empty() else "new_cup"
	var suffix := 2
	while catalog != null and catalog.cups.get_cup(candidate) != null:
		candidate = "%s_%d" % [base, suffix]; suffix += 1
	return StringName(candidate)


func _slugify(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_")
	var filtered := ""
	for character in result:
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_": filtered += character
	return filtered


func _ensure_directory(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _ids(resources: Array) -> PackedStringArray:
	var result := PackedStringArray()
	for resource in resources: result.append(resource.id if resource != null else &"")
	return result
