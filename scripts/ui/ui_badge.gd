class_name UiBadge
extends PanelContainer

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED, NEW, EQUIPPED, ERROR }

var state: State = State.AVAILABLE
var _label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(48, UiTokens.TOUCH_TARGET)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
	_refresh()

func configure(value: State, caption := "") -> UiBadge:
	state = value
	if is_node_ready():
		_label.text = caption if not caption.is_empty() else _default_caption()
		_refresh()
	return self

func _default_caption() -> String:
	return ["BLOQUEADA", "DISPONIBLE", "ACTIVA", "COMPLETADA", "NUEVO", "EQUIPADO", "ERROR"][state]

func _refresh() -> void:
	if _label == null: return
	_label.text = _default_caption() if _label.text.is_empty() else _label.text
	var color := UiTokens.MUTED
	var border := Color.TRANSPARENT
	match state:
		State.LOCKED: color = UiTokens.TEXT_DISABLED
		State.AVAILABLE: color = UiTokens.CYAN; border = UiTokens.CYAN
		State.ACTIVE: color = UiTokens.ELECTRIC_YELLOW; border = UiTokens.ELECTRIC_YELLOW
		State.COMPLETED: color = UiTokens.SUCCESS; border = UiTokens.SUCCESS
		State.NEW: color = UiTokens.ELECTRIC_YELLOW; border = UiTokens.ELECTRIC_YELLOW
		State.EQUIPPED: color = UiTokens.SUCCESS; border = UiTokens.SUCCESS
		State.ERROR: color = UiTokens.CORAL; border = UiTokens.CORAL
	_label.add_theme_color_override("font_color", color)
	add_theme_stylebox_override("panel", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_SMALL, border))
