class_name TrackLevelValidator
extends RefCounted

const JunctionBuilder = preload("res://scripts/world/track_junction_builder.gd")
const SHORTCUT_ROUTE_CLEARANCE := (
	CoastalTrack.ROAD_WIDTH * 0.5
	+ CoastalTrack.SHORTCUT_WIDTH * 0.5
)
const SHORTCUT_MINIMUM_TURN_RADIUS := 8.0
const ROUTE_MAX_GRADE_WARNING := 0.32
const ROUTE_MAX_ELEVATION_STEP_WARNING := 1.5
const ROUTE_MIN_SEGMENT_LENGTH_WARNING := 0.75
const ROUTE_MAX_GRADE_CHANGE_WARNING := 0.20
const ROUTE_MINIMUM_TURN_RADIUS_WARNING := 4.0
const SURFACE_MIN_WIDTH := 0.5
const SURFACE_MIN_PROGRESS := 0.001


static func inspect(track) -> Array[TrackValidationIssue]:
	var issues: Array[TrackValidationIssue] = []
	if track.track_id.is_empty():
		_append_issue(
			issues,
			&"track_id_missing",
			"La pista necesita un identificador.",
			NodePath(".")
		)
	if track.display_name.strip_edges().is_empty():
		_append_issue(
			issues,
			&"display_name_missing",
			"La pista necesita un nombre visible.",
			NodePath(".")
		)

	var main_route: Path3D = track.get_main_route()
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
		if track.start_point_index >= main_route.curve.point_count:
			_append_issue(
				issues,
				&"start_point_invalid",
				"La salida apunta a un punto que ya no existe.",
				NodePath("MainRoute")
			)
		var sampled_route: Array[Vector3] = track._sample_path(main_route, true)
		validation_route = track._apply_start_offset(sampled_route)
		_append_route_geometry_warnings(issues, sampled_route)

	var shortcut_ids: Dictionary = {}
	var shortcuts: Array[TrackShortcut] = track.get_shortcuts()
	for shortcut in shortcuts:
		var shortcut_path: NodePath = track.get_path_to(shortcut)
		var shortcut_transform: Transform3D = track._get_transform_relative_to_track(shortcut)
		var shortcut_position := shortcut_transform.origin
		if shortcut.curve != null and shortcut.curve.point_count > 0:
			shortcut_position = shortcut_transform * shortcut.curve.get_point_position(
				shortcut.curve.point_count / 2
			)
		if shortcut.display_name.strip_edges().is_empty():
			_append_issue(
				issues,
				&"shortcut_name_missing",
				"El atajo %d necesita un nombre." % shortcut.shortcut_id,
				shortcut_path,
				shortcut_position
			)
		if shortcut.shortcut_id in shortcut_ids:
			_append_issue(
				issues,
				&"shortcut_id_duplicate",
				(
					"El identificador de atajo %d está repetido."
					% shortcut.shortcut_id
				),
				shortcut_path,
				shortcut_position
			)
		shortcut_ids[shortcut.shortcut_id] = true
		if shortcut.curve == null or shortcut.curve.point_count < 3:
			_append_issue(
				issues,
				&"shortcut_point_count",
				"%s necesita al menos tres puntos."
				% shortcut.display_name,
				shortcut_path,
				shortcut_position
			)
		elif shortcut.curve.closed:
			_append_issue(
				issues,
				&"shortcut_not_open",
				"%s debe ser una curva abierta." % shortcut.display_name,
				shortcut_path,
				shortcut_position
			)
		elif not validation_route.is_empty():
			var shortcut_errors := validate_shortcut(
				track,
				shortcut,
				validation_route
			)
			for shortcut_error in shortcut_errors:
				var issue_code := &"shortcut_connection"
				if "meta" in shortcut_error or "sale antes" in shortcut_error:
					issue_code = &"shortcut_order"
				elif "contravía" in shortcut_error:
					issue_code = &"shortcut_direction"
				elif "se superpone" in shortcut_error:
					issue_code = &"shortcut_route_overlap"
				_append_issue(
					issues,
					issue_code,
					shortcut_error,
					shortcut_path,
					shortcut_position
				)
			if shortcut_errors.is_empty():
				if (
					shortcut.route_anchor_enabled
					and shortcut.has_meta(&"editor_safety_checked")
				):
					var safety := get_shortcut_safety(track, shortcut)
					if not bool(safety.safe) and safety.code in [
						&"shortcut_turn_too_tight",
						&"shortcut_corridor_too_narrow",
						&"shortcut_barrier_self_intersection",
					]:
						_append_warning_issue(
							issues,
							safety.code,
							String(safety.message),
							shortcut_path,
							shortcut_position
						)
				_append_junction_warning(
					issues,
					track,
					shortcut,
					validation_route,
					shortcut_path,
					shortcut_position
				)

	var props: Node = track.get_node_or_null("Props")
	if props == null:
		_append_issue(
			issues,
			&"props_missing",
			"Falta el nodo Props.",
			NodePath("Props")
		)
	var item_spawns: Node = track.get_node_or_null("ItemSpawns")
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
			var item_path: NodePath = track.get_path_to(child)
			if not child is Marker3D:
				_append_issue(
					issues,
					&"item_type",
					"%s debe ser Marker3D." % child.name,
					item_path,
					(
						track._get_transform_relative_to_track(child).origin
						if child is Node3D
						else Vector3.ZERO
					)
				)
				continue
			var marker_position: Vector3 = track._get_transform_relative_to_track(
				child as Node3D
			).origin
			if (
				_distance_to_route_points_2d(
					marker_position,
					validation_route
				) > CoastalTrack.ROAD_WIDTH * 0.5
			):
				_append_issue(
					issues,
					&"item_off_route",
					"%s está fuera de la carretera." % child.name,
					item_path,
					marker_position
				)

	_inspect_surface_zones(issues, track)
	return issues


static func _inspect_surface_zones(
	issues: Array[TrackValidationIssue],
	track
) -> void:
	var zones: Array[TrackSurfaceZone] = track.get_surface_zones()
	for zone in zones:
		var zone_path: NodePath = track.get_path_to(zone)
		var zone_position := _get_surface_zone_position(track, zone)
		if zone.id.is_empty():
			_append_issue(
				issues,
				&"surface_id_missing",
				"La zona de superficie necesita un identificador.",
				zone_path,
				zone_position
			)
		if zone.surface == null:
			_append_issue(
				issues,
				&"surface_missing",
				"La zona de superficie necesita una superficie asignada.",
				zone_path,
				zone_position
			)
		if zone.path_kind not in [TrackSurfaceZone.PathKind.MAIN, TrackSurfaceZone.PathKind.SHORTCUT]:
			_append_issue(
				issues,
				&"surface_path_invalid",
				"La zona de superficie necesita una ruta válida.",
				zone_path,
				zone_position
			)
		if (
			not is_finite(zone.start_progress)
			or not is_finite(zone.end_progress)
			or not is_finite(zone.lateral_offset)
			or not is_finite(zone.width)
		):
			_append_issue(
				issues,
				&"surface_numeric_invalid",
				"La zona de superficie contiene valores numéricos inválidos.",
				zone_path,
				zone_position
			)
		if (
			zone.start_progress < 0.0
			or zone.end_progress > 1.0
			or zone.start_progress > 1.0
			or zone.end_progress < 0.0
		):
			_append_issue(
				issues,
				&"surface_progress_invalid",
				"El progreso de la zona debe estar entre 0 y 1.",
				zone_path,
				zone_position
			)
		if zone.end_progress - zone.start_progress < SURFACE_MIN_PROGRESS:
			_append_issue(
				issues,
				&"surface_progress_order",
				"La zona necesita un orden de progreso y una longitud válidos.",
				zone_path,
				zone_position
			)
		if zone.width < SURFACE_MIN_WIDTH:
			_append_issue(
				issues,
				&"surface_width_too_small",
				"La zona necesita al menos %.1f m de ancho." % SURFACE_MIN_WIDTH,
				zone_path,
				zone_position
			)
		if zone.surface_priority < 0 or zone.surface_priority > 100:
			_append_issue(
				issues,
				&"surface_priority_invalid",
				"La prioridad de la zona debe estar entre 0 y 100.",
				zone_path,
				zone_position
			)
		if absf(zone.lateral_offset) + zone.width * 0.5 > CoastalTrack.ROAD_WIDTH * 0.5:
			_append_issue(
				issues,
				&"surface_outside_road",
				"La zona excede el ancho transitable de la carretera.",
				zone_path,
				zone_position
			)
		if zone.path_kind == TrackSurfaceZone.PathKind.SHORTCUT:
			var shortcut := _find_shortcut(track, zone.shortcut_id)
			if shortcut == null:
				_append_issue(
					issues,
					&"surface_shortcut_invalid",
					"La zona de superficie apunta a un atajo inexistente.",
					zone_path,
					zone_position
				)

	for first_index in zones.size():
		var first := zones[first_index]
		for second_index in range(first_index + 1, zones.size()):
			var second := zones[second_index]
			if (
				first.path_kind != second.path_kind
				or (
					first.path_kind == TrackSurfaceZone.PathKind.SHORTCUT
					and first.shortcut_id != second.shortcut_id
				)
				or first.end_progress <= second.start_progress
				or second.end_progress <= first.start_progress
				or absf(first.lateral_offset - second.lateral_offset)
					>= (first.width + second.width) * 0.5
			):
				continue
			var second_path: NodePath = track.get_path_to(second)
			var overlap_message := (
				"Las zonas de superficie '%s' y '%s' se solapan; ajusta su progreso, "
				+ "ancho o prioridad."
			) % [String(first.id), String(second.id)]
			if first.surface_priority != second.surface_priority:
				_append_warning_issue(
					issues,
					&"surface_overlap",
					overlap_message
					+ " Se aplicará la prioridad más alta.",
					second_path,
					_get_surface_zone_position(track, second)
				)
				continue
			_append_issue(
				issues,
				&"surface_overlap",
				overlap_message,
				second_path,
				_get_surface_zone_position(track, second)
			)


static func _find_shortcut(track, shortcut_id: int) -> TrackShortcut:
	for shortcut in track.get_shortcuts():
		if shortcut.shortcut_id == shortcut_id:
			return shortcut
	return null


static func _get_surface_zone_position(track, zone: TrackSurfaceZone) -> Vector3:
	var points: Array[Vector3] = []
	if zone.path_kind == TrackSurfaceZone.PathKind.SHORTCUT:
		var shortcut := _find_shortcut(track, zone.shortcut_id)
		if shortcut != null:
			points = track._sample_path(shortcut, false)
	else:
		var route: Path3D = track.get_main_route()
		if route != null:
			points = track._apply_start_offset(track._sample_path(route, true))
	if points.is_empty():
		return track._get_transform_relative_to_track(zone).origin
	var progress := clampf(
		(zone.start_progress + zone.end_progress) * 0.5,
		0.0,
		1.0
	)
	var last_index := points.size() - (1 if zone.path_kind == TrackSurfaceZone.PathKind.SHORTCUT else 0)
	var sample_index := clampi(floori(progress * last_index), 0, points.size() - 1)
	var next_index := (
		(sample_index + 1) % points.size()
		if zone.path_kind == TrackSurfaceZone.PathKind.MAIN
		else mini(sample_index + 1, points.size() - 1)
	)
	var scaled_progress := progress * last_index
	var sample_position: Vector3
	if zone.path_kind == TrackSurfaceZone.PathKind.MAIN and is_equal_approx(progress, 1.0):
		sample_position = points[0]
	else:
		sample_position = points[sample_index].lerp(
			points[next_index],
			scaled_progress - sample_index
		)
	var previous_index := (
		(sample_index - 1 + points.size()) % points.size()
		if zone.path_kind == TrackSurfaceZone.PathKind.MAIN
		else maxi(sample_index - 1, 0)
	)
	var following_index := (
		(sample_index + 1) % points.size()
		if zone.path_kind == TrackSurfaceZone.PathKind.MAIN
		else mini(sample_index + 1, points.size() - 1)
	)
	var forward := points[following_index] - points[previous_index]
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return sample_position
	var right := Vector3(forward.z, 0.0, -forward.x).normalized()
	return sample_position + right * zone.lateral_offset


static func validate_shortcut(
	track,
	shortcut: TrackShortcut,
	validation_route: Array[Vector3]
) -> PackedStringArray:
	var errors := PackedStringArray()
	var shortcut_points: Array[Vector3] = track._sample_path(
		shortcut,
		false
	)
	var entry_index := _find_closest_index_in_points(
		shortcut_points[0],
		validation_route
	)
	var exit_index := _find_closest_index_in_points(
		shortcut_points[-1],
		validation_route
	)
	if (
		_distance_to_route_points_2d(
			shortcut_points[0],
			validation_route
		) > 1.5
		or _distance_to_route_points_2d(
			shortcut_points[-1],
			validation_route
		) > 1.5
	):
		errors.append(
			"%s debe comenzar y terminar sobre MainRoute."
			% shortcut.display_name
		)
	if entry_index >= exit_index:
		errors.append(
			"%s cruza la línea de meta o sale antes de entrar."
			% shortcut.display_name
		)
		return errors
	if not shortcut_follows_route_direction(shortcut_points, validation_route):
		errors.append(
			"%s entra o sale a contravía." % shortcut.display_name
		)
	var corridor_clearance := get_shortcut_corridor_clearance(
		shortcut_points,
		validation_route
	)
	if (
		has_shortcut_route_crossing(shortcut_points, validation_route)
		or (
			corridor_clearance >= 0.0
			and corridor_clearance < SHORTCUT_ROUTE_CLEARANCE
		)
	):
		errors.append(
			"%s se superpone a MainRoute fuera de sus conexiones."
			% shortcut.display_name
		)
	return errors


static func shortcut_follows_route_direction(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3]
) -> bool:
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return false
	var entry_index := _find_closest_index_in_points(
		shortcut_points[0],
		validation_route
	)
	var exit_index := _find_closest_index_in_points(
		shortcut_points[-1],
		validation_route
	)
	var route_entry_forward := (
		validation_route[(entry_index + 1) % validation_route.size()]
		- validation_route[
			(entry_index - 1 + validation_route.size())
			% validation_route.size()
		]
	)
	var route_exit_forward := (
		validation_route[(exit_index + 1) % validation_route.size()]
		- validation_route[
			(exit_index - 1 + validation_route.size())
			% validation_route.size()
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
	return (
		route_entry_forward.normalized().dot(
			shortcut_entry_forward.normalized()
		) >= 0.75
		and route_exit_forward.normalized().dot(
			shortcut_exit_forward.normalized()
		) >= 0.75
	)


static func has_shortcut_route_crossing(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3]
) -> bool:
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return false
	var total_length := 0.0
	for point_index in range(1, shortcut_points.size()):
		total_length += shortcut_points[point_index - 1].distance_to(
			shortcut_points[point_index]
		)
	var progress := 0.0
	for point_index in range(1, shortcut_points.size()):
		var shortcut_start := shortcut_points[point_index - 1]
		var shortcut_finish := shortcut_points[point_index]
		var segment_length := shortcut_start.distance_to(shortcut_finish)
		var segment_middle := progress + segment_length * 0.5
		progress += segment_length
		if (
			segment_middle < SHORTCUT_ROUTE_CLEARANCE
			or total_length - segment_middle < SHORTCUT_ROUTE_CLEARANCE
		):
			continue
		var shortcut_start_2d := Vector2(shortcut_start.x, shortcut_start.z)
		var shortcut_finish_2d := Vector2(shortcut_finish.x, shortcut_finish.z)
		for route_index in validation_route.size():
			var route_start := validation_route[route_index]
			var route_finish := validation_route[
				(route_index + 1) % validation_route.size()
			]
			if Geometry2D.segment_intersects_segment(
				shortcut_start_2d,
				shortcut_finish_2d,
				Vector2(route_start.x, route_start.z),
				Vector2(route_finish.x, route_finish.z)
			) != null:
				return true
	return false


static func get_shortcut_corridor_clearance(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3]
) -> float:
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return -1.0
	var builder := JunctionBuilder.new(
		validation_route,
		CoastalTrack.ROAD_WIDTH,
		CoastalTrack.SHORTCUT_WIDTH
	)
	var entry_junction := builder.build(shortcut_points, true)
	var exit_junction := builder.build(shortcut_points, false)
	if not entry_junction.is_valid or not exit_junction.is_valid:
		return -1.0
	var first_index: int = entry_junction.shortcut_transition_index
	var final_index: int = exit_junction.shortcut_transition_index
	if first_index < 0 or final_index < first_index:
		return -1.0
	var minimum_clearance := INF
	for point_index in range(first_index, final_index + 1):
		minimum_clearance = minf(
			minimum_clearance,
			_distance_to_route_points_2d(
				shortcut_points[point_index],
				validation_route
			)
		)
	return minimum_clearance


static func get_shortcut_minimum_turn_radius(
	shortcut_points: Array[Vector3],
	validation_route: Array[Vector3] = []
) -> float:
	if shortcut_points.size() < 5:
		return 0.0
	var first_index := 0
	var final_index := shortcut_points.size() - 1
	if validation_route.size() >= 3:
		var builder := JunctionBuilder.new(
			validation_route,
			CoastalTrack.ROAD_WIDTH,
			CoastalTrack.SHORTCUT_WIDTH
		)
		var entry_junction := builder.build(shortcut_points, true)
		var exit_junction := builder.build(shortcut_points, false)
		if entry_junction.is_valid and exit_junction.is_valid:
			first_index = entry_junction.shortcut_transition_index
			final_index = exit_junction.shortcut_transition_index
	var sample_stride := maxi(1, shortcut_points.size() / 24)
	var minimum_radius := INF
	for point_index in range(
		first_index + sample_stride,
		final_index - sample_stride + 1,
		sample_stride
	):
		var first := Vector2(
			shortcut_points[point_index - sample_stride].x,
			shortcut_points[point_index - sample_stride].z
		)
		var middle := Vector2(
			shortcut_points[point_index].x,
			shortcut_points[point_index].z
		)
		var final := Vector2(
			shortcut_points[point_index + sample_stride].x,
			shortcut_points[point_index + sample_stride].z
		)
		var first_length := first.distance_to(middle)
		var second_length := middle.distance_to(final)
		var chord_length := first.distance_to(final)
		var doubled_area := absf((middle - first).cross(final - first))
		if (
			first_length <= 0.001
			or second_length <= 0.001
			or chord_length <= 0.001
			or doubled_area <= 0.0001
		):
			continue
		minimum_radius = minf(
			minimum_radius,
			first_length * second_length * chord_length
			/ (2.0 * doubled_area)
		)
	return minimum_radius


static func get_shortcut_safety(
	track,
	shortcut: TrackShortcut
) -> Dictionary:
	var result := {
		"safe": false,
		"code": &"shortcut_geometry_unsafe",
		"message": "La forma del atajo no es segura.",
		"turn_radius": 0.0,
		"clearance": -1.0,
	}
	if track == null or shortcut == null or shortcut.curve == null:
		return result
	var main_route: Path3D = track.get_main_route()
	if main_route == null or main_route.curve == null:
		return result
	var shortcut_points: Array[Vector3] = track._sample_path(shortcut, false)
	var validation_route: Array[Vector3] = track._apply_start_offset(
		track._sample_path(main_route, true)
	)
	if shortcut_points.size() < 3 or validation_route.size() < 3:
		return result
	result.turn_radius = get_shortcut_minimum_turn_radius(
		shortcut_points,
		validation_route
	)
	result.clearance = get_shortcut_corridor_clearance(
		shortcut_points,
		validation_route
	)
	if float(result.turn_radius) < SHORTCUT_MINIMUM_TURN_RADIUS:
		result.code = &"shortcut_turn_too_tight"
		result.message = "%s tiene una curva demasiado cerrada." % shortcut.display_name
		return result
	var junction_builder := JunctionBuilder.new(
		validation_route,
		CoastalTrack.ROAD_WIDTH,
		CoastalTrack.SHORTCUT_WIDTH
	)
	var entry_junction := junction_builder.build(shortcut_points, true)
	var exit_junction := junction_builder.build(shortcut_points, false)
	if not entry_junction.is_valid or not exit_junction.is_valid:
		result.code = &"shortcut_junction_unsafe"
		result.message = "%s no permite una entrada y salida seguras." % shortcut.display_name
		return result
	if (
		float(result.clearance) < SHORTCUT_ROUTE_CLEARANCE
		or has_shortcut_route_crossing(shortcut_points, validation_route)
	):
		result.code = &"shortcut_corridor_too_narrow"
		result.message = "%s no conserva separación suficiente de la carretera." % shortcut.display_name
		return result
	var first_index: int = entry_junction.shortcut_transition_index
	var final_index: int = exit_junction.shortcut_transition_index
	if first_index < 0 or final_index < first_index:
		return result
	var center_section: Array[Vector3] = []
	for point_index in range(first_index, final_index + 1):
		center_section.append(shortcut_points[point_index])
	var barrier_offset := (
		CoastalTrack.SHORTCUT_WIDTH * 0.5
		+ TrackBarrierBuilder.SHORTCUT_BARRIER_SHOULDER
	)
	for lateral_offset in [-barrier_offset, barrier_offset]:
		var barrier_chain := TrackBarrierBuilder.build_open_offset_chain(
			center_section,
			lateral_offset
		)
		if not TrackBarrierBuilder.is_open_chain_safe(barrier_chain):
			result.code = &"shortcut_barrier_self_intersection"
			result.message = "%s doblaría una barrera sobre sí misma." % shortcut.display_name
			return result
	result.safe = true
	result.code = &""
	result.message = "Forma segura."
	return result


static func _append_issue(
	issues: Array[TrackValidationIssue],
	code: StringName,
	message: String,
	target_path: NodePath,
	world_position := Vector3.ZERO
) -> void:
	if _contains_same_issue(
		issues,
		code,
		message,
		target_path,
		world_position,
		TrackValidationIssue.Severity.ERROR
	):
		return
	issues.append(
		TrackValidationIssue.create(
			code,
			message,
			TrackValidationIssue.Severity.ERROR,
			target_path,
			world_position
		)
	)


static func _append_warning_issue(
	issues: Array[TrackValidationIssue],
	code: StringName,
	message: String,
	target_path: NodePath,
	world_position := Vector3.ZERO
) -> void:
	if _contains_same_issue(
		issues,
		code,
		message,
		target_path,
		world_position,
		TrackValidationIssue.Severity.WARNING
	):
		return
	issues.append(
		TrackValidationIssue.create(
			code,
			message,
			TrackValidationIssue.Severity.WARNING,
			target_path,
			world_position
		)
	)


static func _contains_same_issue(
	issues: Array[TrackValidationIssue],
	code: StringName,
	message: String,
	target_path: NodePath,
	world_position: Vector3,
	severity: TrackValidationIssue.Severity
) -> bool:
	for issue in issues:
		if (
			issue.code == code
			and issue.message == message
			and issue.target_path == target_path
			and issue.severity == severity
			and (
				(world_position.is_zero_approx() and issue.world_position.is_zero_approx())
				or issue.world_position.is_equal_approx(world_position)
			)
		):
			return true
	return false


static func _append_junction_warning(
	issues: Array[TrackValidationIssue],
	track,
	shortcut: TrackShortcut,
	validation_route: Array[Vector3],
	shortcut_path: NodePath,
	shortcut_position: Vector3
) -> void:
	var shortcut_points: Array[Vector3] = track._sample_path(shortcut, false)
	var builder := JunctionBuilder.new(
		validation_route,
		CoastalTrack.ROAD_WIDTH,
		CoastalTrack.SHORTCUT_WIDTH
	)
	var fallback_labels := PackedStringArray()
	var warning_position := shortcut_position
	for junction_data in [
		[builder.build(shortcut_points, true), "entrada"],
		[builder.build(shortcut_points, false), "salida"],
	]:
		var junction = junction_data[0]
		if junction.is_valid:
			continue
		fallback_labels.append(
			"%s (%s)" % [junction_data[1], junction.fallback_reason]
		)
		if not junction.world_position.is_zero_approx():
			warning_position = junction.world_position
	if fallback_labels.is_empty():
		return
	issues.append(
		TrackValidationIssue.create(
			&"shortcut_junction_fallback",
			"%s usará una unión recta en %s."
			% [shortcut.display_name, " y ".join(fallback_labels)],
			TrackValidationIssue.Severity.WARNING,
			shortcut_path,
			warning_position
		)
	)


static func _append_route_geometry_warnings(
	issues: Array[TrackValidationIssue],
	points: Array[Vector3]
) -> void:
	if points.size() < 3:
		return
	for point_index in points.size():
		var next_index := (point_index + 1) % points.size()
		var start := points[point_index]
		var finish := points[next_index]
		var horizontal_distance := Vector2(
			finish.x - start.x,
			finish.z - start.z
		).length()
		var segment_length := start.distance_to(finish)
		var elevation_delta := absf(finish.y - start.y)
		var midpoint := start.lerp(finish, 0.5)
		if segment_length < ROUTE_MIN_SEGMENT_LENGTH_WARNING:
			_append_warning_issue(
				issues,
				&"route_segment_too_short",
				"MainRoute tiene un tramo demasiado corto; puede generar una vibración del kart.",
				NodePath("MainRoute"),
				midpoint
			)
		var grade := elevation_delta / maxf(horizontal_distance, 0.01)
		if grade > ROUTE_MAX_GRADE_WARNING:
			_append_warning_issue(
				issues,
				&"route_slope_sharp",
				"MainRoute tiene una pendiente brusca (%.0f%%); puede producir saltos del kart."
				% (grade * 100.0),
				NodePath("MainRoute"),
				midpoint
			)
		if elevation_delta > ROUTE_MAX_ELEVATION_STEP_WARNING and horizontal_distance < 8.0:
			_append_warning_issue(
				issues,
				&"route_height_discontinuity",
				"MainRoute cambia %.1f m de altura en un tramo corto; suaviza esa transición."
				% elevation_delta,
				NodePath("MainRoute"),
				midpoint
			)
		var previous := points[(point_index - 1 + points.size()) % points.size()]
		var previous_horizontal_distance := Vector2(
			start.x - previous.x,
			start.z - previous.z
		).length()
		if previous_horizontal_distance <= 0.01 or horizontal_distance <= 0.01:
			continue
		var previous_grade := (start.y - previous.y) / maxf(
			previous_horizontal_distance,
			0.01
		)
		var signed_grade := (finish.y - start.y) / maxf(horizontal_distance, 0.01)
		if absf(signed_grade - previous_grade) > ROUTE_MAX_GRADE_CHANGE_WARNING:
			_append_warning_issue(
				issues,
				&"route_grade_change",
				"MainRoute cambia la pendiente demasiado rápido; suaviza la transición para evitar un salto del kart.",
				NodePath("MainRoute"),
				midpoint
			)
		var previous_direction := Vector2(
			start.x - previous.x,
			start.z - previous.z
		).normalized()
		var next_direction := Vector2(
			finish.x - start.x,
			finish.z - start.z
		).normalized()
		var turn_angle := acos(clampf(previous_direction.dot(next_direction), -1.0, 1.0))
		var turn_radius := _get_turn_radius(previous, start, finish)
		if (
			turn_angle > 0.35
			and turn_radius < ROUTE_MINIMUM_TURN_RADIUS_WARNING
		):
			_append_warning_issue(
				issues,
				&"route_turn_too_tight",
				"MainRoute tiene un radio de giro de %.1f m; puede provocar una reacción brusca del kart."
				% turn_radius,
				NodePath("MainRoute"),
				start
			)


static func _get_turn_radius(
	previous: Vector3,
	current: Vector3,
	next: Vector3
) -> float:
	var first := Vector2(previous.x, previous.z)
	var middle := Vector2(current.x, current.z)
	var final := Vector2(next.x, next.z)
	var first_length := first.distance_to(middle)
	var second_length := middle.distance_to(final)
	var chord_length := first.distance_to(final)
	if first_length <= 0.01 or second_length <= 0.01:
		return INF
	var twice_area := absf((middle - first).cross(final - first))
	if twice_area <= 0.0001:
		return INF
	return first_length * second_length * chord_length / (2.0 * twice_area)


static func _distance_to_route_points_2d(
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


static func _find_closest_index_in_points(
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


static func _point_to_segment_distance_2d(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(segment_start)
	var weight := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_to(segment_start + segment * weight)
