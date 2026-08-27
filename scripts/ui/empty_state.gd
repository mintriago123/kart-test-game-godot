class_name EmptyState
extends VBoxContainer

const UiTokens = preload("res://scripts/ui/ui_tokens.gd")


func configure(title: String, message: String, icon: Texture2D = null) -> void:
	for child in get_children():
		child.queue_free()
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", UiTokens.SPACE_3)
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(icon_rect)
	var title_label := Label.new()
	title_label.text = title.to_upper()
	title_label.add_theme_font_override("font", UiTokens.DISPLAY_FONT)
	title_label.add_theme_font_size_override("font_size", UiTokens.FONT_H3)
	title_label.add_theme_color_override("font_color", UiTokens.TEXT_SECONDARY)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)
	if not message.is_empty():
		var body := Label.new()
		body.text = message
		body.add_theme_font_size_override("font_size", UiTokens.FONT_BODY)
		body.add_theme_color_override("font_color", UiTokens.MUTED)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 320
		add_child(body)
