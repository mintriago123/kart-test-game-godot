@tool
class_name TrackEditorPersistence
extends RefCounted

const CATALOG_PATH := "res://levels/track_catalog.tres"
const NEW_TRACKS_DIRECTORY := "res://levels/tracks"
const RECOVERY_PATH := "user://coastal_karts_track_recovery.tscn"
const RECOVERY_META_PATH := "user://coastal_karts_track_recovery.cfg"
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
	_cleanup_recovery_artifacts()


func _clear_error() -> void:
	_session.last_persistence_error = ""


func _fail(error: Error, message: String) -> Error:
	_session.last_persistence_error = "%s (%s)." % [
		message,
		error_string(error),
	]
	return error


func _publish_failure(
	error: Error,
	reason: String,
	previous_scene: PackedScene,
	had_previous_scene: bool
) -> Error:
	var restore_error := _restore_scene_after_publish(
		previous_scene,
		had_previous_scene
	)
	var message := reason
	if restore_error != OK:
		message += " No se pudo recuperar la escena anterior: %s" % error_string(
			restore_error
		)
	return _fail(error, message)


func load_track(path: String) -> Error:
	_clear_error()
	if not ResourceLoader.exists(path):
		return _fail(ERR_FILE_NOT_FOUND, "No se encontró la escena de la pista")
	var packed_scene := ResourceLoader.load(
		path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE
	) as PackedScene
	if packed_scene == null:
		return _fail(ERR_FILE_CORRUPT, "La escena de la pista está dañada")
	var loaded_track := packed_scene.instantiate() as TrackLevel
	if loaded_track == null:
		return _fail(ERR_INVALID_DATA, "La escena no contiene un TrackLevel válido")
	_session._set_track(loaded_track, path)
	var catalog_definition := _get_catalog_definition(loaded_track.track_id)
	_session.is_published = catalog_definition != null
	var loaded_laps := loaded_track.track_editor_laps
	var loaded_description := loaded_track.track_editor_description
	if loaded_laps <= 0 and catalog_definition != null:
		loaded_laps = catalog_definition.laps
	if loaded_description.is_empty() and catalog_definition != null:
		loaded_description = catalog_definition.description
	_session.set_editor_metadata(
		loaded_laps if loaded_laps > 0 else 3,
		loaded_description
	)
	var repair_counts: Dictionary = _session.migrate_legacy_anchors()
	var surface_repair_counts: Dictionary = _session.migrate_legacy_surface_priorities()
	for repair_key in surface_repair_counts:
		repair_counts[repair_key] = surface_repair_counts[repair_key]
	_session.last_repair_summary = _format_repair_summary(repair_counts)
	if not _session.last_repair_summary.is_empty():
		_session._set_dirty(true)
		_session.route_changed.emit()
	_session._observe_external_files()
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

	var surfaces := Node3D.new()
	surfaces.name = "Surfaces"
	new_track.add_child(surfaces)
	surfaces.owner = new_track

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
	_session.set_editor_metadata(3, "")
	_session._observe_external_files()
	mark_dirty()


func save() -> Error:
	_clear_error()
	if _session.track == null:
		return _fail(ERR_DOES_NOT_EXIST, "No hay una pista cargada para guardar")
	if _session.scene_path.is_empty():
		var directory_error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(_session.new_tracks_directory)
		)
		if directory_error != OK:
			return _fail(
				directory_error,
				"No se pudo preparar la carpeta de la escena"
			)
		_session.scene_path = "%s/%s.tscn" % [
			_session.new_tracks_directory,
			_session.track.track_id,
		]
	var packed_scene := PackedScene.new()
	_session.track.track_editor_laps = _session.laps
	_session.track.track_editor_description = _session.description
	var pack_error := packed_scene.pack(_session.track)
	if pack_error != OK:
		return _fail(pack_error, "No se pudo preparar la escena para guardar")
	var save_error := _save_resource_atomically(packed_scene, _session.scene_path)
	if save_error != OK:
		return _fail(
			save_error,
			"La escritura atómica de la escena falló"
		)
	if save_error == OK:
		_session._set_dirty(false)
		_session._observe_external_files()
	return save_error


func publish(laps: int, description: String) -> Error:
	_clear_error()
	if _session.track == null or _session.has_blocking_validation_issues():
		return _fail(
			ERR_INVALID_DATA,
			"La validación bloquea la publicación; no se escribieron archivos"
		)
	_session.set_editor_metadata(laps, description)
	var previous_scene := (
		ResourceLoader.load(
			_session.scene_path,
			"PackedScene",
			ResourceLoader.CACHE_MODE_REPLACE
		) as PackedScene
		if not _session.scene_path.is_empty()
		and FileAccess.file_exists(_session.scene_path)
		else null
	)
	var had_previous_scene: bool = (
		not _session.scene_path.is_empty()
		and FileAccess.file_exists(_session.scene_path)
	)
	var save_error := save()
	if save_error != OK:
		return save_error
	var catalog := _load_catalog()
	if catalog == null:
		var catalog_reason := (
			"El catálogo está ausente"
			if not FileAccess.file_exists(_session.catalog_path)
			else "El catálogo no se puede cargar"
		)
		return _publish_failure(
			ERR_FILE_CORRUPT,
			catalog_reason,
			previous_scene,
			had_previous_scene
		)
	var definition := catalog.get_track(_session.track.track_id)
	if definition == null:
		definition = TrackDefinition.new()
		catalog.tracks.append(definition)
	definition.id = _session.track.track_id
	definition.display_name = _session.track.display_name
	definition.description = description
	definition.origin = TrackDefinition.Origin.CUSTOM
	definition.scene = ResourceLoader.load(
		_session.scene_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE
	) as PackedScene
	if definition.scene == null:
		return _publish_failure(
			ERR_FILE_CORRUPT,
			"La escena publicada no se puede volver a cargar",
			previous_scene,
			had_previous_scene
		)
	definition.laps = clampi(laps, 1, 9)
	definition.preview_map = TrackMinimapBuilder.build(_session.track)
	if definition.preview_map == null:
		return _publish_failure(
			ERR_INVALID_DATA,
			"No se pudo generar el plano de preview para el catálogo",
			previous_scene,
			had_previous_scene
		)
	definition.length_km = snappedf(definition.preview_map.length_meters / 1000.0, 0.1)
	definition.shortcut_count = definition.preview_map.shortcut_count
	definition.preview_color = (
		_session.track.track_theme.terrain_color
		if _session.track.track_theme != null
		else Color("#167f93")
	)
	definition.music = _session.track.track_music
	definition.difficulty = _session.track.difficulty
	var catalog_error := _save_resource_atomically(catalog, _session.catalog_path)
	if catalog_error == OK:
		_session.is_published = true
		_session._observe_external_files()
		return OK
	return _publish_failure(
		catalog_error,
		"La escritura atómica del catálogo falló",
		previous_scene,
		had_previous_scene
	)


func mark_dirty() -> void:
	_session._set_dirty(true)
	var now := Time.get_ticks_msec()
	if now - _last_recovery_msec >= 750:
		_save_recovery()
		_last_recovery_msec = now


func clear_recovery() -> void:
	for recovery_path in [RECOVERY_PATH, RECOVERY_META_PATH]:
		if FileAccess.file_exists(recovery_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(recovery_path))
	_cleanup_recovery_artifacts()


func has_recovery() -> bool:
	return FileAccess.file_exists(RECOVERY_PATH)


func get_recovery_info() -> Dictionary:
	var info := {
		"scene_path": "",
		"track_id": "",
		"laps": 3,
		"description": "",
	}
	var config := ConfigFile.new()
	if config.load(RECOVERY_META_PATH) == OK:
		info.scene_path = str(config.get_value("recovery", "scene_path", ""))
		info.track_id = str(config.get_value("recovery", "track_id", ""))
		info.laps = clampi(int(config.get_value("recovery", "laps", 3)), 1, 9)
		info.description = str(config.get_value("recovery", "description", ""))
	return info


func load_recovery() -> Error:
	_clear_error()
	if not FileAccess.file_exists(RECOVERY_PATH):
		return _fail(ERR_FILE_NOT_FOUND, "No se encontró la escena de recuperación")
	var packed_scene := ResourceLoader.load(
		RECOVERY_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_REPLACE
	) as PackedScene
	if packed_scene == null:
		return _fail(ERR_FILE_CORRUPT, "La escena de recuperación está dañada")
	var recovered_track := packed_scene.instantiate() as TrackLevel
	if recovered_track == null:
		return _fail(
			ERR_INVALID_DATA,
			"La recuperación no contiene un TrackLevel válido"
		)
	var info := get_recovery_info()
	_session._set_track(recovered_track, str(info.scene_path))
	var recovery_laps := int(info.laps)
	var recovery_description := str(info.description)
	if recovery_laps <= 0:
		recovery_laps = recovered_track.track_editor_laps
	if recovery_description.is_empty():
		recovery_description = recovered_track.track_editor_description
	_session.set_editor_metadata(
		recovery_laps if recovery_laps > 0 else 3,
		recovery_description
	)
	var repair_counts: Dictionary = _session.migrate_legacy_anchors()
	var surface_repair_counts: Dictionary = _session.migrate_legacy_surface_priorities()
	for repair_key in surface_repair_counts:
		repair_counts[repair_key] = surface_repair_counts[repair_key]
	_session.last_repair_summary = _format_repair_summary(repair_counts)
	_session.is_published = _catalog_contains(recovered_track.track_id)
	_session._set_dirty(true)
	return OK


func _format_repair_summary(counts: Dictionary) -> String:
	var shortcut_count := int(counts.get("shortcuts", 0))
	var item_count := int(counts.get("items", 0))
	var surface_count := int(counts.get("surface_priorities", 0))
	if shortcut_count == 0 and item_count == 0 and surface_count == 0:
		return ""
	var repaired_parts := PackedStringArray()
	if shortcut_count > 0:
		repaired_parts.append(
			"%d %s" % [shortcut_count, "atajo" if shortcut_count == 1 else "atajos"]
		)
	if item_count > 0:
		repaired_parts.append(
			"%d %s" % [item_count, "caja" if item_count == 1 else "cajas"]
		)
	if surface_count > 0:
		repaired_parts.append(
			"%d %s" % [
				surface_count,
				"prioridad de superficie migrada"
				if surface_count == 1
				else "prioridades de superficie migradas",
			]
		)
	var total_repairs := shortcut_count + item_count + surface_count
	var repair_suffix := "reparados"
	if total_repairs == 1:
		repair_suffix = "reparada" if surface_count == 1 or item_count == 1 else "reparado"
	return "%s %s" % [
		" y ".join(repaired_parts),
		repair_suffix,
	]


func _save_recovery() -> void:
	if _session.track == null:
		return
	_session.track.track_editor_laps = _session.laps
	_session.track.track_editor_description = _session.description
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(_session.track)
	if pack_error != OK:
		push_warning(
			"No se pudo preparar la escena de recuperación: %s"
			% error_string(pack_error)
		)
		return
	var save_error := _save_resource_atomically(packed_scene, RECOVERY_PATH)
	if save_error != OK:
		push_warning(
			"No se pudo guardar la escena de recuperación: %s"
			% error_string(save_error)
		)
		return
	var config := ConfigFile.new()
	config.set_value("recovery", "scene_path", _session.scene_path)
	config.set_value("recovery", "track_id", _session.track.track_id)
	config.set_value("recovery", "laps", _session.laps)
	config.set_value("recovery", "description", _session.description)
	var config_temp_path := "%s.tmp.%d.cfg" % [
		RECOVERY_META_PATH.trim_suffix(".cfg"),
		Time.get_ticks_usec(),
	]
	var config_error := config.save(config_temp_path)
	if config_error == OK:
		config_error = _replace_file_atomically(
			config_temp_path,
			RECOVERY_META_PATH
		)
	else:
		_cleanup_atomic_artifacts(RECOVERY_META_PATH)
	if config_error != OK:
		push_warning(
			"No se pudo guardar la metadata de recuperación: %s"
			% error_string(config_error)
		)


func _get_catalog_definition(track_id: StringName) -> TrackDefinition:
	var catalog := _load_catalog()
	return catalog.get_track(track_id) if catalog != null else null


func _load_catalog() -> TrackCatalog:
	if not FileAccess.file_exists(_session.catalog_path):
		return null
	return ResourceLoader.load(
		_session.catalog_path,
		"TrackCatalog",
		ResourceLoader.CACHE_MODE_REPLACE
	) as TrackCatalog


func _restore_scene_after_publish(
	previous_scene: PackedScene,
	had_previous_scene: bool
) -> Error:
	_session._set_dirty(true)
	var restore_error := OK
	if previous_scene != null:
		restore_error = _save_resource_atomically(
			previous_scene,
			_session.scene_path
		)
	elif not had_previous_scene and FileAccess.file_exists(_session.scene_path):
		restore_error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(_session.scene_path)
		)
	_cleanup_atomic_artifacts(_session.scene_path)
	_session._observe_external_files()
	return restore_error


func _save_resource_atomically(resource: Resource, path: String) -> Error:
	_cleanup_atomic_artifacts(path)
	var extension := path.get_extension()
	var stem := path.trim_suffix("." + extension) if not extension.is_empty() else path
	var temp_path := "%s.tmp.%d%s" % [
		stem,
		Time.get_ticks_usec(),
		("." + extension) if not extension.is_empty() else "",
	]
	var temp_error := ResourceSaver.save(resource, temp_path)
	if temp_error != OK:
		_cleanup_atomic_artifacts(path)
		return temp_error
	var replace_error := _replace_file_atomically(temp_path, path)
	_cleanup_atomic_artifacts(path)
	return replace_error


func _replace_file_atomically(source_path: String, target_path: String) -> Error:
	var target_absolute := ProjectSettings.globalize_path(target_path)
	var source_absolute := ProjectSettings.globalize_path(source_path)
	var backup_path := target_path + ".bak"
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	var has_original := FileAccess.file_exists(target_path)
	if FileAccess.file_exists(backup_path) and has_original:
		DirAccess.remove_absolute(backup_absolute)
	if has_original:
		var backup_error := DirAccess.rename_absolute(
			target_absolute,
			backup_absolute
		)
		if backup_error != OK:
			DirAccess.remove_absolute(source_absolute)
			_cleanup_atomic_artifacts(target_path)
			return backup_error
	var replace_error := DirAccess.rename_absolute(
		source_absolute,
		target_absolute
	)
	if replace_error != OK:
		if has_original:
			DirAccess.rename_absolute(backup_absolute, target_absolute)
		DirAccess.remove_absolute(source_absolute)
		_cleanup_atomic_artifacts(target_path)
		return replace_error
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	return OK


func _cleanup_atomic_artifacts(target_path: String) -> void:
	var directory := DirAccess.open(target_path.get_base_dir())
	if directory == null:
		return
	var target_name := target_path.get_file()
	var extension := target_name.get_extension()
	var stem := target_name.trim_suffix("." + extension) if not extension.is_empty() else target_name
	for file_name in directory.get_files():
		if (
			file_name.begins_with(target_name + ".tmp.")
			or file_name.begins_with(stem + ".tmp.")
		):
			directory.remove(file_name)
		elif file_name == target_name + ".bak":
			directory.remove(file_name)


func _cleanup_recovery_artifacts() -> void:
	var directory := DirAccess.open("user://")
	if directory == null:
		return
	for file_name in directory.get_files():
		if not file_name.begins_with("coastal_karts_track_recovery"):
			continue
		if ".tmp." in file_name or file_name.ends_with(".bak"):
			directory.remove(file_name)


func _catalog_contains(track_id: StringName) -> bool:
	var catalog := _load_catalog()
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
