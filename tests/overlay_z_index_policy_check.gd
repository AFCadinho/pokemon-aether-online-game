extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains("const UI_ACTIVE_Z_INDEX := 1000"), "Normal focused HUD groups retain their own layer")
	_check(source.contains("const UI_CHAT_TABS_Z_INDEX := UI_ACTIVE_Z_INDEX + 1"), "Chat tabs remain above normal HUD groups")
	_check(source.contains("const UI_WINDOW_Z_INDEX := UI_CHAT_TABS_Z_INDEX + 1"), "Opened interfaces render above chat tabs")
	_check(source.contains("panel.z_index = UI_WINDOW_Z_INDEX"), "Every activated interface uses the shared window layer")
	_check(not source.contains("panel.z_index = UI_BAG_Z_INDEX if panel == bag_popup else UI_ACTIVE_Z_INDEX"), "Window priority is no longer limited to the Bag")
	_check(source.contains("panel.z_index = UI_BASE_Z_INDEX"), "Closed interfaces return to the base layer")
	_check(source.contains("panel.move_to_front()"), "Windows on the same layer retain click-to-front ordering")
	_check(source.contains("const UI_DRAG_Z_INDEX := 1100") and source.contains("const UI_MODAL_Z_INDEX := 2000"), "Drag previews and modal dialogs remain above regular windows")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
