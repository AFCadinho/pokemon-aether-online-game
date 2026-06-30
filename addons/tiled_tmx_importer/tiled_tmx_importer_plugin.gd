@tool
extends EditorPlugin

const TmxImportDialog := preload("res://addons/tiled_tmx_importer/tmx_import_dialog.gd")

var import_dialog: ConfirmationDialog


func _enter_tree() -> void:
	import_dialog = TmxImportDialog.new()
	get_editor_interface().get_base_control().add_child(import_dialog)
	add_tool_menu_item("Import Tiled TMX...", Callable(self, "_show_import_dialog"))


func _exit_tree() -> void:
	remove_tool_menu_item("Import Tiled TMX...")
	if import_dialog != null:
		import_dialog.queue_free()
		import_dialog = null


func _show_import_dialog() -> void:
	if import_dialog == null:
		return
	import_dialog.popup_centered(Vector2i(720, 300))
