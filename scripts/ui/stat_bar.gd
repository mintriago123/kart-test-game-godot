class_name StatBar
extends HBoxContainer

var bar: ProgressBar
var value_label: Label

func _ready() -> void:
	bar = ProgressBar.new(); bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; add_child(bar)
	value_label = Label.new(); value_label.custom_minimum_size.x = 56; add_child(value_label)

func set_stat(value: float, maximum := 100.0) -> void:
	bar.max_value = maximum; bar.value = value; value_label.text = "%d" % roundi(value)
