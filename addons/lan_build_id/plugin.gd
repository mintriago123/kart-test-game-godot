@tool
extends EditorPlugin

const LanBuildExportPluginScript = preload("res://addons/lan_build_id/lan_build_export_plugin.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = LanBuildExportPluginScript.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
