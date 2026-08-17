class_name KartItemController
extends Node

var kart: Kart
var item: ItemDefinition
var elapsed := 0.0


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func update(delta: float) -> void:
	if item != null:
		elapsed += delta
	else:
		elapsed = 0.0


func grant_random_item() -> bool:
	if item != null or kart.item_catalog == null or kart.item_rng == null:
		return false
	var position := 1
	var total_racers := 1
	if kart.race_manager != null:
		position = kart.race_manager.get_race_position(kart)
		total_racers = kart.race_manager.racers.size()
	item = kart.item_catalog.draw_item(position, total_racers, kart.item_rng)
	elapsed = 0.0
	kart.item_changed.emit(item)
	return item != null


func use_item() -> void:
	if item == null or not kart.is_control_enabled:
		return
	var item_to_use := item
	item = null
	elapsed = 0.0
	kart.item_changed.emit(null)
	var forward := -kart.global_transform.basis.z.normalized()
	var direction := -forward if item_to_use.category == ItemDefinition.ItemCategory.TRAP else forward
	kart.item_use_requested.emit(item_to_use, direction)


func clear() -> void:
	item = null
	elapsed = 0.0
	kart.item_changed.emit(null)
