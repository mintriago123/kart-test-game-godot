class_name CupResultSummary
extends RefCounted

var cup_id: StringName
var difficulty_id: StringName
var race_index := -1
var completed := false
var standings: Array[Dictionary] = []
var medal := UnlockDefinition.Medal.NONE
var previous_best_medal := UnlockDefinition.Medal.NONE
var new_reward_ids := PackedStringArray()
