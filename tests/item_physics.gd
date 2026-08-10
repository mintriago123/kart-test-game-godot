extends SceneTree

class TestKart:
	extends CharacterBody3D

	var hit_count := 0
	var last_hit_duration := 0.0

	func configure() -> void:
		collision_layer = PhysicsLayers.KARTS
		collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.6
		collision.shape = shape
		add_child(collision)

	func receive_hit(duration: float) -> void:
		hit_count += 1
		last_hit_duration = duration


var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_item_profiles()
	await _test_visual_presentation()
	_test_reflection_and_retention()
	await _test_continuous_collision_rates()
	await _test_barrier_layers()
	await _test_barrier_responses()
	await _test_bounce_limit()
	await _test_owner_immunity_and_self_hit()
	await _test_single_impact()
	await _test_ground_following()
	await _test_cleanup_conditions()
	quit(1 if _has_failed else 0)


func _test_item_profiles() -> void:
	var boost := ItemDefinition.boost()
	var coconut := ItemDefinition.tropical_projectile()
	_check(
		is_equal_approx(boost.boost_duration, 1.25)
		and is_equal_approx(boost.boost_power, 11.0),
		"Boost keeps explicit duration and power settings."
	)
	_check(
		coconut.barrier_response == ItemDefinition.BarrierResponse.BOUNCE
		and is_equal_approx(coconut.projectile_speed, 31.0)
		and is_equal_approx(coconut.projectile_duration, 4.0)
		and is_equal_approx(coconut.projectile_impact_duration, 1.1)
		and coconut.projectile_max_bounces == 3
		and is_equal_approx(coconut.projectile_speed_retention, 0.88)
		and is_equal_approx(coconut.projectile_owner_immunity, 0.25),
		"Coco turbo uses its configured arcade physics profile."
	)
	var pineapple := ItemDefinition.homing_pineapple()
	var peel := ItemDefinition.slippery_peel()
	_check(
		is_equal_approx(coconut.world_visual_diameter, 0.96)
		and coconut.show_ground_shadow
		and coconut.show_motion_trail
		and is_equal_approx(pineapple.world_visual_diameter, 1.0)
		and pineapple.show_ground_shadow
		and pineapple.show_motion_trail
		and is_equal_approx(peel.world_visual_diameter, 1.3)
		and peel.show_ground_shadow
		and not peel.show_motion_trail,
		"Coco, pineapple, and peel expose their calibrated presentation flags."
	)


func _test_visual_presentation() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var definitions := [
		ItemDefinition.tropical_projectile(),
		ItemDefinition.homing_pineapple(),
	]
	for definition in definitions:
		var projectile := KartProjectile.new()
		projectile.setup(null, definition, Vector3.FORWARD)
		projectile.set_physics_process(false)
		fixture.add_child(projectile)
		var visual := projectile.get_node_or_null("ItemVisual") as Node3D
		var bounds_result := Node3DBounds.get_node_aabb(visual)
		var largest_dimension := _get_largest_dimension(
			bounds_result.aabb if bool(bounds_result.valid) else AABB()
		)
		var collision := _find_collision_shape(projectile)
		_check(
			bool(bounds_result.valid)
			and absf(largest_dimension - definition.world_visual_diameter)
			<= definition.world_visual_diameter * 0.1
			and collision != null
			and is_equal_approx(
				(collision.shape as SphereShape3D).radius,
				definition.projectile_radius
			),
			"%s stays within 10%% of %.2f m without changing collision radius (%.3f m)."
			% [
				definition.display_name,
				definition.world_visual_diameter,
				largest_dimension,
			]
		)
		var shadow := projectile.get_node_or_null("GroundShadow") as MeshInstance3D
		var trail := projectile.get_node_or_null("MotionTrail") as GPUParticles3D
		_check(
			shadow != null
			and shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and trail != null
			and not trail.local_coords,
			"%s has a non-colliding ground shadow and world-space trail."
			% definition.display_name
		)

	var peel_definition := ItemDefinition.slippery_peel()
	var trap := ItemTrap.new()
	trap.setup(null, peel_definition)
	trap.set_physics_process(false)
	fixture.add_child(trap)
	var peel_visual := trap.get_node_or_null("ItemVisual") as Node3D
	var peel_bounds_result := Node3DBounds.get_node_aabb(peel_visual)
	var peel_largest_dimension := _get_largest_dimension(
		peel_bounds_result.aabb if bool(peel_bounds_result.valid) else AABB()
	)
	var trap_collision := _find_collision_shape(trap)
	_check(
		bool(peel_bounds_result.valid)
		and absf(peel_largest_dimension - 1.3) <= 0.13
		and trap_collision != null
		and is_equal_approx(
			(trap_collision.shape as SphereShape3D).radius,
			0.65
		),
		"Cáscara resbalosa measures 1.30 m and preserves its 0.65 m radius (%.3f m)."
		% peel_largest_dimension
	)
	var peel_shadow := trap.get_node_or_null("GroundShadow") as MeshInstance3D
	_check(
		peel_shadow != null
		and peel_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and trap.get_node_or_null("MotionTrail") == null,
		"Cáscara resbalosa has only its non-colliding ground shadow."
	)
	await _free_fixture(fixture)


func _get_largest_dimension(bounds: AABB) -> float:
	return maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))


func _find_collision_shape(parent: Node) -> CollisionShape3D:
	for child in parent.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


func _test_reflection_and_retention() -> void:
	var reflected := KartProjectile.calculate_bounce_velocity(
		Vector3(10.0, 0.0, 0.0),
		Vector3.LEFT,
		0.88
	)
	_check(
		reflected.is_equal_approx(Vector3(-8.8, 0.0, 0.0)),
		"Barrier reflection reverses the normal component and retains 88% speed."
	)


func _test_continuous_collision_rates() -> void:
	for physics_fps in [15, 30, 60]:
		var fixture := Node3D.new()
		root.add_child(fixture)
		_add_floor(
			fixture,
			Vector3(0.0, -0.1, 0.0),
			Vector3(30.0, 0.2, 8.0),
			PhysicsLayers.WORLD
		)
		_add_wall(fixture, 3.0, PhysicsLayers.MAIN_BARRIERS)
		var projectile := _add_projectile(
			fixture,
			null,
			Vector3(0.0, 0.48, 0.0),
			Vector3.RIGHT
		)
		await physics_frame
		var delta := 1.0 / float(physics_fps)
		for _step in ceili(0.15 / delta):
			projectile._physics_process(delta)
		_check(
			projectile.bounce_count == 1 and projectile.velocity.x < 0.0,
			"Swept movement hits a barrier at %d FPS." % physics_fps
		)
		await _free_fixture(fixture)


func _test_barrier_layers() -> void:
	for barrier_layer in [
		PhysicsLayers.MAIN_BARRIERS,
		PhysicsLayers.SHORTCUT_BARRIERS,
	]:
		var fixture := Node3D.new()
		root.add_child(fixture)
		_add_floor(
			fixture,
			Vector3(0.0, -0.1, 0.0),
			Vector3(20.0, 0.2, 8.0),
			PhysicsLayers.WORLD
		)
		_add_wall(fixture, 2.5, barrier_layer)
		var projectile := _add_projectile(
			fixture,
			null,
			Vector3(0.0, 0.48, 0.0),
			Vector3.RIGHT
		)
		await physics_frame
		projectile._physics_process(0.1)
		_check(
			projectile.bounce_count == 1 and projectile.velocity.x < 0.0,
			"Coco turbo bounces on layer %d." % barrier_layer
		)
		await _free_fixture(fixture)


func _test_barrier_responses() -> void:
	for response in [
		ItemDefinition.BarrierResponse.DESTROY,
		ItemDefinition.BarrierResponse.STICK,
		ItemDefinition.BarrierResponse.IGNORE,
	]:
		var fixture := Node3D.new()
		root.add_child(fixture)
		_add_floor(
			fixture,
			Vector3(0.0, -0.1, 0.0),
			Vector3(20.0, 0.2, 8.0),
			PhysicsLayers.WORLD
		)
		_add_wall(fixture, 2.5, PhysicsLayers.MAIN_BARRIERS)
		var definition := ItemDefinition.tropical_projectile()
		definition.barrier_response = response
		var projectile := _add_projectile(
			fixture,
			null,
			Vector3(0.0, 0.48, 0.0),
			Vector3.RIGHT,
			definition
		)
		await physics_frame
		projectile._physics_process(0.1)
		match response:
			ItemDefinition.BarrierResponse.DESTROY:
				_check(
					projectile.is_queued_for_deletion(),
					"Destroy response removes the projectile on a barrier."
				)
			ItemDefinition.BarrierResponse.STICK:
				_check(
					not projectile.is_queued_for_deletion()
					and projectile._is_stuck
					and projectile.velocity.is_zero_approx(),
					"Stick response stops the projectile on a barrier."
				)
			ItemDefinition.BarrierResponse.IGNORE:
				_check(
					not projectile.is_queued_for_deletion()
					and projectile.global_position.x > 2.5
					and projectile.bounce_count == 0,
					"Ignore response passes through barriers."
				)
		await _free_fixture(fixture)


func _test_bounce_limit() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var projectile := _add_projectile(
		fixture,
		null,
		Vector3.ZERO,
		Vector3.RIGHT
	)
	var successful_bounces := 0
	for bounce_index in 3:
		var normal := Vector3.LEFT if bounce_index % 2 == 0 else Vector3.RIGHT
		if projectile._bounce_from_barrier(normal):
			successful_bounces += 1
	var fourth_bounce_succeeded := projectile._bounce_from_barrier(Vector3.LEFT)
	_check(
		successful_bounces == 3
		and not fourth_bounce_succeeded
		and projectile.is_queued_for_deletion(),
		"Three bounces are allowed and the fourth collision destroys the projectile."
	)
	await _free_fixture(fixture)


func _test_owner_immunity_and_self_hit() -> void:
	var immunity_fixture := Node3D.new()
	root.add_child(immunity_fixture)
	_add_floor(
		immunity_fixture,
		Vector3(0.0, -0.1, 0.0),
		Vector3(30.0, 0.2, 8.0),
		PhysicsLayers.WORLD
	)
	var immune_owner := _add_test_kart(
		immunity_fixture,
		Vector3(0.0, 0.48, 0.0)
	)
	var immune_projectile := _add_projectile(
		immunity_fixture,
		immune_owner,
		Vector3(-2.0, 0.48, 0.0),
		Vector3.RIGHT
	)
	await physics_frame
	for _step in 3:
		immune_projectile._physics_process(0.1)
	_check(
		immune_owner.hit_count == 0 and immune_projectile.global_position.x > 1.0,
		"The launcher is ignored during the initial immunity window."
	)
	await _free_fixture(immunity_fixture)

	var rebound_fixture := Node3D.new()
	root.add_child(rebound_fixture)
	_add_floor(
		rebound_fixture,
		Vector3(0.0, -0.1, 0.0),
		Vector3(30.0, 0.2, 8.0),
		PhysicsLayers.WORLD
	)
	_add_wall(rebound_fixture, 7.0, PhysicsLayers.MAIN_BARRIERS)
	var rebound_owner := _add_test_kart(
		rebound_fixture,
		Vector3(0.0, 0.48, 0.0)
	)
	var rebound_projectile := _add_projectile(
		rebound_fixture,
		rebound_owner,
		Vector3(2.0, 0.48, 0.0),
		Vector3.RIGHT
	)
	await physics_frame
	for _step in 48:
		if rebound_projectile.is_queued_for_deletion():
			break
		rebound_projectile._physics_process(1.0 / 60.0)
	_check(
		rebound_owner.hit_count == 1
		and is_equal_approx(rebound_owner.last_hit_duration, 1.1),
		"A reflected Coco can hit its launcher after immunity expires."
	)
	await _free_fixture(rebound_fixture)


func _test_single_impact() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var target := _add_test_kart(fixture, Vector3.ZERO)
	var projectile := _add_projectile(
		fixture,
		null,
		Vector3.ZERO,
		Vector3.RIGHT
	)
	projectile._hit_kart(target)
	projectile._hit_kart(target)
	_check(
		target.hit_count == 1 and projectile.is_queued_for_deletion(),
		"Each projectile applies its impact to a kart only once."
	)
	await _free_fixture(fixture)


func _test_ground_following() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	_add_floor(
		fixture,
		Vector3(0.0, -0.1, 0.0),
		Vector3(5.0, 0.2, 5.0),
		PhysicsLayers.WORLD
	)
	_add_floor(
		fixture,
		Vector3(10.0, 1.9, 0.0),
		Vector3(5.0, 0.2, 5.0),
		PhysicsLayers.WORLD
	)
	_add_floor(
		fixture,
		Vector3(20.0, 0.9, 0.0),
		Vector3(5.0, 0.2, 5.0),
		PhysicsLayers.SHORTCUTS
	)
	var projectile := _add_projectile(
		fixture,
		null,
		Vector3(0.0, 2.0, 0.0),
		Vector3.RIGHT
	)
	await physics_frame
	var ground_cases := [
		[Vector3(0.0, 2.0, 0.0), 0.48, "flat main road"],
		[Vector3(10.0, 3.0, 0.0), 2.48, "elevated main road"],
		[Vector3(20.0, 2.0, 0.0), 1.48, "shortcut surface"],
	]
	for ground_case in ground_cases:
		projectile.global_position = ground_case[0]
		var has_ground := projectile._follow_ground(0.016)
		_check(
			has_ground
			and is_equal_approx(
				projectile.global_position.y,
				float(ground_case[1])
			),
			"Coco turbo follows the %s." % ground_case[2]
		)
	await _free_fixture(fixture)


func _test_cleanup_conditions() -> void:
	var lifetime_fixture := Node3D.new()
	root.add_child(lifetime_fixture)
	_add_floor(
		lifetime_fixture,
		Vector3(0.0, -0.1, 0.0),
		Vector3(10.0, 0.2, 8.0),
		PhysicsLayers.WORLD
	)
	var short_definition := ItemDefinition.tropical_projectile()
	short_definition.projectile_duration = 0.1
	var short_lived := _add_projectile(
		lifetime_fixture,
		null,
		Vector3(0.0, 0.48, 0.0),
		Vector3.RIGHT,
		short_definition
	)
	await physics_frame
	short_lived._physics_process(0.11)
	_check(
		short_lived.is_queued_for_deletion(),
		"Projectile is removed when its configured duration expires."
	)
	await _free_fixture(lifetime_fixture)

	var gap_fixture := Node3D.new()
	root.add_child(gap_fixture)
	var unsupported := _add_projectile(
		gap_fixture,
		null,
		Vector3(0.0, 2.0, 0.0),
		Vector3.RIGHT
	)
	await physics_frame
	unsupported._physics_process(0.26)
	var survived_short_gap := not unsupported.is_queued_for_deletion()
	unsupported._physics_process(0.26)
	_check(
		survived_short_gap and unsupported.is_queued_for_deletion(),
		"Projectile tolerates a short seam and is removed after 0.5 seconds without ground."
	)
	await _free_fixture(gap_fixture)

	var pause_fixture := Node3D.new()
	root.add_child(pause_fixture)
	_add_floor(
		pause_fixture,
		Vector3(0.0, -0.1, 0.0),
		Vector3(10.0, 0.2, 8.0),
		PhysicsLayers.WORLD
	)
	var paused_projectile := _add_projectile(
		pause_fixture,
		null,
		Vector3(0.0, 0.48, 0.0),
		Vector3.RIGHT
	)
	paused_projectile.set_physics_process(true)
	await physics_frame
	var life_before_pause := paused_projectile.get_remaining_life()
	paused = true
	await create_timer(0.12, true, false, true).timeout
	var life_after_pause := paused_projectile.get_remaining_life()
	paused = false
	_check(
		is_equal_approx(life_before_pause, life_after_pause),
		"Pausing the race freezes projectile lifetime and motion."
	)
	await _free_fixture(pause_fixture)


func _add_projectile(
	parent: Node3D,
	owner: Node3D,
	projectile_position: Vector3,
	direction: Vector3,
	definition: ItemDefinition = null
) -> KartProjectile:
	var projectile := KartProjectile.new()
	projectile.setup(
		owner,
		definition if definition != null else ItemDefinition.tropical_projectile(),
		direction
	)
	parent.add_child(projectile)
	projectile.global_position = projectile_position
	projectile.set_physics_process(false)
	return projectile


func _add_test_kart(parent: Node3D, kart_position: Vector3) -> TestKart:
	var kart := TestKart.new()
	kart.configure()
	parent.add_child(kart)
	kart.global_position = kart_position
	return kart


func _add_floor(
	parent: Node3D,
	floor_position: Vector3,
	size: Vector3,
	layer: int
) -> StaticBody3D:
	return _add_static_box(parent, floor_position, size, layer)


func _add_wall(parent: Node3D, wall_x: float, layer: int) -> StaticBody3D:
	return _add_static_box(
		parent,
		Vector3(wall_x, 1.5, 0.0),
		Vector3(0.2, 3.0, 8.0),
		layer
	)


func _add_static_box(
	parent: Node3D,
	body_position: Vector3,
	size: Vector3,
	layer: int
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = PhysicsLayers.PROJECTILES
	body.position = body_position
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _free_fixture(fixture: Node) -> void:
	fixture.queue_free()
	await process_frame
	await physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
