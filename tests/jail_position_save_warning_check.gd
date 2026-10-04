extends SceneTree

const WORLD_SCRIPT := "res://scripts/world/world.gd"


func _init() -> void:
	var source := FileAccess.get_file_as_string(WORLD_SCRIPT)
	if not source.contains('"jail_detention_active"'):
		push_error("Position save warnings do not recognize active jail detention")
		quit(1)
		return
	if not source.contains("and not expected_position_rejection"):
		push_error("Expected position rejections can still emit save warnings")
		quit(1)
		return

	print("Active jail detention position conflicts are handled without warnings")
	quit(0)
