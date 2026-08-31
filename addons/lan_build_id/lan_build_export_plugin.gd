@tool
extends EditorExportPlugin

const LanBuildIdentityScript = preload("res://scripts/network/lan_build_identity.gd")


func _get_name() -> String:
	return "LAN Build Identity"


func _export_begin(
	_features: PackedStringArray,
	_is_debug: bool,
	_path: String,
	_flags: int
) -> void:
	var result: Dictionary = LanBuildIdentityScript.create_export_identity()
	var build_id := str(result.get("id", "unverifiable:missing"))
	add_file(LanBuildIdentityScript.RUNTIME_FILE_PATH, (build_id + "\n").to_utf8_buffer(), false)
	if not bool(result.get("git_available", false)):
		push_warning(
			"LAN build identity: Git no está disponible o el proyecto no tiene un commit; " +
			"el artefacto se marcará como no verificable (%s)." % build_id
		)
