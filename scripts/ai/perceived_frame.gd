class_name PerceivedFrame
extends RefCounted

var should_reset: bool = false
var speed: float = 0.0
var reaction_delay: float = 0.0
var lookahead: float = 0.0
var projection = null
var sensors: Dictionary = {}


func _init(should_reset_value: bool = false, speed_value: float = 0.0,
		reaction_delay_value: float = 0.0, lookahead_value: float = 0.0,
		projection_value = null, sensors_value: Dictionary = {}) -> void:
	should_reset = should_reset_value
	speed = speed_value
	reaction_delay = reaction_delay_value
	lookahead = lookahead_value
	projection = projection_value
	sensors = sensors_value
