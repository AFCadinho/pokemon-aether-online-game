@tool
extends EditorPlugin

const Authoring := preload("res://tools/guild_furniture_collision_authoring.gd")
const Templates := preload("res://tools/guild_room_template_authoring.gd")
const MENU := "Export Guild Furniture Collision"
var message: AcceptDialog

func _enter_tree() -> void:
	message = AcceptDialog.new()
	message.title = "Guild furniture collision"
	get_editor_interface().get_base_control().add_child(message)
	add_tool_menu_item(MENU, _export)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU)
	if is_instance_valid(message):
		message.queue_free()

func _export() -> void:
	var current := get_editor_interface().get_edited_scene_root()
	var is_template := current != null and current.has_meta("guild_room_template")
	if current != null and (is_template or current.scene_file_path.begins_with("res://scenes/world/guild_base/furniture/")):
		if get_editor_interface().save_scene() != OK:
			message.dialog_text = "Could not save the current furniture scene. Save it before exporting collision."
			message.popup_centered(Vector2i(520, 160))
			return
	var result := Templates.export_scene(current, Authoring.default_backend_path()) if is_template else Authoring.export_catalogs(Authoring.default_backend_path())
	if bool(result.success) and is_template:
		if get_editor_interface().save_scene() != OK:
			result = {"success": false, "error": "Furniture and catalogs were exported, but this template scene could not be saved. Save it manually."}
	message.dialog_text = "Exported %d collision layers to the furniture scenes, game and server catalogs. Shared copies use the same shape. Restart the game and account service to load changed collision." % int(result.get("count", 0)) if bool(result.success) else str(result.error)
	message.popup_centered(Vector2i(520, 160))
	if bool(result.success):
		get_editor_interface().get_resource_filesystem().scan()
