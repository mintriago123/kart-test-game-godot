class_name ItemDefinition
extends Resource

enum ItemType {
	NONE,
	BOOST,
	TROPICAL_PROJECTILE,
}

@export var type: ItemType = ItemType.NONE
@export var display_name: String = ""
@export var duration: float = 0.0
@export var power: float = 0.0


static func boost() -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.type = ItemType.BOOST
	definition.display_name = "Impulso"
	definition.duration = 1.25
	definition.power = 11.0
	return definition


static func tropical_projectile() -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.type = ItemType.TROPICAL_PROJECTILE
	definition.display_name = "Coco turbo"
	definition.duration = 4.0
	definition.power = 1.1
	return definition
