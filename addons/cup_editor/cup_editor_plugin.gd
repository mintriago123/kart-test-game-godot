@tool
extends EditorPlugin

var _screen: CupEditorScreen


func _enter_tree() -> void:
	_screen = CupEditorScreen.new()
	_screen.name = "CupEditorMainScreen"
	_screen.filesystem_refresh_requested.connect(_refresh_filesystem)
	get_editor_interface().get_editor_main_screen().add_child(_screen)
	_make_visible(false)


func _exit_tree() -> void:
	if _screen != null: _screen.queue_free()


func _has_main_screen() -> bool: return true


func _make_visible(value: bool) -> void:
	if _screen != null: _screen.visible = value


func _get_plugin_name() -> String: return "Copas"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("AnimationTrackList", "EditorIcons")


func _refresh_filesystem() -> void:
	get_editor_interface().get_resource_filesystem().scan()
