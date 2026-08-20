extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const BUTTON_ICONS := {
	"dev_money_confirm_button": "res://assets/items/icons/COINCASE.png",
	"dev_gems_confirm_button": "res://assets/ui/donator_gem.svg",
	"dev_aetherite_confirm_button": "res://assets/ui/aetherite.svg",
	"dev_battle_points_confirm_button": "res://assets/ui/battle_points.svg",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(
		overlay_source.contains("func _current_dev_currency_amount()")
			and overlay_source.count("var amount := _current_dev_currency_amount()") == 4,
		"Each developer currency action reads the unsubmitted amount field"
	)
	_check(
		overlay_source.contains("dev_money_amount_spinbox.get_line_edit().grab_focus.call_deferred()"),
		"Developer currency dialog focuses the editable amount field"
	)

	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Developer currency icon check loads the UI overlay")
	if packed == null:
		quit(1)
		return

	var overlay := packed.instantiate()
	root.add_child(overlay)
	await process_frame

	for property_name: String in BUTTON_ICONS:
		var button := overlay.get(property_name) as Button
		var expected_icon_path: String = BUTTON_ICONS[property_name]
		_check(button != null, "%s exists" % property_name)
		if button == null:
			continue
		_check(
			button.icon != null and button.icon.resource_path == expected_icon_path,
			"%s uses its wallet icon" % property_name
		)
		_check(button.expand_icon, "%s scales its icon safely" % property_name)
		_check(
			button.get_theme_constant("icon_max_width") == 20,
			"%s keeps its icon compact" % property_name
		)
		_check(
			button.custom_minimum_size.y == 36.0,
			"%s keeps the existing button height" % property_name
		)

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.queue_free()
	await process_frame
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
