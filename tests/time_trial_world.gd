extends SceneTree

const TRACK_CATALOG: TrackCatalog = preload("res://levels/track_catalog.tres")

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for action in [&"accelerate", &"brake", &"steer_right", &"steer_left", &"drift", &"use_item"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var definition := TRACK_CATALOG.get_default_track()
	var world := RaceWorld.new()
	world.track_definition = definition
	world.race_class = RaceClassDefinition.get_default()
	world.game_mode = GameModeDefinition.TIME_TRIAL
	world.play_intro = false
	root.add_child(world)
	await process_frame
	await process_frame
	_expect(world.race_manager != null, "manager is created")
	_expect(world.race_manager.game_mode == GameModeDefinition.TIME_TRIAL, "manager receives time-trial mode")
	_expect(world.race_manager.racers.size() == 1, "only the player is registered")
	_expect(world.find_children("*", "AiDriver", true, false).is_empty(), "no AI is instantiated")
	_expect(world.find_children("*", "ItemBox", true, false).is_empty(), "no item boxes are instantiated")
	_expect(world.find_child("ItemExecutor", true, false) == null, "item executor is absent")
	_expect(world.find_child("GhostRecorder", true, false) != null, "recorder is ready")
	world.shutdown()
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("TIME TRIAL WORLD TESTS PASSED")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("TIME TRIAL WORLD: " + message)
