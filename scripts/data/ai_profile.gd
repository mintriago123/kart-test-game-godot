class_name AiProfile
extends Resource

@export_range(0.0, 1.0) var precision := 0.8
@export_range(0.0, 1.0) var aggression := 0.5
@export_range(0.0, 1.0) var drift_usage := 0.6
@export_range(0.0, 1.0) var risk_tolerance := 0.5
@export_range(0.0, 1.0) var shortcut_probability := 0.5
@export_range(0.0, 1.0) var item_efficiency := 0.7
@export_range(0.05, 0.5) var reaction_time := 0.18


static func create(
	precision_value: float,
	aggression_value: float,
	drift_value: float,
	risk_value: float,
	shortcut_value: float,
	item_value: float,
	reaction_value: float
) -> AiProfile:
	var profile := AiProfile.new()
	profile.precision = precision_value
	profile.aggression = aggression_value
	profile.drift_usage = drift_value
	profile.risk_tolerance = risk_value
	profile.shortcut_probability = shortcut_value
	profile.item_efficiency = item_value
	profile.reaction_time = reaction_value
	return profile
