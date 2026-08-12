class_name PresentationQuality
extends RefCounted

const VALID_PROFILES := ["low", "medium", "high", "ultra"]
const PROFILES := {
	"low": {"particle_scale": 0.35, "speed_lines": 12, "shadows": false, "shadow_distance": 0.0, "msaa": 0, "glow": 0},
	"medium": {"particle_scale": 0.65, "speed_lines": 20, "shadows": true, "shadow_distance": 70.0, "msaa": 2, "glow": 1},
	"high": {"particle_scale": 1.0, "speed_lines": 32, "shadows": true, "shadow_distance": 95.0, "msaa": 2, "glow": 2},
	"ultra": {"particle_scale": 1.5, "speed_lines": 48, "shadows": true, "shadow_distance": 130.0, "msaa": 4, "glow": 3},
}

static func sanitize(profile: String) -> String:
	return profile if profile in VALID_PROFILES else "medium"

static func get_budget(profile: String) -> Dictionary:
	return PROFILES[sanitize(profile)].duplicate(true)
