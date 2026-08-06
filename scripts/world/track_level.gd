@tool
class_name TrackLevel
extends CoastalTrack

const GENERATED_GROUP := &"track_editor_generated"
const DEFAULT_ROUTE_SUBDIVISIONS := 8
const DEFAULT_SHORTCUT_SUBDIVISIONS := 12

@export var track_id: StringName = &"track"
@export var display_name := "Nueva pista"
@export var start_banner_text := "MICHIKART XD"
@export var track_theme: TrackTheme
@export_range(4, 16, 1) var route_subdivisions := DEFAULT_ROUTE_SUBDIVISIONS
@export_range(6, 18, 1) var shortcut_subdivisions := DEFAULT_SHORTCUT_SUBDIVISIONS
@export_range(0.0, 4.0, 0.25) var shortcut_barrier_overlap := 0.0
@export_range(0, 128, 1) var start_point_index := 0
@export var environment_size := Vector2(310.0, 260.0)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	rebuild_track()


func rebuild_track() -> PackedStringArray:
	clear_generated_track()
	var validation_errors := validate_track()
	if not validation_errors.is_empty():
		push_error(
			"%s no se pudo generar (%d problemas): %s"
			% [
				display_name,
				validation_errors.size(),
				" | ".join(validation_errors),
			]
		)
		return validation_errors
	_generate_track_output()
	return PackedStringArray()


func rebuild_preview() -> PackedStringArray:
	clear_generated_track()
	var validation_errors := validate_track()
	if not _is_main_route_preview_usable():
		return validation_errors
	_generate_track_output()
	return validation_errors


func _generate_track_output() -> void:
	var source_children := get_children()
	route_points.clear()
	item_spawn_points.clear()
	shortcut_definitions.clear()
	_active_shortcuts.clear()
	_prepare_materials()
	_build_route()
	_define_shortcuts()
	_build_environment()
	_build_road()
	_build_shortcuts()
	_build_main_barriers()
	_build_start_arch()
	_build_decorations()
	_define_item_spawns()
	for child in get_children():
		if child not in source_children:
			child.add_to_group(GENERATED_GROUP, true)


func clear_generated_track() -> void:
	for child in get_children():
		if child.is_in_group(GENERATED_GROUP):
			remove_child(child)
			child.free()
	route_points.clear()
	item_spawn_points.clear()
	shortcut_definitions.clear()
	_active_shortcuts.clear()


func validate_track() -> PackedStringArray:
	var errors := PackedStringArray()
	for issue in inspect_track():
		errors.append(issue.message)
	return errors


func inspect_track() -> Array[TrackValidationIssue]:
	var issues: Array[TrackValidationIssue] = []
	if track_id.is_empty():
		_append_issue(
			issues,
			&"track_id_missing",
			"La pista necesita un identificador.",
			NodePath(".")
		)
	if display_name.strip_edges().is_empty():
		_append_issue(
			issues,
			&"display_name_missing",
			"La pista necesita un nombre visible.",
			NodePath(".")
		)

	var main_route := get_main_route()
	var validation_route: Array[Vector3] = []
	if main_route == null:
		_append_issue(
			issues,
			&"route_missing",
			"Falta el nodo MainRoute de tipo Path3D.",
			NodePath("MainRoute")
		)
	elif main_route.curve == null or main_route.curve.point_count < 4:
		_append_issue(
			issues,
			&"route_point_count",
			"MainRoute necesita al menos cuatro puntos.",
			NodePath("MainRoute")
		)
	elif not main_route.curve.closed:
		_append_issue(
			issues,
			&"route_not_closed",
			"MainRoute debe ser una curva cerrada.",
			NodePath("MainRoute")
		)
	elif main_route.curve.get_baked_length() < 120.0:
		_append_issue(
			issues,
			&"route_too_short",
			"La ruta principal debe medir al menos 120 metros.",
			NodePath("MainRoute")
		)
	else:
		if start_point_index >= main_route.curve.point_count:
			_append_issue(
				issues,
				&"start_point_invalid",
				"La salida apunta a un punto que ya no existe.",
				NodePath("MainRoute")
			)
		validation_route = _apply_start_offset(_sample_path(main_route, true))

	var shortcut_ids: Dictionary = {}
	for shortcut in get_shortcuts():
		var shortcut_path := get_path_to(shortcut)
		if shortcut.display_name.strip_edges().is_empty():
			_append_issue(
				issues,
				&"shortcut_name_missing",
				"El atajo %d necesita un nombre." % shortcut.shortcut_id,
				shortcut_path
			)
		if shortcut.shortcut_id in shortcut_ids:
			_append_issue(
				issues,
				&"shortcut_id_duplicate",
				"El identificador de atajo %d está repetido." % shortcut.shortcut_id,
				shortcut_path
			)
		shortcut_ids[shortcut.shortcut_id] = true
		if shortcut.curve == null or shortcut.curve.point_count < 3:
			_append_issue(
				issues,
				&"shortcut_point_count",
				"%s necesita al menos tres puntos." % shortcut.display_name,
				shortcut_path
			)
		elif shortcut.curve.closed:
			_append_issue(
				issues,
				&"shortcut_not_open",
				"%s debe ser una curva abierta." % shortcut.display_name,
				shortcut_path
			)
		elif not validation_route.is_empty():
			var shortcut_errors := PackedStringArray()
			_validate_shortcut(shortcut, validation_route, shortcut_errors)
			for shortcut_error in shortcut_errors:
				var issue_code := &"shortcut_connection"
				if "meta" in shortcut_error or "sale antes" in shortcut_error:
					issue_code = &"shortcut_order"
				elif "contravía" in shortcut_error:
					issue_code = &"shortcut_direction"
				_append_issue(
					issues,
					issue_code,
					shortcut_error,
					shortcut_path
				)

	var props := get_node_or_null("Props")
	if props == null:
		_append_issue(
			issues,
			&"props_missing",
			"Falta el nodo Props.",
			NodePath("Props")
		)
	var item_spawns := get_node_or_null("ItemSpawns")
	if item_spawns == null:
		_append_issue(
			issues,
			&"items_missing",
			"Falta el nodo ItemSpawns.",
			NodePath("ItemSpawns")
		)
	elif item_spawns.get_child_count() < 4:
		_append_issue(
			issues,
			&"item_count",
			"ItemSpawns necesita al menos cuatro marcadores.",
			NodePath("ItemSpawns")
		)
	elif not validation_route.is_empty():
		for child in item_spawns.get_children():
			var item_path := get_path_to(child)
			if not child is Marker3D:
				_append_issue(
					issues,
					&"item_type",
					"%s debe ser Marker3D." % child.name,
					item_path
				)
				continue
			var marker_position := _get_transform_relative_to_track(
				child as Node3D
			).origin
			if (
				_distance_to_route_points_2d(marker_position, validation_route)
				> ROAD_WIDTH * 0.5
			):
				_append_issue(
					issues,
					&"item_off_route",
					"%s está fuera de la carretera." % child.name,
					item_path
				)
	return issues


func _append_issue(
	issues: Array[TrackValidationIssue],
	code: StringName,
	message: String,
	target_path: NodePath
) -> void:
	for issue in issues:
		if issue.code == code and issue.target_path == target_path:
			return
	issues.append(
		TrackValidationIssue.create(
			code,
			message,
			TrackValidationIssue.Severity.ERROR,
			target_path
		)
	)


func _validate_shortcut(
	shortcut: TrackShortcut,
	validation_route: Array[Vector3],
	errors: PackedStringArray
) -> void:
	var shortcut_points := _sample_path(shortcut, false)
	var entry_index := _find_closest_index_in_points(
		shortcut_points[0],
		validation_route
	)
	var exit_index := _find_closest_index_in_points(
		shortcut_points[-1],
		validation_route
	)
	if (
		_distance_to_route_points_2d(shortcut_points[0], validation_route) > 1.5
		or _distance_to_route_points_2d(shortcut_points[-1], validation_route) > 1.5
	):
		errors.append("%s debe comenzar y terminar sobre MainRoute." % shortcut.display_name)
	if entry_index >= exit_index:
		errors.append("%s cruza la línea de meta o sale antes de entrar." % shortcut.display_name)
		return
	var route_entry_forward := (
		validation_route[(entry_index + 1) % validation_route.size()]
		- validation_route[
			(entry_index - 1 + validation_route.size()) % validation_route.size()
		]
	)
	var route_exit_forward := (
		validation_route[(exit_index + 1) % validation_route.size()]
		- validation_route[
			(exit_index - 1 + validation_route.size()) % validation_route.size()
		]
	)
	var shortcut_entry_forward := shortcut_points[2] - shortcut_points[0]
	var shortcut_exit_forward := (
		shortcut_points[-1] - shortcut_points[shortcut_points.size() - 3]
	)
	route_entry_forward.y = 0.0
	route_exit_forward.y = 0.0
	shortcut_entry_forward.y = 0.0
	shortcut_exit_forward.y = 0.0
	if (
		route_entry_forward.normalized().dot(shortcut_entry_forward.normalized()) < 0.75
		or route_exit_forward.normalized().dot(shortcut_exit_forward.normalized()) < 0.75
	):
		errors.append("%s entra o sale a contravía." % shortcut.display_name)


func _distance_to_route_points_2d(
	point: Vector3,
	points: Array[Vector3]
) -> float:
	var flattened_point := Vector2(point.x, point.z)
	var minimum_distance := INF
	for point_index in points.size():
		var next_index := (point_index + 1) % points.size()
		minimum_distance = minf(
			minimum_distance,
			_point_to_segment_distance_2d(
				flattened_point,
				Vector2(points[point_index].x, points[point_index].z),
				Vector2(points[next_index].x, points[next_index].z)
			)
		)
	return minimum_distance


func _find_closest_index_in_points(
	point: Vector3,
	points: Array[Vector3]
) -> int:
	var closest_index := 0
	var closest_distance := INF
	for point_index in points.size():
		var distance := point.distance_squared_to(points[point_index])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = point_index
	return closest_index


func get_main_route() -> Path3D:
	return get_node_or_null("MainRoute") as Path3D


func get_shortcuts() -> Array[TrackShortcut]:
	var shortcuts: Array[TrackShortcut] = []
	var shortcuts_root := get_node_or_null("Shortcuts")
	if shortcuts_root == null:
		return shortcuts
	for child in shortcuts_root.get_children():
		if child is TrackShortcut:
			shortcuts.append(child)
	return shortcuts


func _is_main_route_preview_usable() -> bool:
	var main_route := get_main_route()
	return (
		main_route != null
		and main_route.curve != null
		and main_route.curve.point_count >= 3
		and main_route.curve.closed
		and main_route.curve.get_baked_length() > 0.001
	)


func _is_shortcut_preview_usable(
	shortcut: TrackShortcut,
	duplicate_ids: Dictionary
) -> bool:
	if (
		shortcut == null
		or shortcut.shortcut_id in duplicate_ids
		or shortcut.curve == null
		or shortcut.curve.point_count < 3
		or shortcut.curve.closed
		or route_points.is_empty()
	):
		return false
	var shortcut_errors := PackedStringArray()
	_validate_shortcut(shortcut, route_points, shortcut_errors)
	return shortcut_errors.is_empty()


func _prepare_materials() -> void:
	if track_theme == null:
		super._prepare_materials()
		return
	_road_material = _material(track_theme.road_color, 0.9)
	_edge_material = _material(track_theme.curb_color, 0.72)
	_sand_material = _material(track_theme.terrain_color, 1.0)
	_barrier_material = _create_barrier_material(track_theme.barrier_color)
	_shortcut_material = _material(track_theme.shortcut_color, 0.86)


func _build_route() -> void:
	route_points = _apply_start_offset(_sample_path(get_main_route(), true))


func _define_shortcuts() -> void:
	var shortcut_id_counts: Dictionary = {}
	for shortcut in get_shortcuts():
		shortcut_id_counts[shortcut.shortcut_id] = (
			int(shortcut_id_counts.get(shortcut.shortcut_id, 0)) + 1
		)
	var duplicate_ids: Dictionary = {}
	for shortcut_id in shortcut_id_counts:
		if int(shortcut_id_counts[shortcut_id]) > 1:
			duplicate_ids[shortcut_id] = true
	for shortcut in get_shortcuts():
		if not _is_shortcut_preview_usable(shortcut, duplicate_ids):
			continue
		var shortcut_points := _sample_path(shortcut, false)
		_align_shortcut_junction_heights(shortcut_points)
		shortcut_definitions.append({
			"id": shortcut.shortcut_id,
			"name": shortcut.display_name,
			"entry_index": _find_closest_route_index(shortcut_points[0]),
			"exit_index": _find_closest_route_index(shortcut_points[-1]),
			"points": shortcut_points,
		})


func _build_environment() -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "EnvironmentWater"
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = environment_size
	ocean.mesh = ocean_mesh
	ocean.position.y = -0.8
	var water_color := track_theme.water_color if track_theme != null else Color("#167f93")
	var ocean_material := _material(water_color, 0.36)
	ocean_material.metallic = 0.08
	ocean.material_override = ocean_material
	add_child(ocean)

	var minimum := Vector3(INF, 0.0, INF)
	var maximum := Vector3(-INF, 0.0, -INF)
	for route_point in route_points:
		minimum.x = minf(minimum.x, route_point.x)
		minimum.z = minf(minimum.z, route_point.z)
		maximum.x = maxf(maximum.x, route_point.x)
		maximum.z = maxf(maximum.z, route_point.z)
	var terrain_center := Vector3(
		(minimum.x + maximum.x) * 0.5,
		-0.45,
		(minimum.z + maximum.z) * 0.5
	)
	var terrain_size := Vector3(
		maximum.x - minimum.x + 55.0,
		0.5,
		maximum.z - minimum.z + 55.0
	)
	_create_island(terrain_center, terrain_size)


func _build_decorations() -> void:
	pass


func _define_item_spawns() -> void:
	var item_spawns_root := get_node_or_null("ItemSpawns")
	if item_spawns_root != null:
		for child in item_spawns_root.get_children():
			if child is Marker3D:
				item_spawn_points.append(
					_get_transform_relative_to_track(child as Node3D).origin
					+ Vector3.UP * 1.2
				)
	if item_spawn_points.is_empty():
		for fraction in [0.12, 0.38, 0.64, 0.88]:
			var route_index := int(route_points.size() * fraction) % route_points.size()
			item_spawn_points.append(route_points[route_index] + Vector3.UP * 1.2)
	for shortcut_definition in shortcut_definitions:
		var shortcut_points: Array[Vector3] = shortcut_definition.points
		item_spawn_points.append(
			shortcut_points[shortcut_points.size() / 2] + Vector3.UP * 1.2
		)


func _get_start_banner_text() -> String:
	return start_banner_text


func _get_shortcut_barrier_join_clearance() -> float:
	return (
		ROAD_WIDTH * 0.5
		- BARRIER_PATH_INSET
		- shortcut_barrier_overlap
	)


func _sample_path(path: Path3D, is_closed: bool) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if path == null or path.curve == null:
		return points
	var curve_segment_count := (
		path.curve.point_count if is_closed else path.curve.point_count - 1
	)
	var subdivisions := route_subdivisions if is_closed else shortcut_subdivisions
	var path_to_track := _get_transform_relative_to_track(path)
	for curve_segment in curve_segment_count:
		for subdivision in subdivisions:
			var progress := float(subdivision) / subdivisions
			var local_point := path.curve.sample(curve_segment, progress)
			points.append(path_to_track * local_point)
	if not is_closed:
		var final_point := path.curve.sample(curve_segment_count - 1, 1.0)
		points.append(path_to_track * final_point)
	return points


func _get_transform_relative_to_track(node: Node3D) -> Transform3D:
	var relative_transform := Transform3D.IDENTITY
	var current_node := node
	while current_node != null and current_node != self:
		relative_transform = current_node.transform * relative_transform
		current_node = current_node.get_parent() as Node3D
	return relative_transform


func _apply_start_offset(points: Array[Vector3]) -> Array[Vector3]:
	if points.is_empty() or start_point_index <= 0:
		return points
	var offset := mini(start_point_index * route_subdivisions, points.size() - 1)
	var rotated: Array[Vector3] = []
	for point_index in points.size():
		rotated.append(points[(point_index + offset) % points.size()])
	return rotated


func _find_closest_route_index(point: Vector3) -> int:
	var closest_index := 0
	var closest_distance := INF
	for route_index in route_points.size():
		var distance := point.distance_squared_to(route_points[route_index])
		if distance < closest_distance:
			closest_distance = distance
			closest_index = route_index
	return closest_index
