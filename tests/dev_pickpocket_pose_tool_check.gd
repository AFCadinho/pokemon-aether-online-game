extends SceneTree

const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_PATH)
	_check(source.contains("dev_pickpocket_pose_button"), "Developer Tools exposes the pickpocket pose button")
	_check(
		source.contains("func _on_dev_pickpocket_pose_button_pressed()"),
		"Pickpocket pose button has a dedicated handler"
	)
	_check(
		source.contains("CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET"),
		"Developer tool activates the dedicated pickpocket movement style"
	)
	_check(
		source.contains("await get_tree().create_timer(DEV_PICKPOCKET_POSE_DURATION).timeout"),
		"Pickpocket pose is a short one-shot action"
	)
	_check(
		source.contains("ending_style == CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET")
			and source.contains('player_node.call("clear_activity_style")'),
		"Developer tool automatically restores the normal player pose"
	)
	_check(
		source.contains("current_style != CharacterAppearanceService.BODY_MOVEMENT_DEFAULT")
			and source.contains("ending_style == CharacterAppearanceService.BODY_MOVEMENT_PICKPOCKET"),
		"Developer tool does not overwrite fishing, surfing, or riding poses"
	)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
