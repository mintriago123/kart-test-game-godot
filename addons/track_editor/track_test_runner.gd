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
var _configuration := ""
var _result_path := DEFAULT_RESULT_PATH
var _status_path := "user://coastal_karts_track_test_status.cfg"
var _has_written_result := false
var _status_ready := false
var _status_elapsed := 0.0
var _test_phase := "initiating"
var _last_written_state := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configure_input()
	var config := ConfigFile.new()
	if config.load(TEST_CONFIG_PATH) != OK:
		_abort_test("No se encontró la configuración de prueba de pista.")
		return
	var scene_path := str(config.get_value("track", "scene_path", ""))
	_test_token = str(config.get_value("test", "token", ""))
	_result_path = str(config.get_value("test", "result_path", DEFAULT_RESULT_PATH))
	_status_path = str(
		config.get_value(
			"test",
			"status_path",
			"user://coastal_karts_track_test_status.cfg"
		)
	)
	if _test_token.is_empty() or scene_path.is_empty():
		_abort_test("La configuración de prueba no contiene una pista o token válido.")
		return
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		_abort_test("No se pudo abrir la pista de prueba: %s" % scene_path)
		return
	var definition := TrackDefinition.new()
	definition.id = StringName(config.get_value("track", "id", "test_track"))
	_track_id = definition.id
	definition.display_name = "Prueba de pista"
	definition.scene = packed_scene
	definition.laps = int(config.get_value("track", "laps", 3))
	_configuration = "vueltas=%d" % definition.laps
	var configured_cc := str(config.get_value("track", "cc_id", ""))
	if not configured_cc.is_empty():
		_configuration += " · %s" % configured_cc
	_world = RaceWorld.new()
	_world.track_definition = definition
	add_child(_world)
	_setup_diagnostics()
	_status_ready = true
	_test_phase = "ready"
	_write_status("ready")


func _process(delta: float) -> void:
	_status_elapsed += delta
	if (
		_world == null
		or _world.player_kart == null
		or _world.race_manager == null
	):
		return
	var desired_state := "ready"
	if _world.race_manager.state == RaceManager.RaceState.RACING:
		_test_phase = "running"
		desired_state = "running"
	elif _world.race_manager.state == RaceManager.RaceState.FINISHED:
		_test_phase = "completed"
		desired_state = "completed"
	if _status_ready and (
		desired_state != _last_written_state or _status_elapsed >= 1.0
	):
		_status_elapsed = 0.0
		_write_status(desired_state)
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
		if not _has_physical_key_event(action, actions[action]):
			var event := InputEventKey.new()
			event.physical_keycode = actions[action]
			InputMap.action_add_event(action, event)


func _has_physical_key_event(action: StringName, keycode: Key) -> bool:
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey:
			var key_event := existing_event as InputEventKey
			if key_event.physical_keycode == keycode:
				return true
	return false


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
		_test_phase = "completed"
		_write_status("completed")
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
	var values: Dictionary = _diagnostics.to_dictionary(_track_id, _test_token, _configuration)
	for key in values:
		result.set_value("result", key, values[key])
	var error := result.save(_result_path)
	if error != OK:
		push_error("No se pudo guardar el diagnóstico de pista: %s" % error_string(error))
	elif _diagnostics.failure_reason.is_empty():
		_test_phase = "completed" if _diagnostics.completed else _test_phase
		_write_status("completed" if _diagnostics.completed else _test_phase)


func _abort_test(message: String) -> void:
	push_error(message)
	_diagnostics.failure_reason = message
	_write_result()
	_write_status("failed", message)
	call_deferred("_quit_after_test_error")


func _quit_after_test_error() -> void:
	get_tree().quit(1)


func _write_status(state: String, error_message := "") -> void:
	if _status_path.is_empty():
		return
	var status := ConfigFile.new()
	status.set_value("test", "token", _test_token)
	status.set_value("test", "state", state)
	status.set_value("test", "phase", _test_phase)
	status.set_value("test", "heartbeat", Time.get_unix_time_from_system())
	if not error_message.is_empty():
		status.set_value("test", "error", error_message)
	var save_error := status.save(_status_path)
	if save_error != OK:
		push_error("No se pudo actualizar el estado de la prueba: %s" % error_string(save_error))
	else:
		_last_written_state = state


func _exit_tree() -> void:
	_write_result()
