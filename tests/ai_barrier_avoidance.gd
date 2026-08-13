extends SceneTree

var _failures := 0
var _fixture: Node3D
var _kart: Kart
var _driver: AiDriver


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_fixture = Node3D.new()
	root.add_child(_fixture)
	_kart = Kart.new()
	_fixture.add_child(_kart)
	_driver = AiDriver.new()
	_fixture.add_child(_driver)
	_driver.kart = _kart
	await physics_frame

	var clear := _driver._sense_barriers(0.0)
	_check(_all_clear(clear), "A clear corridor leaves all three sensors open.")

	var front_wall := _add_wall(Vector3(0.0, 0.55, -1.0), Vector3(4.0, 1.5, 0.3))
	await physics_frame
	var front := _driver._sense_barriers(0.0)
	_check(float(front.front) < 1.0, "A frontal barrier is detected.")
	_check(
		_driver._apply_barrier_steering(0.0, front, Vector3.FORWARD) != 0.0,
		"A frontal barrier produces an avoidance turn."
	)
	front_wall.queue_free()
	await physics_frame

	var left_wall := _add_wall(Vector3(-1.1, 0.55, -0.3), Vector3(0.4, 1.5, 2.0))
	await physics_frame
	var left := _driver._sense_barriers(0.0)
	_check(float(left.left) < float(left.right), "The left sensor isolates a left barrier.")
	_check(
		_driver._apply_barrier_steering(0.0, left, Vector3.FORWARD) > 0.0,
		"A left barrier steers toward the free right side."
	)
	left_wall.queue_free()
	await physics_frame

	var right_wall := _add_wall(Vector3(1.1, 0.55, -0.3), Vector3(0.4, 1.5, 2.0))
	await physics_frame
	var right := _driver._sense_barriers(0.0)
	_check(float(right.right) < float(right.left), "The right sensor isolates a right barrier.")
	_check(
		_driver._apply_barrier_steering(0.0, right, Vector3.FORWARD) < 0.0,
		"A right barrier steers toward the free left side."
	)
	right_wall.queue_free()

	_fixture.queue_free()
	if _failures == 0:
		print("AI barrier avoidance tests passed.")
		quit(0)
	else:
		push_error("%d AI barrier avoidance tests failed." % _failures)
		quit(1)


func _add_wall(position: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.MAIN_BARRIERS
	wall.collision_mask = 0
	wall.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	_fixture.add_child(wall)
	return wall


func _all_clear(sensors: Dictionary) -> bool:
	return (
		is_equal_approx(float(sensors.front), 1.0)
		and is_equal_approx(float(sensors.left), 1.0)
		and is_equal_approx(float(sensors.right), 1.0)
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures += 1
	push_error("FAIL: " + message)
