@tool
class_name TrackShortcut
extends Path3D

@export var shortcut_id := 0
@export var display_name := "Nuevo atajo"


func ensure_curve() -> Curve3D:
	if curve == null:
		curve = Curve3D.new()
	curve.closed = false
	return curve
