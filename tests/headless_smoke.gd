extends SceneTree

var _has_failed := false
var _shortcut_was_accepted := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_check(packed_scene != null, "Main scene loads.")
	if packed_scene == null:
		quit(1)
		return
	var main := packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.settings.is_persistence_enabled = false
	main.settings.best_times.clear()
	main.settings.select_track(&"coastal")
	_check(main.main_menu != null, "Main menu is created.")
	_check(
		main.main_menu.track_catalog != null
		and main.main_menu.track_catalog.tracks.size() == 2,
		"Main menu exposes both authored tracks."
	)
	_check(
		main.main_menu._track_selector != null
		and not main.main_menu._track_selector.visible,
		"Main menu keeps track choices in a separate screen."
	)
	main.main_menu._show_track_selector()
	await process_frame
	_check(
		main.main_menu._track_selector.visible,
		"Play opens the dedicated track selection screen."
	)
	var track_buttons_are_touch_friendly := true
	for track_button in main.main_menu._track_buttons.values():
		track_buttons_are_touch_friendly = (
			track_buttons_are_touch_friendly
			and (track_button as Button).custom_minimum_size.y >= 44.0
		)
	_check(
		track_buttons_are_touch_friendly,
		"Track choices use touch-friendly native buttons."
	)
	var track_buttons_are_onscreen := true
	var menu_viewport_size: Vector2 = main.main_menu.get_viewport().get_visible_rect().size
	for track_button in main.main_menu._track_buttons.values():
		var track_button_rect: Rect2 = (track_button as Button).get_global_rect()
		track_buttons_are_onscreen = (
			track_buttons_are_onscreen
			and track_button_rect.position.x >= 0.0
			and track_button_rect.position.y >= 0.0
			and track_button_rect.end.x <= menu_viewport_size.x
			and track_button_rect.end.y <= menu_viewport_size.y
		)
	_check(track_buttons_are_onscreen, "Track choices remain inside the viewport.")
	main.main_menu._select_track(&"garden")
	_check(
		main.settings.selected_track_id == &"garden",
		"Track selection is propagated to game settings."
	)
	main.main_menu._select_track(&"coastal")
	main.main_menu._hide_track_selector()
	_check(
		not main.main_menu._track_selector.visible,
		"Track selection returns to the uncluttered main menu."
	)
	await _test_scalable_track_selector()
	var isolated_settings := GameSettings.new()
	isolated_settings.is_persistence_enabled = false
	isolated_settings.register_race_time(95.0, &"coastal")
	isolated_settings.register_race_time(82.0, &"garden")
	_check(
		is_equal_approx(isolated_settings.get_best_time(&"coastal"), 95.0)
		and is_equal_approx(isolated_settings.get_best_time(&"garden"), 82.0),
		"Best times are stored independently for each track."
	)
	main.main_menu._toggle_settings()
	await process_frame
	_check(main.main_menu._settings_panel.visible, "Settings panel opens.")
	main.main_menu._toggle_settings()
	main.start_game(&"coastal", false)
	await process_frame
	await process_frame
	_check(main.race_world != null, "Race world is created.")
	if main.race_world != null:
		_check(main.race_world.race_manager.racers.size() == 4, "Four racers are registered.")
		_check(main.race_world.race_manager.route_points.size() >= 40, "Track route is complete.")
		_check(main.race_world.player_kart != null, "Player kart is available.")
		var racers_share_catalog := true
		for registered_racer in main.race_world.race_manager.racers:
			racers_share_catalog = (
				racers_share_catalog
				and registered_racer.item_catalog
				== main.race_world.item_catalog
			)
		_check(
			main.race_world.item_catalog.items.size() == 6
			and racers_share_catalog,
			"Player and bots share RaceWorld's six-item catalog."
		)
		await create_timer(4.2).timeout
		_check(
			main.race_world.race_manager.state == RaceManager.RaceState.RACING,
			"Countdown transitions to an active race."
		)
		var active_racers := 0
		for racer in main.race_world.race_manager.racers:
			if racer.is_control_enabled:
				active_racers += 1
		_check(active_racers == 4, "All racers receive control after the countdown.")
		var moving_ai := 0
		for racer_index in range(1, 4):
			var ai_racer: Node = main.race_world.race_manager.racers[racer_index]
			if Vector2(ai_racer.velocity.x, ai_racer.velocity.z).length() > 0.5:
				moving_ai += 1
		_check(moving_ai >= 2, "AI racers accelerate and follow the route.")

		var player: Kart = main.race_world.player_kart
		var track: CoastalTrack = main.race_world._track
		var manager: RaceManager = main.race_world.race_manager
		var hud: RaceHud = main.race_world._hud
		hud.set_mobile_controls_enabled(true)
		await process_frame
		_check(hud._touch_controls.visible, "Mobile controls can be enabled on a touch device.")
		var steering_pad: CoastalJoystick = hud._steering_pad
		var drift_button := hud._touch_controls.get_node("DriftButton") as MobileActionButton
		var item_button := hud._touch_controls.get_node("ItemButton") as MobileActionButton
		var brake_button := hud._touch_controls.get_node("BrakeButton") as MobileActionButton
		_check(
			steering_pad.size.x >= 240.0 and steering_pad.size.y >= 188.0,
			"Steering uses a large thumb-friendly touch area."
		)
		_check(
			drift_button.size.x >= 128.0
			and item_button.size.x >= 100.0
			and brake_button.size.x >= 96.0,
			"Mobile actions use large separated touch targets."
		)
		var viewport_size := hud.get_viewport().get_visible_rect().size
		var action_buttons := [drift_button, item_button, brake_button]
		var are_buttons_onscreen := true
		for action_button in action_buttons:
			var button_rect: Rect2 = action_button.get_global_rect()
			are_buttons_onscreen = (
				are_buttons_onscreen
				and button_rect.position.x >= 0.0
				and button_rect.position.y >= 0.0
				and button_rect.end.x <= viewport_size.x
				and button_rect.end.y <= viewport_size.y
			)
		_check(are_buttons_onscreen, "All mobile action buttons remain inside the viewport.")
		_check(Input.is_action_pressed(&"accelerate"), "Mobile controls accelerate automatically.")
		Input.action_press(&"brake")
		await process_frame
		_check(
			not Input.is_action_pressed(&"accelerate"),
			"Automatic acceleration yields while braking."
		)
		Input.action_release(&"brake")
		await process_frame
		steering_pad._begin_drag(Vector2(110.0, 94.0))
		steering_pad._update_target(Vector2(176.0, 94.0))
		steering_pad._process(0.2)
		_check(
			Input.get_action_strength(&"steer_right") > 0.45,
			"Floating steering pad produces progressive steering."
		)
		steering_pad._end_drag()
		drift_button._set_pressed(true)
		_check(Input.is_action_pressed(&"drift"), "Drift supports a sustained touch.")
		drift_button._set_pressed(false)
		hud.set_mobile_controls_enabled(false)
		await process_frame
		_check(
			not Input.is_action_pressed(&"accelerate")
			and not Input.is_action_pressed(&"steer_right")
			and not Input.is_action_pressed(&"drift"),
			"Mobile actions release safely when controls are hidden."
		)
		_check(track.get_route_length() >= 400.0, "Expanded track is at least 400 meters long.")
		_check(track.shortcut_definitions.size() == 2, "Two physical shortcuts are available.")
		for shortcut_definition in track.shortcut_definitions:
			_check(
				_is_shortcut_corridor_clear(
					track,
					shortcut_definition,
					manager.racers
				),
				"%s has a collision-free entrance and exit." % shortcut_definition.name
			)
			_check(
				_shortcut_follows_race_direction(track, shortcut_definition),
				"%s enters and rejoins in the race direction." % shortcut_definition.name
			)
			_check(
				_shortcut_barriers_clear_main_road(track, shortcut_definition),
				"%s keeps its barriers outside the main road." % shortcut_definition.name
			)
			_check(
				_shortcut_surface_is_continuous(track, shortcut_definition),
				"%s keeps continuous floor support through both seams."
				% shortcut_definition.name
			)
		_check(
			_barriers_contain_drivable_corridors(track, manager.racers),
			"Main route and shortcuts are physically contained by barriers."
		)
		_check(
			track.get_node_or_null("MainBarrierLeftCollision") != null
			and track.get_node_or_null("MainBarrierRightCollision") != null,
			"Continuous barriers protect both sides of the main route."
		)
		_check(
			(player.collision_mask & PhysicsLayers.SHORTCUTS) == 0,
			"Player ignores shortcut seams while driving on the main route."
		)
		_check(
			(player.collision_mask & PhysicsLayers.MAIN_BARRIERS) != 0
			and (
				player.collision_mask
				& PhysicsLayers.SHORTCUT_BARRIERS
			) != 0,
			"Player collides with main and shortcut barriers."
		)
		for racer_index in range(1, 4):
			var ai_kart: Kart = manager.racers[racer_index]
			_check(
				ai_kart.collision_mask == player.collision_mask,
				"%s uses the same track collisions as the player." % ai_kart.racer_name
			)

		var player_id := player.get_instance_id()
		var saved_race_data: Dictionary = manager._race_data[player_id].duplicate(true)
		var saved_transform := player.global_transform
		var shortcut: Dictionary = track.shortcut_definitions[0]
		var shortcut_test_data: Dictionary = saved_race_data.duplicate(true)
		shortcut_test_data.next_checkpoint = int(shortcut.entry_index)
		manager._race_data[player_id] = shortcut_test_data
		manager.set_process(false)
		_shortcut_was_accepted = false
		manager.shortcut_accepted.connect(
			func(accepted_kart: Node) -> void:
				if accepted_kart == player:
					_shortcut_was_accepted = true
		)
		var shortcut_points: Array[Vector3] = shortcut.points
		var shortcut_surface_was_enabled := false
		for shortcut_point in shortcut_points:
			player.global_position = shortcut_point + Vector3.UP * 0.7
			player.velocity = Vector3.ZERO
			await physics_frame
			await physics_frame
			await process_frame
			shortcut_surface_was_enabled = (
				shortcut_surface_was_enabled
				or (
					player.collision_mask
					& PhysicsLayers.SHORTCUTS
				) != 0
			)
		var shortcut_result: Dictionary = manager._race_data[player_id]
		manager.set_process(true)
		if not _shortcut_was_accepted:
			var exit_gate := track.get_node("Shortcut0ExitGate") as Area3D
			print(
				"INFO: Shortcut gate not accepted; checkpoint=%d active=%s distance=%.2f overlaps=%s."
				% [
					int(shortcut_result.next_checkpoint),
					str(track._active_shortcuts.get(player_id, "none")),
					player.global_position.distance_to(exit_gate.global_position),
					str(exit_gate.get_overlapping_bodies().map(
						func(body: Node3D) -> String: return body.name
					)),
				]
			)
		_check(
			_shortcut_was_accepted
			and int(shortcut_result.next_checkpoint) >= int(shortcut.exit_index) + 1,
			"Shortcut gate advances through its declared exit checkpoint."
		)
		_check(
			shortcut_surface_was_enabled
			and (
				player.collision_mask
				& PhysicsLayers.SHORTCUTS
			) == 0,
			"Shortcut floor activates only between its entry and exit gates."
		)
		manager._race_data[player_id] = saved_race_data
		player.global_transform = saved_transform
		player.velocity = Vector3.ZERO

		player.held_item = ItemDefinition.boost()
		player.use_item()
		_check(player.held_item == null, "Boost item is consumed.")
		var projectile_count_before: int = (
			main.race_world._projectiles.get_child_count()
		)
		player.held_item = ItemDefinition.tropical_projectile()
		player.use_item()
		_check(player.held_item == null, "Projectile item is consumed.")
		_check(
			main.race_world._projectiles.get_child_count()
			== projectile_count_before + 1
			and main.race_world._projectiles.get_child(
				projectile_count_before
			) is KartProjectile,
			"Player launches Coco turbo through the RaceWorld projectile container."
		)
		var bot: Kart = manager.racers[1]
		bot.held_item = ItemDefinition.tropical_projectile()
		bot.use_item()
		_check(
			main.race_world._projectiles.get_child_count()
			== projectile_count_before + 2,
			"Bots launch Coco turbo through the same RaceWorld flow."
		)
		main.race_world._clear_projectiles()
		_check(
			main.race_world._projectiles.get_child_count() == 0,
			"RaceWorld clears every active projectile."
		)

		for lap in manager.total_laps:
			for route_index in range(1, manager.route_points.size()):
				player.global_position = manager.route_points[route_index]
				player.velocity = Vector3.ZERO
				manager._update_racers()
				await process_frame
			player.global_position = manager.route_points[0]
			player.velocity = Vector3.ZERO
			manager._update_racers()
			await process_frame
		_check(not player.is_control_enabled, "Three valid laps finish the player race.")
		player.is_control_enabled = true
		player.held_item = ItemDefinition.tropical_projectile()
		player.use_item()
		_check(
			main.race_world._projectiles.get_child_count() == 1,
			"A projectile can be active immediately before a race restart."
		)
		main._restart_game()
		await process_frame
		await process_frame
		_check(
			main.race_world != null
			and main.race_world._projectiles.get_child_count() == 0,
			"Restarting the race replaces the world without active projectiles."
		)
	main.queue_free()
	await process_frame
	var garden_main := packed_scene.instantiate()
	root.add_child(garden_main)
	await process_frame
	await process_frame
	garden_main.settings.is_persistence_enabled = false
	garden_main.start_game(&"garden", false)
	await process_frame
	await process_frame
	var garden_world: RaceWorld = garden_main.race_world
	_check(garden_world != null, "Garden track can be selected from the catalog.")
	if garden_world != null:
		var garden_track: CoastalTrack = garden_world._track
		var garden_manager: RaceManager = garden_world.race_manager
		_check(
			garden_track.get_route_length() >= 300.0,
			"Garden track is at least 300 meters long."
		)
		_check(
			garden_track.shortcut_definitions.size() == 1,
			"Garden track exposes its authored shortcut."
		)
		_check(
			garden_track.get_node("Props").get_child_count() >= 8,
			"Garden track instantiates its CC0 asset dressing."
		)
		for garden_shortcut in garden_track.shortcut_definitions:
			_check(
				_is_shortcut_corridor_clear(
					garden_track,
					garden_shortcut,
					garden_manager.racers
				),
				"%s is open for the player kart." % garden_shortcut.name
			)
			_check(
				_shortcut_follows_race_direction(garden_track, garden_shortcut),
				"%s follows the garden race direction." % garden_shortcut.name
			)
			_check(
				_shortcut_surface_is_continuous(garden_track, garden_shortcut),
				"%s has continuous floor support." % garden_shortcut.name
			)
		_check(
			_barriers_contain_drivable_corridors(
				garden_track,
				garden_manager.racers
			),
			"Garden route and shortcut are physically contained by barriers."
		)
	garden_main.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit(1 if _has_failed else 0)


func _test_scalable_track_selector() -> void:
	var catalog := TrackCatalog.new()
	var shared_scene := load("res://levels/coastal_track.tscn") as PackedScene
	for track_index in 12:
		var definition := TrackDefinition.new()
		definition.id = StringName("test_track_%d" % track_index)
		definition.display_name = "Pista %02d" % (track_index + 1)
		definition.description = "Pista para verificar el selector escalable."
		definition.scene = shared_scene
		definition.preview_color = Color.from_hsv(
			float(track_index) / 12.0,
			0.5,
			0.85
		)
		catalog.tracks.append(definition)
	var selector := TrackSelectScreen.new()
	root.add_child(selector)
	await process_frame
	selector.configure(catalog, {}, &"test_track_0")
	await process_frame
	_check(
		selector.track_buttons.size() == 12
		and selector.find_child("TrackScroll", true, false) is ScrollContainer,
		"Track selection scales to many published tracks using a scrollable list."
	)
	selector.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)


func _is_shortcut_corridor_clear(
	track: CoastalTrack,
	shortcut_definition: Dictionary,
	racers: Array[Node]
) -> bool:
	var probe_shape := BoxShape3D.new()
	probe_shape.size = Vector3(1.55, 0.72, 2.35)
	var excluded_rids: Array[RID] = []
	for racer_node in racers:
		if racer_node is CollisionObject3D:
			excluded_rids.append((racer_node as CollisionObject3D).get_rid())
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe_shape
	query.collision_mask = PhysicsLayers.BARRIERS
	query.collide_with_areas = false
	query.exclude = excluded_rids
	var shortcut_points: Array[Vector3] = shortcut_definition.points
	var drive_points: Array[Vector3] = []
	var route_size := track.route_points.size()
	var entry_index: int = shortcut_definition.entry_index
	var exit_index: int = shortcut_definition.exit_index
	for route_offset in range(-3, 1):
		drive_points.append(
			track.route_points[(entry_index + route_offset + route_size) % route_size]
		)
	for shortcut_point in shortcut_points:
		if drive_points.back().distance_to(shortcut_point) > 0.01:
			drive_points.append(shortcut_point)
	for route_offset in range(1, 4):
		drive_points.append(track.route_points[(exit_index + route_offset) % route_size])
	var space_state := track.get_world_3d().direct_space_state
	for lateral_offset in [-3.0, 0.0, 3.0]:
		var lane_offset := float(lateral_offset)
		for point_index in drive_points.size() - 1:
			var previous_index := maxi(point_index - 1, 0)
			var following_index := mini(point_index + 1, drive_points.size() - 1)
			var current_forward := (
				drive_points[following_index] - drive_points[previous_index]
			)
			current_forward.y = 0.0
			current_forward = current_forward.normalized()
			var next_following_index := mini(point_index + 2, drive_points.size() - 1)
			var next_forward := (
				drive_points[next_following_index] - drive_points[point_index]
			)
			next_forward.y = 0.0
			next_forward = next_forward.normalized()
			var current_right := Vector3.UP.cross(current_forward)
			var next_right := Vector3.UP.cross(next_forward)
			var start: Vector3 = (
				drive_points[point_index]
				+ current_right * lane_offset
				+ Vector3.UP * 0.72
			)
			var end: Vector3 = (
				drive_points[point_index + 1]
				+ next_right * lane_offset
				+ Vector3.UP * 0.72
			)
			query.transform = Transform3D(Basis.looking_at(current_forward), start)
			query.motion = end - start
			var motion_fractions := space_state.cast_motion(query)
			if motion_fractions[0] < 0.98:
				var blocked_transform := query.transform
				blocked_transform.origin += query.motion * minf(
					motion_fractions[0] + 0.04,
					1.0
				)
				query.transform = blocked_transform
				query.motion = Vector3.ZERO
				var blockers := space_state.intersect_shape(query, 8)
				var blocker_names: Array[String] = []
				for blocker in blockers:
					var collider := blocker.get("collider") as Node
					if collider != null:
						blocker_names.append(collider.name)
				print(
					"INFO: %s lane %.1f blocked at segment %d (safe motion %.3f) by %s."
					% [
						shortcut_definition.name,
						lane_offset,
						point_index,
						motion_fractions[0],
						", ".join(blocker_names),
					]
				)
				return false
	return true


func _barriers_contain_drivable_corridors(
	track: CoastalTrack,
	racers: Array[Node]
) -> bool:
	var probe_shape := CapsuleShape3D.new()
	probe_shape.radius = 0.7
	probe_shape.height = 1.35
	var excluded_rids: Array[RID] = []
	for racer_node in racers:
		if racer_node is CollisionObject3D:
			excluded_rids.append((racer_node as CollisionObject3D).get_rid())
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe_shape
	query.collision_mask = PhysicsLayers.BARRIERS
	query.collide_with_areas = false
	query.exclude = excluded_rids
	var space_state := track.get_world_3d().direct_space_state
	for route_index in range(0, track.route_points.size(), 2):
		var route_forward := (
			track.route_points[(route_index + 1) % track.route_points.size()]
			- track.route_points[
				(route_index - 1 + track.route_points.size()) % track.route_points.size()
			]
		)
		route_forward.y = 0.0
		var route_right := Vector3.UP.cross(route_forward.normalized())
		for side in [-1.0, 1.0]:
			if not _motion_hits_barrier(
				space_state,
				query,
				track.route_points[route_index] + Vector3.UP * 0.82,
				route_right * side * 60.0
			):
				var escape_start := (
					track.route_points[route_index] + Vector3.UP * 0.82
				)
				var escape_motion: Vector3 = route_right * float(side) * 60.0
				var ray_query := PhysicsRayQueryParameters3D.create(
					escape_start,
					escape_start + escape_motion,
					PhysicsLayers.BARRIERS
				)
				ray_query.collide_with_areas = false
				var ray_hit := space_state.intersect_ray(ray_query)
				print(
					"INFO: Main route can escape at point %d on side %.0f from %s toward %s; ray=%s."
					% [
						route_index,
						side,
						track.route_points[route_index],
						route_right * side,
						ray_hit,
					]
				)
				return false
	for shortcut_definition in track.shortcut_definitions:
		var shortcut_points: Array[Vector3] = shortcut_definition.points
		for point_index in range(2, shortcut_points.size() - 2, 2):
			var shortcut_forward := (
				shortcut_points[point_index + 1] - shortcut_points[point_index - 1]
			)
			shortcut_forward.y = 0.0
			var shortcut_right := Vector3.UP.cross(shortcut_forward.normalized())
			for side in [-1.0, 1.0]:
				if not _motion_hits_barrier(
					space_state,
					query,
					shortcut_points[point_index] + Vector3.UP * 0.82,
					shortcut_right * side * 50.0
				):
					print(
						"INFO: %s can escape at point %d on side %.0f."
						% [shortcut_definition.name, point_index, side]
					)
					return false
	return true


func _shortcut_surface_is_continuous(
	track: CoastalTrack,
	shortcut_definition: Dictionary
) -> bool:
	var shortcut_points: Array[Vector3] = shortcut_definition.points
	var space_state := track.get_world_3d().direct_space_state
	for point_index in shortcut_points.size() - 1:
		for subdivision in 5:
			var weight := float(subdivision) / 5.0
			var sample_position := shortcut_points[point_index].lerp(
				shortcut_points[point_index + 1],
				weight
			)
			var query := PhysicsRayQueryParameters3D.create(
				sample_position + Vector3.UP * 0.8,
				sample_position - Vector3.UP * 0.8,
				PhysicsLayers.DRIVABLE_SURFACES
			)
			query.collide_with_areas = false
			var floor_hit := space_state.intersect_ray(query)
			if floor_hit.is_empty():
				print(
					"INFO: %s has no floor at segment %d subdivision %d."
					% [shortcut_definition.name, point_index, subdivision]
				)
				return false
			var floor_position: Vector3 = floor_hit.position
			if absf(floor_position.y - sample_position.y) > 0.2:
				var floor_collider := floor_hit.get("collider") as Node
				print(
					"INFO: %s floor drops %.2f m at segment %d subdivision %d on %s."
					% [
						shortcut_definition.name,
						absf(floor_position.y - sample_position.y),
						point_index,
						subdivision,
						floor_collider.name if floor_collider != null else "unknown",
					]
				)
				return false
	return true


func _motion_hits_barrier(
	space_state: PhysicsDirectSpaceState3D,
	query: PhysicsShapeQueryParameters3D,
	start: Vector3,
	motion: Vector3
) -> bool:
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.motion = motion
	var motion_fractions := space_state.cast_motion(query)
	return motion_fractions[0] < 0.98


func _shortcut_follows_race_direction(
	track: CoastalTrack,
	shortcut_definition: Dictionary
) -> bool:
	var route_size := track.route_points.size()
	var entry_index: int = shortcut_definition.entry_index
	var exit_index: int = shortcut_definition.exit_index
	var shortcut_points: Array[Vector3] = shortcut_definition.points
	var entry_forward: Vector3 = (
		track.route_points[(entry_index + 1) % route_size]
		- track.route_points[(entry_index - 1 + route_size) % route_size]
	)
	var exit_forward: Vector3 = (
		track.route_points[(exit_index + 1) % route_size]
		- track.route_points[(exit_index - 1 + route_size) % route_size]
	)
	var shortcut_entry_forward: Vector3 = shortcut_points[2] - shortcut_points[0]
	var shortcut_exit_forward: Vector3 = (
		shortcut_points.back()
		- shortcut_points[shortcut_points.size() - 3]
	)
	entry_forward.y = 0.0
	exit_forward.y = 0.0
	shortcut_entry_forward.y = 0.0
	shortcut_exit_forward.y = 0.0
	entry_forward = entry_forward.normalized()
	exit_forward = exit_forward.normalized()
	shortcut_entry_forward = shortcut_entry_forward.normalized()
	shortcut_exit_forward = shortcut_exit_forward.normalized()
	return (
		entry_forward.dot(shortcut_entry_forward) > 0.8
		and exit_forward.dot(shortcut_exit_forward) > 0.8
	)


func _shortcut_barriers_clear_main_road(
	track: CoastalTrack,
	shortcut_definition: Dictionary
) -> bool:
	var shortcut_points: Array[Vector3] = shortcut_definition.points
	var minimum_clearance := INF
	var minimum_point_index := -1
	for point_index in range(8, shortcut_points.size() - 8):
		for side in [-1.0, 1.0]:
			var barrier_point: Vector3 = track._offset_path_point(
				shortcut_points,
				point_index,
				side * CoastalTrack.SHORTCUT_WIDTH * 0.5,
				0.0,
				false
			)
			var clearance := _distance_to_route(barrier_point, track.route_points)
			if clearance < minimum_clearance:
				minimum_clearance = clearance
				minimum_point_index = point_index
	if minimum_clearance < 9.5:
		print(
			"INFO: %s barrier approaches main road by %.2f m at point %d."
			% [shortcut_definition.name, minimum_clearance, minimum_point_index]
		)
		return false
	return true


func _distance_to_route(point: Vector3, route: Array[Vector3]) -> float:
	var flattened_point := Vector2(point.x, point.z)
	var minimum_distance := INF
	for route_index in route.size():
		var segment_start := Vector2(route[route_index].x, route[route_index].z)
		var next_route_index := (route_index + 1) % route.size()
		var segment_end := Vector2(route[next_route_index].x, route[next_route_index].z)
		var segment := segment_end - segment_start
		var segment_length_squared := segment.length_squared()
		var weight := 0.0
		if segment_length_squared > 0.001:
			weight = clampf(
				(flattened_point - segment_start).dot(segment) / segment_length_squared,
				0.0,
				1.0
			)
		var closest_point := segment_start + segment * weight
		minimum_distance = minf(
			minimum_distance,
			flattened_point.distance_to(closest_point)
		)
	return minimum_distance
