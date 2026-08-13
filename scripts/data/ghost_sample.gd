class_name GhostSample
extends RefCounted

enum DriveState { NORMAL, DRIFTING, BOOSTING, DRIFT_BOOSTING }

var time := 0.0
var position := Vector3.ZERO
var rotation := Quaternion.IDENTITY
var drive_state := DriveState.NORMAL
var discontinuity := false
var progress := 0.0
