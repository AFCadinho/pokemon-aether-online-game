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
	_check_contains(router_source, '"field", "field_hazard", "screen":', "battlefield-wide animations remain globally anchored")
	_check_contains(router_source, '"status_buff":\n\t\t\treturn actor_id', "self-buff animations follow their actor")
	_check_contains(router_source, 'config.get("static_visual_anchor", "")', "catalog entries can override the default visual binding")
	_check_contains(player_source, "@export var sheet_visual_offset: Vector2 = Vector2.ZERO", "sheet visual offset is explicit and defaults to no movement")
	_check_contains(player_source, "_battlefield_position(sheet_position) + sheet_visual_offset", "sheet correction is applied after battlefield mirroring")

	quit(1 if failed else 0)


func _check_contains(source: String, needle: String, label: String) -> void:
	if source.contains(needle):
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s: expected source contract '%s'" % [label, needle])
