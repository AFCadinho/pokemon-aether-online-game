extends SceneTree

const RENDERER_PATH := "res://scripts/battle/battle_event_renderer.gd"

var failed := false


func _init() -> void:
	_check_faint_hp_update_is_before_faint_animation()
	_check_stat_particles_and_sprite_response_share_one_presentation()
	_check_heal_particles_and_sprite_response_share_one_presentation()
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


func _check_stat_particles_and_sprite_response_share_one_presentation() -> void:
	var source := FileAccess.get_file_as_string(RENDERER_PATH)
	var defer_index := source.find("var defer_stat_change_effect := (")
	var presentation_index := source.find("await animation_router.play_stat_change_presentation_for_target(")

	_check_equal(defer_index >= 0, true, "stat-change effect is deferred from generic effect playback")
	_check_equal(presentation_index >= 0, true, "stat-change particles and sprite response use one presentation path")
	_check_equal(
		defer_index < presentation_index,
		true,
		"stat-change effect is deferred before the combined presentation starts"
	)


func _check_heal_particles_and_sprite_response_share_one_presentation() -> void:
	var source := FileAccess.get_file_as_string(RENDERER_PATH)
	var heal_block_index := source.find("if heal_target_ident != \"\":")
	var wish_effect_index := source.find("await animation_router.play_effect_animation(effect_animation_key, effect_animation_target_ident)", heal_block_index)
	var combined_index := source.find("await animation_router.play_heal_presentation_for_target(", heal_block_index)

	_check_equal(heal_block_index >= 0, true, "heal block exists")
	_check_equal(combined_index >= 0, true, "healing particles and sprite response use one presentation path")
	_check_equal(wish_effect_index >= 0, true, "Wish fulfillment retains its dedicated first effect")
	_check_equal(wish_effect_index < combined_index, true, "Wish fulfillment plays before the combined normal heal presentation")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
