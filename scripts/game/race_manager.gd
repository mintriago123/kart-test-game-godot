class_name RaceManager
extends Node

signal countdown_changed(text: String)
signal countdown_progress(remaining: float)
signal race_started
signal race_info_changed(lap: int, total_laps: int, position: int, total_racers: int, time: float)
signal racer_finished(racer: Node, position: int, time: float)
signal player_finished(position: int, time: float)
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
const RESULTS_WAIT_DURATION := 15.0

@export var total_laps := 3

var state := RaceState.PRE_RACE
var route_points: Array[Vector3] = []
var racers: Array[Node] = []
var player_kart: Node
var race_time := 0.0
var track_id: StringName
var cc_id: StringName
var game_mode := GameModeDefinition.RACE
var previous_best_time := -1.0
var previous_best_lap_time := -1.0

var _race_data: Dictionary = {}
var _countdown_remaining := 3.0
var _last_countdown_text := ""
var _finish_count := 0
var _results_wait_remaining := 0.0


func configure(points: Array[Vector3]) -> void:
	route_points = points


func register_kart(kart: Node, is_player: bool = false, start_position: int = 0) -> void:
	racers.append(kart)
	_race_data[kart.get_instance_id()] = {
		"lap": 0,
		"next_checkpoint": 1,
		"finished": false,
		"finish_position": 0,
		"finish_time": 0.0,
		"lap_started_at": 0.0,
		"lap_times": [],
		"start_position": start_position if start_position > 0 else racers.size(),
		"items_collected": 0,
		"items_used": 0,
		"hits_landed": 0,
		"hits_blocked": 0,
		"shortcuts_used": 0,
		"recoveries": 0,
	}
	kart.race_manager = self
	kart.is_control_enabled = false
	if is_player:
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
	var data: Dictionary = _race_data.get(kart.get_instance_id(), {})
	return int(data.get("next_checkpoint", 0))


func get_completed_checkpoint_count(kart: Node) -> int:
	var data: Dictionary = _race_data.get(kart.get_instance_id(), {})
	if data.is_empty():
		return 0
	var next_index := int(data.get("next_checkpoint", 1))
	var completed_in_lap := (next_index - 1 + route_points.size()) % route_points.size()
	return int(data.get("lap", 0)) * route_points.size() + completed_in_lap


func complete_shortcut(kart: Node, entry_index: int, exit_index: int) -> bool:
	if not _race_data.has(kart.get_instance_id()):
		return false
	if entry_index < 0 or exit_index >= route_points.size() or entry_index >= exit_index:
		return false
	var data: Dictionary = _race_data[kart.get_instance_id()]
	if data.finished:
		return false
	var next_index: int = data.next_checkpoint
	var first_valid_index := maxi(entry_index - 2, 0)
	if next_index < first_valid_index or next_index > exit_index:
		return false
	data.next_checkpoint = (exit_index + 1) % route_points.size()
	_race_data[kart.get_instance_id()] = data
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
		var data: Dictionary = _race_data[kart.get_instance_id()]
		if data.finished:
			continue
		var checkpoints_advanced := 0
		while checkpoints_advanced < MAX_CHECKPOINTS_PER_FRAME:
			var next_index: int = data.next_checkpoint
			if not _has_reached_checkpoint(kart.global_position, next_index):
				break
			kart.set_respawn_transform(_create_respawn_transform(kart, next_index))
			next_index = (next_index + 1) % route_points.size()
			if next_index == 1:
				data.lap += 1
				var lap_time: float = race_time - float(data.lap_started_at)
				data.lap_started_at = race_time
				var lap_times: Array = data.lap_times
				lap_times.append(lap_time)
				data.lap_times = lap_times
				lap_completed.emit(kart, int(data.lap), lap_time)
				if data.lap >= total_laps:
					_finish_racer(kart, data)
					break
			data.next_checkpoint = next_index
			_race_data[kart.get_instance_id()] = data
			checkpoints_advanced += 1


func _finish_racer(kart: Node, data: Dictionary) -> void:
	_finish_count += 1
	data.finished = true
	data.finish_position = _finish_count
	data.finish_time = race_time
	_race_data[kart.get_instance_id()] = data
	kart.is_control_enabled = false
	racer_finished.emit(kart, _finish_count, race_time)
	if kart == player_kart:
		if game_mode == GameModeDefinition.TIME_TRIAL or _finish_count == racers.size():
			player_finished.emit(_finish_count, race_time)
			_complete_race(false)
		else:
			state = RaceState.WAITING_FOR_RIVALS
			_results_wait_remaining = RESULTS_WAIT_DURATION
			player_finished.emit(_finish_count, race_time)
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
	if kart == null or not _race_data.has(kart.get_instance_id()):
		return null
	return _build_racer_result(kart, _race_data[kart.get_instance_id()])


func _increment_stat(kart: Node, key: String) -> void:
	if state not in [RaceState.RACING, RaceState.WAITING_FOR_RIVALS] or kart == null:
		return
	var id := kart.get_instance_id()
	if not _race_data.has(id):
		return
	var data: Dictionary = _race_data[id]
	data[key] = int(data.get(key, 0)) + 1
	_race_data[id] = data


func get_provisional_standings() -> Array[RacerRaceResult]:
	var ordered := racers.duplicate()
	ordered.sort_custom(_is_racer_ahead)
	var standings: Array[RacerRaceResult] = []
	for index in ordered.size():
		var racer: Node = ordered[index]
		var racer_data: Dictionary = _race_data[racer.get_instance_id()]
		var racer_result := _build_racer_result(racer, racer_data)
		racer_result.finish_position = int(racer_data.finish_position) if bool(racer_data.finished) else index + 1
		standings.append(racer_result)
	return standings


func get_results_wait_remaining() -> float:
	return _results_wait_remaining


func get_best_active_racer() -> Node:
	var ordered := racers.duplicate()
	ordered.sort_custom(_is_racer_ahead)
	for racer in ordered:
		if not bool(_race_data[racer.get_instance_id()].finished):
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
		var racer_data: Dictionary = _race_data[racer.get_instance_id()]
		if not bool(racer_data.finished):
			racer_data.finish_position = index + 1
			racer_data.is_dnf = mark_unfinished_dnf
			_race_data[racer.get_instance_id()] = racer_data
		var racer_result := _build_racer_result(racer, racer_data)
		result.standings.append(racer_result)
		if racer == player_kart:
			result.player_result = racer_result
		if racer.has_method("set_drive_input"):
			racer.set_drive_input(0.0, 0.0, 0.0, false, false)
		racer.is_control_enabled = false
	result.finalize_records()
	race_completed.emit(result)


func _build_racer_result(kart: Node, data: Dictionary) -> RacerRaceResult:
	var result := RacerRaceResult.new()
	var raw_racer_id: Variant = kart.get("racer_id")
	result.racer_id = str(raw_racer_id) if raw_racer_id != null else &""
	result.racer_name = str(kart.get("racer_name"))
	result.is_player = kart == player_kart
	result.start_position = int(data.get("start_position", 0))
	result.finish_position = int(data.get("finish_position", 0))
	result.laps_completed = int(data.get("lap", 0))
	for value in data.get("lap_times", []):
		result.lap_times.append(float(value))
	result.finish_time = float(data.get("finish_time", -1.0)) if bool(data.get("finished", false)) else -1.0
	result.is_dnf = bool(data.get("is_dnf", false))
	if not result.lap_times.is_empty():
		result.best_lap_time = result.lap_times.min()
	result.items_collected = int(data.get("items_collected", 0))
	result.items_used = int(data.get("items_used", 0))
	result.hits_landed = int(data.get("hits_landed", 0))
	result.hits_blocked = int(data.get("hits_blocked", 0))
	result.shortcuts_used = int(data.get("shortcuts_used", 0))
	result.recoveries = int(data.get("recoveries", 0))
	return result


func _emit_player_info() -> void:
	if player_kart == null:
		return
	var data: Dictionary = _race_data[player_kart.get_instance_id()]
	var displayed_lap := clampi(int(data.lap) + 1, 1, total_laps)
	race_info_changed.emit(
		displayed_lap,
		total_laps,
		get_race_position(player_kart),
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
	var data_a: Dictionary = _race_data[a.get_instance_id()]
	var data_b: Dictionary = _race_data[b.get_instance_id()]
	if data_a.finished or data_b.finished:
		if data_a.finished and data_b.finished:
			return int(data_a.finish_position) < int(data_b.finish_position)
		return bool(data_a.finished)
	var progress_a := _calculate_progress(a, data_a)
	var progress_b := _calculate_progress(b, data_b)
	return progress_a > progress_b


func _calculate_progress(kart: Node, data: Dictionary) -> float:
	var next_index: int = data.next_checkpoint
	var previous_index := (next_index - 1 + route_points.size()) % route_points.size()
	var segment_length := route_points[previous_index].distance_to(route_points[next_index])
	var distance_to_next: float = kart.global_position.distance_to(route_points[next_index])
	var segment_progress := 1.0 - clampf(distance_to_next / maxf(segment_length, 0.1), 0.0, 1.0)
	return float(data.lap * route_points.size() + previous_index) + segment_progress


func get_racer_progress(kart: Node) -> float:
	if kart == null or not _race_data.has(kart.get_instance_id()):
		return -1.0
	return _calculate_progress(kart, _race_data[kart.get_instance_id()])
