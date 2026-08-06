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


static func create(
	issue_code: StringName,
	issue_message: String,
	issue_severity := Severity.ERROR,
	issue_target_path := NodePath(),
	issue_world_position := Vector3.ZERO
) -> TrackValidationIssue:
	var issue := TrackValidationIssue.new()
	issue.code = issue_code
	issue.message = issue_message
	issue.severity = issue_severity
	issue.target_path = issue_target_path
	issue.world_position = issue_world_position
	return issue
