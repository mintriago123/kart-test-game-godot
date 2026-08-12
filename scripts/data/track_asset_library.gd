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


func get_entry(asset_id: StringName) -> TrackAssetEntry:
	if asset_id.is_empty():
		return null
	for asset_entry in get_valid_entries():
		if asset_entry.id == asset_id:
			return asset_entry
	return null


func get_entry_for_scene_path(scene_path: String) -> TrackAssetEntry:
	if scene_path.is_empty():
		return null
	for asset_entry in get_valid_entries():
		if (
			asset_entry.scene != null
			and asset_entry.scene.resource_path == scene_path
		):
			return asset_entry
	return null
