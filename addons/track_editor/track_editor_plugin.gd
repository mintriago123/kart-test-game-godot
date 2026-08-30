@tool
extends EditorPlugin

const TEST_RUNNER_SCENE := "res://addons/track_editor/track_test_runner.tscn"
const TEST_CONFIG_PATH := "user://coastal_karts_track_test.cfg"
const TEST_RESULT_PATH := "user://coastal_karts_track_test_result.cfg"
const TEST_STATUS_PATH := "user://coastal_karts_track_test_status.cfg"

var _screen: TrackEditorScreen
var _enabled_distraction_free := false


func _enter_tree() -> void:
	_screen = TrackEditorScreen.new()
	_screen.name = "TrackEditorMainScreen"
	_screen.play_requested.connect(_handle_play_requested)
	get_editor_interface().get_editor_main_screen().add_child(_screen)
	_make_visible(false)


func _exit_tree() -> void:
	var test_is_pending := _screen != null and _screen.has_pending_test()
	if _screen != null:
		_screen.queue_free()
	if not test_is_pending:
		for test_path in [TEST_CONFIG_PATH, TEST_RESULT_PATH, TEST_STATUS_PATH]:
			if FileAccess.file_exists(test_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if _enabled_distraction_free:
		get_editor_interface().set_distraction_free_mode(false)
		_enabled_distraction_free = false


func _has_main_screen() -> bool:
	return true


func _make_visible(is_visible: bool) -> void:
	if _screen != null:
		_screen.visible = is_visible
		if is_visible:
			_screen.offer_recovery()
	var editor_interface := get_editor_interface()
	if is_visible and not editor_interface.is_distraction_free_mode_enabled():
		editor_interface.set_distraction_free_mode(true)
		_enabled_distraction_free = true
	elif not is_visible and _enabled_distraction_free:
		editor_interface.set_distraction_free_mode(false)
		_enabled_distraction_free = false


func _get_plugin_name() -> String:
	return "Pistas"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon(
		"Path3D",
		"EditorIcons"
	)


func _handle_play_requested(
	scene_path: String,
	track_id: StringName,
	laps: int
) -> void:
	var config := ConfigFile.new()
	config.set_value("track", "scene_path", scene_path)
	config.set_value("track", "id", track_id)
	config.set_value("track", "laps", laps)
	var test_token := "%s-%s" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_msec(),
	]
	config.set_value("test", "token", test_token)
	config.set_value("test", "result_path", TEST_RESULT_PATH)
	config.set_value("test", "status_path", TEST_STATUS_PATH)
	if FileAccess.file_exists(TEST_RESULT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_RESULT_PATH))
	if FileAccess.file_exists(TEST_STATUS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATUS_PATH))
	var save_error := config.save(TEST_CONFIG_PATH)
	if save_error != OK:
		push_error("No se pudo preparar la prueba de pista: %s" % error_string(save_error))
		return
	_screen.track_test_started(test_token, TEST_RESULT_PATH, TEST_STATUS_PATH)
	get_editor_interface().play_custom_scene(TEST_RUNNER_SCENE)
