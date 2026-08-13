class_name CupEvaluationResult
extends RefCounted

var standings: Array[Dictionary] = []
var player_position := 0
var player_points := 0
var medal := UnlockDefinition.Medal.NONE
var eligible_rewards: Array[UnlockDefinition] = []
var errors := PackedStringArray()


func is_valid() -> bool:
	return errors.is_empty()
