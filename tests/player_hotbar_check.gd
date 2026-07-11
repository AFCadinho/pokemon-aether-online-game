extends SceneTree

var failures := 0

func _init() -> void:
	var service := FileAccess.get_file_as_string("res://scripts/services/player_hotbar_service.gd")
	var ui := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var drag_source := FileAccess.get_file_as_string("res://scripts/ui/hotbar_bag_item_slot.gd")
	_check(service.contains("/game/hotbar"), "generic hotbar endpoint")
	_check(service.contains("func assign("), "persistent slot assignment")
	_check(ui.contains("func _setup_player_hotbar"), "existing hotkey sidebar integration")
	_check(ui.contains("range(8)"), "eight hotbar slots")
	_check(ui.contains("_hotbar_index_from_keycode"), "number-key activation")
	_check(not ui.contains("hotbar_panel = PanelContainer.new()"), "no duplicate horizontal hotbar")
	_check(ui.contains("escape-rope-action"), "virtual Escape Rope key item")
	_check(ui.contains("MOUSE_BUTTON_RIGHT"), "Bag-to-hotbar assignment")
	_check(ui.contains("_on_hotbar_bag_item_dropped"), "Bag drag-and-drop target")
	_check(drag_source.contains("CANVAS_ITEM_Z_MAX") and drag_source.contains("z_as_relative = false"), "drag preview above hotbar")
	_check(ui.contains("PlayerHotbarService.clear_slot"), "hotbar slot removal")
	_check(ui.contains("_show_bag_item_use_popup(item)"), "medicine target flow reuse")
	_check(ui.contains("escape_rope_slot.visible = false"), "Escape Rope removed from toggle bar")
	_check(not ui.contains("escape_rope_slot.visible = visible_unlocked"), "status refresh cannot restore legacy Escape Rope slot")
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
