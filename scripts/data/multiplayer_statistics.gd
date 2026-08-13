class_name MultiplayerStatistics
extends RefCounted

var races_played := 0
var victories := 0
var podiums := 0
var best_finish_position := 0
var driving_time_seconds := 0.0
var items_collected := 0
var items_used := 0
var shortcuts_used := 0
var recoveries := 0


func record(result: RacerRaceResult) -> void:
	if result == null:
		return
	races_played += 1
	victories += int(result.finish_position == 1)
	podiums += int(result.finish_position > 0 and result.finish_position <= 3)
	if result.finish_position > 0 and (best_finish_position == 0 or result.finish_position < best_finish_position):
		best_finish_position = result.finish_position
	driving_time_seconds += maxf(result.finish_time, 0.0)
	items_collected += result.items_collected
	items_used += result.items_used
	shortcuts_used += result.shortcuts_used
	recoveries += result.recoveries


func to_dict() -> Dictionary:
	return {
		"races_played": races_played,
		"victories": victories,
		"podiums": podiums,
		"best_finish_position": best_finish_position,
		"driving_time_seconds": driving_time_seconds,
		"items_collected": items_collected,
		"items_used": items_used,
		"shortcuts_used": shortcuts_used,
		"recoveries": recoveries,
	}


static func from_dict(value: Variant) -> MultiplayerStatistics:
	var result := MultiplayerStatistics.new()
	if not value is Dictionary:
		return result
	var data := value as Dictionary
	result.races_played = maxi(int(data.get("races_played", 0)), 0)
	result.victories = maxi(int(data.get("victories", 0)), 0)
	result.podiums = maxi(int(data.get("podiums", 0)), 0)
	result.best_finish_position = maxi(int(data.get("best_finish_position", 0)), 0)
	result.driving_time_seconds = maxf(float(data.get("driving_time_seconds", 0.0)), 0.0)
	result.items_collected = maxi(int(data.get("items_collected", 0)), 0)
	result.items_used = maxi(int(data.get("items_used", 0)), 0)
	result.shortcuts_used = maxi(int(data.get("shortcuts_used", 0)), 0)
	result.recoveries = maxi(int(data.get("recoveries", 0)), 0)
	return result
