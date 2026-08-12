class_name ItemDefinition
extends Resource

enum ItemType {
	NONE,
	BOOST,
	TURBO_COCONUT,
	SEA_BUBBLE,
	SLIPPERY_PEEL,
	HOMING_PINEAPPLE,
	TROPICAL_WAVE,
}

enum ItemCategory {
	NONE,
	BOOST,
	PROJECTILE,
	SHIELD,
	TRAP,
	AREA_EFFECT,
}

enum BarrierResponse {
	DESTROY,
	BOUNCE,
	STICK,
	IGNORE,
}

const BOOST_PATH := "res://items/definitions/boost.tres"
const TURBO_COCONUT_PATH := "res://items/definitions/turbo_coconut.tres"
const SEA_BUBBLE_PATH := "res://items/definitions/sea_bubble.tres"
const SLIPPERY_PEEL_PATH := "res://items/definitions/slippery_peel.tres"
const HOMING_PINEAPPLE_PATH := "res://items/definitions/homing_pineapple.tres"
const TROPICAL_WAVE_PATH := "res://items/definitions/tropical_wave.tres"

@export_group("Identity")
@export var id: StringName
@export var type: ItemType = ItemType.NONE
@export var category: ItemCategory = ItemCategory.NONE
@export var display_name := ""

@export_group("Presentation")
@export var icon: Texture2D
@export var hud_color := Color("#77d0c2")
@export var visual_scene: PackedScene
@export_range(0.0, 20.0, 0.01) var world_visual_diameter := 0.0
@export var show_ground_shadow := false
@export var show_motion_trail := false

@export_group("Distribution")
@export var position_weights := PackedInt32Array([25, 25, 25, 25])

@export_group("Boost")
@export var boost_duration := 0.0
@export var boost_power := 0.0

@export_group("Projectile")
@export var barrier_response: BarrierResponse = BarrierResponse.DESTROY
@export var projectile_speed := 0.0
@export var projectile_duration := 0.0
@export var projectile_radius := 0.48
@export var projectile_impact_duration := 0.0
@export var projectile_max_bounces := 0
@export var projectile_speed_retention := 1.0
@export var projectile_owner_immunity := 0.0
@export var projectile_max_turn_rate := 0.0

@export_group("Shield")
@export var shield_duration := 0.0

@export_group("Trap")
@export var trap_spawn_distance := 0.0
@export var trap_duration := 0.0
@export var trap_radius := 0.0
@export var trap_impact_duration := 0.0
@export var trap_owner_immunity := 0.0

@export_group("Area effect")
@export var area_radius := 0.0
@export var area_impact_duration := 0.0
@export var effect_visual_duration := 0.0


static func boost() -> ItemDefinition:
	return _load_copy(BOOST_PATH)


static func tropical_projectile() -> ItemDefinition:
	return _load_copy(TURBO_COCONUT_PATH)


static func sea_bubble() -> ItemDefinition:
	return _load_copy(SEA_BUBBLE_PATH)


static func slippery_peel() -> ItemDefinition:
	return _load_copy(SLIPPERY_PEEL_PATH)


static func homing_pineapple() -> ItemDefinition:
	return _load_copy(HOMING_PINEAPPLE_PATH)


static func tropical_wave() -> ItemDefinition:
	return _load_copy(TROPICAL_WAVE_PATH)


static func _load_copy(path: String) -> ItemDefinition:
	var definition := load(path) as ItemDefinition
	if definition == null:
		push_error("Item definition could not be loaded: %s" % path)
		return ItemDefinition.new()
	return definition.duplicate(true) as ItemDefinition
