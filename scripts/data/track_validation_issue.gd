@tool
class_name TrackValidationIssue
extends RefCounted

enum Severity {
	WARNING,
	ERROR,
}

var severity := Severity.ERROR
var code: StringName
var message := ""
var target_path := NodePath()
var world_position := Vector3.ZERO
var workflow_step := 1
var focus_kind: StringName = &"route"


static func create(
	issue_code: StringName,
	issue_message: String,
	issue_severity := Severity.ERROR,
	issue_target_path := NodePath(),
	issue_world_position := Vector3.ZERO,
	issue_workflow_step := -1,
	issue_focus_kind: StringName = &""
) -> TrackValidationIssue:
	var issue := TrackValidationIssue.new()
	issue.code = issue_code
	issue.message = issue_message
	issue.severity = issue_severity
	issue.target_path = issue_target_path
	issue.world_position = issue_world_position
	issue.workflow_step = (
		issue_workflow_step
		if issue_workflow_step >= 0
		else workflow_step_for(issue_code, issue_target_path)
	)
	issue.focus_kind = (
		issue_focus_kind
		if not issue_focus_kind.is_empty()
		else focus_kind_for(issue_code, issue_target_path)
	)
	return issue


func group_key() -> String:
	return "%s|%s|%s|%d" % [code, target_path, message, severity]


func location_key() -> String:
	if world_position.is_zero_approx():
		return str(target_path)
	return "%s|%.2f|%.2f|%.2f" % [
		target_path,
		world_position.x,
		world_position.y,
		world_position.z,
	]


func is_blocking() -> bool:
	return severity == Severity.ERROR


static func workflow_step_for(issue_code: StringName, issue_target_path: NodePath) -> int:
	var path_text := str(issue_target_path)
	if path_text == "." or issue_code in [&"track_id_missing", &"display_name_missing"]:
		return 0
	if path_text.begins_with("Shortcuts/") or issue_code.begins_with("shortcut_"):
		return 2
	if (
		path_text.begins_with("ItemSpawns/")
		or path_text.begins_with("Props/")
		or path_text in ["ItemSpawns", "Props"]
		or issue_code.begins_with("item_")
		or issue_code.begins_with("prop_")
		or issue_code in [&"items_missing", &"item_count", &"props_missing"]
	):
		return 3
	if path_text.begins_with("Surfaces/") or issue_code.begins_with("surface_"):
		return 4
	return 1


static func focus_kind_for(issue_code: StringName, issue_target_path: NodePath) -> StringName:
	var path_text := str(issue_target_path)
	if path_text.begins_with("Shortcuts/") or issue_code.begins_with("shortcut_"):
		return &"shortcut"
	if (
		path_text.begins_with("ItemSpawns/")
		or path_text == "ItemSpawns"
		or issue_code.begins_with("item_")
		or issue_code in [&"items_missing", &"item_count"]
	):
		return &"item"
	if (
		path_text.begins_with("Props/")
		or path_text == "Props"
		or issue_code.begins_with("prop_")
		or issue_code == &"props_missing"
	):
		return &"prop"
	if path_text.begins_with("Surfaces/") or issue_code.begins_with("surface_"):
		return &"surface"
	return &"route"
