@tool
class_name TrackEditorScreen
extends Control

signal play_requested(scene_path: String, track_id: StringName, laps: int)

const CATALOG_PATH := "res://levels/track_catalog.tres"
const PreviewController := preload(
	"res://addons/track_editor/track_editor_preview_controller.gd"
)
const SetupPanel := preload("res://addons/track_editor/track_setup_panel.gd")
const RoutePanel := preload("res://addons/track_editor/track_route_panel.gd")
const ShortcutPanel := preload("res://addons/track_editor/track_shortcut_panel.gd")
const ObjectPanel := preload("res://addons/track_editor/track_object_panel.gd")
const SurfacePanel := preload("res://addons/track_editor/track_surface_panel.gd")
const ReviewPanel := preload("res://addons/track_editor/track_review_panel.gd")
const ValidationController := preload(
	"res://addons/track_editor/track_editor_validation_controller.gd"
)
const DialogController := preload(
	"res://addons/track_editor/track_editor_dialog_controller.gd"
)
const ConflictController := preload(
	"res://addons/track_editor/track_editor_conflict_controller.gd"
)
const ExternalController := preload(
	"res://addons/track_editor/track_editor_external_controller.gd"
)
const PublicationController := preload(
	"res://addons/track_editor/track_editor_publication_controller.gd"
)
const PlaytestController := preload(
	"res://addons/track_editor/track_editor_playtest_controller.gd"
)
const EditController := preload(
	"res://addons/track_editor/track_editor_edit_controller.gd"
)
const EditorStyle := preload("res://addons/track_editor/track_editor_style.gd")
const Selection := preload(
	"res://addons/track_editor/track_editor_selection.gd"
)
const STEP_LABELS := [
	"1  CONFIGURACIÓN",
	"2  CARRETERA",
	"3  ATAJOS",
	"4  OBJETOS",
	"5  SUPERFICIES",
	"6  REVISAR",
]
const PANEL_WORKFLOW_ID := 0
const PANEL_INSPECTOR_ID := 1
const PANEL_STATUS_ID := 2
const PANEL_RESET_LAYOUT_ID := 3
const COMPACT_LAYOUT_BREAKPOINT := 1600.0
const NEW_DIALOG_PREFERRED_SIZE := Vector2i(480, 340)
const NEW_DIALOG_CONTENT_WIDTH := 400.0
const TEST_CONFIG_PATH := "user://coastal_karts_track_test.cfg"
const TEST_STATUS_PATH := "user://coastal_karts_track_test_status.cfg"
const TEST_STARTUP_TIMEOUT_SECONDS := 10.0
const TEST_HEARTBEAT_TIMEOUT_SECONDS := 5.0

var session := TrackEditorSession.new()
var _preview_controller := PreviewController.new()
var _conflict_controller := ConflictController.new()
var _external_controller := ExternalController.new(session)
var _publication_controller := PublicationController.new(session)
var _playtest_controller := PlaytestController.new()
var _validation_controller := ValidationController.new()
var _dialog_controller := DialogController.new()
var _edit_controller := EditController.new(session)

var _title_label: Label
var _dirty_label: Label
var _status_label: Label
var _step_buttons: Array[Button] = []
var _properties: VBoxContainer
var _map_view: TrackMapView
var _preview_container: SubViewportContainer
var _preview_viewport: SubViewport
var _preview_camera: Camera3D
var _view_toggle: Button
var _preview_status_label: Label
var _undo_button: Button
var _redo_button: Button
var _track_picker: OptionButton
var _navigation_panel: PanelContainer
var _inspector_panel: PanelContainer
var _editor_root: VBoxContainer
var _content_status_split: VSplitContainer
var _navigation_split: HSplitContainer
var _inspector_split: HSplitContainer
var _status_panel: PanelContainer
var _panels_menu: MenuButton
var _header_actions_scroll: ScrollContainer
var _new_button: Button
var _open_button: Button
var _user_open_button: Button
var _save_button: Button
var _guide_button: Button
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _new_size: OptionButton
var _new_template_details: Label
var _open_dialog: FileDialog
var _user_open_dialog: FileDialog
var _unsaved_dialog: ConfirmationDialog
var _recovery_dialog: ConfirmationDialog
var _guide_dialog: AcceptDialog
var _calibration_dialog: ConfirmationDialog
var _pending_action := ""
var _pending_path := ""
var _current_step := 0
var _is_showing_preview := false
var _selection: RefCounted = Selection.none()
var _pending_test_token := ""
var _test_result_path := ""
var _test_status_path := TEST_STATUS_PATH
var _test_wait_elapsed := 0.0
var _test_ready := false
var _is_compact := false
var _preview_rebuild_pending := false
var _catalog_conflict_pending := false
var _scene_conflict_pending := false
var _playtest_state: StringName = &"iniciando"
var last_playtest_summary: Dictionary = {}
var playtest_summaries: Dictionary = {}
var _inspector_focus_path := NodePath()
var _inspector_scroll_value := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	theme = _create_workshop_theme()
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_connect_session()
	_reload_track_picker()
	if _track_picker.item_count > 0:
		_load_selected_track()
	call_deferred("_offer_recovery")


func _exit_tree() -> void:
	_preview_controller.dispose()


func has_pending_test() -> bool:
	return not _pending_test_token.is_empty()


func get_playtest_state() -> StringName:
	return _playtest_state


func get_publication_state() -> StringName:
	return _publication_controller.get_state()


func _set_playtest_state(new_state: StringName) -> void:
	_playtest_state = new_state
	_playtest_controller.set_state(new_state)
	if _status_label == null or _pending_test_token.is_empty():
		return
	var marker := "⚠" if new_state == &"fallido" else "▶"
	_status_label.text = "%s  PRUEBA · %s" % [marker, _playtest_controller.get_state_label()]
	_status_label.add_theme_color_override(
		"font_color",
		EditorStyle.ERROR if new_state == &"fallido" else EditorStyle.FOCUS
	)


func _sync_conflict_flags() -> void:
	_scene_conflict_pending = _conflict_controller.scene_pending
	_catalog_conflict_pending = _conflict_controller.catalog_pending


func offer_recovery() -> void:
	_offer_recovery()


func _process(delta: float) -> void:
	if _preview_rebuild_pending:
		_preview_rebuild_pending = false
		_preview_controller.flush_pending(session.track, _map_view)
		_update_preview_status()
	if _external_controller.process(delta):
		_process_preview_poll()
	_poll_test_status(delta)


func _process_preview_poll() -> void:
	_preview_controller.request_rebuild(session.track, _map_view)
	if _preview_controller.has_pending_rebuild():
		_preview_rebuild_pending = true




func track_test_started(
	token: String,
	result_path: String,
	status_path := TEST_STATUS_PATH
) -> void:
	_pending_test_token = token
	_test_result_path = result_path
	_test_status_path = status_path
	_test_wait_elapsed = 0.0
	_test_ready = false
	_set_playtest_state(&"iniciando")
	_show_success("Prueba iniciada. Usa F8 o VOLVER AL EDITOR para regresar.")


func _poll_test_status(delta: float) -> void:
	if _pending_test_token.is_empty():
		return
	if not _test_result_path.is_empty() and FileAccess.file_exists(_test_result_path):
		var result := ConfigFile.new()
		if (
			result.load(_test_result_path) == OK
			and str(result.get_value("result", "token", "")) == _pending_test_token
		):
			_show_test_result(result)
			_clear_test_state()
			return
	var status := ConfigFile.new()
	if not _test_status_path.is_empty() and FileAccess.file_exists(_test_status_path):
		if status.load(_test_status_path) == OK:
			if str(status.get_value("test", "token", "")) == _pending_test_token:
				var state := str(status.get_value("test", "state", ""))
				if state == "failed":
					var failure_reason := str(
						status.get_value("test", "error", "Error desconocido.")
					)
					_playtest_controller.fail(failure_reason)
					_set_playtest_state(&"fallido")
					_show_error(
						"La prueba no pudo iniciarse: %s"
						% failure_reason
					)
					_clear_test_state()
					return
				if state == "ready":
					_set_playtest_state(&"listo")
					_test_ready = true
				elif state in ["running", "executing"]:
					_set_playtest_state(&"ejecutando")
					_test_ready = true
				elif state in ["completed", "complete"]:
					_set_playtest_state(&"completado")
					_test_ready = true
				var heartbeat := float(
					status.get_value("test", "heartbeat", 0.0)
				)
				if (
					heartbeat > 0.0
					and Time.get_unix_time_from_system() - heartbeat
					> TEST_HEARTBEAT_TIMEOUT_SECONDS
				):
					var stale_seconds := Time.get_unix_time_from_system() - heartbeat
					_playtest_controller.fail(
						"heartbeat detenido hace %.1f s" % stale_seconds
					)
					_set_playtest_state(&"fallido")
					_show_error(
						"La prueba dejó de responder: heartbeat detenido hace %.1f s."
						% stale_seconds
					)
					_clear_test_state()
					return
	if not _test_ready:
		_test_wait_elapsed += delta
		if _test_wait_elapsed >= TEST_STARTUP_TIMEOUT_SECONDS:
			_playtest_controller.fail("timeout de inicio")
			_set_playtest_state(&"fallido")
			_show_error("La prueba no respondió a tiempo: timeout de inicio.")
			_clear_test_state()
			return
	return


func _clear_test_state() -> void:
	_pending_test_token = ""
	_test_ready = false
	_test_wait_elapsed = 0.0
	for path in [TEST_CONFIG_PATH, _test_status_path, _test_result_path]:
		if not path.is_empty() and FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_test_status_path = TEST_STATUS_PATH


func _show_test_result(result: ConfigFile) -> void:
	var elapsed := float(result.get_value("result", "elapsed_time", 0.0))
	var minutes := floori(elapsed / 60.0)
	var seconds := fmod(elapsed, 60.0)
	var completed := bool(result.get_value("result", "completed", false))
	var failure_reason := str(result.get_value("result", "failure_reason", ""))
	last_playtest_summary = {
		"track_id": str(result.get_value("result", "track_id", "")),
		"configuration": str(result.get_value("result", "configuration", "")),
		"elapsed_time": elapsed,
		"completed": completed,
		"recovery_count": int(result.get_value("result", "recovery_count", 0)),
		"off_route_count": int(result.get_value("result", "off_route_count", 0)),
		"shortcut_count": int(result.get_value("result", "shortcut_count", 0)),
		"recovery_reasons": result.get_value("result", "recovery_reasons", {}),
		"last_recovery_reason": str(result.get_value("result", "last_recovery_reason", "")),
	}
	_playtest_controller.record_summary(last_playtest_summary)
	playtest_summaries = _playtest_controller.summaries
	if not failure_reason.is_empty():
		_playtest_controller.fail(failure_reason)
		_set_playtest_state(&"fallido")
		_show_error("Prueba fallida: %s" % failure_reason)
		return
	_set_playtest_state(&"completado")
	var reasons: Dictionary = result.get_value("result", "recovery_reasons", {})
	var reason_text := ""
	if not reasons.is_empty():
		var entries := PackedStringArray()
		for reason in reasons:
			entries.append("%s ×%d" % [reason, int(reasons[reason])])
		reason_text = " · Motivos: %s" % ", ".join(entries)
	_show_success(
		"Última prueba%s%s · %02d:%06.3f · %d recuperaciones · %d fuera de ruta · %d atajos%s."
		% [
			" completada" if completed else "",
			(" · " + str(result.get_value("result", "configuration", ""))) if not str(result.get_value("result", "configuration", "")).is_empty() else "",
			minutes,
			seconds,
			int(result.get_value("result", "recovery_count", 0)),
			int(result.get_value("result", "off_route_count", 0)),
			int(result.get_value("result", "shortcut_count", 0)),
			reason_text,
		]
	)


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not key_event.ctrl_pressed:
		return
	if key_event.keycode == KEY_Z:
		if key_event.shift_pressed:
			session.redo_route()
		else:
			session.undo_route()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_Y:
		session.redo_route()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_S:
		_handle_save_pressed()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var viewport_scroll := ScrollContainer.new()
	viewport_scroll.name = "EditorViewportScroll"
	viewport_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	viewport_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(viewport_scroll)

	_editor_root = VBoxContainer.new()
	_editor_root.name = "EditorLayout"
	_editor_root.custom_minimum_size.x = 960.0
	_editor_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_root.add_theme_constant_override("separation", 0)
	viewport_scroll.add_child(_editor_root)

	_editor_root.add_child(_build_header())

	_content_status_split = VSplitContainer.new()
	_content_status_split.name = "WorkspaceStatusSplit"
	_content_status_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_status_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_status_split.add_theme_constant_override("separation", 8)
	_editor_root.add_child(_content_status_split)

	_navigation_split = HSplitContainer.new()
	_navigation_split.name = "WorkflowWorkspaceSplit"
	_navigation_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_navigation_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_navigation_split.add_theme_constant_override("separation", 8)
	_content_status_split.add_child(_navigation_split)

	var navigation := _build_navigation()
	_navigation_split.add_child(navigation)

	_inspector_split = HSplitContainer.new()
	_inspector_split.name = "WorkspaceInspectorSplit"
	_inspector_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_split.add_theme_constant_override("separation", 8)
	_navigation_split.add_child(_inspector_split)

	var workspace := _build_workspace()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_split.add_child(workspace)

	var inspector := _build_inspector()
	_inspector_split.add_child(inspector)

	_status_panel = PanelContainer.new()
	_status_panel.name = "EditorStatusPanel"
	_status_panel.custom_minimum_size.y = 44.0
	_status_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_status_split.add_child(_status_panel)

	_status_label = Label.new()
	_status_label.name = "EditorStatus"
	_status_label.text = "● Abre una pista o crea una nueva."
	_status_label.custom_minimum_size.y = 44.0
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
	_status_label.add_theme_color_override("font_shadow_color", EditorStyle.CANVAS_BACKGROUND)
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_status_panel.add_child(_status_label)

	_build_new_dialog()
	_build_open_dialog()
	_build_user_open_dialog()
	_build_unsaved_dialog()
	_build_recovery_dialog()
	_dialog_controller.build(self)
	_dialog_controller.external_reload_requested.connect(_reload_external_scene)
	_dialog_controller.external_keep_requested.connect(_keep_external_scene)
	_dialog_controller.catalog_acknowledged.connect(_acknowledge_catalog_change)
	_dialog_controller.compare_requested.connect(_show_conflict_comparison)
	_build_guide_dialog()
	_build_calibration_dialog()
	call_deferred("_reset_panel_layout")


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "PitLaneToolbar"
	header.custom_minimum_size.y = 64.0
	header.add_theme_constant_override("separation", 8)

	_title_label = Label.new()
	_title_label.text = "PISTAS  /  SIN PISTA"
	_title_label.custom_minimum_size.x = 280.0
	_title_label.add_theme_font_size_override("font_size", EditorStyle.TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", EditorStyle.FOCUS)
	header.add_child(_title_label)

	_header_actions_scroll = ScrollContainer.new()
	_header_actions_scroll.name = "HeaderActionsScroll"
	_header_actions_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_header_actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	header.add_child(_header_actions_scroll)
	var header_actions := HBoxContainer.new()
	header_actions.add_theme_constant_override("separation", 8)
	_header_actions_scroll.add_child(header_actions)

	_new_button = _button("＋ NUEVA", _handle_new_pressed, "Crear una pista nueva")
	_new_button.name = "NewTrackButton"
	header_actions.add_child(_new_button)
	_open_button = _button("ABRIR", _handle_open_pressed, "Abrir una pista o borrador")
	_open_button.name = "OpenTrackButton"
	header_actions.add_child(_open_button)
	_user_open_button = _button(
		"USER://",
		_handle_user_open_pressed,
		"Abrir un borrador guardado en los datos del usuario"
	)
	_user_open_button.name = "OpenUserDraftButton"
	header_actions.add_child(_user_open_button)

	_track_picker = OptionButton.new()
	_track_picker.name = "TrackPicker"
	_track_picker.custom_minimum_size = Vector2(220.0, 44.0)
	_track_picker.item_selected.connect(func(_index: int) -> void: _request_load_selected())
	header_actions.add_child(_track_picker)

	_save_button = _button("GUARDAR", _handle_save_pressed, "Guardar borrador")
	_save_button.name = "SaveTrackButton"
	header_actions.add_child(_save_button)

	_undo_button = _button("↶", session.undo_route, "Deshacer cambio de carretera")
	_undo_button.custom_minimum_size.x = 48.0
	header_actions.add_child(_undo_button)
	_redo_button = _button("↷", session.redo_route, "Rehacer cambio de carretera")
	_redo_button.custom_minimum_size.x = 48.0
	header_actions.add_child(_redo_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_actions.add_child(spacer)

	_guide_button = _button("? GUÍA", _show_guide, "Abrir guía del editor")
	_guide_button.name = "EditorGuideButton"
	header_actions.add_child(_guide_button)

	_dirty_label = Label.new()
	_dirty_label.text = "GUARDADO"
	_dirty_label.add_theme_color_override("font_color", EditorStyle.SUCCESS)
	header_actions.add_child(_dirty_label)

	header.add_child(_button("▶ PROBAR", _handle_test_pressed))
	header.add_child(_button("PUBLICAR", _handle_publish_pressed, "", true))
	return header


func _build_navigation() -> Control:
	_navigation_panel = PanelContainer.new()
	_navigation_panel.name = "WorkflowNavigation"
	_navigation_panel.custom_minimum_size.x = 210.0
	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	_navigation_panel.add_child(navigation)

	var label := Label.new()
	label.text = "RUTA DE TRABAJO"
	label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
	navigation.add_child(label)

	var group := ButtonGroup.new()
	for step_index in STEP_LABELS.size():
		var step_button := Button.new()
		step_button.text = STEP_LABELS[step_index]
		step_button.toggle_mode = true
		step_button.button_group = group
		step_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		step_button.custom_minimum_size = Vector2(190.0, 50.0)
		step_button.pressed.connect(_show_step.bind(step_index))
		navigation.add_child(step_button)
		_step_buttons.append(step_button)
	_step_buttons[0].button_pressed = true

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)

	var help := Label.new()
	help.text = (
		"CONSEJO DE BOXES\n\nSigue los pasos de arriba hacia abajo. "
		+ "No necesitas usar el árbol de nodos ni el Inspector."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
	navigation.add_child(help)
	return _navigation_panel


func _build_workspace() -> VBoxContainer:
	var workspace := VBoxContainer.new()
	workspace.add_theme_constant_override("separation", 0)

	var view_bar := HBoxContainer.new()
	view_bar.custom_minimum_size.y = 48.0
	var map_label := Label.new()
	map_label.text = "  MESA DE TRAZADO"
	map_label.add_theme_color_override("font_color", EditorStyle.TEXT_PRIMARY)
	view_bar.add_child(map_label)
	_panels_menu = MenuButton.new()
	_panels_menu.name = "PanelLayoutMenu"
	_panels_menu.text = "PANELES"
	_panels_menu.tooltip_text = "Mostrar, ocultar o restablecer los paneles del editor"
	_panels_menu.custom_minimum_size = Vector2(104.0, 44.0)
	_panels_menu.focus_mode = Control.FOCUS_ALL
	var panels_popup := _panels_menu.get_popup()
	panels_popup.add_check_item("Ruta de trabajo", PANEL_WORKFLOW_ID)
	panels_popup.set_item_checked(0, true)
	panels_popup.add_check_item("Inspector", PANEL_INSPECTOR_ID)
	panels_popup.set_item_checked(1, true)
	panels_popup.add_check_item("Estado", PANEL_STATUS_ID)
	panels_popup.set_item_checked(2, true)
	panels_popup.add_separator()
	panels_popup.add_item("Restablecer distribución", PANEL_RESET_LAYOUT_ID)
	panels_popup.id_pressed.connect(_handle_panel_menu_action)
	view_bar.add_child(_panels_menu)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_bar.add_child(spacer)
	var grid_picker := OptionButton.new()
	grid_picker.name = "GridStep"
	grid_picker.tooltip_text = "Cuadrícula usada al mantener Ctrl durante el movimiento"
	grid_picker.custom_minimum_size = Vector2(86.0, 44.0)
	for grid_value in [1, 2, 5]:
		grid_picker.add_item("%d m" % grid_value, grid_value)
	grid_picker.item_selected.connect(func(index: int) -> void:
		_map_view.set_grid_step(float(grid_picker.get_item_id(index)))
	)
	view_bar.add_child(grid_picker)
	var layers := MenuButton.new()
	layers.name = "MapLayers"
	layers.text = "CAPAS"
	layers.custom_minimum_size = Vector2(92.0, 44.0)
	layers.focus_mode = Control.FOCUS_ALL
	var layer_labels := {
		&"direction": "Sentido",
		&"objects": "Objetos",
		&"shortcuts": "Atajos y portales",
		&"surfaces": "Superficies",
		&"errors": "Errores",
		&"slope": "Pendiente",
		&"curvature": "Curvatura",
		&"barriers": "Barreras",
	}
	for layer_name in layer_labels:
		var layer_index := layers.get_popup().item_count
		layers.get_popup().add_check_item(layer_labels[layer_name])
		layers.get_popup().set_item_metadata(layer_index, layer_name)
		layers.get_popup().set_item_checked(
			layer_index,
			layer_name in [&"direction", &"objects", &"shortcuts", &"surfaces", &"errors"]
		)
	layers.get_popup().index_pressed.connect(func(index: int) -> void:
		var popup := layers.get_popup()
		var enabled := not popup.is_item_checked(index)
		popup.set_item_checked(index, enabled)
		_map_view.set_layer_enabled(
			StringName(popup.get_item_metadata(index)),
			enabled
		)
	)
	view_bar.add_child(layers)
	view_bar.add_child(_button("−", func() -> void: _map_view.zoom_out(), "Alejar mapa"))
	view_bar.add_child(_button("＋", func() -> void: _map_view.zoom_in(), "Acercar mapa"))
	view_bar.add_child(_button("ENCUADRAR", func() -> void: _map_view.frame_all(), "Mostrar la pista completa"))
	_view_toggle = _button("VISTA 3D", _toggle_view)
	_preview_status_label = Label.new()
	_preview_status_label.name = "PreviewStatus"
	_preview_status_label.text = "● PREVIEW PENDIENTE"
	_preview_status_label.add_theme_color_override("font_color", EditorStyle.FOCUS)
	_preview_status_label.custom_minimum_size.x = 150.0
	_preview_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_bar.add_child(_preview_status_label)
	view_bar.add_child(_view_toggle)
	workspace.add_child(view_bar)

	var view_stack := Control.new()
	view_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_child(view_stack)

	_map_view = TrackMapView.new()
	_map_view.name = "TrackMap"
	_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_view.edit_started.connect(session.snapshot_route_for_undo)
	_map_view.route_edited.connect(_handle_route_edited)
	_map_view.edit_finished.connect(_handle_route_edit_finished)
	_map_view.point_selected.connect(_handle_point_selected)
	_map_view.selection_changed.connect(_handle_selection_changed)
	_map_view.entity_move_requested.connect(_handle_entity_move_requested)
	_map_view.entity_delete_requested.connect(_handle_entity_delete_requested)
	_map_view.entity_duplicate_requested.connect(_handle_entity_duplicate_requested)
	view_stack.add_child(_map_view)

	_preview_container = _preview_controller.build(view_stack)
	_preview_viewport = _preview_controller.viewport
	_preview_camera = _preview_controller.camera
	return workspace


func _build_inspector() -> Control:
	_inspector_panel = PanelContainer.new()
	_inspector_panel.name = "TrackInspector"
	_inspector_panel.custom_minimum_size.x = 320.0
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspector_panel.add_child(scroll)
	_properties = VBoxContainer.new()
	_properties.custom_minimum_size.x = 292.0
	_properties.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_properties.add_theme_constant_override("separation", 10)
	scroll.add_child(_properties)
	return _inspector_panel


func _apply_responsive_layout() -> void:
	if _editor_root != null:
		_editor_root.custom_minimum_size.y = maxf(size.y, 480.0)
	_set_compact_mode(size.x < COMPACT_LAYOUT_BREAKPOINT)


func _set_compact_mode(is_compact: bool) -> void:
	_is_compact = is_compact
	if _navigation_panel == null or _inspector_panel == null:
		return
	_navigation_panel.custom_minimum_size.x = 180.0 if is_compact else 210.0
	_inspector_panel.custom_minimum_size.x = 280.0 if is_compact else 320.0
	_properties.custom_minimum_size.x = 252.0 if is_compact else 292.0
	_title_label.custom_minimum_size.x = 220.0 if is_compact else 280.0
	_track_picker.custom_minimum_size.x = 160.0 if is_compact else 220.0
	_new_button.text = "＋" if is_compact else "＋ NUEVA"
	_guide_button.text = "?" if is_compact else "? GUÍA"


func _handle_panel_menu_action(id: int) -> void:
	match id:
		PANEL_WORKFLOW_ID:
			_navigation_panel.visible = not _navigation_panel.visible
			_set_panel_menu_checked(PANEL_WORKFLOW_ID, _navigation_panel.visible)
		PANEL_INSPECTOR_ID:
			_inspector_panel.visible = not _inspector_panel.visible
			_set_panel_menu_checked(PANEL_INSPECTOR_ID, _inspector_panel.visible)
		PANEL_STATUS_ID:
			_status_panel.visible = not _status_panel.visible
			_set_panel_menu_checked(PANEL_STATUS_ID, _status_panel.visible)
		PANEL_RESET_LAYOUT_ID:
			_navigation_panel.show()
			_inspector_panel.show()
			_status_panel.show()
			_set_panel_menu_checked(PANEL_WORKFLOW_ID, true)
			_set_panel_menu_checked(PANEL_INSPECTOR_ID, true)
			_set_panel_menu_checked(PANEL_STATUS_ID, true)
			call_deferred("_reset_panel_layout")


func _set_panel_menu_checked(id: int, is_checked: bool) -> void:
	if _panels_menu == null:
		return
	var item_index := _panels_menu.get_popup().get_item_index(id)
	if item_index >= 0:
		_panels_menu.get_popup().set_item_checked(item_index, is_checked)


func _reset_panel_layout() -> void:
	if (
		_content_status_split == null
		or _navigation_split == null
		or _inspector_split == null
		or _navigation_panel == null
		or _inspector_panel == null
		or _status_panel == null
	):
		return
	_navigation_split.split_offset = roundi(
		_navigation_panel.custom_minimum_size.x
	)
	_inspector_split.split_offset = maxi(
		roundi(
			_inspector_split.size.x
			- _inspector_panel.custom_minimum_size.x
		),
		0
	)
	_content_status_split.split_offset = maxi(
		roundi(
			_content_status_split.size.y
			- _status_panel.custom_minimum_size.y
		),
		0
	)


func _connect_session() -> void:
	session.track_changed.connect(_handle_track_changed)
	session.route_changed.connect(_handle_session_route_changed)
	session.dirty_changed.connect(_handle_dirty_changed)
	session.history_changed.connect(_handle_history_changed)
	_preview_controller.state_changed.connect(_handle_preview_state_changed)
	_external_controller.changes_detected.connect(_handle_external_changes)


func _reload_track_picker() -> void:
	_track_picker.clear()
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var catalog := ResourceLoader.load(
		CATALOG_PATH,
		"TrackCatalog",
		ResourceLoader.CACHE_MODE_REPLACE
	) as TrackCatalog
	if catalog == null:
		return
	for definition in catalog.tracks:
		if definition != null and definition.scene != null:
			_track_picker.add_item(definition.display_name)
			_track_picker.set_item_metadata(
				_track_picker.item_count - 1,
				definition.scene.resource_path
			)


func _request_load_selected() -> void:
	if _track_picker.selected < 0:
		return
	var path := str(_track_picker.get_item_metadata(_track_picker.selected))
	if session.is_dirty:
		_show_unsaved_dialog("load", path)
	else:
		_load_path(path)


func _load_selected_track() -> void:
	if _track_picker.selected >= 0:
		_load_path(str(_track_picker.get_item_metadata(_track_picker.selected)))


func _load_path(path: String) -> void:
	var error := session.load_track(path)
	if error != OK:
		_show_error(_get_persistence_error("No se pudo abrir la pista"))
		return
	_show_step(_current_step)
	if session.last_repair_summary.is_empty():
		_show_success("Pista abierta. Comienza por Configuración o Carretera.")
	else:
		_show_success(
			"%s. Guarda para conservar la reparación."
			% session.last_repair_summary.capitalize()
		)


func _handle_track_changed(track: TrackLevel) -> void:
	_conflict_controller.clear_all()
	_sync_conflict_flags()
	_publication_controller.refresh()
	_selection = Selection.none()
	_preview_controller.set_track(track)
	_map_view.set_track(track)
	_title_label.text = "PISTAS  /  %s" % track.display_name.to_upper()
	_rebuild_preview()
	_refresh_validation()
	_show_step(_current_step)
	_update_preview_status()


func _handle_dirty_changed(is_dirty: bool) -> void:
	_publication_controller.refresh()
	_dirty_label.text = "● SIN GUARDAR" if is_dirty else "✓ GUARDADO"
	_dirty_label.add_theme_color_override(
		"font_color",
		EditorStyle.FOCUS if is_dirty else EditorStyle.SUCCESS
	)


func _handle_session_route_changed() -> void:
	_map_view.set_track(session.track)
	_restore_selection_after_history()
	_rebuild_preview()
	_show_step(_current_step)
	_update_preview_status()


func _handle_history_changed(can_undo: bool, can_redo: bool) -> void:
	_undo_button.disabled = not can_undo
	_redo_button.disabled = not can_redo



func _show_step(step_index: int, preserve_inspector_state := true) -> void:
	var previous_step := _current_step
	var focus_path := NodePath()
	var scroll_value := 0
	if preserve_inspector_state and _properties != null:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner != null and _properties.is_ancestor_of(focus_owner):
			focus_path = _properties.get_path_to(focus_owner)
		var inspector_scroll := _properties.get_parent() as ScrollContainer
		if inspector_scroll != null:
				scroll_value = inspector_scroll.scroll_vertical
	_current_step = clampi(step_index, 0, STEP_LABELS.size() - 1)
	_step_buttons[_current_step].set_pressed_no_signal(true)
	_clear_inspector_properties()
	if session.track == null:
		_add_help("Abre o crea una pista para comenzar.")
		return
	match _current_step:
		0:
			_build_setup_properties()
		1:
			_build_route_properties()
		2:
			_build_shortcut_properties()
		3:
			_build_object_properties()
		4:
			_build_surface_properties()
		5:
			_build_review_properties()
	_inspector_focus_path = focus_path
	_inspector_scroll_value = scroll_value if previous_step == _current_step else 0
	call_deferred(
		"_restore_inspector_state",
		_inspector_focus_path,
		_inspector_scroll_value,
		not preserve_inspector_state
	)


func _clear_inspector_properties() -> void:
	if _properties == null:
		return
	for child in _properties.get_children():
		_properties.remove_child(child)
		if is_instance_valid(child):
			child.queue_free()


func _build_surface_properties() -> void:
	var panel := SurfacePanel.new()
	panel.name = "TrackSurfacePanel"
	panel.configure(session.track, _button, _selection)
	panel.surface_selection_requested.connect(_handle_surface_selection_requested)
	panel.create_requested.connect(_handle_surface_create_requested)
	panel.update_requested.connect(_handle_surface_update_requested)
	panel.delete_requested.connect(_handle_surface_delete_requested)
	_properties.add_child(panel)


func _build_setup_properties() -> void:
	var panel := SetupPanel.new()
	panel.name = "TrackSetupPanel"
	panel.configure(session.track, session.laps, session.description, _button)
	panel.name_changed.connect(_handle_track_name_changed)
	panel.laps_changed.connect(_handle_laps_changed)
	panel.description_changed.connect(_handle_description_changed)
	panel.metadata_edit_finished.connect(session.finish_metadata_edit)
	panel.environment_theme_changed.connect(func(value: TrackTheme) -> void:
		session.snapshot_track_for_undo()
		session.track.track_theme = value
		session.finish_metadata_edit()
		session.mark_dirty()
		_rebuild_preview()
	)
	panel.music_changed.connect(func(value: AudioStream) -> void:
		session.snapshot_track_for_undo()
		session.track.track_music = value
		session.finish_metadata_edit()
		session.mark_dirty()
	)
	panel.difficulty_changed.connect(func(value: String) -> void:
		session.snapshot_track_for_undo()
		session.track.difficulty = value
		session.finish_metadata_edit()
		session.mark_dirty()
	)
	_properties.add_child(panel)


func _build_route_properties() -> void:
	var panel := RoutePanel.new()
	panel.name = "TrackRoutePanel"
	panel.configure(session.track, _map_view.selected_point, _button)
	panel.add_point_requested.connect(_handle_add_point)
	panel.delete_point_requested.connect(_handle_delete_point)
	panel.height_changed.connect(_map_view.set_selected_height)
	panel.mark_start_requested.connect(_handle_mark_start)
	panel.position_changed.connect(_handle_route_position_changed)
	_properties.add_child(panel)


func _build_shortcut_properties() -> void:
	var panel := ShortcutPanel.new()
	panel.name = "TrackShortcutPanel"
	panel.configure(session.track, _button, _selection)
	panel.create_shortcut_requested.connect(_create_shortcut)
	panel.delete_shortcut_requested.connect(_delete_shortcut)
	panel.shortcut_selection_requested.connect(
		func(selected: RefCounted) -> void: _map_view.set_selection(selected)
	)
	panel.shortcut_shape_changed.connect(_handle_shortcut_shape_changed)
	panel.shortcut_rename_requested.connect(_handle_shortcut_rename_requested)
	panel.shortcut_reset_requested.connect(_handle_shortcut_reset_requested)
	_properties.add_child(panel)


func _build_object_properties() -> void:
	var panel := ObjectPanel.new()
	panel.name = "TrackObjectPanel"
	panel.configure(session.track, _button, _selection)
	panel.add_item_requested.connect(_add_item_spawn)
	panel.add_asset_requested.connect(_add_asset)
	panel.anchor_changed.connect(_handle_object_anchor_changed)
	panel.duplicate_requested.connect(_handle_entity_duplicate_requested)
	panel.delete_requested.connect(_handle_entity_delete_requested)
	panel.restore_recommended_requested.connect(
		_handle_restore_recommended_requested
	)
	panel.calibrate_known_requested.connect(
		func() -> void: _calibration_dialog.popup_centered(Vector2i(520, 220))
	)
	_properties.add_child(panel)


func _build_review_properties() -> void:
	var issues := _inspect_track()
	var panel := ReviewPanel.new()
	panel.name = "TrackReviewPanel"
	panel.configure(issues, _button)
	panel.issue_focus_requested.connect(_focus_issue)
	panel.validate_requested.connect(_handle_validate_pressed)
	panel.save_requested.connect(_handle_save_pressed)
	panel.test_requested.connect(_handle_test_pressed)
	panel.publish_requested.connect(_handle_publish_pressed)
	_properties.add_child(panel)


func _handle_track_name_changed(value: String) -> void:
	session.snapshot_metadata_for_undo()
	if not session.set_display_name(value):
		return
	_title_label.text = "PISTAS  /  %s" % value.to_upper()
	session.mark_dirty()


func _handle_laps_changed(value: int) -> void:
	session.snapshot_metadata_for_undo()
	if session.set_editor_metadata(value, session.description):
		session.mark_dirty()


func _handle_description_changed(value: String) -> void:
	session.snapshot_metadata_for_undo()
	if session.set_editor_metadata(session.laps, value):
		session.mark_dirty()


func _handle_new_pressed() -> void:
	if session.is_dirty:
		_show_unsaved_dialog("new", "")
	else:
		_popup_new_dialog()


func _handle_open_pressed() -> void:
	_open_dialog.popup_centered_ratio(0.72)


func _handle_user_open_pressed() -> void:
	_user_open_dialog.popup_centered_ratio(0.72)


func _create_new_track() -> void:
	var size_ids := [&"small", &"medium", &"large"]
	session.create_track(size_ids[_new_size.selected], _new_name.text)
	_new_dialog.hide()
	_show_success("Plantilla creada. Ajusta los puntos amarillos a tu gusto.")


func _handle_save_pressed() -> void:
	var changes := session.get_external_changes()
	if _conflict_controller.scene_pending or bool(changes.get("scene", false)):
		_show_external_change_dialog()
		return
	var error := session.save()
	if error == OK:
		session.clear_recovery()
		_publication_controller.refresh()
		_show_success("Borrador guardado en %s." % session.scene_path)
	else:
		_show_error(_get_persistence_error("No se pudo guardar"))


func _handle_publish_pressed() -> void:
	var changes := session.get_external_changes()
	_conflict_controller.absorb(changes)
	_sync_conflict_flags()
	if _conflict_controller.has_pending():
		if _conflict_controller.scene_pending:
			_show_external_change_dialog()
		else:
			_show_catalog_change_dialog()
		return
	if bool(changes.get("scene", false)):
		_show_external_change_dialog()
		return
	var issues := _inspect_track()
	if session.track != null:
		issues = issues + _validation_controller.inspect_racing_line(session.track)
	if _has_blocking_issues(issues):
		_show_error(
			"Validación bloqueante: corrige los problemas indicados antes de publicar."
		)
		_show_step(5)
		return
	var error := _publication_controller.publish(
		session.laps,
		session.description
	)
	if error == OK:
		session.clear_recovery()
		_reload_track_picker()
		_show_success("Pista publicada. Ya aparece en el menú del juego.")
	else:
		_show_error(_get_persistence_error("No se pudo publicar"))


func _handle_test_pressed() -> void:
	var issues := _inspect_track()
	if session.track == null or _has_blocking_issues(issues):
		_show_error("La pista necesita pasar la revisión antes de probarla.")
		_show_step(5)
		return
	var error := session.save()
	if error != OK:
		_show_error(_get_persistence_error("No se pudo preparar la prueba"))
		return
	_set_playtest_state(&"iniciando")
	play_requested.emit(session.scene_path, session.track.track_id, session.laps)
	_show_success("Iniciando prueba con el kart del jugador…")


func _handle_validate_pressed() -> void:
	_rebuild_preview()
	var issues := _inspect_track()
	if session.track != null:
		issues = issues + _validation_controller.inspect_racing_line(session.track)
	if issues.is_empty():
		_show_success("Revisión completa: no hay problemas.")
	elif _has_blocking_issues(issues):
		_show_error("La pista tiene problemas. Usa los mensajes para localizarlos.")
	else:
		_show_warning("Revisión completa con advertencias no bloqueantes.")
	_show_step(5)


func _handle_route_edited() -> void:
	session.mark_dirty()
	_map_view.queue_redraw()


func _handle_route_edit_finished() -> void:
	session.recalculate_route_dependents()
	_rebuild_preview()
	_refresh_validation()
	_show_step(_current_step)
	_show_success("Carretera actualizada.")


func _handle_point_selected(_point_index: int) -> void:
	pass


func _handle_selection_changed(new_selection: RefCounted) -> void:
	_selection = new_selection
	var step := int(_selection.workflow_step())
	if step >= 0:
		_show_step(step, false)


func _restore_inspector_state(
	focus_path: NodePath,
	scroll_value: int,
	focus_first_control: bool
) -> void:
	if _properties == null:
		return
	var inspector_scroll := _properties.get_parent() as ScrollContainer
	if inspector_scroll != null:
		inspector_scroll.scroll_vertical = scroll_value
	if not focus_path.is_empty():
		var remembered_control := _properties.get_node_or_null(focus_path) as Control
		if (
			remembered_control != null
			and remembered_control.visible
			and remembered_control.focus_mode != Control.FOCUS_NONE
			and _is_focusable_inspector_control(remembered_control)
		):
			remembered_control.grab_focus()
			return
	if not focus_first_control:
		return
	for candidate in _properties.find_children("*", "Control", true, false):
		var control := candidate as Control
		if (
			control != null
			and control.visible
			and control.focus_mode != Control.FOCUS_NONE
			and _is_focusable_inspector_control(control)
		):
			control.grab_focus()
			return


func _is_focusable_inspector_control(control: Control) -> bool:
	if control is BaseButton:
		return not (control as BaseButton).disabled
	if control is LineEdit:
		return (control as LineEdit).editable
	if control is TextEdit:
		return (control as TextEdit).editable
	if control is SpinBox:
		return (control as SpinBox).editable
	return true


func _handle_surface_selection_requested(selected: RefCounted) -> void:
	_map_view.set_selection(selected, true)


func _handle_surface_create_requested(data: Dictionary) -> void:
	var result: Dictionary = _edit_controller.create_surface(data)
	if not bool(result.get("ok", false)):
		_show_error("No se pudo crear la zona de superficie.")
		return
	_complete_surface_edit("Zona de superficie creada.")
	_map_view.set_selection(result.selection)


func _handle_surface_update_requested(
	selected: RefCounted,
	data: Dictionary
) -> void:
	var result: Dictionary = _edit_controller.update_surface(selected, data)
	if not bool(result.get("changed", false)):
		_show_warning("La zona no cambió.")
		return
	_complete_surface_edit("Zona de superficie actualizada.")


func _handle_surface_delete_requested(selected: RefCounted) -> void:
	if not bool(_edit_controller.delete_surface(selected).get("ok", false)):
		_show_error("No se encontró la zona seleccionada.")
		return
	_selection = Selection.none()
	_map_view.clear_selection()
	_complete_surface_edit("Zona de superficie eliminada.")


func _complete_surface_edit(message: String) -> void:
	_map_view.refresh_view_bounds()
	_rebuild_preview()
	_refresh_validation()
	_show_step(4)
	var issues := _inspect_track()
	if _has_blocking_issues(issues):
		_show_error(message + " Revisa la zona antes de publicar.")
	else:
		_show_success(message)


func _handle_entity_move_requested(
	selected: RefCounted,
	track_position: Vector3
) -> void:
	if session.move_entity(selected, track_position):
		session.mark_dirty()
		if selected.is_shortcut_control() and _current_step == 2:
			_show_step(2)


func _handle_entity_delete_requested(selected: RefCounted) -> void:
	if selected == null or selected.is_empty():
		return
	if not bool(_edit_controller.delete_entity(selected).get("ok", false)):
		_show_error("Este elemento no se puede eliminar.")
		return
	_selection = Selection.none()
	_map_view.clear_selection()
	_complete_entity_edit("Elemento eliminado.")


func _handle_entity_duplicate_requested(selected: RefCounted) -> void:
	if selected == null or selected.is_empty():
		return
	var result: Dictionary = _edit_controller.duplicate_entity(selected)
	if not bool(result.get("ok", false)):
		_show_error("Este elemento no se puede duplicar.")
		return
	_selection = result.selection
	_map_view.set_selection(_selection)
	_complete_entity_edit("Elemento duplicado.")


func _complete_entity_edit(message: String) -> void:
	_map_view.refresh_view_bounds()
	_rebuild_preview()
	_refresh_validation()
	_show_step(_current_step)
	_show_success(message)


func _restore_selection_after_history() -> void:
	if _selection == null or _selection.is_empty():
		return
	if (
		_selection.kind != Selection.Kind.ROUTE_POINT
		and session.track.get_node_or_null(_selection.node_path) == null
	):
		_selection = Selection.none()
	_map_view.set_selection(_selection)


func _refresh_validation() -> void:
	if session.track == null:
		return
	var issues := _inspect_track()
	_map_view.set_issues(issues)
	_update_step_badges(issues)


func _update_step_badges(issues: Array[TrackValidationIssue]) -> void:
	var counts := _validation_controller.counts_by_step(issues)
	for step_index in STEP_LABELS.size():
		_step_buttons[step_index].text = (
			"%s  ⚠ %d" % [STEP_LABELS[step_index], counts[step_index]]
			if counts[step_index] > 0
			else STEP_LABELS[step_index]
		)


func _handle_route_position_changed(position: Vector3) -> void:
	if _selection.kind != Selection.Kind.ROUTE_POINT:
		return
	session.snapshot_track_for_undo()
	if session.update_route_point(_selection.point_index, position):
		session.mark_dirty()
		session.recalculate_route_dependents()
		_complete_entity_edit("Punto de carretera actualizado.")


func _handle_object_anchor_changed(
	selected: RefCounted,
	progress: float,
	lateral: float,
	height: float,
	rotation: float,
	scale_multiplier: float
) -> void:
	session.snapshot_track_for_undo()
	var changed := (
		session.update_item_progress(selected, progress)
		if selected.kind == Selection.Kind.ITEM
		else session.update_prop_anchor(
			selected,
			progress,
			lateral,
			height,
			rotation,
			scale_multiplier
		)
	)
	if changed:
		session.mark_dirty()
		_complete_entity_edit("Objeto actualizado.")


func _handle_restore_recommended_requested(selected: RefCounted) -> void:
	session.snapshot_track_for_undo()
	if not session.restore_prop_recommended_scale(selected):
		session.discard_latest_snapshot()
		_show_error("No se reconoce este asset; se conservó su tamaño actual.")
		return
	session.mark_dirty()
	_complete_entity_edit("Tamaño recomendado restaurado.")


func _calibrate_known_props() -> void:
	session.snapshot_track_for_undo()
	var result := session.calibrate_known_props()
	var affected := int(result.get("affected", 0))
	var omitted := int(result.get("omitted", 0))
	if affected == 0:
		session.discard_latest_snapshot()
		_show_warning(
			"No se calibró decoración; %d objeto(s) desconocido(s) quedaron intactos."
			% omitted
		)
		return
	session.mark_dirty()
	_complete_entity_edit(
		"Calibración terminada: %d afectado(s), %d omitido(s)."
		% [affected, omitted]
	)


func _handle_shortcut_midpoint_changed(
	selected: RefCounted,
	longitudinal: float,
	lateral: float,
	height: float
) -> void:
	session.snapshot_track_for_undo()
	var result := session.fit_shortcut_midpoint(
		selected,
		longitudinal,
		lateral,
		height
	)
	if result.status == &"accepted" or result.status == &"adjusted":
		session.mark_dirty()
		_complete_entity_edit(String(result.message))
	else:
		session.discard_latest_snapshot()
		_rebuild_preview()
		_refresh_validation()
		_show_step(2)
		_show_error(String(result.message))


func _handle_shortcut_shape_changed(
	selected: RefCounted,
	shape: Dictionary
) -> void:
	session.snapshot_track_for_undo()
	var result := session.fit_shortcut_shape(selected, shape)
	if result.status in [&"accepted", &"adjusted"]:
		session.mark_dirty()
		_complete_entity_edit(String(result.message))
	else:
		session.discard_latest_snapshot()
		_rebuild_preview()
		_refresh_validation()
		_show_step(2)
		_show_error(String(result.message))


func _handle_shortcut_rename_requested(
	selected: RefCounted,
	display_name: String
) -> void:
	session.snapshot_track_for_undo()
	if not session.rename_shortcut(selected, display_name):
		session.discard_latest_snapshot()
		_show_error("El atajo necesita un nombre.")
		return
	session.mark_dirty()
	_complete_entity_edit("Atajo renombrado.")


func _handle_shortcut_reset_requested(selected: RefCounted) -> void:
	session.snapshot_track_for_undo()
	var result := session.reset_shortcut_safe(selected)
	if result.status == &"adjusted":
		session.mark_dirty()
		_complete_entity_edit(String(result.message))
	elif result.status == &"accepted":
		session.discard_latest_snapshot()
		_show_step(2)
		_show_success(String(result.message))
	else:
		session.discard_latest_snapshot()
		_show_step(2)
		_show_error(String(result.message))


func _handle_add_point() -> void:
	if _map_view.insert_point_after_selected():
		session.mark_dirty()
		_rebuild_preview()
		_show_step(1)


func _handle_delete_point() -> void:
	if _map_view.delete_selected_point():
		session.mark_dirty()
		_rebuild_preview()
		_show_step(1)
	else:
		_show_error("La carretera necesita al menos cuatro puntos.")


func _handle_mark_start() -> void:
	session.snapshot_route_for_undo()
	if _map_view.mark_selected_as_start():
		session.mark_dirty()
		_rebuild_preview()
		_show_success("La salida se moverá al punto seleccionado.")


func _create_shortcut(entry_index: int, exit_index: int) -> void:
	if exit_index <= entry_index + 1:
		_show_error("La salida debe estar al menos dos puntos después de la entrada.")
		return
	var curve := session.track.get_main_route().curve
	var start := curve.get_point_position(entry_index)
	var finish := curve.get_point_position(exit_index)
	var entry_forward := _get_route_forward_at_position(curve, start)
	var exit_forward := _get_route_forward_at_position(curve, finish)
	var shortcut_curve := _find_clear_shortcut_curve(
		start,
		finish,
		entry_forward,
		exit_forward
	)
	if shortcut_curve == null:
		_show_error(
			"No hay espacio seguro para ese atajo. Elige otra entrada o salida."
		)
		return
	session.snapshot_track_for_undo()
	var shortcut := TrackShortcut.new()
	shortcut.name = "Shortcut%d" % (session.track.get_shortcuts().size() + 1)
	shortcut.shortcut_id = session.track.get_shortcuts().size()
	shortcut.display_name = "Atajo %d" % (shortcut.shortcut_id + 1)
	shortcut.curve = shortcut_curve
	var shortcuts := session.track.get_node_or_null("Shortcuts")
	shortcuts.add_child(shortcut)
	shortcut.owner = session.track
	session.configure_shortcut_anchor(shortcut, true)
	session.mark_dirty()
	_map_view.queue_redraw()
	_rebuild_preview()
	_show_step(2)
	var errors := session.track.validate_track()
	if errors.is_empty():
		_show_success("Atajo creado y conectado.")
	else:
		_show_error("Atajo creado. Revisa su dirección y conexiones.")


func _get_route_forward_at_position(
	route_curve: Curve3D,
	position: Vector3
) -> Vector3:
	var route_length := route_curve.get_baked_length()
	if route_length <= 0.001:
		return Vector3.FORWARD
	var offset := route_curve.get_closest_offset(position)
	var sample_distance := minf(1.0, route_length * 0.01)
	var previous_offset := offset - sample_distance
	var next_offset := offset + sample_distance
	if route_curve.closed:
		previous_offset = fposmod(previous_offset, route_length)
		next_offset = fposmod(next_offset, route_length)
	else:
		previous_offset = maxf(previous_offset, 0.0)
		next_offset = minf(next_offset, route_length)
	var forward := (
		route_curve.sample_baked(next_offset)
		- route_curve.sample_baked(previous_offset)
	)
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _find_clear_shortcut_curve(
	start: Vector3,
	finish: Vector3,
	entry_forward: Vector3,
	exit_forward: Vector3
) -> Curve3D:
	var direct_2d := Vector2(finish.x - start.x, finish.z - start.z)
	if direct_2d.length_squared() <= 0.001:
		return null
	var lateral_2d := Vector2(-direct_2d.y, direct_2d.x).normalized()
	var lateral := Vector3(lateral_2d.x, 0.0, lateral_2d.y)
	var route_points := session.track._sample_path(
		session.track.get_main_route(),
		true
	)
	var required_clearance := TrackLevelValidator.SHORTCUT_ROUTE_CLEARANCE + 2.0
	var base_offset := required_clearance + 2.0
	for offset_multiplier in [1.0, 1.45, 2.0, 2.8, 3.8]:
		var best_curve: Curve3D = null
		var best_score := -INF
		for side in [-1.0, 1.0]:
			var midpoint := start.lerp(finish, 0.5)
			midpoint += lateral * base_offset * offset_multiplier * side
			for tangent_ratio in [0.14, 0.2, 0.26, 0.32]:
				var candidate := _build_shortcut_curve(
					start,
					finish,
					midpoint,
					entry_forward,
					exit_forward,
					tangent_ratio
				)
				var candidate_points := _sample_shortcut_curve(candidate)
				if TrackLevelValidator.has_shortcut_route_crossing(
					candidate_points,
					route_points
				):
					continue
				if not TrackLevelValidator.shortcut_follows_route_direction(
					candidate_points,
					route_points
				):
					continue
				var clearance := TrackLevelValidator.get_shortcut_corridor_clearance(
					candidate_points,
					route_points
				)
				var turn_radius := TrackLevelValidator.get_shortcut_minimum_turn_radius(
					candidate_points,
					route_points
				)
				if (
					clearance < required_clearance
					or turn_radius < TrackLevelValidator.SHORTCUT_MINIMUM_TURN_RADIUS
				):
					continue
				var score := minf(turn_radius, 40.0) + clearance * 0.1
				if score > best_score:
					best_curve = candidate
					best_score = score
		if best_curve != null:
			return best_curve
	return null


func _sample_shortcut_curve(shortcut_curve: Curve3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var segment_count := shortcut_curve.point_count - 1
	for segment_index in segment_count:
		for subdivision in session.track.shortcut_subdivisions:
			points.append(
				shortcut_curve.sample(
					segment_index,
					float(subdivision) / session.track.shortcut_subdivisions
				)
			)
	points.append(shortcut_curve.sample(segment_count - 1, 1.0))
	return points


func _build_shortcut_curve(
	start: Vector3,
	finish: Vector3,
	midpoint: Vector3,
	entry_forward: Vector3,
	exit_forward: Vector3,
	tangent_ratio := 0.22
) -> Curve3D:
	var shortcut_curve := Curve3D.new()
	var endpoint_distance := minf(
		start.distance_to(midpoint),
		midpoint.distance_to(finish)
	)
	var endpoint_tangent_length := clampf(
		endpoint_distance * tangent_ratio,
		8.0,
		28.0
	)
	var middle_direction := (finish - start).normalized()
	var middle_tangent_length := clampf(endpoint_distance * 0.24, 6.0, 18.0)
	var middle_tangent := middle_direction * middle_tangent_length
	shortcut_curve.add_point(
		start,
		Vector3.ZERO,
		entry_forward * endpoint_tangent_length
	)
	shortcut_curve.add_point(midpoint, -middle_tangent, middle_tangent)
	shortcut_curve.add_point(
		finish,
		-exit_forward * endpoint_tangent_length
	)
	return shortcut_curve


func _delete_shortcut(shortcut: TrackShortcut) -> void:
	if not is_instance_valid(shortcut):
		return
	session.snapshot_track_for_undo()
	shortcut.get_parent().remove_child(shortcut)
	shortcut.free()
	_selection = Selection.none()
	_map_view.clear_selection()
	session.mark_dirty()
	_map_view.queue_redraw()
	_rebuild_preview()
	_show_step(2)


func _add_item_spawn(point_index: int) -> void:
	var item_root := session.track.get_node_or_null("ItemSpawns")
	var route := session.track.get_main_route()
	if item_root == null or route == null or route.curve == null:
		_show_error("La pista no tiene un contenedor de cajas válido.")
		return
	session.snapshot_track_for_undo()
	var marker := Marker3D.new()
	marker.name = "ItemSpawn%d" % (item_root.get_child_count() + 1)
	marker.position = route.curve.get_point_position(point_index)
	item_root.add_child(marker)
	marker.owner = session.track
	session.anchor_item_spawn(
		marker,
		session.get_route_progress_for_control_point(point_index)
	)
	session.mark_dirty()
	_rebuild_preview()
	_show_step(3)
	_show_success("Caja colocada sobre la carretera.")


func _add_asset(
	entry: TrackAssetEntry,
	point_index: int,
	side_sign: float,
	distance: float,
	rotation_degrees_y: float,
	scale_multiplier: float = 1.0
) -> void:
	var props := session.track.get_node_or_null("Props")
	var route := session.track.get_main_route()
	if props == null or route == null or entry == null or entry.scene == null:
		_show_error("No se pudo colocar el asset.")
		return
	var instance := entry.scene.instantiate() as Node3D
	if instance == null:
		_show_error("El asset seleccionado no es un modelo 3D.")
		return
	var scale_result := entry.resolve_base_scale()
	var base_scale: Vector3 = scale_result.scale
	session.snapshot_track_for_undo()
	instance.name = entry.display_name.validate_node_name()
	var previous_index := (
		point_index - 1 + route.curve.point_count
	) % route.curve.point_count
	var next_index := (point_index + 1) % route.curve.point_count
	var forward := (
		route.curve.get_point_position(next_index)
		- route.curve.get_point_position(previous_index)
	)
	forward.y = 0.0
	forward = forward.normalized()
	var side := Vector3(-forward.z, 0.0, forward.x) * side_sign
	instance.position = route.curve.get_point_position(point_index) + side * distance
	instance.rotation_degrees.y = rotation_degrees_y
	props.add_child(instance)
	instance.owner = session.track
	session.set_prop_asset_id(instance, entry.id)
	session.initialize_prop_scale(instance, base_scale, scale_multiplier)
	session.anchor_prop(
		instance,
		session.get_route_progress_for_control_point(point_index),
		side_sign * distance,
		0.0,
		rotation_degrees_y
	)
	session.mark_dirty()
	_rebuild_preview()
	_show_step(3)
	if bool(scale_result.used_fallback):
		_show_warning(
			"%s se colocó con su escala predeterminada; no se pudo medir el modelo."
			% entry.display_name
		)
	else:
		_show_success("%s colocado junto a la carretera." % entry.display_name)


func _focus_issue(issue: TrackValidationIssue) -> void:
	if issue.focus_kind == &"shortcut":
		_selection = Selection.node(
			Selection.Kind.SHORTCUT_MIDPOINT,
			issue.target_path
		)
	elif issue.focus_kind == &"item":
		_selection = Selection.node(Selection.Kind.ITEM, issue.target_path)
	elif issue.focus_kind == &"prop":
		_selection = Selection.node(Selection.Kind.PROP, issue.target_path)
	elif issue.focus_kind == &"surface":
		_selection = Selection.node(Selection.Kind.SURFACE, issue.target_path)
	else:
		_selection = Selection.none()
	var selection_target_exists: bool = (
		_selection.kind == Selection.Kind.ROUTE_POINT
		or session.track != null
		and session.track.get_node_or_null(_selection.node_path) != null
	)
	if not _selection.is_empty() and selection_target_exists:
		_map_view.set_selection(_selection, true)
	else:
		_selection = Selection.none()
		_show_step(issue.workflow_step)
		_map_view.focus_issue(issue)
	if not issue.world_position.is_zero_approx():
		_map_view.focus_world_position(issue.world_position)
	if issue.severity == TrackValidationIssue.Severity.WARNING:
		_show_warning(issue.message)
	else:
		_show_error(issue.message)


func _rebuild_preview() -> void:
	_preview_rebuild_pending = true
	_preview_controller.request_rebuild(session.track, _map_view)
	_update_preview_status()


func _handle_preview_state_changed(_state: StringName) -> void:
	_update_preview_status()


func _update_preview_status() -> void:
	if _preview_status_label == null:
		return
	var state: StringName = _preview_controller.preview_state
	match state:
		&"pendiente":
			_preview_status_label.text = "● PREVIEW PENDIENTE"
			_preview_status_label.add_theme_color_override("font_color", EditorStyle.FOCUS)
		&"diferido":
			_preview_status_label.text = "○ PREVIEW DIFERIDO"
			_preview_status_label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
		&"actualizado_con_advertencias":
			_preview_status_label.text = "△ PREVIEW CON AVISOS"
			_preview_status_label.add_theme_color_override("font_color", EditorStyle.FOCUS)
		&"sin_pista":
			_preview_status_label.text = "— SIN PREVIEW"
			_preview_status_label.add_theme_color_override("font_color", EditorStyle.TEXT_MUTED)
		_:
			_preview_status_label.text = "✓ PREVIEW ACTUALIZADO"
			_preview_status_label.add_theme_color_override("font_color", EditorStyle.SUCCESS)


func _inspect_track() -> Array[TrackValidationIssue]:
	return _validation_controller.inspect(session.track)


func _has_blocking_issues(issues: Array[TrackValidationIssue]) -> bool:
	return _validation_controller.has_blocking_issues(issues)


func _frame_preview_camera() -> void:
	if session.track == null:
		return
	_preview_controller.frame_camera(session.track.route_points)


func _toggle_view() -> void:
	_preview_rebuild_pending = false
	_is_showing_preview = _preview_controller.toggle_view(
		_map_view,
		_view_toggle,
		session.track
	)


func _show_success(message: String) -> void:
	_status_label.text = "✓  " + message
	_status_label.add_theme_color_override("font_color", EditorStyle.SUCCESS)


func _show_error(message: String) -> void:
	_status_label.text = "⚠  " + message
	_status_label.add_theme_color_override("font_color", EditorStyle.ERROR)


func _show_warning(message: String) -> void:
	_status_label.text = "⚠  " + message
	_status_label.add_theme_color_override("font_color", EditorStyle.FOCUS)


func _get_persistence_error(fallback: String) -> String:
	var detail := session.last_persistence_error
	return detail if not detail.is_empty() else fallback


func _add_help(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", EditorStyle.TEXT_SECONDARY)
	_properties.add_child(label)


func _button(
	text: String,
	callback: Callable,
	tooltip := "",
	is_primary := false
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44.0
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	if is_primary:
		button.add_theme_color_override("font_color", EditorStyle.CANVAS_BACKGROUND)
		button.add_theme_stylebox_override("normal", _style_box(EditorStyle.FOCUS, EditorStyle.FOCUS))
		button.add_theme_stylebox_override("hover", _style_box(Color("#ffd66e"), Color("#ffffff")))
		button.add_theme_stylebox_override("pressed", _style_box(Color("#d9a72d"), Color("#ffffff")))
		button.add_theme_stylebox_override("focus", _style_box(Color("#f6c344"), Color("#ffffff"), 3))
	return button


func _build_new_dialog() -> void:
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Nueva pista"
	_new_dialog.ok_button_text = "Crear pista"
	_new_dialog.cancel_button_text = "Cancelar"
	_new_dialog.confirmed.connect(_create_new_track)
	add_child(_new_dialog)
	var content := VBoxContainer.new()
	content.name = "NewTrackDialogContent"
	content.custom_minimum_size.x = NEW_DIALOG_CONTENT_WIDTH
	content.add_theme_constant_override("separation", 8)
	_new_dialog.add_child(content)
	var instructions := Label.new()
	instructions.text = "Elige un nombre y un tamaño. Todo lo demás se prepara automáticamente."
	instructions.custom_minimum_size.x = NEW_DIALOG_CONTENT_WIDTH
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instructions)
	_new_name = LineEdit.new()
	_new_name.placeholder_text = "Ejemplo: Bahía Relámpago"
	_new_name.custom_minimum_size.y = 44.0
	content.add_child(_new_name)
	_new_dialog.register_text_enter(_new_name)
	_new_size = OptionButton.new()
	_new_size.add_item("Pequeña · carrera rápida")
	_new_size.add_item("Mediana · recomendada")
	_new_size.add_item("Grande · recorrido largo")
	_new_size.select(1)
	_new_size.custom_minimum_size.y = 44.0
	_new_size.item_selected.connect(
		func(_index: int) -> void: _update_new_template_details()
	)
	content.add_child(_new_size)
	_new_template_details = Label.new()
	_new_template_details.name = "NewTemplateDetails"
	_new_template_details.custom_minimum_size.x = NEW_DIALOG_CONTENT_WIDTH
	_new_template_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_template_details.add_theme_color_override(
		"font_color",
		EditorStyle.TEXT_SECONDARY
	)
	content.add_child(_new_template_details)
	for button in [
		_new_dialog.get_ok_button(),
		_new_dialog.get_cancel_button(),
	]:
		button.custom_minimum_size.y = 44.0
		button.focus_mode = Control.FOCUS_ALL
	_update_new_template_details()
	content.size = Vector2(NEW_DIALOG_CONTENT_WIDTH, 260.0)
	content.queue_sort()


func _popup_new_dialog() -> void:
	_update_new_template_details()
	_new_dialog.popup_centered_clamped(NEW_DIALOG_PREFERRED_SIZE, 0.9)
	_new_name.call_deferred("grab_focus")


func _update_new_template_details() -> void:
	if _new_size == null or _new_template_details == null:
		return
	var size_ids := [&"small", &"medium", &"large"]
	var selected_index := clampi(_new_size.selected, 0, size_ids.size() - 1)
	var metrics := session.get_template_metrics(size_ids[selected_index])
	var dimensions: Vector2 = metrics.dimensions
	var environment_size: Vector2 = metrics.environment_size
	_new_template_details.text = (
		"Radio base: %d m  ·  %d puntos\n"
		+ "Circuito: %d × %d m  ·  longitud estimada: %d m\n"
		+ "Entorno: %d × %d m"
	) % [
		roundi(float(metrics.radius)),
		int(metrics.point_count),
		roundi(dimensions.x),
		roundi(dimensions.y),
		roundi(float(metrics.length)),
		roundi(environment_size.x),
		roundi(environment_size.y),
	]


func _build_unsaved_dialog() -> void:
	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Cambios sin guardar"
	_unsaved_dialog.dialog_text = "Esta pista tiene cambios sin guardar. ¿Qué quieres hacer?"
	_unsaved_dialog.ok_button_text = "Guardar"
	_unsaved_dialog.cancel_button_text = "Cancelar"
	_unsaved_dialog.add_button("Descartar", true, "discard")
	_unsaved_dialog.confirmed.connect(_save_then_continue)
	_unsaved_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			_unsaved_dialog.hide()
			_continue_pending_action()
	)
	add_child(_unsaved_dialog)


func _build_recovery_dialog() -> void:
	_recovery_dialog = ConfirmationDialog.new()
	_recovery_dialog.title = "Recuperación de pista"
	_recovery_dialog.ok_button_text = "Restaurar"
	_recovery_dialog.cancel_button_text = "Ahora no"
	_recovery_dialog.add_button("Descartar", true, "discard")
	_recovery_dialog.confirmed.connect(_restore_recovery)
	_recovery_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			session.clear_recovery()
			_recovery_dialog.hide()
			_show_success("Recuperación descartada.")
	)
	add_child(_recovery_dialog)


func _poll_external_changes() -> void:
	_external_controller.poll()


func _handle_external_changes(changes: Dictionary) -> void:
	if session.track == null:
		return
	var scene_was_pending := _conflict_controller.scene_pending
	var catalog_was_pending := _conflict_controller.catalog_pending
	_conflict_controller.absorb(changes)
	_sync_conflict_flags()
	var scene_became_pending := (
		_conflict_controller.scene_pending and not scene_was_pending
	)
	var catalog_became_pending := (
		_conflict_controller.catalog_pending and not catalog_was_pending
	)
	if bool(changes.get("catalog", false)):
		if session.is_dirty:
			if bool(changes.get("scene", false)):
				if scene_became_pending or catalog_became_pending:
					_show_external_change_dialog()
			elif catalog_became_pending:
				_show_catalog_change_dialog()
		else:
			if catalog_became_pending:
				_reload_track_picker()
				session.acknowledge_external_changes(false, true)
				_conflict_controller.clear_catalog()
				_sync_conflict_flags()
				_show_warning("El catálogo cambió fuera del editor; se actualizó la lista de pistas.")
	if not bool(changes.get("scene", false)):
		return
	if session.is_dirty:
		if scene_became_pending:
			_show_external_change_dialog()
		return
	var path := session.scene_path
	var error := session.load_track(path)
	if error == OK:
		_conflict_controller.clear_scene()
		_sync_conflict_flags()
		_show_warning("La pista se recargó porque cambió fuera del editor.")
	else:
		_show_error(
			_get_persistence_error(
				"La pista cambió fuera del editor y no se pudo recargar"
			)
		)


func _show_external_change_dialog() -> void:
	_dialog_controller.show_external(_conflict_controller.affected_scope())


func _show_catalog_change_dialog() -> void:
	_dialog_controller.show_catalog()


func _acknowledge_catalog_change() -> void:
	session.acknowledge_external_changes(false, true)
	_conflict_controller.clear_catalog()
	_sync_conflict_flags()
	_reload_track_picker()
	_show_warning("Catálogo actualizado. Revisa la pista y vuelve a publicar cuando esté lista.")


func _reload_external_scene() -> void:
	var path := session.scene_path
	var error := session.load_track(path)
	if error == OK:
		_conflict_controller.clear_all()
		_sync_conflict_flags()
		_show_success("Cambios externos cargados.")
	else:
		_show_error(_get_persistence_error("No se pudo recargar la pista"))


func _keep_external_scene() -> void:
	session.acknowledge_external_changes(true, false)
	_conflict_controller.clear_scene()
	_sync_conflict_flags()
	_show_warning("Se conservaron los cambios locales.")
	if _catalog_conflict_pending:
		_show_catalog_change_dialog()


func _show_conflict_comparison() -> void:
	_dialog_controller.show_comparison(_conflict_controller.comparison_text(
		session.get_external_change_summary()
	))


func _offer_recovery() -> void:
	if (
		_recovery_dialog == null
		or not visible
		or session.is_dirty
		or not session.has_recovery()
	):
		return
	var info := session.get_recovery_info()
	var track_id := str(info.get("track_id", ""))
	var source := str(info.get("scene_path", ""))
	var source_text := source if not source.is_empty() else "pista nueva"
	_recovery_dialog.dialog_text = (
		"Se encontró una edición recuperable de %s%s. ¿Quieres restaurarla?"
		% [
			source_text,
			(" (" + track_id + ")" if not track_id.is_empty() else ""),
		]
	)
	_recovery_dialog.popup_centered()


func _restore_recovery() -> void:
	var error := session.load_recovery()
	if error != OK:
		_show_error(
			"No se pudo restaurar la recuperación (%s). Se conservará para otro intento."
			% error_string(error)
		)
		return
	_show_step(_current_step)
	_show_success("Edición recuperada. Guarda la pista para conservarla.")


func _build_calibration_dialog() -> void:
	_calibration_dialog = ConfirmationDialog.new()
	_calibration_dialog.title = "Calibrar decoración conocida"
	_calibration_dialog.dialog_text = (
		"Se restaurará el tamaño recomendado de todos los assets reconocidos. "
		+ "Los objetos desconocidos no cambiarán."
	)
	_calibration_dialog.ok_button_text = "Calibrar"
	_calibration_dialog.cancel_button_text = "Cancelar"
	_calibration_dialog.confirmed.connect(_calibrate_known_props)
	add_child(_calibration_dialog)


func _build_open_dialog() -> void:
	_open_dialog = FileDialog.new()
	_open_dialog.title = "Abrir pista o borrador"
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.current_dir = "res://levels"
	_open_dialog.filters = PackedStringArray(["*.tscn ; Escenas de pista"])
	_open_dialog.file_selected.connect(_handle_file_selected)
	add_child(_open_dialog)


func _build_user_open_dialog() -> void:
	_user_open_dialog = FileDialog.new()
	_user_open_dialog.title = "Abrir borrador de user://"
	_user_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_user_open_dialog.access = FileDialog.ACCESS_USERDATA
	_user_open_dialog.current_dir = "user://"
	_user_open_dialog.filters = PackedStringArray(["*.tscn ; Escenas de pista"])
	_user_open_dialog.file_selected.connect(_handle_file_selected)
	add_child(_user_open_dialog)


func _handle_file_selected(path: String) -> void:
	var normalized_path := ProjectSettings.localize_path(path)
	if normalized_path == path:
		var user_root := ProjectSettings.globalize_path("user://").trim_suffix("/")
		var absolute_path := path.trim_suffix("/")
		if absolute_path.begins_with(user_root + "/"):
			normalized_path = "user://" + absolute_path.substr(user_root.length() + 1)
	if session.is_dirty:
		_show_unsaved_dialog("load", normalized_path)
	else:
		_load_path(normalized_path)


func _build_guide_dialog() -> void:
	_guide_dialog = AcceptDialog.new()
	_guide_dialog.title = "Cómo crear una pista"
	_guide_dialog.ok_button_text = "Entendido"
	_guide_dialog.dialog_text = (
		"1. CONFIGURACIÓN: escribe el nombre y las vueltas.\n\n"
		+ "2. CARRETERA: arrastra los puntos blancos en el mapa.\n\n"
		+ "3. ATAJOS: elige una entrada y una salida.\n\n"
		+ "4. OBJETOS: coloca cajas y decoración sin tocar nodos.\n\n"
		+ "5. SUPERFICIES: asigna zonas y comprueba sus límites.\n\n"
		+ "6. REVISAR: corrige los avisos, prueba y publica.\n\n"
		+ "Puedes volver a abrir esta guía con el botón ? GUÍA."
	)
	add_child(_guide_dialog)


func _show_guide() -> void:
	_guide_dialog.popup_centered(Vector2i(540, 520))


func _show_unsaved_dialog(action: String, path: String) -> void:
	_pending_action = action
	_pending_path = path
	_unsaved_dialog.popup_centered()


func _save_then_continue() -> void:
	if session.save() == OK:
		_continue_pending_action()
	else:
		_show_error(
			_get_persistence_error("No se pudo guardar; la acción fue cancelada")
		)


func _continue_pending_action() -> void:
	match _pending_action:
		"load":
			_load_path(_pending_path)
		"new":
			_popup_new_dialog()
	_pending_action = ""
	_pending_path = ""


func _create_workshop_theme() -> Theme:
	return EditorStyle.create_theme()


func _style_box(
	background: Color,
	border: Color,
	border_width := 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
