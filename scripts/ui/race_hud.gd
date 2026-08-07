class_name RaceHud
extends CanvasLayer

signal retry_requested
signal menu_requested
signal intro_skip_requested

var _status_view: RaceStatusView
var _touch_view: RaceTouchControls
var _flow_overlay: RaceFlowOverlay
var _player_kart: Kart

var _lap_label: Label
var _position_label: Label
var _time_label: Label
var _speed_label: Label
var _item_label: Label
var _item_chip: PanelContainer
var _item_icon: TextureRect
var _item_button: MobileActionButton
var _shield_panel: PanelContainer
var _shield_icon: TextureRect
var _shield_label: Label
var _shield_bar: ProgressBar
var _countdown_label: Label
var _drift_bar: ProgressBar
var _results_panel: Control
var _results_title: Label
var _retry_button: Button
var _pause_overlay: Control
var _touch_controls: Control
var _steering_pad: CoastalJoystick
var _race_elements: Array[CanvasItem] = []
var _intro_overlay: Control
var _intro_content: Control
var _intro_title: Label
var _intro_laps: Label
var _intro_skip_button: Button
var _is_intro_visible := false

var mobile_controls_enabled := (
	OS.has_feature("android")
	or OS.has_feature("ios")
	or DisplayServer.is_touchscreen_available()
)
var vibration_enabled := true


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()


func bind_player(kart: Kart) -> void:
	_player_kart = kart
	_touch_view.bind_player(kart)
	kart.item_changed.connect(_handle_item_changed)
	kart.boost_changed.connect(_handle_boost_changed)
	kart.shield_state_changed.connect(_handle_shield_state_changed)
	_handle_item_changed(kart.held_item)


func update_race_info(
	lap: int,
	total_laps: int,
	position: int,
	racers: int,
	race_time: float
) -> void:
	_status_view.update_race_info(
		lap,
		total_laps,
		position,
		racers,
		race_time
	)


func show_countdown(text: String) -> void:
	_status_view.show_countdown(text, _is_intro_visible)


func show_intro(track_name: String, total_laps: int) -> void:
	_is_intro_visible = true
	_flow_overlay.show_intro(track_name, total_laps)
	_set_race_elements_visible(false)
	_set_touch_controls_visible(false)
	_release_auto_acceleration()


func update_intro_progress(elapsed: float) -> void:
	_flow_overlay.update_intro_progress(elapsed)


func set_intro_skip_enabled(enabled: bool) -> void:
	_flow_overlay.set_intro_skip_enabled(enabled)


func hide_intro() -> void:
	if not _is_intro_visible:
		return
	_is_intro_visible = false
	_flow_overlay.hide_intro()
	_set_race_elements_visible(true)
	_countdown_label.visible = not _countdown_label.text.is_empty()


func show_results(position: int, race_time: float) -> void:
	_flow_overlay.show_results(position, race_time)
	_set_touch_controls_visible(false)


func _process(_delta: float) -> void:
	if _player_kart != null:
		_status_view.update_speed(_player_kart.get_speed_kph())
	if _flow_overlay != null:
		_flow_overlay.update_pause_visibility(get_tree().paused)
	if _touch_view != null:
		_touch_view.update_state(
			get_tree().paused,
			_results_panel.visible,
			_is_intro_visible
		)


func _exit_tree() -> void:
	_release_auto_acceleration()


func set_mobile_controls_enabled(enabled: bool) -> void:
	mobile_controls_enabled = enabled
	if _touch_view == null:
		return
	_touch_view.set_mobile_controls_enabled(enabled)
	_touch_view.update_state(
		get_tree().paused,
		_results_panel.visible,
		_is_intro_visible
	)


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_status_view = RaceStatusView.new()
	_status_view.name = "RaceStatus"
	_status_view.build_interface()
	root.add_child(_status_view)
	_bind_status_references()

	_touch_view = RaceTouchControls.new()
	_touch_view.build_interface(
		mobile_controls_enabled,
		vibration_enabled
	)
	root.add_child(_touch_view)
	_bind_touch_references()

	_flow_overlay = RaceFlowOverlay.new()
	_flow_overlay.build_interface()
	root.add_child(_flow_overlay)
	_flow_overlay.retry_requested.connect(
		func() -> void: retry_requested.emit()
	)
	_flow_overlay.menu_requested.connect(
		func() -> void: menu_requested.emit()
	)
	_flow_overlay.intro_skip_requested.connect(
		func() -> void: intro_skip_requested.emit()
	)
	_bind_flow_references()


func _bind_status_references() -> void:
	_lap_label = _status_view.lap_label
	_position_label = _status_view.position_label
	_time_label = _status_view.time_label
	_speed_label = _status_view.speed_label
	_item_label = _status_view.item_label
	_item_chip = _status_view.item_chip
	_item_icon = _status_view.item_icon
	_shield_panel = _status_view.shield_panel
	_shield_icon = _status_view.shield_icon
	_shield_label = _status_view.shield_label
	_shield_bar = _status_view.shield_bar
	_countdown_label = _status_view.countdown_label
	_drift_bar = _status_view.drift_bar
	_race_elements = _status_view.race_elements


func _bind_touch_references() -> void:
	_touch_controls = _touch_view
	_steering_pad = _touch_view.steering_pad
	_item_button = _touch_view.item_button


func _bind_flow_references() -> void:
	_intro_overlay = _flow_overlay.intro_overlay
	_intro_content = _flow_overlay.intro_content
	_intro_title = _flow_overlay.intro_title
	_intro_laps = _flow_overlay.intro_laps
	_intro_skip_button = _flow_overlay.intro_skip_button
	_pause_overlay = _flow_overlay.pause_overlay
	_results_panel = _flow_overlay.results_panel
	_results_title = _flow_overlay.results_title
	_retry_button = _flow_overlay.retry_button


func _handle_item_changed(item: ItemDefinition) -> void:
	_status_view.show_item(item)
	_touch_view.show_item(item)


func _handle_shield_state_changed(
	item: ItemDefinition,
	remaining: float,
	total: float
) -> void:
	_status_view.show_shield(
		item,
		remaining,
		total,
		_is_intro_visible
	)


func _handle_boost_changed(charge_ratio: float) -> void:
	_status_view.show_boost(charge_ratio)


func _unhandled_input(event: InputEvent) -> void:
	if _flow_overlay.handle_input(event):
		get_viewport().set_input_as_handled()


func _request_intro_skip() -> void:
	_flow_overlay.request_intro_skip()


func _set_touch_controls_visible(is_visible: bool) -> void:
	_touch_view.set_controls_visible(is_visible)


func _set_race_elements_visible(is_visible: bool) -> void:
	_status_view.set_race_elements_visible(
		is_visible,
		(
			_player_kart != null
			and _player_kart.get_shield_remaining() > 0.0
		)
	)


func _release_auto_acceleration() -> void:
	if _touch_view != null:
		_touch_view.release_auto_acceleration()
