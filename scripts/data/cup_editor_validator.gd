@tool
class_name CupEditorValidator
extends RefCounted


static func validate(cup: CupDefinition, catalog: ProgressionCatalog = null) -> Array[CupValidationIssue]:
	var issues: Array[CupValidationIssue] = []
	if cup == null:
		issues.append(CupValidationIssue.new(&"information", "No hay una Copa abierta."))
		return issues
	for message in cup.validate():
		issues.append(CupValidationIssue.new(_path_for_message(message), message))
	if cup.display_name.strip_edges().is_empty():
		issues.append(CupValidationIssue.new(&"information/name", "El nombre visible es obligatorio."))
	if catalog == null:
		return issues
	for track in cup.tracks:
		if track != null and catalog_has_track(catalog, track.id) == false:
			issues.append(CupValidationIssue.new(&"tracks", "La pista %s ya no está publicada." % track.id))
	if not cup.prerequisite_cup_id.is_empty():
		var prerequisite := catalog.cups.get_cup(cup.prerequisite_cup_id) if catalog.cups != null else null
		if prerequisite == null:
			issues.append(CupValidationIssue.new(&"information/prerequisite", "La Copa previa %s no está publicada." % cup.prerequisite_cup_id))
		elif not cup.prerequisite_difficulty_id.is_empty() and catalog.difficulties.get_difficulty(cup.prerequisite_difficulty_id) not in prerequisite.difficulties:
			issues.append(CupValidationIssue.new(&"information/prerequisite", "La dificultad requerida no pertenece a la Copa previa."))
	for unlock in cup.unlocks:
		if unlock == null or not unlock.is_valid():
			issues.append(CupValidationIssue.new(&"rewards", "Hay una recompensa incompleta."))
			continue
		if unlock.requirement_type != UnlockDefinition.CUP_MEDAL or unlock.cup_id != cup.id:
			issues.append(CupValidationIssue.new(&"rewards", "La recompensa %s no pertenece a esta configuración." % unlock.id))
	if cup.unlocks.size() > 3:
		issues.append(CupValidationIssue.new(&"rewards", "Una Copa admite como máximo tres recompensas."))
	var cells := {}; var local_variants := {}
	for unlock in cup.unlocks:
		if unlock == null or unlock.kart_variant == null: continue
		var cell := str(unlock.required_medal)
		if cells.has(cell): issues.append(CupValidationIssue.new(&"rewards", "La celda %s tiene más de una recompensa." % cell))
		cells[cell] = true
		if local_variants.has(unlock.kart_variant.id): issues.append(CupValidationIssue.new(&"rewards", "El vehículo %s está asignado más de una vez." % unlock.kart_variant.id))
		local_variants[unlock.kart_variant.id] = true
		if catalog.unlocks != null:
			for existing in catalog.unlocks.unlocks:
				if (existing != null and existing.kart_variant != null
						and existing.kart_variant.id == unlock.kart_variant.id
						and existing.id != unlock.id and existing.cup_id != cup.id):
					issues.append(CupValidationIssue.new(&"rewards", "El vehículo %s ya está asignado a %s." % [unlock.kart_variant.id, existing.id]))
	return _deduplicate(issues)


static func catalog_has_track(_catalog: ProgressionCatalog, track_id: StringName) -> bool:
	var track_catalog := load("res://levels/track_catalog.tres") as TrackCatalog
	var track := track_catalog.get_track(track_id) if track_catalog != null else null
	return track != null and track.is_valid()


static func _path_for_message(message: String) -> StringName:
	var lower := message.to_lower()
	if "prerequisite" in lower or "previa" in lower: return &"information/prerequisite"
	if "track" in lower: return &"tracks"
	if "racer" in lower or "scoring" in lower or "player" in lower or "opponent" in lower: return &"competition"
	if "medal" in lower or "threshold" in lower: return &"medals"
	if "difficult" in lower: return &"competition/difficulties"
	if "id" in lower: return &"information/id"
	return &"review"


static func _deduplicate(values: Array[CupValidationIssue]) -> Array[CupValidationIssue]:
	var result: Array[CupValidationIssue] = []
	var seen := {}
	for issue in values:
		var key := "%s:%s" % [issue.field_path, issue.message]
		if not seen.has(key):
			seen[key] = true
			result.append(issue)
	return result
