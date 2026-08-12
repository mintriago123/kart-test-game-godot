extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload(
	"res://levels/track_catalog.tres"
)

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_official_minimaps()
	await _test_legacy_fallback_and_placeholder()
	await _test_view_fitting()
	quit(1 if _has_failed else 0)


func _test_official_minimaps() -> void:
	var expected_shortcuts := {
		&"coastal": 2,
		&"garden": 2,
	}
	for definition in TRACK_CATALOG.tracks:
		var preview_map := definition.preview_map
		_check(
			preview_map != null and preview_map.is_valid(),
			"%s stores a valid generated minimap."
			% definition.display_name
		)
		if preview_map == null:
			continue
		_check(
			preview_map.route_points.size() >= 3
			and preview_map.start_direction.length_squared() > 0.9,
			"%s stores its route, start and direction."
			% definition.display_name
		)
		_check(
			preview_map.shortcut_count
			== int(expected_shortcuts.get(definition.id, -1)),
			"%s stores the expected shortcut count."
			% definition.display_name
		)
		_check(
			preview_map.shortcut_ranges.size()
			== preview_map.shortcut_count * 2,
			"%s stores a point range for every shortcut."
			% definition.display_name
		)
		var track := definition.scene.instantiate() as TrackLevel
		var generated_map := TrackMinimapBuilder.build(track)
		_check(
			generated_map != null
			and _points_are_equal(
				preview_map.shortcut_points,
				generated_map.shortcut_points
			)
			and preview_map.shortcut_ranges == generated_map.shortcut_ranges,
			"%s stored minimap matches its current shortcut geometry."
			% definition.display_name
		)
		track.free()


func _points_are_equal(
	first: PackedVector2Array,
	second: PackedVector2Array
) -> bool:
	if first.size() != second.size():
		return false
	for point_index in first.size():
		if first[point_index].distance_to(second[point_index]) > 0.001:
			return false
	return true


func _test_legacy_fallback_and_placeholder() -> void:
	var selector := TrackSelectScreen.new()
	root.add_child(selector)
	await process_frame

	var legacy_definition := TrackDefinition.new()
	legacy_definition.id = &"legacy"
	legacy_definition.display_name = "Pista heredada"
	legacy_definition.scene = load(
		"res://levels/coastal_track.tscn"
	) as PackedScene
	var legacy_catalog := TrackCatalog.new()
	legacy_catalog.tracks.append(legacy_definition)
	selector.configure(legacy_catalog, {}, legacy_definition.id)
	await process_frame
	_check(
		legacy_definition.preview_map != null
		and legacy_definition.preview_map.is_valid()
		and selector._minimap_view.visible
		and selector._minimap_view.is_map_available(),
		"Selector builds an in-memory minimap for legacy definitions."
	)
	_check(
		selector._details_label.text.contains(" M")
		and selector._details_label.text.contains("2 ATAJOS"),
		"Selector displays generated length and shortcut metadata."
	)

	var invalid_scene := PackedScene.new()
	var invalid_root := Node3D.new()
	invalid_scene.pack(invalid_root)
	invalid_root.free()
	var invalid_definition := TrackDefinition.new()
	invalid_definition.id = &"invalid"
	invalid_definition.display_name = "Pista inválida"
	invalid_definition.scene = invalid_scene
	var invalid_catalog := TrackCatalog.new()
	invalid_catalog.tracks.append(invalid_definition)
	selector.configure(invalid_catalog, {}, invalid_definition.id)
	await process_frame
	_check(
		selector._minimap_view.visible
		and not selector._minimap_view.is_map_available()
		and selector._preview_panel.tooltip_text.contains(
			"Sin mapa disponible"
		),
		"Selector exposes the visible no-map state for invalid scenes."
	)

	var cover_definition := TrackDefinition.new()
	cover_definition.id = &"cover"
	cover_definition.display_name = "Pista con portada"
	cover_definition.scene = legacy_definition.scene
	cover_definition.preview_map = legacy_definition.preview_map
	var cover_image := Image.create(
		2,
		2,
		false,
		Image.FORMAT_RGBA8
	)
	cover_image.fill(Color.WHITE)
	cover_definition.preview_texture = ImageTexture.create_from_image(
		cover_image
	)
	var cover_catalog := TrackCatalog.new()
	cover_catalog.tracks.append(cover_definition)
	selector.configure(cover_catalog, {}, cover_definition.id)
	await process_frame
	_check(
		selector._preview_texture.visible
		and not selector._minimap_view.visible,
		"Optional cover textures take priority over generated minimaps."
	)

	selector.queue_free()
	await process_frame


func _test_view_fitting() -> void:
	var view := TrackMinimapView.new()
	view.size = Vector2(900.0, 420.0)
	root.add_child(view)
	await process_frame
	var variants := {
		"wide": PackedVector2Array([
			Vector2(-240.0, -5.0),
			Vector2(240.0, -5.0),
			Vector2(240.0, 5.0),
			Vector2(-240.0, 5.0),
		]),
		"tall": PackedVector2Array([
			Vector2(-5.0, -240.0),
			Vector2(5.0, -240.0),
			Vector2(5.0, 240.0),
			Vector2(-5.0, 240.0),
		]),
		"small": PackedVector2Array([
			Vector2(-1.0, -1.0),
			Vector2(1.0, -1.0),
			Vector2(1.0, 1.0),
			Vector2(-1.0, 1.0),
		]),
		"negative": PackedVector2Array([
			Vector2(-320.0, -180.0),
			Vector2(-190.0, -175.0),
			Vector2(-185.0, -80.0),
			Vector2(-315.0, -75.0),
		]),
	}
	for variant_name in variants:
		var data := _make_minimap_data(variants[variant_name])
		view.set_minimap_data(data)
		var all_points_fit := true
		for point in data.route_points:
			var mapped := view._map_point_to_screen(point)
			all_points_fit = (
				all_points_fit
				and mapped.x >= TrackMinimapView.MAP_PADDING - 0.1
				and mapped.y >= TrackMinimapView.MAP_PADDING - 0.1
				and mapped.x
				<= view.size.x - TrackMinimapView.MAP_PADDING + 0.1
				and mapped.y
				<= view.size.y - TrackMinimapView.MAP_PADDING + 0.1
			)
		_check(
			all_points_fit,
			"%s minimap fits without clipping." % variant_name.capitalize()
		)

	var proportional_data := _make_minimap_data(
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(100.0, 0.0),
			Vector2(100.0, 60.0),
			Vector2(0.0, 60.0),
		])
	)
	view.set_minimap_data(proportional_data)
	var origin := view._map_point_to_screen(Vector2.ZERO)
	var horizontal_scale := (
		view._map_point_to_screen(Vector2.RIGHT) - origin
	).length()
	var vertical_scale := (
		view._map_point_to_screen(Vector2.DOWN) - origin
	).length()
	_check(
		is_equal_approx(horizontal_scale, vertical_scale),
		"Minimap uses one uniform scale without deformation."
	)
	view.queue_free()
	await process_frame


func _make_minimap_data(
	points: PackedVector2Array
) -> TrackMinimapData:
	var data := TrackMinimapData.new()
	data.route_points = points
	data.start_position = points[0]
	data.start_direction = (points[1] - points[0]).normalized()
	data.length_meters = 100.0
	return data


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
