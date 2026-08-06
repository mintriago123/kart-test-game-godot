@tool
class_name TrackAssetLibrary
extends Resource

@export var entries: Array[TrackAssetEntry] = []


func get_valid_entries() -> Array[TrackAssetEntry]:
	var valid_entries: Array[TrackAssetEntry] = []
	for asset_entry in entries:
		if asset_entry != null and asset_entry.is_valid():
			valid_entries.append(asset_entry)
	return valid_entries
