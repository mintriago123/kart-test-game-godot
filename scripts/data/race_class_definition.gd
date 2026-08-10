class_name RaceClassDefinition
extends Resource

const DEFAULT_ID := &"150"

@export var id: StringName = DEFAULT_ID
@export var display_name := "150 CC"
@export var description := "Velocidad equilibrada para competir."
@export var speed_multiplier := 1.0
@export var acceleration_multiplier := 1.0
@export var braking_multiplier := 1.0
@export var steering_multiplier := 1.0
@export var grip_multiplier := 1.0
@export var drift_grip_multiplier := 1.0
@export var boost_multiplier := 1.0
@export var maximum_camera_fov := 85.0


static func get_all() -> Array[RaceClassDefinition]:
	return [
		_create(
			&"50",
			"50 CC",
			"Conducción tranquila, estable y perfecta para aprender.",
			0.88,
			0.95,
			1.00,
			1.08,
			1.08,
			1.05,
			0.90,
			80.0
		),
		_create(
			&"100",
			"100 CC",
			"Ritmo ágil con buen agarre y frenadas permisivas.",
			1.04,
			1.05,
			1.05,
			1.04,
			1.04,
			1.03,
			1.00,
			82.0
		),
		_create(
			DEFAULT_ID,
			"150 CC",
			"La experiencia equilibrada de velocidad y control.",
			1.20,
			1.15,
			1.12,
			1.00,
			1.00,
			1.00,
			1.10,
			85.0
		),
		_create(
			&"200",
			"200 CC",
			"Máxima velocidad, menos agarre y frenadas obligatorias.",
			1.40,
			1.25,
			1.25,
			0.94,
			0.92,
			0.90,
			1.20,
			88.0
		),
	]


static func get_by_id(race_class_id: StringName) -> RaceClassDefinition:
	for definition in get_all():
		if definition.id == race_class_id:
			return definition
	return get_default()


static func get_default() -> RaceClassDefinition:
	for definition in get_all():
		if definition.id == DEFAULT_ID:
			return definition
	return RaceClassDefinition.new()


func apply_to(base_stats: KartStats) -> KartStats:
	var source := base_stats if base_stats != null else KartStats.new()
	var scaled := source.copy()
	scaled.max_speed *= speed_multiplier
	scaled.reverse_speed *= speed_multiplier
	scaled.acceleration *= acceleration_multiplier
	scaled.braking *= braking_multiplier
	scaled.steering_speed *= steering_multiplier
	scaled.grip *= grip_multiplier
	scaled.drift_grip *= drift_grip_multiplier
	scaled.boost_power *= boost_multiplier
	return scaled


static func _create(
	racing_id: StringName,
	racing_name: String,
	racing_description: String,
	speed: float,
	acceleration: float,
	braking: float,
	steering: float,
	grip: float,
	drift_grip: float,
	boost: float,
	maximum_fov: float
) -> RaceClassDefinition:
	var definition := RaceClassDefinition.new()
	definition.id = racing_id
	definition.display_name = racing_name
	definition.description = racing_description
	definition.speed_multiplier = speed
	definition.acceleration_multiplier = acceleration
	definition.braking_multiplier = braking
	definition.steering_multiplier = steering
	definition.grip_multiplier = grip
	definition.drift_grip_multiplier = drift_grip
	definition.boost_multiplier = boost
	definition.maximum_camera_fov = maximum_fov
	return definition
