class_name KartShieldController
extends Node

var kart: Kart
var _item: ItemDefinition
var _remaining := 0.0
var _visual: Node3D


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func update(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining <= 0.0:
		clear_shield()
	else:
		kart.shield_state_changed.emit(_item, _remaining, _item.shield_duration)


func is_active() -> bool:
	return _remaining > 0.0


func activate(item: ItemDefinition) -> void:
	if item == null or item.shield_duration <= 0.0:
		return
	clear_shield()
	_item = item
	_remaining = item.shield_duration
	if item.visual_scene != null:
		_visual = item.visual_scene.instantiate() as Node3D
		if _visual != null:
			kart.add_child(_visual)
	kart.shield_state_changed.emit(_item, _remaining, _item.shield_duration)


func get_remaining() -> float:
	return _remaining


func clear_shield() -> void:
	var previous_item := _item
	_item = null
	_remaining = 0.0
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null
	kart.shield_state_changed.emit(previous_item, 0.0, previous_item.shield_duration if previous_item != null else 0.0)
