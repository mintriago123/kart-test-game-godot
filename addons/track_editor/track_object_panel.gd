@tool
class_name TrackObjectPanel
extends "res://addons/track_editor/track_editor_panel.gd"

const ASSET_LIBRARY_PATH := "res://assets/track/track_asset_library.tres"

signal add_item_requested(point_index: int)
signal add_asset_requested(
	entry: TrackAssetEntry,
	point_index: int,
	side_sign: float,
	distance: float,
	rotation_degrees_y: float
)


func configure(track: TrackLevel, button_factory: Callable) -> void:
	configure_panel("4  OBJETOS", button_factory)
	add_help(
		"Elige un punto y un lado. El editor coloca la decoración fuera "
		+ "de la carretera para no bloquear los karts."
	)
	var route := track.get_main_route()
	var point_count := (
		route.curve.point_count
		if route != null and route.curve != null
		else 0
	)
	add_field_label("Cajas de objetos")
	var route_point := OptionButton.new()
	for point_index in point_count:
		route_point.add_item("Punto %d" % (point_index + 1))
	route_point.custom_minimum_size.y = 44.0
	add_child(route_point)
	add_child(
		make_button(
			"＋ AÑADIR CAJA",
			func() -> void: add_item_requested.emit(route_point.selected)
		)
	)

	add_field_label("Decoración CC0")
	var asset_picker := OptionButton.new()
	var asset_entries: Array[TrackAssetEntry] = []
	var library := load(ASSET_LIBRARY_PATH) as TrackAssetLibrary
	if library != null:
		asset_entries = library.get_valid_entries()
		for entry in asset_entries:
			asset_picker.add_item("%s  ·  %s" % [entry.category, entry.display_name])
	asset_picker.custom_minimum_size.y = 44.0
	asset_picker.disabled = asset_entries.is_empty()
	add_child(asset_picker)

	var side_picker := OptionButton.new()
	side_picker.add_item("Lado izquierdo")
	side_picker.add_item("Lado derecho")
	side_picker.custom_minimum_size.y = 44.0
	add_child(side_picker)
	add_field_label("Distancia desde el centro")
	var asset_distance := SpinBox.new()
	asset_distance.min_value = 12.0
	asset_distance.max_value = 35.0
	asset_distance.step = 1.0
	asset_distance.value = 15.0
	asset_distance.suffix = " m"
	asset_distance.custom_minimum_size.y = 44.0
	add_child(asset_distance)
	add_field_label("Rotación")
	var asset_rotation := SpinBox.new()
	asset_rotation.min_value = -180.0
	asset_rotation.max_value = 180.0
	asset_rotation.step = 15.0
	asset_rotation.suffix = "°"
	asset_rotation.custom_minimum_size.y = 44.0
	add_child(asset_rotation)
	var add_asset := make_button(
		"＋ COLOCAR DECORACIÓN",
		func() -> void:
			if asset_picker.selected >= 0:
				add_asset_requested.emit(
					asset_entries[asset_picker.selected],
					route_point.selected,
					-1.0 if side_picker.selected == 0 else 1.0,
					asset_distance.value,
					asset_rotation.value
				)
	)
	add_asset.disabled = asset_entries.is_empty()
	add_child(add_asset)

	var counts := Label.new()
	var props := track.get_node_or_null("Props")
	var items := track.get_node_or_null("ItemSpawns")
	counts.text = "Decoración: %d\nCajas: %d" % [
		props.get_child_count() if props != null else 0,
		items.get_child_count() if items != null else 0,
	]
	counts.add_theme_color_override("font_color", Color("#aab5b9"))
	add_child(counts)
