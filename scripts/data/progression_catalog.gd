@tool
class_name ProgressionCatalog
extends Resource
@export var cups: CupCatalog
@export var racers: RacerCatalog
@export var difficulties: DifficultyCatalog
@export var unlocks: UnlockCatalog
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if cups == null: errors.append("Missing cup catalog.")
	else: cups.get_valid_cups(); errors.append_array(cups.diagnostics)
	if racers == null: errors.append("Missing racer catalog.")
	else: errors.append_array(racers.validate())
	if difficulties == null: errors.append("Missing difficulty catalog.")
	else: errors.append_array(difficulties.validate())
	if unlocks == null: errors.append("Missing unlock catalog.")
	else: errors.append_array(unlocks.validate())
	return errors
