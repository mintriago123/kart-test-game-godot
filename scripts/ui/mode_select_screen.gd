class_name ModeSelectScreen
extends Control

signal mode_selected(mode: int)
signal back_requested
var last_focused_mode := GameModeDefinition.RACE
var _page: Control
var _title: Label
var _cards: GridContainer
var _back: Button
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
			return [mode, &"time_trial", "CONTRARRELOJ", "INDIVIDUAL · Supera tu récord y corre contra tu fantasma."]
		GameModeDefinition.CUP:
			return [mode, &"cup", "COPA", "CAMPAÑA · Cuatro pilotos, puntos, medallas y recompensas."]
		GameModeDefinition.LOCAL_MULTIPLAYER:
			return [mode, &"local_multiplayer", "PANTALLA DIVIDIDA", "LOCAL · Dos jugadores y seis rivales IA en una pantalla."]
		GameModeDefinition.LAN_MULTIPLAYER:
			return [mode, &"lan_multiplayer", "RED LOCAL", "RED · Hasta cuatro dispositivos en una red de confianza."]
		_:
			return [GameModeDefinition.RACE, &"quick_race", "CARRERA RÁPIDA", "INDIVIDUAL · Ocho corredores, objetos y acción."]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = UiTokens.GRAPHITE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var page := VBoxContainer.new(); _page = page; page.set_anchors_preset(Control.PRESET_CENTER); page.position = Vector2(-600, -270); page.size = Vector2(1200, 540); page.pivot_offset = page.size * 0.5; add_child(page)
	_title = Label.new(); _title.text = "ELIGE CÓMO CORRER"; _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; page.add_child(_title)
	var cards := GridContainer.new(); _cards = cards; cards.columns = 2; cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL; page.add_child(cards)
	_visible_modes = available_modes_for_platform(OS.has_feature("android"), OS.has_feature("ios"))
	for mode in _visible_modes:
		var descriptor := descriptor_for_mode(mode)
		var card := EventCard.new(); card.configure(descriptor[1], descriptor[2], descriptor[3]); card.pressed.connect(_choose.bind(mode)); card.focus_entered.connect(_remember_focus.bind(mode)); cards.add_child(card)
	_back = ActionButton.new(); _back.text = "VOLVER"; _back.focus_mode = Control.FOCUS_NONE; _back.pressed.connect(func(): back_requested.emit()); page.add_child(_back)
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
	var viewport := size if size.x > 1.0 else get_viewport_rect().size
	var compact := viewport.x < UiTokens.BREAKPOINT_TWO_PANEL_WIDTH or viewport.y < UiTokens.BREAKPOINT_TWO_PANEL_HEIGHT
	_title.add_theme_font_size_override("font_size", UiTokens.FONT_TITLE_COMPACT if compact else UiTokens.FONT_TITLE_WIDE)
	_page.size = Vector2(clampf(viewport.x - 32.0, 320.0, 1180.0), maxf(320.0, viewport.y - 28.0))
	_page.position = (viewport - _page.size) * 0.5
	_page.pivot_offset = _page.size * 0.5
	_cards.columns = 1 if compact else 2
	for child in _cards.get_children():
		(child as Control).custom_minimum_size = Vector2(maxf(280.0, (_page.size.x - 20.0) / (1 if compact else 2) - 10.0), 150.0 if compact else 180.0)
	_back.custom_minimum_size.y = UiTokens.TOUCH_TARGET

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
