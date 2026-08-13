class_name ModeSelectScreen
extends Control

signal mode_selected(mode: int)
signal back_requested
var last_focused_mode := GameModeDefinition.RACE
var _page: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.GRAPHITE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var page := VBoxContainer.new(); _page = page; page.set_anchors_preset(Control.PRESET_CENTER); page.position = Vector2(-480, -190); page.size = Vector2(960, 380); page.pivot_offset = page.size * 0.5; add_child(page)
	var title := Label.new(); title.text = "ELIGE CÓMO CORRER"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 42); page.add_child(title)
	var cards := HBoxContainer.new(); cards.alignment = BoxContainer.ALIGNMENT_CENTER; page.add_child(cards)
	for descriptor in [[GameModeDefinition.RACE, &"quick_race", "CARRERA RÁPIDA", "Compite contra tres rivales con objetos."], [GameModeDefinition.TIME_TRIAL, &"time_trial", "CONTRARRELOJ", "Supera tu récord y corre contra tu fantasma."], [GameModeDefinition.CUP, &"cup", "COPA", "Tres circuitos, puntos, medallas y recompensas."]]:
		var card := EventCard.new(); card.configure(descriptor[1], descriptor[2], descriptor[3]); card.pressed.connect(_choose.bind(descriptor[0])); card.focus_entered.connect(func(): last_focused_mode = descriptor[0]); cards.add_child(card)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func(): back_requested.emit()); page.add_child(back)
	resized.connect(_update_layout); _update_layout()

func focus_last() -> void:
	var cards := find_children("*", "EventCard", true, false)
	var index := [GameModeDefinition.RACE, GameModeDefinition.TIME_TRIAL, GameModeDefinition.CUP].find(last_focused_mode)
	if index >= 0 and index < cards.size(): (cards[index] as Control).grab_focus.call_deferred()

func _choose(mode: int) -> void:
	last_focused_mode = mode
	mode_selected.emit(mode)

func _update_layout() -> void:
	if _page == null: return
	var factor := minf(1.0, minf((size.x - 32.0) / 960.0, (size.y - 32.0) / 380.0))
	_page.scale = Vector2.ONE * maxf(factor, 0.5)
