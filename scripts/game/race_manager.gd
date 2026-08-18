class_name RaceManager
extends Node

signal countdown_changed(text: String)
signal countdown_progress(remaining: float)
signal race_started
signal race_info_changed(lap: int, total_laps: int, position: int, total_racers: int, time: float)
signal race_info_changed_for(kart: Node, lap: int, total_laps: int, position: int, total_racers: int, time: float)
signal racer_finished(racer: Node, position: int, time: float)
signal player_finished(position: int, time: float)
signal human_finished(racer: Node, position: int, time: float)
signal race_completed(result: RaceResult)
signal provisional_standings_changed(standings: Array[RacerRaceResult])
signal results_countdown_changed(remaining: float)
signal lap_completed(racer: Node, lap_number: int, lap_time: float)
signal shortcut_accepted(kart: Node)

enum RaceState {
	PRE_RACE,
	COUNTDOWN,
	RACING,
	WAITING_FOR_RIVALS,
	FINISHED,
}

const CHECKPOINT_RADIUS := 9.0
const CHECKPOINT_CORRIDOR_WIDTH := 12.0
const MAX_CHECKPOINTS_PER_FRAME := 5
const RESULTS_WAIT_DURATION := 30.0

@export var total_laps := 3

var state := RaceState.PRE_RACE
var route_points: Array[Vector3] = []
var racers: Array[Node] = []
var player_kart: Node
var human_karts: Array[Node] = []
var local_player_karts: Array[Node] = []
var race_time := 0.0
var track_id: StringName
var cc_id: StringName
var game_mode := GameModeDefinition.RACE
var previous_best_time := -1.0
var previous_best_lap_time := -1.0

var _race_states: Dictionary[int, RacerRaceState] = {}
var _countdown_remaining := 3.0
var _last_countdown_text := ""
var _finish_count := 0
var _results_wait_remaining := 0.0
var _local_player_indices: Dictionary = {}


func configure(points: Array[Vector3]) -> void:
	route_points = points


func register_kart(
	kart: Node,
	is_player: bool = false,
	start_position: int = 0,
	local_player_index: int = -1,
	is_human: bool = false
) -> void:
	racers.append(kart)
	var race_state := RacerRaceState.new()
	race_state.start_position = start_position if start_position > 0 else racers.size()
	_race_states[kart.get_instance_id()] = race_state
	kart.race_manager = self
	kart.is_control_enabled = false
	if is_player or is_human:
		human_karts.append(kart)
	if is_player or local_player_index >= 0:
		if not local_player_karts.has(kart):
			local_player_karts.append(kart)
		_local_player_indices[kart.get_instance_id()] = local_player_index if local_player_index >= 0 else local_player_karts.size() - 1
	if player_kart == null and (is_player or local_player_index >= 0):
		player_kart = kart


func begin() -> void:
	if state != RaceState.PRE_RACE:
		return
	if route_points.size() < 3 or racers.is_empty():
		push_error("RaceManager requires a route and at least one racer.")
		return
	state = RaceState.COUNTDOWN
	race_time = 0.0
	_countdown_remaining = 3.0
	_emit_countdown("3")
	countdown_progress.emit(_countdown_remaining)


func get_countdown_remaining() -> float:
	return _countdown_remaining


func get_race_state(kart: Node) -> RacerRaceState:
	if kart == null:
		return null
	return _race_states.get(kart.get_instance_id()) as RacerRaceState


func _process(delta: float) -> void:
	match state:
		RaceState.COUNTDOWN:
			_process_countdown(delta)
		RaceState.RACING:
			race_time += delta
			_update_racers()
			_emit_player_info()
		RaceState.WAITING_FOR_RIVALS:
			race_time += delta
			_results_wait_remaining = maxf(_results_wait_remaining - delta, 0.0)
			_update_racers()
			if state != RaceState.WAITING_FOR_RIVALS:
				return
			results_countdown_changed.emit(_results_wait_remaining)
			provisional_standings_changed.emit(get_provisional_standings())
			if state == RaceState.WAITING_FOR_RIVALS and _results_wait_remaining <= 0.0:
				_complete_race(true)


func get_next_checkpoint_index(kart: Node) -> int:
	var race_state := get_race_state(kart)
	return race_state.next_checkpoint if race_state != null else 0


func get_completed_checkpoint_count(kart: Node) -> int:
	var race_state := get_race_state(kart)
	if race_state == null:
		return 0
	var next_index := race_state.next_checkpoint
	var completed_in_lap := (next_index - 1 + route_points.size()) % route_points.size()
	return race_state.lap * route_points.size() + completed_in_lap


func complete_shortcut(kart: Node, entry_index: int, exit_index: int) -> bool:
	if not _race_states.has(kart.get_instance_id()):
		return false
	if entry_index < 0 or exit_index >= route_points.size() or entry_index >= exit_index:
		return false
	var race_state := get_race_state(kart)
	if race_state.finished:
		return false
	var next_index := race_state.next_checkpoint
	var first_valid_index := maxi(entry_index - 2, 0)
	if next_index < first_valid_index or next_index > exit_index:
		return false
	race_state.next_checkpoint = (exit_index + 1) % route_points.size()
	_increment_stat(kart, "shortcuts_used")
	kart.set_respawn_transform(_create_respawn_transform(kart, exit_index))
	shortcut_accepted.emit(kart)
	return true


func get_race_position(kart: Node) -> int:
	var ordered := racers.duplicate()
	ordered.sort_custom(_is_racer_ahead)
	return ordered.find(kart) + 1


func get_racer_ahead(kart: Node) -> Node:
	if game_mode == GameModeDefinition.TIME_TRIAL:
		return null
	var ordered := racers.duplicate()
	ordered.sort_custom(_is_racer_ahead)
	var index := ordered.find(kart)
	if index <= 0:
		return null
	return ordered[index - 1]


func _process_countdown(delta: float) -> void:
	_countdown_remaining -= delta
	countdown_progress.emit(maxf(_countdown_remaining, 0.0))
	if _countdown_remaining <= 0.0:
		state = RaceState.RACING
		for kart in racers:
			if kart.has_method("resolve_launch_boost"):
				kart.resolve_launch_boost(GameModeDefinition.has_rivals(game_mode))
			kart.is_control_enabled = true
		_emit_countdown("¡YA!")
		race_started.emit()
		get_tree().create_timer(0.85).timeout.connect(func() -> void: _emit_countdown(""))
		return
	_emit_countdown(str(maxi(ceili(_countdown_remaining), 1)))


func _update_racers() -> void:
	for kart in racers:
		var race_state := get_race_state(kart)
		if race_state.finished:
			continue
		var checkpoints_advanced := 0
		while checkpoints_advanced < MAX_CHECKPOINTS_PER_FRAME:
			var next_index := race_state.next_checkpoint
			if not _has_reached_checkpoint(kart.global_position, next_index):
				break
			kart.set_respawn_transform(_create_respawn_transform(kart, next_index))
			next_index = (next_index + 1) % route_points.size()
			if next_index == 1:
				race_state.lap += 1
				var lap_time := race_time - race_state.lap_started_at
				race_state.lap_started_at = race_time
				race_state.lap_times.append(lap_time)
				lap_completed.emit(kart, race_state.lap, lap_time)
				if race_state.lap >= total_laps:
					_finish_racer(kart, race_state)
					break
			race_state.next_checkpoint = next_index
			checkpoints_advanced += 1


func _finish_racer(kart: Node, race_state: RacerRaceState) -> void:
	_finish_count += 1
	race_state.finished = true
	race_state.finish_position = _finish_count
	race_state.finish_time = race_time
	kart.is_control_enabled = false
	racer_finished.emit(kart, _finish_count, race_time)
	if kart in human_karts:
		human_finished.emit(kart, _finish_count, race_time)
		if kart == player_kart:
			player_finished.emit(_finish_count, race_time)
		if game_mode == GameModeDefinition.TIME_TRIAL or _finish_count == racers.size():
			_complete_race(false)
		elif state != RaceState.WAITING_FOR_RIVALS:
			state = RaceState.WAITING_FOR_RIVALS
			_results_wait_remaining = RESULTS_WAIT_DURATION
			results_countdown_changed.emit(_results_wait_remaining)
			provisional_standings_changed.emit(get_provisional_standings())
	elif _finish_count == racers.size() and state == RaceState.WAITING_FOR_RIVALS:
		_complete_race(false)


func record_item_collected(kart: Node) -> void:
	_increment_stat(kart, "items_collected")


func record_item_used(kart: Node) -> void:
	_increment_stat(kart, "items_used")


func record_item_hit(source: Node, target: Node, result: int) -> void:
	if result == Kart.HitResult.APPLIED:
		_increment_stat(source, "hits_landed")
	elif result == Kart.HitResult.BLOCKED:
		_increment_stat(target, "hits_blocked")


func record_recovery(kart: Node) -> void:
	_increment_stat(kart, "recoveries")


func get_racer_result(kart: Node) -> RacerRaceResult:
	if kart == null or not _race_states.has(kart.get_instance_id()):
		return null
	return _build_racer_result(kart, get_race_state(kart))


func _increment_stat(kart: Node, key: String) -> void:
	if state not in [RaceState.RACING, RaceState.WAITING_FOR_RIVALS] or kart == null:
		return
	var id := kart.get_instance_id()
	if not _race_states.has(id):
		return
	var race_state := _race_states[id] as RacerRaceState
	race_state.set(key, int(race_state.get(key)) + 1)


func get_provisional_standings() -> Array[RacerRaceResult]:
	var ordered := racers.duplicate()
	ordered.sort_custom(_is_racer_ahead)
	var standings: Array[RacerRaceResult] = []
	for index in ordered.size():
		var racer: Node = ordered[index]
		var racer_state := get_race_state(racer)
		var racer_result := _build_racer_result(racer, racer_state)
		racer_result.finish_position = racer_state.finish_position if racer_state.finished else index + 1
		standings.append(racer_result)
	return standings


func get_results_wait_remaining() -> float:
	return _results_wait_remaining


func get_best_active_racer() -> Node:
	var ordered := racers.duplicate()
	ordered.sort_custom(_is_racer_ahead)
	for racer in ordered:
		var race_state := get_race_state(racer)
		if not race_state.finished:
			return racer
	return null


func _complete_race(mark_unfinished_dnf: bool) -> void:
	if state == RaceState.FINISHED:
		return
	state = RaceState.FINISHED
	var ordered := racers.duplicate()
	ordered.sort_custom(_is_racer_ahead)
	var result := RaceResult.new()
	result.track_id = track_id
	result.cc_id = cc_id
	result.game_mode = game_mode
	result.previous_best_time = previous_best_time
	result.previous_best_lap_time = previous_best_lap_time
	for index in ordered.size():
		var racer: Node = ordered[index]
		var race_state := get_race_state(racer)
		if not race_state.finished:
			race_state.finish_position = index + 1
			race_state.is_dnf = mark_unfinished_dnf
		var racer_result := _build_racer_result(racer, race_state)
		result.standings.append(racer_result)
		if racer in local_player_karts:
			result.player_results.append(racer_result)
		if racer.has_method("set_drive_input"):
			racer.set_drive_input(0.0, 0.0, 0.0, false, false)
		racer.is_control_enabled = false
	result.player_results.sort_custom(func(a: RacerRaceResult, b: RacerRaceResult) -> bool:
		return a.local_player_index < b.local_player_index
	)
	if not result.player_results.is_empty():
		result.local_player_index = 0
		result.player_result = result.player_results[0]
	result.finalize_records()
	race_completed.emit(result)


func _build_racer_result(kart: Node, race_state: RacerRaceState) -> RacerRaceResult:
	var result := RacerRaceResult.new()
	var raw_racer_id: Variant = kart.get("racer_id")
	result.racer_id = str(raw_racer_id) if raw_racer_id != null else &""
	result.racer_name = str(kart.get("racer_name"))
	result.is_player = kart in human_karts
	result.local_player_index = int(_local_player_indices.get(kart.get_instance_id(), -1))
	var raw_slot: Variant = kart.get("participant_slot")
	result.participant_slot = int(raw_slot) if raw_slot != null else -1
	result.start_position = race_state.start_position
	result.finish_position = race_state.finish_position
	result.laps_completed = race_state.lap
	result.lap_times.assign(race_state.lap_times)
	result.finish_time = race_state.finish_time if race_state.finished else -1.0
	result.is_dnf = race_state.is_dnf
	if not result.lap_times.is_empty():
		result.best_lap_time = result.lap_times.min()
	result.items_collected = race_state.items_collected
	result.items_used = race_state.items_used
	result.hits_landed = race_state.hits_landed
	result.hits_blocked = race_state.hits_blocked
	result.shortcuts_used = race_state.shortcuts_used
	result.recoveries = race_state.recoveries
	return result


func _emit_player_info() -> void:
	if player_kart == null:
		return
	for local_kart in local_player_karts:
		if not is_instance_valid(local_kart):
			continue
		var race_state := get_race_state(local_kart)
		var displayed_lap := clampi(race_state.lap + 1, 1, total_laps)
		race_info_changed_for.emit(
			local_kart,
			displayed_lap,
			total_laps,
			get_race_position(local_kart),
			racers.size(),
			race_time
		)
		if local_kart == player_kart:
			race_info_changed.emit(
				displayed_lap,
				total_laps,
				get_race_position(local_kart),
				racers.size(),
				race_time
			)


func _emit_countdown(text: String) -> void:
	if text == _last_countdown_text:
		return
	_last_countdown_text = text
	countdown_changed.emit(text)


func _has_reached_checkpoint(kart_position: Vector3, checkpoint_index: int) -> bool:
	var checkpoint := route_points[checkpoint_index]
	if kart_position.distance_to(checkpoint) <= CHECKPOINT_RADIUS:
		return true
	var previous_index := (checkpoint_index - 1 + route_points.size()) % route_points.size()
	var segment := checkpoint - route_points[previous_index]
	var segment_length := segment.length()
	if segment_length <= 0.01:
		return true
	var direction := segment / segment_length
	var distance_along := (kart_position - route_points[previous_index]).dot(direction)
	if distance_along < segment_length:
		return false
	var closest_point := route_points[previous_index] + direction * distance_along
	return kart_position.distance_to(closest_point) <= CHECKPOINT_CORRIDOR_WIDTH


func _create_respawn_transform(kart: Node, checkpoint_index: int) -> Transform3D:
	var next_index := (checkpoint_index + 1) % route_points.size()
	var forward := (route_points[next_index] - route_points[checkpoint_index]).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var racer_index := racers.find(kart)
	var lane_offset := (float(racer_index) - (racers.size() - 1) * 0.5) * 1.1
	var respawn_position := (
		route_points[checkpoint_index]
		+ right * lane_offset
		+ Vector3.UP * 0.85
	)
	return Transform3D(Basis.IDENTITY, respawn_position).looking_at(
		respawn_position + forward,
		Vector3.UP
	)


func _is_racer_ahead(a: Node, b: Node) -> bool:
	var state_a := get_race_state(a)
	var state_b := get_race_state(b)
	if state_a.finished or state_b.finished:
		if state_a.finished and state_b.finished:
			return state_a.finish_position < state_b.finish_position
		return state_a.finished
	var progress_a := _calculate_progress(a, state_a)
	var progress_b := _calculate_progress(b, state_b)
	return progress_a > progress_b


func _calculate_progress(kart: Node, race_state: RacerRaceState) -> float:
	var next_index := race_state.next_checkpoint
	var previous_index := (next_index - 1 + route_points.size()) % route_points.size()
	var segment_length := route_points[previous_index].distance_to(route_points[next_index])
	var distance_to_next: float = kart.global_position.distance_to(route_points[next_index])
	var segment_progress := 1.0 - clampf(distance_to_next / maxf(segment_length, 0.1), 0.0, 1.0)
	return float(race_state.lap * route_points.size() + previous_index) + segment_progress


func get_racer_progress(kart: Node) -> float:
	if kart == null or not _race_states.has(kart.get_instance_id()):
		return -1.0
	return _calculate_progress(kart, get_race_state(kart))
