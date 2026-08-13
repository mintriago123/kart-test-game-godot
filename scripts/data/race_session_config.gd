class_name RaceSessionConfig
extends RefCounted

var track: TrackDefinition
var race_class: RaceClassDefinition
var game_mode := GameModeDefinition.RACE
var racers: Array[RacerDefinition] = []
var participants: Array[RaceParticipantConfig] = []
var grid_size := 8
var items_enabled := true
var player_racer_id: StringName
var difficulty: DifficultyDefinition
var equipped_variant: KartVariantDefinition
var driving_tuning := DrivingTuningDefinition.new()
var race_seed := 0
var run_id: StringName
var cup_id: StringName
var cup_race_index := -1
var lan_session: LanSession


static func create_default(mode: int = GameModeDefinition.RACE) -> RaceSessionConfig:
	var config := RaceSessionConfig.new()
	var progression := load("res://progression/progression_catalog.tres") as ProgressionCatalog
	if progression != null and progression.racers != null:
		config.racers.assign(progression.racers.racers)
	config.player_racer_id = &"marea"
	config.game_mode = mode
	config.ensure_participants()
	return config


func ensure_participants() -> void:
	if not participants.is_empty():
		_sync_compatibility_aliases()
		return
	for index in racers.size():
		var racer := racers[index]
		var is_player := racer != null and racer.id == player_racer_id
		participants.append(RaceParticipantConfig.create(
			index,
			racer,
			equipped_variant if is_player else (racer.default_kart_visual if racer != null else null),
			RaceParticipantConfig.ControlType.LOCAL if is_player else RaceParticipantConfig.ControlType.AI,
			RaceParticipantConfig.DEVICE_KEYBOARD if is_player else RaceParticipantConfig.DEVICE_NONE,
			-1
		))
	_sync_compatibility_aliases()


func set_participants(values: Array[RaceParticipantConfig]) -> void:
	participants.assign(values)
	_sync_compatibility_aliases()


func get_local_participants() -> Array[RaceParticipantConfig]:
	ensure_participants()
	var result: Array[RaceParticipantConfig] = []
	for participant in participants:
		if participant != null and participant.is_local():
			result.append(participant)
	return result


func validate() -> PackedStringArray:
	ensure_participants()
	var errors := PackedStringArray()
	if grid_size < 1 or grid_size > 8:
		errors.append("Grid size must be between one and eight.")
	if participants.size() > grid_size:
		errors.append("Participant count exceeds the configured grid.")
	var slots := {}
	var racers_by_id := {}
	var keyboards := 0
	var gamepads := {}
	for participant in participants:
		if participant == null:
			errors.append("Session has a missing participant.")
			continue
		errors.append_array(participant.validate())
		if slots.has(participant.slot_id):
			errors.append("Duplicate participant slot: %d." % participant.slot_id)
		else:
			slots[participant.slot_id] = true
		if participant.racer != null:
			if racers_by_id.has(participant.racer.id):
				errors.append("Duplicate participant racer: %s." % participant.racer.id)
			else:
				racers_by_id[participant.racer.id] = true
		if participant.is_local() and participant.device_type == RaceParticipantConfig.DEVICE_KEYBOARD:
			keyboards += 1
		if participant.is_local() and participant.device_type == RaceParticipantConfig.DEVICE_GAMEPAD:
			if gamepads.has(participant.device_id):
				errors.append("Gamepad %d is assigned more than once." % participant.device_id)
			else:
				gamepads[participant.device_id] = true
	if keyboards > 1:
		errors.append("Keyboard may only be assigned to one local participant.")
	if game_mode == GameModeDefinition.LOCAL_MULTIPLAYER and get_local_participants().size() != 2:
		errors.append("Local multiplayer requires exactly two local participants.")
	if game_mode == GameModeDefinition.CUP and participants.size() != 4:
		errors.append("Cup sessions require exactly four participants.")
	return errors


func _sync_compatibility_aliases() -> void:
	racers.clear()
	var first_local: RaceParticipantConfig
	for participant in participants:
		if participant == null or participant.racer == null:
			continue
		racers.append(participant.racer)
		if first_local == null and participant.is_local():
			first_local = participant
	if first_local != null:
		player_racer_id = first_local.racer.id
		equipped_variant = first_local.vehicle
