class_name FallbackEmblem
extends Control

@export var accent := UiTokens.ELECTRIC_YELLOW
@export var seed_text := "MK"

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.36
	var points := PackedVector2Array()
	for i in 8:
		var angle := -PI * 0.5 + TAU * float(i) / 8.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, accent.darkened(0.55))
	draw_polyline(points + PackedVector2Array([points[0]]), accent, 3.0, true)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(seed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, center - Vector2(text_size.x * 0.5, -7), seed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTokens.WARM_WHITE)
