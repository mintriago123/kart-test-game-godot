extends SceneTree

const CYCLE_COUNT := 4

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for cycle_index in CYCLE_COUNT:
		await _exercise_playback_cycle(cycle_index)
	for _frame_index in 3:
		await process_frame
	quit(1 if _has_failed else 0)


func _exercise_playback_cycle(cycle_index: int) -> void:
	var manager := SoundManager.new()
	root.add_child(manager)
	await process_frame

	manager.start_music()
	manager.play_countdown("3")
	manager.play_countdown("2")
	manager.play_countdown("1")
	manager.play_countdown("¡YA!")
	manager.play_pickup()
	manager.play_hit()
	manager.play_projectile_bounce(cycle_index)
	manager.play_item_activation()
	manager.play_shield_block()
	manager.play_item_deploy()
	manager.play_item_launch()
	manager.play_item_impact()
	manager.play_finish()

	var music_stream_ref: WeakRef = weakref(manager._music_player.stream)
	var tone_stream_ref: WeakRef = weakref(manager._sfx_player.stream)
	var manager_ref: WeakRef = weakref(manager)
	var playback_state_is_expected := (
		not manager._music_player.playing
		and not manager._sfx_player.playing
		if AudioServer.get_driver_name() == "Dummy"
		else (
			manager._music_player.playing
			and manager._sfx_player.playing
		)
	)
	_check(
		manager._music_player.stream is AudioStreamWAV
		and manager._sfx_player.stream is AudioStreamWAV,
		"Playback cycle %d builds generated music and tones."
		% (cycle_index + 1)
	)
	_check(
		playback_state_is_expected,
		"Playback cycle %d respects the active audio driver."
		% (cycle_index + 1)
	)

	manager.shutdown()
	manager.shutdown()
	_check(
		manager._music_player == null
		and manager._sfx_player == null,
		"Playback cycle %d shuts down idempotently."
		% (cycle_index + 1)
	)
	await process_frame
	await create_timer(0.05, true, false, true).timeout
	_check(
		music_stream_ref.get_ref() == null
		and tone_stream_ref.get_ref() == null,
		"Playback cycle %d releases temporary audio streams."
		% (cycle_index + 1)
	)

	manager.queue_free()
	await process_frame
	await process_frame
	_check(
		manager_ref.get_ref() == null,
		"Playback cycle %d destroys the sound manager."
		% (cycle_index + 1)
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_has_failed = true
		push_error("FAIL: " + message)
