extends Node

const TEST_CONFIG_PATH := "user://coastal_karts_track_test.cfg"
const DEFAULT_RESULT_PATH := "user://coastal_karts_track_test_result.cfg"
const Diagnostics := preload(
	"res://addons/track_editor/track_test_diagnostics.gd"
)
const TestOverlay := preload(
	"res://addons/track_editor/track_test_overlay.gd"
)

var _world: RaceWorld
var _diagnostics := Diagnostics.new()
var _overlay
var _test_token := ""
var _track_id := &""
var _result_path := DEFAULT_RESULT_PATH
var _has_written_result := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input()
	var config := ConfigFile.new()
	if config.load(TEST_CONFIG_PATH) != OK:
		push_error("No se encontró la configuración de prueba de pista.")
		return
	var scene_path := str(config.get_value("track", "scene_path", ""))
	_test_token = str(config.get_value("test", "token", ""))
	_result_path = str(config.get_value("test", "result_path", DEFAULT_RESULT_PATH))
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("No se pudo abrir la pista de prueba: %s" % scene_path)
		return
	var definition := TrackDefinition.new()
	definition.id = StringName(config.get_value("track", "id", "test_track"))
	_track_id = definition.id
	definition.display_name = "Prueba de pista"
	definition.scene = packed_scene
	definition.laps = int(config.get_value("track", "laps", 3))
	_world = RaceWorld.new()
	_world.track_definition = definition
	add_child(_world)
	_setup_diagnostics()


func _process(delta: float) -> void:
	if (
		_world == null
		or _world.player_kart == null
		or _world.race_manager == null
	):
		return
	_diagnostics.elapsed_time = _world.race_manager.race_time
	_diagnostics.observe_position(_world.player_kart.global_position, delta)
	if _overlay != null:
		_overlay.update_metrics(_diagnostics)


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
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8:
			_return_to_editor()
			return
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
	if (
		event.is_action_pressed(&"reset_kart")
		and _world != null
		and _world.player_kart != null
	):
		_world.player_kart.reset_to_last_checkpoint()


func _setup_diagnostics() -> void:
	var runtime_track := _world.get("_track") as CoastalTrack
	_diagnostics.configure(runtime_track)
	if _world.player_kart != null:
		_world.player_kart.recovered.connect(func() -> void:
			_diagnostics.record_recovery(_world.player_kart.last_recovery_reason)
		)
	if _world.race_manager != null:
		_world.race_manager.shortcut_accepted.connect(func(kart: Node) -> void:
			if kart == _world.player_kart:
				_diagnostics.record_shortcut()
		)
	_world.race_completed.connect(func(_time: float) -> void:
		_diagnostics.completed = true
	)
	_overlay = TestOverlay.new()
	_overlay.return_requested.connect(_return_to_editor)
	add_child(_overlay)


func _return_to_editor() -> void:
	_write_result()
	get_tree().quit()


func _write_result() -> void:
	if _has_written_result or _test_token.is_empty():
		return
	_has_written_result = true
	var result := ConfigFile.new()
	var values: Dictionary = _diagnostics.to_dictionary(_track_id, _test_token)
	for key in values:
		result.set_value("result", key, values[key])
	var error := result.save(_result_path)
	if error != OK:
		push_error("No se pudo guardar el diagnóstico de pista: %s" % error_string(error))


func _exit_tree() -> void:
	_write_result()
