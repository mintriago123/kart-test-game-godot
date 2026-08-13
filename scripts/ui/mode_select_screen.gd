class_name ModeSelectScreen
extends Control

signal mode_selected(mode: int)
signal back_requested
var last_focused_mode := GameModeDefinition.RACE
var _page: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.GRAPHITE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var page := VBoxContainer.new(); _page = page; page.set_anchors_preset(Control.PRESET_CENTER); page.position = Vector2(-600, -270); page.size = Vector2(1200, 540); page.pivot_offset = page.size * 0.5; add_child(page)
	var title := Label.new(); title.text = "ELIGE CÓMO CORRER"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 42); page.add_child(title)
	var cards := GridContainer.new(); cards.columns = 3; cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; page.add_child(cards)
	var descriptors := [[GameModeDefinition.RACE, &"quick_race", "CARRERA RÁPIDA", "Ocho corredores, objetos y acción individual."], [GameModeDefinition.TIME_TRIAL, &"time_trial", "CONTRARRELOJ", "Supera tu récord y corre contra tu fantasma."], [GameModeDefinition.CUP, &"cup", "COPA", "Cuatro pilotos, puntos, medallas y recompensas."], [GameModeDefinition.LOCAL_MULTIPLAYER, &"local_multiplayer", "PANTALLA DIVIDIDA", "Dos jugadores y seis rivales IA en una pantalla."]]
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		descriptors.append([GameModeDefinition.LAN_MULTIPLAYER, &"lan_multiplayer", "RED LOCAL", "Hasta cuatro PCs en una red de confianza."])
	for descriptor in descriptors:
		var card := EventCard.new(); card.configure(descriptor[1], descriptor[2], descriptor[3]); card.pressed.connect(_choose.bind(descriptor[0])); card.focus_entered.connect(func(): last_focused_mode = descriptor[0]); cards.add_child(card)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func(): back_requested.emit()); page.add_child(back)
	resized.connect(_update_layout); _update_layout()

func focus_last() -> void:
	var cards := find_children("*", "EventCard", true, false)
	var index := [GameModeDefinition.RACE, GameModeDefinition.TIME_TRIAL, GameModeDefinition.CUP, GameModeDefinition.LOCAL_MULTIPLAYER, GameModeDefinition.LAN_MULTIPLAYER].find(last_focused_mode)
	if index >= 0 and index < cards.size(): (cards[index] as Control).grab_focus.call_deferred()

func _choose(mode: int) -> void:
	last_focused_mode = mode
	mode_selected.emit(mode)

func _update_layout() -> void:
	if _page == null: return
	var factor := minf(1.0, minf((size.x - 32.0) / 1200.0, (size.y - 32.0) / 540.0))
	_page.scale = Vector2.ONE * maxf(factor, 0.5)
