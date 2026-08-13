class_name ModeSelectScreen
extends Control

signal mode_selected(mode: int)
signal back_requested
var last_focused_mode := GameModeDefinition.RACE
var _page: Control
var _visible_modes: Array[int] = []


static func available_modes_for_platform(is_android: bool, is_ios: bool) -> Array[int]:
	var result: Array[int] = [
		GameModeDefinition.RACE,
		GameModeDefinition.TIME_TRIAL,
		GameModeDefinition.CUP,
	]
	if not is_android and not is_ios:
		result.append(GameModeDefinition.LOCAL_MULTIPLAYER)
	if not is_ios:
		result.append(GameModeDefinition.LAN_MULTIPLAYER)
	return result


static func descriptor_for_mode(mode: int) -> Array:
	match mode:
		GameModeDefinition.TIME_TRIAL:
			return [mode, &"time_trial", "CONTRARRELOJ", "Supera tu récord y corre contra tu fantasma."]
		GameModeDefinition.CUP:
			return [mode, &"cup", "COPA", "Cuatro pilotos, puntos, medallas y recompensas."]
		GameModeDefinition.LOCAL_MULTIPLAYER:
			return [mode, &"local_multiplayer", "PANTALLA DIVIDIDA", "Dos jugadores y seis rivales IA en una pantalla."]
		GameModeDefinition.LAN_MULTIPLAYER:
			return [mode, &"lan_multiplayer", "RED LOCAL", "Hasta cuatro dispositivos en una red de confianza."]
		_:
			return [GameModeDefinition.RACE, &"quick_race", "CARRERA RÁPIDA", "Ocho corredores, objetos y acción individual."]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.GRAPHITE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var page := VBoxContainer.new(); _page = page; page.set_anchors_preset(Control.PRESET_CENTER); page.position = Vector2(-600, -270); page.size = Vector2(1200, 540); page.pivot_offset = page.size * 0.5; add_child(page)
	var title := Label.new(); title.text = "ELIGE CÓMO CORRER"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 42); page.add_child(title)
	var cards := GridContainer.new(); cards.columns = 3; cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; page.add_child(cards)
	_visible_modes = available_modes_for_platform(OS.has_feature("android"), OS.has_feature("ios"))
	for mode in _visible_modes:
		var descriptor := descriptor_for_mode(mode)
		var card := EventCard.new(); card.configure(descriptor[1], descriptor[2], descriptor[3]); card.pressed.connect(_choose.bind(mode)); card.focus_entered.connect(_remember_focus.bind(mode)); cards.add_child(card)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func(): back_requested.emit()); page.add_child(back)
	resized.connect(_update_layout); _update_layout()

func focus_last() -> void:
	var cards := find_children("*", "EventCard", true, false)
	var index := _visible_modes.find(last_focused_mode)
	if index >= 0 and index < cards.size(): (cards[index] as Control).grab_focus.call_deferred()

func _choose(mode: int) -> void:
	last_focused_mode = mode
	mode_selected.emit(mode)

func _remember_focus(mode: int) -> void:
	last_focused_mode = mode

func _update_layout() -> void:
	if _page == null: return
	var factor := minf(1.0, minf((size.x - 32.0) / 1200.0, (size.y - 32.0) / 540.0))
	_page.scale = Vector2.ONE * maxf(factor, 0.5)
