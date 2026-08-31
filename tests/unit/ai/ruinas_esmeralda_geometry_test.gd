extends SceneTree

const TRACK_SCENE := preload("res://levels/tracks/ruinas_esmeralda.tscn")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var track := TRACK_SCENE.instantiate() as TrackLevel
	_check(track != null, "Ruinas Esmeralda instantiates for geometry checks.")
	if track == null:
		quit(1)
		return
	root.add_child(track)
	await process_frame

	var road := track.get_node_or_null("MainRoad") as MeshInstance3D
	var faces := road.mesh.get_faces() if road != null and road.mesh != null else PackedVector3Array()
	var minimum_normal_y := 1.0
	var finite_faces := true
	for face_index in range(0, faces.size(), 3):
		var first: Vector3 = faces[face_index]
		var second: Vector3 = faces[face_index + 1]
		var third: Vector3 = faces[face_index + 2]
		var normal := (second - first).cross(third - first).normalized()
		minimum_normal_y = minf(minimum_normal_y, normal.y)
		finite_faces = finite_faces and is_finite(normal.x) and is_finite(normal.y) and is_finite(normal.z)
	_check(
		faces.size() > 0 and finite_faces and minimum_normal_y >= 0.5,
		"Ruinas Esmeralda road faces remain finite and upward-facing."
	)

	var collision_body := track.get_node_or_null("MainRoadCollision") as StaticBody3D
	var authored_shape := (
		(collision_body.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
		if collision_body != null and collision_body.get_child_count() > 0
		else null
	)
	_check(
			authored_shape != null
			and authored_shape.backface_collision
			and collision_body != null
			and collision_body.get_child_count() == 1
			and not (collision_body.get_child(0) as CollisionShape3D).disabled,
		"Ruinas Esmeralda uses one continuous road collision surface."
	)

	var line := RacingLineBuilder.build(track.route_points, [], "ruinas-geometry")
	var has_section_63 := false
	var has_section_64 := false
	for sample in line.samples:
		has_section_63 = has_section_63 or sample.section_id == 63
		has_section_64 = has_section_64 or sample.section_id == 64
	_check(has_section_63 and has_section_64, "Racing-line sections 63/64 remain addressable.")

	track.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
