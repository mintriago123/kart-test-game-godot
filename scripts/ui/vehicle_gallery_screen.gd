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
var card_scroll: ScrollContainer
var title_label: Label
var status_label: Label
var status_badge: UiBadge
var requirement_label: Label
var stats: VBoxContainer
var primary: ActionButton
var details_panel: VBoxContainer
var left_button: Button
var right_button: Button
var _variants: Array[KartVariantDefinition] = []
var _swipe_start := Vector2.ZERO
var _pending_configuration: Array = []
var _scroll_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = UiTokens.INK; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	showroom = VehicleViewport.new(); showroom.set_anchors_preset(Control.PRESET_LEFT_WIDE); showroom.anchor_right = 0.7; showroom.offset_left = 20; showroom.offset_top = 20; showroom.offset_bottom = -150; showroom.set_framing(VehicleViewport.Framing.GARAGE); add_child(showroom)
	left_button = Button.new(); left_button.text = "‹"; left_button.custom_minimum_size = Vector2(52, 64); left_button.set_anchors_preset(Control.PRESET_CENTER_LEFT); left_button.position.x = 22; left_button.pressed.connect(_move.bind(-1)); add_child(left_button)
	right_button = Button.new(); right_button.text = "›"; right_button.custom_minimum_size = Vector2(52, 64); right_button.set_anchors_preset(Control.PRESET_CENTER); right_button.anchor_left = 0.7; right_button.anchor_right = 0.7; right_button.position = Vector2(-74, -32); right_button.pressed.connect(_move.bind(1)); add_child(right_button)
	details_panel = VBoxContainer.new(); details_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE); details_panel.anchor_left = 0.7; details_panel.offset_left = 12; details_panel.offset_right = -24; details_panel.offset_top = 28; details_panel.offset_bottom = -158; details_panel.add_theme_constant_override("separation", 8); add_child(details_panel)
	var panel := details_panel
	title_label = Label.new(); title_label.add_theme_font_size_override("font_size", 32); panel.add_child(title_label)
	status_badge = UiBadge.new(); panel.add_child(status_badge)
	status_label = Label.new(); status_label.add_theme_font_size_override("font_size", 18); panel.add_child(status_label)
	requirement_label = Label.new(); requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(requirement_label)
	stats = VBoxContainer.new(); stats.size_flags_vertical = Control.SIZE_EXPAND_FILL; panel.add_child(stats)
	primary = ActionButton.new(); primary.kind = ActionButton.Kind.PRIMARY; primary.pressed.connect(_activate); panel.add_child(primary)
	var back := ActionButton.new(); back.text = "VOLVER"; back.pressed.connect(func(): back_requested.emit()); panel.add_child(back)
	var strip := ScrollContainer.new(); card_scroll = strip; strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); strip.offset_left = 24; strip.offset_right = -24; strip.offset_top = -138; strip.offset_bottom = -18; strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; add_child(strip)
	cards = HBoxContainer.new(); cards.alignment = BoxContainer.ALIGNMENT_CENTER; cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cards.add_theme_constant_override("separation", 12); strip.add_child(cards)
	if not _pending_configuration.is_empty():
		var pending := _pending_configuration
		_pending_configuration = []
		configure(pending[0], pending[1], pending[2])
	resized.connect(_refresh_gallery_spacing)
	resized.connect(_update_layout)
	card_scroll.resized.connect(_refresh_gallery_spacing)
	_update_layout()

func configure(value_catalog: ProgressionCatalog, value_progress: PlayerProgress, value_payload: Dictionary) -> void:
	if not is_node_ready() or showroom == null:
		_pending_configuration = [value_catalog, value_progress, value_payload.duplicate(true)]
		return
	catalog = value_catalog; progress = value_progress; payload = value_payload.duplicate(true); _variants.clear()
	if catalog != null and catalog.unlocks != null:
		_variants.assign(catalog.unlocks.variants)
	_build_cards()
	var requested := StringName(payload.get("variant_id", &""))
	if requested.is_empty() and str(payload.get("source", "standalone")) == "standalone": requested = last_inspected_variant_id
	if requested.is_empty() and progress != null: requested = progress.equipped_kart_variant_id
	if requested.is_empty() and not _variants.is_empty(): requested = _variants[0].id
	focus_variant(requested)

func _build_cards() -> void:
	if cards == null: return
	for child in cards.get_children(): child.queue_free()
	var leading := Control.new(); leading.custom_minimum_size.x = maxf(0.0, card_scroll.size.x * 0.5 - 95.0); leading.mouse_filter = Control.MOUSE_FILTER_IGNORE; cards.add_child(leading)
	for variant in _variants:
		var unlock := _get_unlock(variant.id)
		var unlocked := _is_unlocked(variant.id)
		var button := Button.new(); button.name = str(variant.id); button.text = variant.display_name.to_upper(); button.custom_minimum_size = Vector2(190, 88); button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(focus_variant.bind(variant.id)); button.focus_entered.connect(focus_variant.bind(variant.id)); cards.add_child(button)
	var trailing := Control.new(); trailing.custom_minimum_size.x = maxf(0.0, card_scroll.size.x * 0.5 - 95.0); trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE; cards.add_child(trailing)

func _refresh_gallery_spacing() -> void:
	if cards == null or card_scroll == null or cards.get_child_count() < 2: return
	var spacer := maxf(0.0, card_scroll.size.x * 0.5 - 95.0)
	(cards.get_child(0) as Control).custom_minimum_size.x = spacer
	(cards.get_child(cards.get_child_count() - 1) as Control).custom_minimum_size.x = spacer
	_center_focused_card.call_deferred(false)

func _update_layout() -> void:
	if showroom == null or details_panel == null or card_scroll == null: return
	var compact_width := size.x < 900.0
	var compact_height := size.y < 500.0
	var split := 0.5 if compact_width else 0.7
	showroom.anchor_right = split
	details_panel.anchor_left = split
	right_button.anchor_left = split; right_button.anchor_right = split
	card_scroll.visible = not compact_height
	stats.visible = not compact_height
	showroom.offset_bottom = -18.0 if compact_height else -150.0
	details_panel.offset_top = 12.0 if compact_height else 28.0
	details_panel.offset_bottom = -18.0 if compact_height else -158.0

func focus_variant(variant_id: StringName) -> void:
	var variant := _get_variant(variant_id)
	if variant == null:
		return
	focused_variant_id = variant.id; last_inspected_variant_id = variant.id; payload["variant_id"] = variant.id
	showroom.show_variant(variant); title_label.text = variant.display_name.to_upper()
	var equipped := progress != null and progress.equipped_kart_variant_id == variant.id
	var unlocked := _is_unlocked(variant.id)
	var unlock := _get_unlock(variant.id)
	var is_new := unlocked and unlock != null and progress.is_reward_new(unlock.id)
	if is_new:
		progress.mark_reward_seen(unlock.id)
		_update_card_badges()
	var locked_by_cup := bool(payload.get("continue_active", false)) and str(payload.get("source", "")) == "play" and not equipped
	status_label.text = "EQUIPADO" if equipped else ("NUEVO" if is_new else ("DISPONIBLE" if unlocked else "BLOQUEADO"))
	status_label.add_theme_color_override("font_color", UiTokens.SUCCESS if equipped or unlocked else UiTokens.CORAL)
	status_badge.configure(UiBadge.State.EQUIPPED if equipped else (UiBadge.State.NEW if is_new else (UiBadge.State.AVAILABLE if unlocked else UiBadge.State.LOCKED)))
	if locked_by_cup:
		requirement_label.text = "Vehículo fijado para esta copa activa."
	elif unlocked:
		requirement_label.text = "Listo para competir."
	elif unlock != null:
		requirement_label.text = "Requisito · %s" % unlock.requirement_text(catalog)
	else:
		requirement_label.text = "No disponible"
	_build_stats(variant)
	var standalone := str(payload.get("source", "standalone")) == "standalone"
	primary.text = ("EQUIPADO" if equipped else ("EQUIPAR" if unlocked else "BLOQUEADO")) if standalone else ("CONTINUAR" if unlocked and not locked_by_cup else ("EQUIPADO" if locked_by_cup else "BLOQUEADO"))
	primary.disabled = (standalone and (equipped or not unlocked)) or (not standalone and (not unlocked or locked_by_cup))
	for candidate in cards.find_children("*", "Button", false, false):
		var card := candidate as Button
		card.add_theme_stylebox_override("normal", UiTokens.panel(UiTokens.WARM_WHITE, 12, UiTokens.CYAN if card.name == str(variant.id) else Color.TRANSPARENT))
	_center_focused_card.call_deferred(false)

func _update_card_badges() -> void:
	for variant in _variants:
		var button := cards.get_node_or_null(str(variant.id)) as Button
		if button == null: continue
		var unlock := _get_unlock(variant.id)
		var unlocked := _is_unlocked(variant.id)
		button.text = variant.display_name.to_upper()

func _center_focused_card(animated := true) -> void:
	if card_scroll == null or cards == null: return
	var button := cards.get_node_or_null(str(focused_variant_id)) as Control
	if button == null: return
	var target := int(button.position.x + button.size.x * 0.5 - card_scroll.size.x * 0.5)
	target = clampi(target, 0, int(card_scroll.get_h_scroll_bar().max_value))
	if not animated:
		card_scroll.scroll_horizontal = target
		return
	if _scroll_tween != null: _scroll_tween.kill()
	_scroll_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_property(card_scroll, "scroll_horizontal", target, 0.16)

func _build_stats(variant: KartVariantDefinition) -> void:
	for child in stats.get_children(): child.queue_free()
	var equipped := _get_variant(progress.equipped_kart_variant_id) if progress != null else null
	for data in [["Velocidad", variant.speed, 1.2], ["Aceleración", variant.acceleration, 1.2], ["Manejo", variant.handling, 1.2], ["Peso", variant.weight, 1.25], ["Miniturbo", variant.mini_turbo_duration_multiplier, 1.25]]:
		var current := float(data[1]); var baseline := _stat_value(equipped, str(data[0])) if equipped != null else current; var difference := current - baseline
		var row := HBoxContainer.new(); stats.add_child(row)
		var label := Label.new(); label.text = str(data[0]); label.custom_minimum_size.x = 90; row.add_child(label)
		var bar := ProgressBar.new(); bar.max_value = float(data[2]); bar.value = current; bar.show_percentage = false; bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(bar)
		bar.add_theme_stylebox_override("background", UiTokens.panel(UiTokens.GRAPHITE, UiTokens.RADIUS_SMALL))
		bar.add_theme_stylebox_override("fill", UiTokens.panel(UiTokens.CYAN if difference >= -0.001 else UiTokens.CORAL, UiTokens.RADIUS_SMALL))
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

func _move(direction: int, animated := true) -> void:
	if _variants.is_empty(): return
	var index := 0
	for i in _variants.size():
		if _variants[i].id == focused_variant_id:
			index = i
	focus_variant(_variants[posmod(index + direction, _variants.size())].id)
	_center_focused_card(animated)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed(&"ui_left"): _move(-1, false); get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"): _move(1, false); get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed: _swipe_start = event.position
		elif absf(event.position.x - _swipe_start.x) > 60: _move(-1 if event.position.x > _swipe_start.x else 1)

func _is_unlocked(variant_id: StringName) -> bool:
	if progress == null or catalog == null: return false
	if progress.equipped_kart_variant_id == variant_id: return true
	if catalog.unlocks.is_initial_variant(variant_id): return true
	var unlock := _get_unlock(variant_id)
	return unlock != null and progress.unlocked_reward_ids.has(unlock.id)

func _get_unlock(variant_id: StringName) -> UnlockDefinition:
	return catalog.unlocks.get_unlock_for_variant(variant_id) if catalog != null and catalog.unlocks != null else null

func _get_variant(variant_id: StringName) -> KartVariantDefinition:
	return catalog.unlocks.get_variant(variant_id) if catalog != null else null
