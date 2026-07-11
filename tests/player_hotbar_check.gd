extends SceneTree

var failures := 0

func _init() -> void:
	var service := FileAccess.get_file_as_string("res://scripts/services/player_hotbar_service.gd")
	var ui := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(service.contains("/game/hotbar"), "generic hotbar endpoint")
	_check(service.contains("func assign("), "persistent slot assignment")
	_check(ui.contains("func _setup_player_hotbar"), "four-slot hotbar UI")
	_check(ui.contains("escape-rope-action"), "virtual Escape Rope key item")
	_check(ui.contains("MOUSE_BUTTON_RIGHT"), "Bag-to-hotbar assignment")
	_check(ui.contains("PlayerHotbarService.clear_slot"), "hotbar slot removal")
	_check(ui.contains("_show_bag_item_use_popup(item)"), "medicine target flow reuse")
	_check(ui.contains("escape_rope_slot.visible = false"), "Escape Rope removed from toggle bar")
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
