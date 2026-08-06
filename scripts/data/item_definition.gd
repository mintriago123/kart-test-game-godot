class_name ItemDefinition
extends Resource

enum ItemType {
	NONE,
	BOOST,
	TROPICAL_PROJECTILE,
}

enum BarrierResponse {
	DESTROY,
	BOUNCE,
	STICK,
	IGNORE,
}

@export var type: ItemType = ItemType.NONE
@export var display_name: String = ""
@export var barrier_response: BarrierResponse = BarrierResponse.DESTROY
@export var projectile_speed := 0.0
@export var projectile_duration := 0.0
@export var projectile_radius := 0.48
@export var projectile_impact_duration := 0.0
@export var projectile_max_bounces := 0
@export var projectile_speed_retention := 1.0
@export var projectile_owner_immunity := 0.0
@export var boost_duration := 0.0
@export var boost_power := 0.0


static func boost() -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.type = ItemType.BOOST
	definition.display_name = "Impulso"
	definition.boost_duration = 1.25
	definition.boost_power = 11.0
	return definition


static func tropical_projectile() -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.type = ItemType.TROPICAL_PROJECTILE
	definition.display_name = "Coco turbo"
	definition.barrier_response = BarrierResponse.BOUNCE
	definition.projectile_speed = 31.0
	definition.projectile_duration = 4.0
	definition.projectile_radius = 0.48
	definition.projectile_impact_duration = 1.1
	definition.projectile_max_bounces = 3
	definition.projectile_speed_retention = 0.88
	definition.projectile_owner_immunity = 0.25
	return definition
