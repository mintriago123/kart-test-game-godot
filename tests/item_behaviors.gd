extends SceneTree

class ResultKart:
	extends CharacterBody3D

	var hit_count := 0
	var next_result := Kart.HitResult.APPLIED

	func configure() -> void:
		collision_layer = PhysicsLayers.KARTS
		collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.6
		collision.shape = shape
		add_child(collision)

	func receive_hit(_duration: float) -> int:
		hit_count += 1
		return next_result


var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_shield_results_and_expiration()
	await _test_trap_owner_and_single_contact()
	await _test_trap_ground_snap_and_expiry()
	await _test_homing_turn_and_target_loss()
	await _test_wave_line_of_sight()
	await _test_executor_and_cleanup()
	await _test_pause_freezes_active_durations()
	await _test_ai_item_rules()
	await _test_hud_item_feedback()
	quit(1 if _has_failed else 0)


func _test_shield_results_and_expiration() -> void:
	var kart := Kart.new()
	root.add_child(kart)
	await process_frame
	kart.activate_shield(ItemDefinition.sea_bubble())
	var blocked := kart.receive_hit(1.0)
	var applied := kart.receive_hit(1.0)
	var ignored := kart.receive_hit(1.0)
	_check(
		blocked == Kart.HitResult.BLOCKED
		and applied == Kart.HitResult.APPLIED
		and ignored == Kart.HitResult.IGNORED,
		"Hits distinguish shield block, applied stun, and invulnerability."
	)
	kart._status_timers.clear_invulnerability()
	kart.activate_shield(ItemDefinition.sea_bubble())
	kart._update_timers(7.01)
	_check(
		is_zero_approx(kart.get_shield_remaining())
		and kart.receive_hit(0.5) == Kart.HitResult.APPLIED,
		"Sea Bubble expires after seven active seconds."
	)
	kart.queue_free()
	await process_frame


func _test_trap_owner_and_single_contact() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var owner := ResultKart.new()
	owner.configure()
	fixture.add_child(owner)
	var target := ResultKart.new()
	target.configure()
	fixture.add_child(target)
	var trap := ItemTrap.new()
	var definition := ItemDefinition.slippery_peel()
	trap.setup(owner, definition)
	fixture.add_child(trap)
	trap._handle_body_entered(owner)
	var owner_was_immune := owner.hit_count == 0
	trap._physics_process(0.76)
	trap._handle_body_entered(owner)
	trap._handle_body_entered(target)
	_check(
		owner_was_immune
		and owner.hit_count == 1
		and target.hit_count == 0
		and trap.is_queued_for_deletion(),
		"Peel ignores its owner for 0.75 s, then consumes on one contact."
	)
	var ignored_trap := ItemTrap.new()
	target.next_result = Kart.HitResult.IGNORED
	ignored_trap.setup(owner, definition)
	fixture.add_child(ignored_trap)
	ignored_trap._handle_body_entered(target)
	_check(
		ignored_trap.is_queued_for_deletion(),
		"Peel is consumed even when the contacted kart is invulnerable."
	)
	fixture.queue_free()
	await process_frame


func _test_trap_ground_snap_and_expiry() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var floor := StaticBody3D.new()
	floor.collision_layer = PhysicsLayers.WORLD
	floor.collision_mask = 0
	fixture.add_child(floor)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(8.0, 0.2, 8.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor.add_child(floor_collision)
	var trap := ItemTrap.new()
	var definition := ItemDefinition.slippery_peel()
	trap.setup(null, definition)
	fixture.add_child(trap)
	await physics_frame
	var was_snapped := trap.place(Vector3(0.0, 2.0, 0.0))
	var collision := trap.get_child(0) as CollisionShape3D
	trap._physics_process(10.01)
	_check(
		was_snapped
		and is_equal_approx(trap.global_position.y, 0.08)
		and is_equal_approx(
			(collision.shape as SphereShape3D).radius,
			0.65
		)
		and trap.is_queued_for_deletion(),
		"Peel snaps to the road, uses radius 0.65 m, and expires after 10 s."
	)
	fixture.queue_free()
	await process_frame


func _test_homing_turn_and_target_loss() -> void:
	var current := Vector3.FORWARD
	var desired := Vector3.RIGHT
	var max_angle := 2.8 / 60.0
	var rotated := HomingProjectile.rotate_direction_toward(
		current,
		desired,
		max_angle
	)
	_check(
		absf(current.angle_to(rotated) - max_angle) < 0.0001,
		"Homing pineapple respects its 2.8 rad/s maximum turn."
	)
	var fixture := Node3D.new()
	root.add_child(fixture)
	var target := Node3D.new()
	fixture.add_child(target)
	target.position = Vector3(8.0, 0.0, -8.0)
	var projectile := HomingProjectile.new()
	projectile.setup_homing(
		null,
		ItemDefinition.homing_pineapple(),
		Vector3.FORWARD,
		target
	)
	fixture.add_child(projectile)
	projectile.set_physics_process(false)
	target.queue_free()
	await process_frame
	projectile._update_homing(0.1)
	_check(
		projectile.get_target() == null
		and projectile.velocity.normalized().is_equal_approx(Vector3.FORWARD),
		"Homing pineapple continues straight after losing its target."
	)
	fixture.queue_free()
	await process_frame


func _test_wave_line_of_sight() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	await physics_frame
	var start := Vector3(0.0, 1.0, 0.0)
	var finish := Vector3(6.0, 1.0, 0.0)
	_check(
		ItemExecutor.has_clear_line_of_sight(
			fixture.get_world_3d(),
			start,
			finish
		),
		"Tropical Wave sees targets through open space."
	)
	var barrier := StaticBody3D.new()
	barrier.collision_layer = PhysicsLayers.MAIN_BARRIERS
	barrier.collision_mask = 0
	barrier.position = Vector3(3.0, 1.0, 0.0)
	fixture.add_child(barrier)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 3.0, 3.0)
	collision.shape = shape
	barrier.add_child(collision)
	await physics_frame
	_check(
		not ItemExecutor.has_clear_line_of_sight(
			fixture.get_world_3d(),
			start,
			finish
		),
		"Tropical Wave is blocked by race barriers."
	)
	fixture.queue_free()
	await process_frame


func _test_executor_and_cleanup() -> void:
	var manager := RaceManager.new()
	root.add_child(manager)
	manager.configure([
		Vector3.ZERO,
		Vector3(0.0, 0.0, -20.0),
		Vector3(20.0, 0.0, -20.0),
	])
	var active_items := Node3D.new()
	active_items.name = "ActiveItems"
	root.add_child(active_items)
	var projectiles := Node3D.new()
	projectiles.name = "Projectiles"
	active_items.add_child(projectiles)
	var traps := Node3D.new()
	traps.name = "Traps"
	active_items.add_child(traps)
	var effects := Node3D.new()
	effects.name = "Effects"
	active_items.add_child(effects)
	var source := Kart.new()
	root.add_child(source)
	source.position = Vector3.ZERO
	manager.register_kart(source, true)
	var target := Kart.new()
	root.add_child(target)
	target.position = Vector3(0.0, 0.0, -5.0)
	manager.register_kart(target)
	var executor := ItemExecutor.new()
	root.add_child(executor)
	executor.setup(manager, projectiles, traps, effects)
	await process_frame
	executor.execute(ItemDefinition.tropical_projectile(), source, Vector3.FORWARD)
	executor.execute(ItemDefinition.homing_pineapple(), source, Vector3.FORWARD)
	executor.execute(ItemDefinition.slippery_peel(), source, Vector3.BACK)
	executor.execute(ItemDefinition.boost(), source, Vector3.FORWARD)
	executor.execute(ItemDefinition.tropical_wave(), source, Vector3.FORWARD)
	executor.execute(ItemDefinition.sea_bubble(), source, Vector3.FORWARD)
	var pineapple := projectiles.get_child(1) as HomingProjectile
	_check(
		projectiles.get_child_count() == 2
		and traps.get_child_count() == 1
		and effects.get_child_count() == 2
		and source.get_shield_remaining() > 0.0,
		"Family executor dispatches all six item definitions."
	)
	_check(
		pineapple != null
		and pineapple.get_target() == target
			and not source._status_timers.is_stunned()
			and is_equal_approx(target._status_timers.get_stun_remaining(), 0.8),
		"Pineapple locks the racer immediately ahead and Wave excludes its user."
	)
	for container in [projectiles, traps, effects]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	source.clear_item_effects()
	_check(
		projectiles.get_child_count() == 0
		and traps.get_child_count() == 0
		and effects.get_child_count() == 0
		and is_zero_approx(source.get_shield_remaining()),
		"ActiveItems cleanup removes projectiles, traps, effects, and shield."
	)
	executor.queue_free()
	source.queue_free()
	target.queue_free()
	active_items.queue_free()
	manager.queue_free()
	await process_frame


func _test_pause_freezes_active_durations() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var kart := Kart.new()
	fixture.add_child(kart)
	var trap := ItemTrap.new()
	trap.setup(kart, ItemDefinition.slippery_peel())
	fixture.add_child(trap)
	kart.activate_shield(ItemDefinition.sea_bubble())
	await physics_frame
	var shield_before := kart.get_shield_remaining()
	var trap_before := trap.get_remaining_life()
	paused = true
	await create_timer(0.12, true, false, true).timeout
	var shield_after := kart.get_shield_remaining()
	var trap_after := trap.get_remaining_life()
	paused = false
	_check(
		is_equal_approx(shield_before, shield_after)
		and is_equal_approx(trap_before, trap_after),
		"Pausing freezes shield and trap durations."
	)
	fixture.queue_free()
	await process_frame


func _test_ai_item_rules() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var manager := RaceManager.new()
	fixture.add_child(manager)
	manager.configure([
		Vector3.ZERO,
		Vector3(0.0, 0.0, -100.0),
		Vector3(100.0, 0.0, -100.0),
	])
	var kart := Kart.new()
	fixture.add_child(kart)
	manager.register_kart(kart)
	var ahead := Kart.new()
	fixture.add_child(ahead)
	ahead.position = Vector3(0.0, 0.0, -5.0)
	manager.register_kart(ahead)
	var behind := Kart.new()
	fixture.add_child(behind)
	behind.position = Vector3(0.0, 0.0, 10.0)
	manager.register_kart(behind)
	var ai := AiDriver.new()
	kart.add_child(ai)
	ai.setup(kart, manager, 0.0)
	var forward := Vector3.FORWARD
	ai.set("_item_cooldown", 0.0)
	var all_rules_match := true
	for item in [
		ItemDefinition.boost(),
		ItemDefinition.tropical_projectile(),
		ItemDefinition.sea_bubble(),
		ItemDefinition.slippery_peel(),
		ItemDefinition.homing_pineapple(),
		ItemDefinition.tropical_wave(),
	]:
		kart.held_item = item
		ai.set("_observed_item", item)
		ai.set("_held_item_time", 0.0)
		all_rules_match = all_rules_match and ai._should_use_item(forward)
	_check(all_rules_match, "AI recognizes tactical use conditions for all six items.")
	ahead.position = Vector3(0.0, 0.0, -60.0)
	behind.position = Vector3(0.0, 0.0, 20.0)
	for timeout_item in [
		ItemDefinition.slippery_peel(),
		ItemDefinition.homing_pineapple(),
		ItemDefinition.tropical_wave(),
	]:
		kart.held_item = timeout_item
		ai.set("_observed_item", timeout_item)
		ai.set(
			"_held_item_time",
			4.0
			if timeout_item.type == ItemDefinition.ItemType.SLIPPERY_PEEL
			else 6.0
		)
		all_rules_match = all_rules_match and ai._should_use_item(forward)
	_check(all_rules_match, "AI clears every retained item by its configured timeout.")
	fixture.queue_free()
	await process_frame


func _test_hud_item_feedback() -> void:
	for action_name in [
		&"steer_left",
		&"steer_right",
		&"accelerate",
		&"brake",
		&"drift",
		&"use_item",
	]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	root.add_child(viewport)
	var hud := RaceHud.new()
	viewport.add_child(hud)
	await process_frame
	var kart := Kart.new()
	viewport.add_child(kart)
	await process_frame
	hud.bind_player(kart)
	var bubble := ItemDefinition.sea_bubble()
	hud._handle_item_changed(bubble)
	hud._handle_shield_state_changed(bubble, 6.25, 7.0)
	var chip_rect := hud._item_chip.get_global_rect()
	var shield_rect := hud._shield_panel.get_global_rect()
	_check(
		hud._item_icon.texture == bubble.icon
		and hud._item_label.text == "BURBUJA MARINA"
		and hud._item_button.item_icon == bubble.icon
		and hud._item_button.button_label == "OBJETO",
		"HUD chip and mobile button show the current icon without losing text."
	)
	_check(
		hud._shield_panel.visible
		and "6.2 s" in hud._shield_label.text
		and chip_rect.position.x >= 0.0
		and chip_rect.end.x <= viewport.size.x
		and shield_rect.position.x >= 0.0
		and shield_rect.end.x <= viewport.size.x,
		"Bubble icon, named duration bar, and item chip fit a 640×360 viewport."
	)
	viewport.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
