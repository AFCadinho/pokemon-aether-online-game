extends SceneTree

const RENDERER_PATH := "res://scripts/battle/battle_event_renderer.gd"

var failed := false


func _init() -> void:
	_check_faint_hp_update_is_before_faint_animation()
	quit(1 if failed else 0)


func _check_faint_hp_update_is_before_faint_animation() -> void:
	var source := FileAccess.get_file_as_string(RENDERER_PATH)
	var faint_block_index := source.find("if faint_target_ident != \"\":")
	var hp_update_index := source.find("_set_active_hud_hp_from_event(faint_target_ident, event_data, false)", faint_block_index)
	var animation_index := source.find("await animation_router.play_faint_tween_for_target(faint_target_ident)", faint_block_index)

	_check_equal(faint_block_index >= 0, true, "faint block exists")
	_check_equal(hp_update_index >= 0, true, "faint block sets final HP")
	_check_equal(animation_index >= 0, true, "faint block plays faint animation")
	_check_equal(
		hp_update_index < animation_index,
		true,
		"faint HP update is before faint animation"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
