@tool
extends ConfirmationDialog

const TmxVisualImporter := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")

var tmx_path_edit: LineEdit
var output_scene_edit: LineEdit
var status_label: Label


func _init() -> void:
	title = "Import Tiled TMX"
	ok_button_text = "Import"
	min_size = Vector2i(720, 300)


func _ready() -> void:
	_build_ui()
	confirmed.connect(_on_confirmed)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	var source_label := Label.new()
	source_label.text = "TMX source path"
	rows.add_child(source_label)

	tmx_path_edit = LineEdit.new()
	tmx_path_edit.placeholder_text = "res://maps/sample/desert.tmx or /absolute/path/desert.tmx"
	rows.add_child(tmx_path_edit)

	var output_label := Label.new()
	output_label.text = "Output scene path"
	rows.add_child(output_label)

	output_scene_edit = LineEdit.new()
	output_scene_edit.placeholder_text = "res://imported/tiled/desert/desert.tscn"
	rows.add_child(output_scene_edit)

	var hint_label := Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.text = "The importer creates one visual .tscn scene and one shared .tileset.tres beside it. It imports tile layers only and ignores object layers/properties."
	rows.add_child(hint_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status_label)


func _on_confirmed() -> void:
	var tmx_path := tmx_path_edit.text.strip_edges()
	var output_scene_path := output_scene_edit.text.strip_edges()
	if tmx_path == "" or output_scene_path == "":
		status_label.text = "TMX source and output scene path are required."
		popup_centered(size)
		return

	var importer := TmxVisualImporter.new()
	var result: Dictionary = importer.import_tmx(tmx_path, output_scene_path)
	if not bool(result.get("success", false)):
		status_label.text = "Import failed: %s" % str(result.get("error", "Unknown error"))
		popup_centered(size)
		return

	status_label.text = "Imported %s" % str(result.get("scene_path", output_scene_path))
	EditorInterface.get_resource_filesystem().scan()
