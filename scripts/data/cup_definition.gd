@tool
class_name CupDefinition
extends Resource

@export var id: StringName
@export var display_name := "Copa"
@export_multiline var description := ""
@export var icon: Texture2D
@export var tracks: Array[TrackDefinition] = []
@export var player_racer: RacerDefinition
@export var opponents: Array[RacerDefinition] = []
@export var scoring_table := PackedInt32Array([9, 6, 3, 1])
@export var medal_thresholds := PackedInt32Array([9, 17, 24])
@export var difficulties: Array[DifficultyDefinition] = []
@export var unlocks: Array[UnlockDefinition] = []
@export var prerequisite_cup_id: StringName
@export var prerequisite_difficulty_id: StringName
@export_enum("Bronce:1", "Plata:2", "Oro:3") var prerequisite_medal: int = UnlockDefinition.BRONZE
@export var sort_order := 0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("Cup id is empty.")
	if tracks.size() != 3: errors.append("Cup %s must contain exactly three tracks." % id)
	var track_ids := {}
	for track in tracks:
		if track == null or not track.is_valid(): errors.append("Cup %s has a missing or invalid track." % id)
		elif track_ids.has(track.id): errors.append("Cup %s repeats track %s." % [id, track.id])
		else: track_ids[track.id] = true
	var racers: Array[RacerDefinition] = []
	if player_racer != null: racers.append(player_racer)
	racers.append_array(opponents)
	if player_racer == null or opponents.size() != 3: errors.append("Cup %s must define one player and three opponents." % id)
	var racer_ids := {}
	for racer in racers:
		if racer == null: errors.append("Cup %s has a missing racer." % id)
		elif racer_ids.has(racer.id): errors.append("Cup %s repeats racer %s." % [id, racer.id])
		else: racer_ids[racer.id] = true
	if scoring_table.size() != 4: errors.append("Cup %s scoring table must have four entries." % id)
	else:
		for index in range(1, scoring_table.size()):
			if scoring_table[index - 1] <= scoring_table[index]: errors.append("Cup %s scoring table must be strictly decreasing." % id); break
	if medal_thresholds.size() != 3 or not (medal_thresholds[0] < medal_thresholds[1] and medal_thresholds[1] < medal_thresholds[2] and medal_thresholds[2] <= scoring_table[0] * 3):
		errors.append("Cup %s medal thresholds must be bronze < silver < gold <= maximum points." % id)
	if difficulties.is_empty(): errors.append("Cup %s has no difficulties." % id)
	if not prerequisite_cup_id.is_empty():
		if prerequisite_cup_id == id: errors.append("Cup %s cannot require itself." % id)
		if prerequisite_medal not in [UnlockDefinition.BRONZE, UnlockDefinition.SILVER, UnlockDefinition.GOLD]:
			errors.append("Cup %s has an invalid prerequisite medal." % id)
	elif not prerequisite_difficulty_id.is_empty(): errors.append("Cup %s defines a prerequisite difficulty without a prerequisite cup." % id)
	return errors

func medal_for_points(points: int) -> int:
	if points >= medal_thresholds[2]: return UnlockDefinition.GOLD
	if points >= medal_thresholds[1]: return UnlockDefinition.SILVER
	if points >= medal_thresholds[0]: return UnlockDefinition.BRONZE
	return UnlockDefinition.Medal.NONE
