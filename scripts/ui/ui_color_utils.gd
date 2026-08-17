class_name UiColorUtils
extends RefCounted

const MIN_TEXT_CONTRAST := 4.5
const GRAPHITE := Color("#0B1117")
const WARM_WHITE := Color("#F4F0E6")


static func safe_accent(source: Color) -> Color:
	# Keep the track identity while preventing muddy or fluorescent UI accents.
	var saturation := clampf(source.s, 0.28, 0.82)
	var value := clampf(source.v, 0.42, 0.82)
	return Color.from_hsv(source.h, saturation, value, source.a)


static func readable_foreground(background: Color) -> Color:
	var accent := safe_accent(background)
	return WARM_WHITE if contrast_ratio(accent, WARM_WHITE) >= MIN_TEXT_CONTRAST else GRAPHITE


static func contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	var lighter := maxf(first_luminance, second_luminance)
	var darker := minf(first_luminance, second_luminance)
	return (lighter + 0.05) / (darker + 0.05)


static func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)


static func _linear_channel(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)
