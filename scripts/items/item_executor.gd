class_name ItemExecutor
extends Node

signal item_activated(item: ItemDefinition, source_kart: Kart)
signal kart_hit(item: ItemDefinition, kart: Node3D, result: int)
signal projectile_bounced(bounce_count: int)

var race_manager: RaceManager
var projectiles: Node3D
var traps: Node3D
var effects: Node3D


func setup(
	manager: RaceManager,
	projectile_container: Node3D,
	trap_container: Node3D,
	effect_container: Node3D
) -> void:
	race_manager = manager
	projectiles = projectile_container
	traps = trap_container
	effects = effect_container


func execute(
	item: ItemDefinition,
	source_kart: Kart,
	direction: Vector3,
	allow_homing: bool = true
) -> bool:
	if (
		item == null
		or not is_instance_valid(source_kart)
		or race_manager == null
	):
		return false
	var was_executed := false
	match item.category:
		ItemDefinition.ItemCategory.BOOST:
			source_kart.activate_boost(item.boost_duration, item.boost_power)
			_spawn_effect(item, source_kart, true)
			was_executed = true
		ItemDefinition.ItemCategory.PROJECTILE:
			was_executed = _spawn_projectile(
				item,
				source_kart,
				direction,
				allow_homing
			)
		ItemDefinition.ItemCategory.SHIELD:
			source_kart.activate_shield(item)
			was_executed = true
		ItemDefinition.ItemCategory.TRAP:
			was_executed = _spawn_trap(item, source_kart, direction)
		ItemDefinition.ItemCategory.AREA_EFFECT:
			_execute_area_effect(item, source_kart)
			was_executed = true
	if was_executed:
		item_activated.emit(item, source_kart)
	return was_executed


static func has_clear_line_of_sight(
	world: World3D,
	start: Vector3,
	end: Vector3
) -> bool:
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		start,
		end,
		PhysicsLayers.BARRIERS
	)
	query.collide_with_areas = false
	return world.direct_space_state.intersect_ray(query).is_empty()


func _spawn_projectile(
	item: ItemDefinition,
	source_kart: Kart,
	direction: Vector3,
	allow_homing: bool
) -> bool:
	if projectiles == null or direction.is_zero_approx():
		return false
	var projectile: KartProjectile
	if item.type == ItemDefinition.ItemType.HOMING_PINEAPPLE:
		var homing_projectile := HomingProjectile.new()
		homing_projectile.setup_homing(
			source_kart,
			item,
			direction,
			race_manager.get_racer_ahead(source_kart) if allow_homing else null
		)
		projectile = homing_projectile
	else:
		projectile = KartProjectile.new()
		projectile.setup(source_kart, item, direction)
	projectile.bounced.connect(
		func(bounce_count: int) -> void:
			projectile_bounced.emit(bounce_count)
	)
	projectile.kart_hit.connect(
		func(kart: Node3D, result: int) -> void:
			kart_hit.emit(item, kart, result)
	)
	projectiles.add_child(projectile)
	projectile.global_position = (
		source_kart.global_position
		+ direction.normalized() * 2.0
		+ Vector3.UP * (item.projectile_radius + 0.25)
	)
	return true


func _spawn_trap(
	item: ItemDefinition,
	source_kart: Kart,
	direction: Vector3
) -> bool:
	if traps == null or direction.is_zero_approx():
		return false
	var trap := ItemTrap.new()
	trap.setup(source_kart, item)
	trap.kart_hit.connect(
		func(kart: Node3D, result: int) -> void:
			kart_hit.emit(item, kart, result)
	)
	traps.add_child(trap)
	trap.place(
		source_kart.global_position
		+ direction.normalized() * item.trap_spawn_distance
		+ Vector3.UP
	)
	return true


func _execute_area_effect(
	item: ItemDefinition,
	source_kart: Kart
) -> void:
	var origin := source_kart.global_position + Vector3.UP * 0.65
	for racer in race_manager.racers:
		var target := racer as Node3D
		if (
			target == null
			or target == source_kart
			or not is_instance_valid(target)
			or not target.has_method("receive_hit")
		):
			continue
		var target_point := target.global_position + Vector3.UP * 0.65
		if origin.distance_to(target_point) > item.area_radius:
			continue
		if not has_clear_line_of_sight(
			source_kart.get_world_3d(),
			origin,
			target_point
		):
			continue
		var raw_result: Variant = target.receive_hit(item.area_impact_duration)
		var hit_result := (
			int(raw_result)
			if raw_result != null
			else Kart.HitResult.APPLIED
		)
		kart_hit.emit(item, target, hit_result)
	_spawn_effect(item, source_kart, false)


func _spawn_effect(
	item: ItemDefinition,
	source_kart: Kart,
	follow_source: bool
) -> void:
	if effects == null or item.visual_scene == null:
		return
	var effect := item.visual_scene.instantiate() as ItemBurstEffect
	if effect == null:
		return
	effect.setup(item, source_kart, follow_source)
	effects.add_child(effect)
