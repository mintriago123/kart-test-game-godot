class_name KartSurfaceController
extends Node

var kart: Kart
var _surface := SurfaceDefinition.asphalt()
var _zones := {}


func setup(controlled_kart: Kart) -> void:
	kart = controlled_kart


func get_surface() -> SurfaceDefinition:
	return _surface


func set_surface(value: SurfaceDefinition) -> void:
	_surface = value if value != null else SurfaceDefinition.asphalt()


func enter_zone(zone: Node) -> void:
	_zones[zone.get_instance_id()] = zone
	_refresh()


func exit_zone(zone: Node) -> void:
	_zones.erase(zone.get_instance_id())
	_refresh()


func _refresh() -> void:
	var selected: Node
	for value in _zones.values():
		var zone := value as Node
		if is_instance_valid(zone) and zone.is_better_than(selected):
			selected = zone
	set_surface(selected.get("surface") as SurfaceDefinition if selected != null else null)
