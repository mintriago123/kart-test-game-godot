class_name VehicleGalleryScreen
extends Control

signal action_requested(payload: Dictionary)
signal back_requested

var catalog: ProgressionCatalog
var progress: PlayerProgress
var payload: Dictionary = {}
var focused_variant_id: StringName
var last_inspected_variant_id: StringName
var showroom: VehicleViewport
var cards: HBoxContainer
var title_label: Label
var status_label: Label
var requirement_label: Label
var stats: VBoxContainer
var primary: ActionButton
var _variants: Array[KartVariantDefinition] = []
var _swipe_start := Vector2.ZERO
var _inspected: Dictionary = {}
var _pending_configuration: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = UiTokens.INK; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	showroom = VehicleViewport.new(); showroom.set_anchors_preset(Control.PRESET_LEFT_WIDE); showroom.anchor_right = 0.7; showroom.offset_left = 20; showroom.offset_top = 20; showroom.offset_bottom = -150; showroom.set_framing(VehicleViewport.Framing.GARAGE); add_child(showroom)
	var left := Button.new(); left.text = "‹"; left.custom_minimum_size = Vector2(52, 64); left.set_anchors_preset(Control.PRESET_CENTER_LEFT); left.position.x = 22; left.pressed.connect(_move.bind(-1)); add_child(left)
	var right := Button.new(); right.text = "›"; right.custom_minimum_size = Vector2(52, 64); right.set_anchors_preset(Control.PRESET_CENTER); right.anchor_left = 0.7; right.anchor_right = 0.7; right.position = Vector2(-74, -32); right.pressed.connect(_move.bind(1)); add_child(right)
	var panel := VBoxContainer.new(); panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE); panel.anchor_left = 0.7; panel.offset_left = 12; panel.offset_right = -24; panel.offset_top = 28; panel.offset_bottom = -158; panel.add_theme_constant_override("separation", 8); add_child(panel)
	title_label = Label.new(); title_label.add_theme_font_size_override("font_size", 32); panel.add_child(title_label)
	status_label = Label.new(); status_label.add_theme_font_size_override("font_size", 18); panel.add_child(status_label)
	requirement_label = Label.new(); requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(requirement_label)
	stats = VBoxContainer.new(); stats.size_flags_vertical = Control.SIZE_EXPAND_FILL; panel.add_child(stats)
	primary = ActionButton.new(); primary.kind = ActionButton.Kind.PRIMARY; primary.pressed.connect(_activate); panel.add_child(primary)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func(): back_requested.emit()); panel.add_child(back)
	var strip := ScrollContainer.new(); strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); strip.offset_left = 24; strip.offset_right = -24; strip.offset_top = -138; strip.offset_bottom = -18; strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(strip)
	cards = HBoxContainer.new(); cards.alignment = BoxContainer.ALIGNMENT_CENTER; cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cards.add_theme_constant_override("separation", 12); strip.add_child(cards)
	if not _pending_configuration.is_empty():
		var pending := _pending_configuration
		_pending_configuration = []
		configure(pending[0], pending[1], pending[2])

func configure(value_catalog: ProgressionCatalog, value_progress: PlayerProgress, value_payload: Dictionary) -> void:
	if not is_node_ready() or showroom == null:
		_pending_configuration = [value_catalog, value_progress, value_payload.duplicate(true)]
		return
	catalog = value_catalog; progress = value_progress; payload = value_payload.duplicate(true); _variants.clear()
	if catalog != null:
		for unlock in catalog.unlocks.unlocks:
			if unlock != null and unlock.kart_variant != null: _variants.append(unlock.kart_variant)
	_build_cards()
	var requested := StringName(payload.get("variant_id", &""))
	if requested.is_empty() and str(payload.get("source", "standalone")) == "standalone": requested = last_inspected_variant_id
	if requested.is_empty() and progress != null: requested = progress.equipped_kart_variant_id
	if requested.is_empty() and not _variants.is_empty(): requested = _variants[0].id
	focus_variant(requested)

func _build_cards() -> void:
	if cards == null: return
	for child in cards.get_children(): child.queue_free()
	for variant in _variants:
		var button := Button.new(); button.text = variant.display_name.to_upper(); button.custom_minimum_size = Vector2(190, 88); button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(focus_variant.bind(variant.id)); button.focus_entered.connect(focus_variant.bind(variant.id)); cards.add_child(button)

func focus_variant(variant_id: StringName) -> void:
	var variant := _get_variant(variant_id)
	if variant == null:
		return
	focused_variant_id = variant.id; last_inspected_variant_id = variant.id; payload["variant_id"] = variant.id
	showroom.show_variant(variant); title_label.text = variant.display_name.to_upper()
	var equipped := progress != null and progress.equipped_kart_variant_id == variant.id
	var unlocked := _is_unlocked(variant.id)
	var is_new := unlocked and not equipped and not _inspected.has(variant.id)
	_inspected[variant.id] = true
	var locked_by_cup := bool(payload.get("continue_active", false)) and str(payload.get("source", "")) == "play" and not equipped
	status_label.text = "EQUIPADO" if equipped else ("NUEVO" if is_new else ("DISPONIBLE" if unlocked else "BLOQUEADO"))
	var unlock := _get_unlock(variant.id)
	if locked_by_cup:
		requirement_label.text = "Vehículo fijado para esta copa activa."
	elif unlocked:
		requirement_label.text = "Listo para competir."
	elif unlock != null:
		requirement_label.text = "Requisito · %s / %s / %s" % [unlock.cup_id, unlock.difficulty_id, ["", "BRONCE", "PLATA", "ORO"][unlock.required_medal]]
	else:
		requirement_label.text = "No disponible"
	_build_stats(variant)
	var standalone := str(payload.get("source", "standalone")) == "standalone"
	primary.text = ("EQUIPADO" if equipped else ("EQUIPAR" if unlocked else "BLOQUEADO")) if standalone else ("CONTINUAR" if unlocked and not locked_by_cup else ("EQUIPADO" if locked_by_cup else "BLOQUEADO"))
	primary.disabled = (standalone and (equipped or not unlocked)) or (not standalone and (not unlocked or locked_by_cup))

func _build_stats(variant: KartVariantDefinition) -> void:
	for child in stats.get_children(): child.queue_free()
	var equipped := _get_variant(progress.equipped_kart_variant_id) if progress != null else null
	for data in [["Velocidad", variant.speed, 1.2], ["Aceleración", variant.acceleration, 1.2], ["Manejo", variant.handling, 1.2], ["Peso", variant.weight, 1.25], ["Miniturbo", variant.mini_turbo_duration_multiplier, 1.25]]:
		var current := float(data[1]); var baseline := _stat_value(equipped, str(data[0])) if equipped != null else current; var difference := current - baseline
		var row := HBoxContainer.new(); stats.add_child(row)
		var label := Label.new(); label.text = str(data[0]); label.custom_minimum_size.x = 90; row.add_child(label)
		var bar := ProgressBar.new(); bar.max_value = float(data[2]); bar.value = current; bar.show_percentage = false; bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(bar)
		var value := Label.new(); value.text = "%.2f  %s %.2f" % [current, "↑" if difference > 0.001 else ("↓" if difference < -0.001 else "="), absf(difference)]; value.custom_minimum_size.x = 112; row.add_child(value)

func _stat_value(variant: KartVariantDefinition, label: String) -> float:
	match label:
		"Velocidad": return variant.speed
		"Aceleración": return variant.acceleration
		"Manejo": return variant.handling
		"Peso": return variant.weight
		_: return variant.mini_turbo_duration_multiplier

func _activate() -> void:
	var result := payload.duplicate(true); result["variant_id"] = focused_variant_id; action_requested.emit(result)

func _move(direction: int) -> void:
	if _variants.is_empty(): return
	var index := 0
	for i in _variants.size():
		if _variants[i].id == focused_variant_id:
			index = i
	focus_variant(_variants[posmod(index + direction, _variants.size())].id)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed(&"ui_left"): _move(-1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"): _move(1); get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed: _swipe_start = event.position
		elif absf(event.position.x - _swipe_start.x) > 60: _move(-1 if event.position.x > _swipe_start.x else 1)

func _is_unlocked(variant_id: StringName) -> bool:
	if progress == null or catalog == null: return false
	if progress.equipped_kart_variant_id == variant_id: return true
	var unlock := _get_unlock(variant_id)
	return unlock != null and (progress.unlocked_reward_ids.has(unlock.id) or (catalog.unlocks.unlocks.size() > 0 and catalog.unlocks.unlocks[0] == unlock))

func _get_unlock(variant_id: StringName) -> UnlockDefinition:
	for unlock in catalog.unlocks.unlocks:
		if unlock != null and unlock.kart_variant != null and unlock.kart_variant.id == variant_id: return unlock
	return null

func _get_variant(variant_id: StringName) -> KartVariantDefinition:
	return catalog.unlocks.get_variant(variant_id) if catalog != null else null
