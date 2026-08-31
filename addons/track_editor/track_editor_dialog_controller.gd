@tool
class_name TrackEditorDialogController
extends RefCounted

signal external_reload_requested
signal external_keep_requested
signal catalog_acknowledged
signal compare_requested

var external_dialog: ConfirmationDialog
var catalog_dialog: AcceptDialog
var comparison_dialog: AcceptDialog


func build(parent: Control) -> void:
	external_dialog = ConfirmationDialog.new()
	external_dialog.name = "ExternalChangeDialog"
	external_dialog.title = "Archivo cambiado externamente"
	external_dialog.ok_button_text = "Recargar"
	external_dialog.cancel_button_text = "Conservar localmente"
	external_dialog.add_button("Comparar estado", false, "compare")
	external_dialog.confirmed.connect(func() -> void: external_reload_requested.emit())
	external_dialog.canceled.connect(func() -> void: external_keep_requested.emit())
	external_dialog.custom_action.connect(_handle_custom_action)
	parent.add_child(external_dialog)

	catalog_dialog = AcceptDialog.new()
	catalog_dialog.name = "CatalogChangeDialog"
	catalog_dialog.title = "Catálogo cambiado externamente"
	catalog_dialog.ok_button_text = "Actualizar catálogo"
	catalog_dialog.add_button("Comparar estado", false, "compare")
	catalog_dialog.confirmed.connect(func() -> void: catalog_acknowledged.emit())
	catalog_dialog.custom_action.connect(_handle_custom_action)
	parent.add_child(catalog_dialog)

	comparison_dialog = AcceptDialog.new()
	comparison_dialog.name = "ConflictComparisonDialog"
	comparison_dialog.title = "Comparar estado"
	comparison_dialog.ok_button_text = "Entendido"
	comparison_dialog.dialog_text = "No hay cambios externos pendientes."
	parent.add_child(comparison_dialog)
	for button in [
		external_dialog.get_ok_button(),
		external_dialog.get_cancel_button(),
		catalog_dialog.get_ok_button(),
		comparison_dialog.get_ok_button(),
	]:
		if button != null:
			button.custom_minimum_size.y = 44.0
			button.focus_mode = Control.FOCUS_ALL


func show_external(affected_scope: String) -> void:
	if external_dialog == null or external_dialog.visible:
		return
	external_dialog.dialog_text = (
		"Cambió %s fuera del editor. Recargar descarta los cambios locales; "
		+ "conservarlos permite guardarlos encima del archivo externo. "
		+ "Comparar estado muestra las firmas detectadas."
		% affected_scope
	)
	external_dialog.popup_centered(Vector2i(560, 220))


func show_catalog() -> void:
	if catalog_dialog == null or catalog_dialog.visible:
		return
	catalog_dialog.dialog_text = (
		"El catálogo de pistas cambió fuera del editor. Actualízalo y confirma la "
		+ "versión más reciente antes de publicar; tus cambios locales se conservarán."
	)
	catalog_dialog.popup_centered(Vector2i(560, 220))


func show_comparison(summary_text: String) -> void:
	if comparison_dialog == null:
		return
	comparison_dialog.dialog_text = summary_text
	comparison_dialog.popup_centered(Vector2i(620, 360))


func _handle_custom_action(action: StringName) -> void:
	if action == &"compare":
		compare_requested.emit()
