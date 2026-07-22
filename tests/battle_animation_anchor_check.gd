extends SceneTree

const ROUTER_PATH := "res://scripts/battle/battle_animation_router.gd"
const PLAYER_PATH := "res://scripts/battle/animations/move_animation_player.gd"

var failed := false


func _init() -> void:
	var router_source := FileAccess.get_file_as_string(ROUTER_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)

	_check_contains(router_source, "_apply_move_sheet_anchor(animation_node, move_actor_ident, move_target_ident, overlay, config)", "overlay animations receive the live sheet anchor")
	_check_contains(router_source, "_apply_move_sheet_anchor(animation_node, move_actor_ident, move_target_ident, parent_node, config)", "fallback animations receive the live sheet anchor")
	_check_contains(router_source, "dynamic_anchor_source - fixed_anchor", "fixed sheet coordinates are corrected from the current sprite anchor")
	_check_contains(router_source, "if animation_node == null or not animation_node.show_sheet_sprites:", "procedural-only animations cannot receive a duplicate sheet offset")
	_check_contains(router_source, "display_position_to_battlefield_source(source_position)", "projectile anchors are converted before mirrored battlefield rendering")
	_check_contains(router_source, '"field", "field_hazard", "screen":', "battlefield-wide animations remain globally anchored")
	_check_contains(router_source, '"status_buff":\n\t\t\treturn actor_id', "self-buff animations follow their actor")
	_check_contains(router_source, 'config.get("static_visual_anchor", "")', "catalog entries can override the default visual binding")
	_check_contains(router_source, "_play_move_target_hit_flash_if_needed(config, move_target_ident, animation_options)", "moves can flash their target at impact timing")
	_check_contains(router_source, "func _should_suppress_target_feedback_for_miss", "misses can suppress hit-only target feedback")
	_check_contains(router_source, "animation_node.heat_wave_config = _with_projectile_endpoint_anchors(", "heat waves receive live attacker and target anchors")
	_check_contains(router_source, "animation_node.draco_meteor_config = _with_target_effect_anchor(animation_node.draco_meteor_config, target_anchor)", "Draco Meteor rain follows the live target anchor")
	_check_contains(router_source, "animation_node.focus_aura_config = (config.get(\"focus_aura\", {}) as Dictionary).duplicate(true)", "focus auras are configured through the move catalog")
	_check_contains(router_source, "animation_node.stat_change_config = (config.get(\"stat_change\", {}) as Dictionary).duplicate(true)", "stat-change energy is configured through the effect catalog")
	_check_contains(router_source, "func _create_dark_pulse_underlay_if_needed(", "Dark Pulse can split its floor and orbit particles around the actor sprite")
	_check_order(router_source, "_move_timing_background_below_sprites(animation_node, parent_node, config)", "var underlay_overlay := _create_dark_pulse_underlay_if_needed(", "Dark Pulse floor ring is layered above its opaque background")
	_check_contains(player_source, "@export var sheet_visual_offset: Vector2 = Vector2.ZERO", "sheet visual offset is explicit and defaults to no movement")
	_check_contains(player_source, "_battlefield_position(sheet_position) + sheet_visual_offset", "sheet correction is applied after battlefield mirroring")
	_check_contains(player_source, "func display_position_to_battlefield_source(position: Vector2) -> Vector2:", "mirrored animations can convert display anchors to source coordinates")
	_check_contains(player_source, "var steam_count: int = maxi(0, int(fire_stream_config.get(\"steam_count\", 0)))", "stream effects can add a steam impact without a separate sprite sheet")
	_check_contains(player_source, "if cell_pattern < sheet_pattern_min or cell_pattern > sheet_pattern_max:", "moves can show only the relevant portion of an imported sheet")
	_check_contains(player_source, "reverse_pattern_override if reverse_battlefield", "mirrored animations can select an opponent-facing sheet pattern")
	_check_contains(player_source, "if index < sheet_visible_start_frame:", "sheet impact effects can wait until their projectile arrives")
	_check_contains(player_source, "func _draw_heat_wave_visual() -> void:", "moves can render a configurable multi-lane heat wave")
	_check_contains(player_source, "func _draw_draco_meteor_visual() -> void:", "Draco Meteor can render staggered target-bound meteor rain")
	_check_contains(player_source, "func _draw_draco_meteor_impact(", "Draco Meteor stops each projectile in an impact burst")
	_check_contains(player_source, "func _draw_focus_aura_visual() -> void:", "status moves can render a reusable multicolor focus aura")
	_check_contains(player_source, "func _draw_stat_change_visual() -> void:", "stat changes can render directional energy particles")
	_check_contains(player_source, 'var draw_layer := str(dark_pulse_config.get("draw_layer", "all"))', "Dark Pulse supports separate underlay and foreground passes")

	quit(1 if failed else 0)


func _check_contains(source: String, needle: String, label: String) -> void:
	if source.contains(needle):
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s: expected source contract '%s'" % [label, needle])


func _check_order(source: String, first: String, second: String, label: String) -> void:
	var first_index := source.find(first)
	var second_index := source.find(second)
	if first_index >= 0 and second_index > first_index:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s: expected '%s' before '%s'" % [label, first, second])
