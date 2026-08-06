extends Node

const TEST_CONFIG_PATH := "user://coastal_karts_track_test.cfg"

var _world: RaceWorld


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input()
	var config := ConfigFile.new()
	if config.load(TEST_CONFIG_PATH) != OK:
		push_error("No se encontró la configuración de prueba de pista.")
		return
	var scene_path := str(config.get_value("track", "scene_path", ""))
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("No se pudo abrir la pista de prueba: %s" % scene_path)
		return
	var definition := TrackDefinition.new()
	definition.id = StringName(config.get_value("track", "id", "test_track"))
	definition.display_name = "Prueba de pista"
	definition.scene = packed_scene
	definition.laps = int(config.get_value("track", "laps", 3))
	_world = RaceWorld.new()
	_world.track_definition = definition
	add_child(_world)


func _configure_input() -> void:
	var actions := {
		&"steer_left": KEY_A,
		&"steer_right": KEY_D,
		&"accelerate": KEY_W,
		&"brake": KEY_S,
		&"drift": KEY_SPACE,
		&"use_item": KEY_E,
		&"pause": KEY_ESCAPE,
		&"reset_kart": KEY_R,
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		var event := InputEventKey.new()
		event.physical_keycode = actions[action]
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
	if (
		event.is_action_pressed(&"reset_kart")
		and _world != null
		and _world.player_kart != null
	):
		_world.player_kart.reset_to_last_checkpoint()
