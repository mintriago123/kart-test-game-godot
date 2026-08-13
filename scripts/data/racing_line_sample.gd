class_name RacingLineSample
extends RefCounted

var distance := 0.0
var position := Vector3.ZERO
var forward := Vector3.FORWARD
var curvature := 0.0
var recommended_speed_ratio := 1.0
var available_width := 0.0
var lateral_offset := 0.0
var section_id := -1


func duplicate_sample() -> RacingLineSample:
	var result := RacingLineSample.new()
	result.distance = distance
	result.position = position
	result.forward = forward
	result.curvature = curvature
	result.recommended_speed_ratio = recommended_speed_ratio
	result.available_width = available_width
	result.lateral_offset = lateral_offset
	result.section_id = section_id
	return result
