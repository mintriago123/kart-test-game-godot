class_name RaceSessionConfig
extends RefCounted

var track: TrackDefinition
var race_class: RaceClassDefinition
var game_mode := GameModeDefinition.RACE
var racers: Array[RacerDefinition] = []
var player_racer_id: StringName
var difficulty: DifficultyDefinition
var equipped_variant: KartVariantDefinition
var driving_tuning := DrivingTuningDefinition.new()
var race_seed := 0
var run_id: StringName
var cup_id: StringName
var cup_race_index := -1


static func create_default(mode: int = GameModeDefinition.RACE) -> RaceSessionConfig:
	var config := RaceSessionConfig.new()
	var progression := load("res://progression/progression_catalog.tres") as ProgressionCatalog
	if progression != null and progression.racers != null:
		config.racers.assign(progression.racers.racers)
	config.player_racer_id = &"marea"
	config.game_mode = mode
	return config
