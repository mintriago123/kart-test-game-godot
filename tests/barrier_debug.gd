extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path in [
		"res://levels/coastal_track.tscn",
		"res://levels/garden_track.tscn",
	]:
		var track := (load(scene_path) as PackedScene).instantiate() as TrackLevel
		root.add_child(track)
		await process_frame
		print("TRACK ", track.display_name)
		for lateral_offset in [
			-CoastalTrack.ROAD_WIDTH * 0.5 + CoastalTrack.BARRIER_PATH_INSET,
			CoastalTrack.ROAD_WIDTH * 0.5 - CoastalTrack.BARRIER_PATH_INSET,
		]:
			print("SIDE ", lateral_offset, " ", track._build_main_barrier_portals(lateral_offset))
		for shortcut in track.shortcut_definitions:
			var points: Array[Vector3] = shortcut.points
			for data in [
				[points[0], points[mini(CoastalTrack.SHORTCUT_PORTAL_SEGMENTS, points.size() - 1)] - points[0]],
				[points[-1], points[maxi(points.size() - 1 - CoastalTrack.SHORTCUT_PORTAL_SEGMENTS, 0)] - points[-1]],
			]:
				var location := track._get_closest_route_location(data[0])
				var right := Vector3.UP.cross(location.forward).normalized()
				print(
					"  ",
					shortcut.name,
					" progress=",
					location.progress,
					" side=",
					signf((data[1] as Vector3).dot(right)),
					" cross=",
					absf(
						Vector2(location.forward.x, location.forward.z).cross(
							Vector2((data[1] as Vector3).normalized().x, (data[1] as Vector3).normalized().z)
						)
					)
				)
			var ring := track._build_miter_barrier_ring(
				track.route_points,
				CoastalTrack.ROAD_WIDTH * 0.5 - CoastalTrack.BARRIER_PATH_INSET
			)
			var portals := track._build_main_barrier_portals(
				CoastalTrack.ROAD_WIDTH * 0.5 - CoastalTrack.BARRIER_PATH_INSET
			)
			var chains := track._split_barrier_ring(ring, portals)
			for point_index in range(0, points.size(), 2):
				var forward := (
					points[mini(point_index + 1, points.size() - 1)]
					- points[maxi(point_index - 1, 0)]
				).normalized()
				var lane_point := points[point_index] + Vector3.UP.cross(forward) * -3.0
				var closest := INF
				for chain_value in chains:
					var chain := chain_value as PackedVector3Array
					for chain_index in chain.size() - 1:
						closest = minf(
							closest,
							track._point_to_segment_distance_2d(
								Vector2(lane_point.x, lane_point.z),
								Vector2(chain[chain_index].x, chain[chain_index].z),
								Vector2(chain[chain_index + 1].x, chain[chain_index + 1].z)
							)
						)
				if closest < 2.0:
					print("    NEAR ", shortcut.name, " point=", point_index, " d=", closest, " p=", lane_point)
		track.queue_free()
		await process_frame
	quit()
