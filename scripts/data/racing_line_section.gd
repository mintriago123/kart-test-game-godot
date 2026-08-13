class_name RacingLineSection
extends RefCounted

enum Type { STRAIGHT, BRAKING, CORNER_ENTRY, CORNER_APEX, CORNER_EXIT }

var id := -1
var type := Type.STRAIGHT
var start_distance := 0.0
var end_distance := 0.0
var turn_direction := 0.0
var peak_curvature := 0.0
