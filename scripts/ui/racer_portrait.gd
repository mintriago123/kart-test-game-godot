class_name RacerPortrait
extends Control

var racer: RacerDefinition
var texture: Texture2D

func configure(value: RacerDefinition) -> void:
	racer = value
	texture = value.portrait if value != null else null
	if texture == null and value != null:
		var path := "res://assets/racers/portraits/%s.png" % value.id
		if ResourceLoader.exists(path): texture = load(path) as Texture2D
	queue_redraw()

func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	queue_redraw()

func _draw() -> void:
	var color := racer.body_color if racer != null else UiTokens.CYAN
	var center := size * 0.5
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
	else:
		draw_circle(center, minf(size.x, size.y) * 0.42, color.darkened(0.35))
		draw_circle(center + Vector2(0, 4), minf(size.x, size.y) * 0.27, color)
		draw_circle(center + Vector2(-10, -18), 4, UiTokens.WARM_WHITE)
		draw_circle(center + Vector2(10, -18), 4, UiTokens.WARM_WHITE)
		var initial := racer.display_name.substr(0, 1).to_upper() if racer != null and not racer.display_name.is_empty() else "?"
		var font := ThemeDB.fallback_font
		draw_string(font, center + Vector2(-8, 8), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTokens.GRAPHITE)
