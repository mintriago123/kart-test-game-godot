class_name RacingLineBranch
extends RefCounted

var shortcut_id := -1
var entry_distance := 0.0
var exit_distance := 0.0
var samples: Array[RacingLineSample] = []
var estimated_gain := 0.0
var risk := 0.0
var minimum_precision := 0.0
var total_length := 0.0
