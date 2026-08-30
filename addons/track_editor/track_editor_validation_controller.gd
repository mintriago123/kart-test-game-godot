@tool
class_name TrackEditorValidationController
extends RefCounted

var issues: Array[TrackValidationIssue] = []


func inspect(track: TrackLevel) -> Array[TrackValidationIssue]:
	issues.clear()
	if track == null:
		return issues
	for issue in track.inspect_track():
		if issue != null:
			issues.append(issue)
	return issues.duplicate()


func has_blocking_issues(candidate_issues: Array[TrackValidationIssue] = issues) -> bool:
	for issue in candidate_issues:
		if issue.is_blocking():
			return true
	return false


func counts_by_step(candidate_issues: Array[TrackValidationIssue] = issues) -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for issue in candidate_issues:
		var step := clampi(issue.workflow_step, 0, counts.size() - 1)
		counts[step] += 1
	return counts


static func group_issues(candidate_issues: Array[TrackValidationIssue]) -> Array[Dictionary]:
	var grouped: Array[Dictionary] = []
	var indexes: Dictionary = {}
	for issue in candidate_issues:
		var key := issue.group_key()
		if indexes.has(key):
			var group_index: int = indexes[key]
			(grouped[group_index].issues as Array).append(issue)
			continue
		indexes[key] = grouped.size()
		grouped.append({
			"issue": issue,
			"issues": [issue],
		})
	return grouped
