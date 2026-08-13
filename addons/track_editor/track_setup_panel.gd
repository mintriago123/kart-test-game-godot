@tool
class_name TrackSetupPanel
extends "res://addons/track_editor/track_editor_panel.gd"

signal name_changed(value: String)
signal laps_changed(value: int)
signal description_changed(value: String)
signal environment_theme_changed(theme: TrackTheme)
signal music_changed(music: AudioStream)
signal difficulty_changed(value: String)

const THEMES := [
	["Costa", "res://levels/themes/coastal_theme.tres"],
	["Desierto", "res://levels/themes/desert_theme.tres"],
	["Pantano", "res://levels/themes/swamp_theme.tres"],
	["Cañón", "res://levels/themes/canyon_theme.tres"],
	["Otoño", "res://levels/themes/autumn_theme.tres"],
	["Piratas", "res://levels/themes/pirate_theme.tres"],
	["Volcán", "res://levels/themes/volcano_theme.tres"],
	["Glacial", "res://levels/themes/glacier_theme.tres"],
	["Selva", "res://levels/themes/jungle_theme.tres"],
	["Neón", "res://levels/themes/neon_theme.tres"],
]
const MUSIC := [
	["Pure Raceway", "res://assets/music/coastal.ogg"],
	["Rhythm Garden", "res://assets/music/garden.ogg"],
	["Hot Roadway", "res://assets/music/bahia_turbo.ogg"],
]


func configure(
	track: TrackLevel,
	laps: int,
	description: String,
	button_factory: Callable
) -> void:
	configure_panel("1  CONFIGURACIÓN", button_factory)
	add_help("Ponle identidad a la pista. Las opciones técnicas se configuran solas.")
	add_field_label("Nombre visible")
	var name_edit := LineEdit.new()
	name_edit.text = track.display_name
	name_edit.custom_minimum_size.y = 44.0
	name_edit.text_changed.connect(
		func(value: String) -> void: name_changed.emit(value)
	)
	add_child(name_edit)

	add_field_label("Identificador")
	var id_label := Label.new()
	id_label.text = str(track.track_id)
	id_label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
	add_child(id_label)

	add_field_label("Ambientación")
	var theme_picker := OptionButton.new()
	for option in THEMES:
		theme_picker.add_item(option[0])
		theme_picker.set_item_metadata(theme_picker.item_count - 1, option[1])
		if track.track_theme != null and track.track_theme.resource_path == option[1]:
			theme_picker.select(theme_picker.item_count - 1)
	theme_picker.item_selected.connect(func(index: int) -> void:
		environment_theme_changed.emit(load(theme_picker.get_item_metadata(index)) as TrackTheme)
	)
	add_child(theme_picker)

	add_field_label("Música")
	var music_picker := OptionButton.new()
	for option in MUSIC:
		music_picker.add_item(option[0])
		music_picker.set_item_metadata(music_picker.item_count - 1, option[1])
		if track.track_music != null and track.track_music.resource_path == option[1]:
			music_picker.select(music_picker.item_count - 1)
	music_picker.item_selected.connect(func(index: int) -> void:
		music_changed.emit(load(music_picker.get_item_metadata(index)) as AudioStream)
	)
	add_child(music_picker)

	add_field_label("Dificultad")
	var difficulty_picker := OptionButton.new()
	difficulty_picker.add_item("Media")
	difficulty_picker.add_item("Difícil")
	difficulty_picker.select(1 if track.difficulty == "Difícil" else 0)
	difficulty_picker.item_selected.connect(func(index: int) -> void:
		difficulty_changed.emit(difficulty_picker.get_item_text(index))
	)
	add_child(difficulty_picker)

	add_field_label("Vueltas")
	var laps_input := SpinBox.new()
	laps_input.min_value = 1.0
	laps_input.max_value = 9.0
	laps_input.value = laps
	laps_input.custom_minimum_size.y = 44.0
	laps_input.value_changed.connect(
		func(value: float) -> void: laps_changed.emit(int(value))
	)
	add_child(laps_input)

	add_field_label("Descripción para el menú")
	var description_input := TextEdit.new()
	description_input.text = description
	description_input.custom_minimum_size.y = 100.0
	description_input.text_changed.connect(
		func() -> void: description_changed.emit(description_input.text)
	)
	add_child(description_input)
