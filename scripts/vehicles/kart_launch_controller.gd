class_name KartLaunchController
extends Node

var kart: Kart
var crossing := INF
var resolved := false
var straight_launch_requested := false


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func capture_input() -> void:
	if kart.race_manager == null or kart.race_manager.state != RaceManager.RaceState.COUNTDOWN:
		return
	if is_inf(crossing) and kart.get_throttle_input() > kart.driving_tuning.launch_throttle_threshold:
		crossing = -kart.race_manager.get_countdown_remaining()


func register_crossing(relative_time: float) -> void:
	if is_inf(crossing):
		crossing = relative_time


func resolve(enabled: bool) -> int:
	if resolved or not enabled:
		resolved = true
		return 0
	resolved = true
	if crossing < kart.driving_tuning.launch_early_limit:
		kart._status_timers.launch_bog_remaining = kart.driving_tuning.launch_bog_duration
		kart.presentation_launch_bogged.emit()
		return -1
	if crossing >= kart.driving_tuning.launch_perfect_start and crossing <= 0.0:
		kart._activate_boost(kart.driving_tuning.launch_perfect_duration, kart.driving_tuning.launch_boost_power)
		return 2
	if crossing >= kart.driving_tuning.launch_good_start and crossing < kart.driving_tuning.launch_perfect_start:
		kart._activate_boost(kart.driving_tuning.launch_good_duration, kart.driving_tuning.launch_boost_power)
		return 1
	return 0


func request_straight_launch() -> void:
	straight_launch_requested = true


func consume_straight_launch_request() -> bool:
	var was_requested := straight_launch_requested
	straight_launch_requested = false
	return was_requested
