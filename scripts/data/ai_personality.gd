class_name AiPersonality
extends Resource

@export_range(0.0, 1.0) var precision := 0.8
@export_range(0.0, 1.0) var aggression := 0.5
@export_range(0.0, 1.0) var drift_usage := 0.6
@export_range(0.0, 1.0) var risk_tolerance := 0.5
@export_range(0.0, 1.0) var shortcut_probability := 0.5
@export_range(0.0, 1.0) var item_efficiency := 0.7
@export_range(0.05, 0.5) var reaction_time := 0.18


static func defaults() -> AiPersonality:
	return AiPersonality.new()
