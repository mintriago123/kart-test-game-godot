@tool
class_name TrackEditorConflictController
extends RefCounted

var scene_pending := false
var catalog_pending := false
var last_summary: Dictionary = {}


func absorb(changes: Dictionary) -> void:
	scene_pending = scene_pending or bool(changes.get("scene", false))
	catalog_pending = catalog_pending or bool(changes.get("catalog", false))
	last_summary = changes.duplicate(true)


func has_pending() -> bool:
	return scene_pending or catalog_pending


func clear_scene() -> void:
	scene_pending = false


func clear_catalog() -> void:
	catalog_pending = false


func clear_all() -> void:
	scene_pending = false
	catalog_pending = false
	last_summary.clear()


func affected_scope() -> String:
	if scene_pending and catalog_pending:
		return "la escena y el catálogo"
	if catalog_pending:
		return "el catálogo"
	return "la escena"


func state_label(changes: Dictionary) -> String:
	return "externa" if (
		bool(changes.get("scene", false)) or scene_pending
	) else "local"


func comparison_text(summary: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("RESUMEN DE CAMBIOS EXTERNOS")
	lines.append("")
	for source_key in [&"scene", &"catalog"]:
		var source: Dictionary = summary.get(source_key, {})
		var pending := bool(source.get("changed", false))
		if source_key == &"scene":
			pending = pending or scene_pending
		else:
			pending = pending or catalog_pending
		var source_label := "Escena" if source_key == &"scene" else "Catálogo"
		var path := str(source.get("path", ""))
		lines.append("%s: %s" % [source_label, "CAMBIÓ" if pending else "sin cambios"])
		if not path.is_empty():
			lines.append("  Archivo: %s" % path)
		if pending:
			lines.append(
				"  Firma observada: %s"
				% _format_signature(source.get("observed", {}))
			)
			lines.append(
				"  Firma actual: %s"
				% _format_signature(source.get("current", {}))
			)
	lines.append("")
	if catalog_pending or bool(summary.get("catalog", {}).get("changed", false)):
		lines.append("Confirma el catálogo más reciente antes de publicar.")
	else:
		lines.append("Recargar descarta los cambios locales; conservarlos permite sobrescribir.")
	return "\n".join(lines)


func _format_signature(signature: Dictionary) -> String:
	if not bool(signature.get("exists", false)):
		return "no existe"
	return "tamaño %d · hash %s" % [
		int(signature.get("size", 0)),
		str(signature.get("hash", "desconocido")),
	]
