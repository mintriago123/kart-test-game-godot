class_name AiShortcutPlanner
extends RefCounted

func select_branch(
	racing_line: RacingLine,
	current_distance: float,
	completed_checkpoints: int,
	race_seed: int,
	racer_id: StringName,
	personality: AiPersonality,
	decided: Dictionary
) -> int:
	if racing_line == null or racing_line.shortcut_branches.is_empty():
		return -1
	for branch in racing_line.shortcut_branches:
		var key := "%d:%d" % [completed_checkpoints, branch.shortcut_id]
		if decided.has(key):
			continue
		var approach := branch.entry_distance - current_distance
		if approach < 0.0:
			approach += racing_line.total_length
		if approach > 18.0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = ("%d|%s|shortcut|%s" % [race_seed, racer_id, key]).hash()
		var safe_risk_ceiling := personality.risk_tolerance
		var eligible := (
			personality.precision >= branch.minimum_precision
			and branch.risk <= safe_risk_ceiling
		)
		var risk_factor := clampf(1.0 - maxf(branch.risk - personality.risk_tolerance, 0.0), 0.0, 1.0)
		var selected := eligible and rng.randf() < personality.shortcut_probability * risk_factor
		decided[key] = selected
		if selected:
			return branch.shortcut_id
	return -1
