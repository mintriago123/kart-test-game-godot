class_name MenuShell
extends Control

enum Layout { COMPACT, STANDARD, WIDE }

var layout := Layout.STANDARD
var safe_margin := 24
var header: HBoxContainer
var content: MarginContainer
var prompt_bar: HBoxContainer
var title_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTokens.create_theme()
	_build()
	resized.connect(_update_layout)
	_update_layout()

func set_title(value: String, eyebrow: String = "CAMPEONATO MICHIKART") -> void:
	title_label.text = value
	var eyebrow_label := header.get_node("Heading/Eyebrow") as Label
	eyebrow_label.text = eyebrow

func set_prompts(prompts: Array[Dictionary]) -> void:
	for child in prompt_bar.get_children():
		child.queue_free()
	for descriptor in prompts:
		var prompt := ActionPromptView.new()
		prompt.set_action(StringName(descriptor.get("action", &"ui_accept")))
		prompt.caption = str(descriptor.get("label", ""))
		prompt_bar.add_child(prompt)

func _build() -> void:
	var background := ColorRect.new()
	background.color = UiTokens.GRAPHITE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var page := VBoxContainer.new()
	page.name = "SafeArea"
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	header = HBoxContainer.new()
	header.custom_minimum_size.y = 78
	page.add_child(header)
	var heading := VBoxContainer.new()
	heading.name = "Heading"
	header.add_child(heading)
	var eyebrow := Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "CAMPEONATO MICHIKART"
	eyebrow.add_theme_color_override("font_color", UiTokens.CYAN)
	heading.add_child(eyebrow)
	title_label = Label.new()
	title_label.text = "MICHIKART XD"
	title_label.add_theme_font_size_override("font_size", 38)
	heading.add_child(title_label)
	content = MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(content)
	prompt_bar = HBoxContainer.new()
	prompt_bar.alignment = BoxContainer.ALIGNMENT_END
	prompt_bar.custom_minimum_size.y = 58
	page.add_child(prompt_bar)

func _update_layout() -> void:
	if size.x < 800 or size.y < 500:
		layout = Layout.COMPACT
		safe_margin = 16
	elif size.x >= 1600:
		layout = Layout.WIDE
		safe_margin = 48
	else:
		layout = Layout.STANDARD
		safe_margin = 28
	var page := get_node("SafeArea") as VBoxContainer
	page.offset_left = safe_margin
	page.offset_top = safe_margin
	page.offset_right = -safe_margin
	page.offset_bottom = -safe_margin
