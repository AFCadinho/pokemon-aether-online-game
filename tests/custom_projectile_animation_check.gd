extends SceneTree

const CATALOG_PATH := "res://data/battle_move_animations.json"
const ANIMATION_PLAYER_PATH := "res://scripts/battle/animations/move_animation_player.gd"
const ROUTER_PATH := "res://scripts/battle/battle_animation_router.gd"

var failed := false


func _init() -> void:
	var catalog := JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) as Dictionary
	var moves := catalog.get("moves", catalog) as Dictionary
	_check_custom_move(moves, "watergun", "water_splash", "Water Gun")
	_check_custom_move(moves, "dragonbreath", "dragon_breath", "Dragon Breath")

	var animation_player_source := FileAccess.get_file_as_string(ANIMATION_PLAYER_PATH)
	var router_source := FileAccess.get_file_as_string(ROUTER_PATH)
	_check(animation_player_source.contains("func _draw_dragon_breath_visual()"), "Dragon Breath has a custom renderer")
	_check(router_source.contains("animation_node.dragon_breath_config"), "Dragon Breath is wired into the animation router")
	quit(1 if failed else 0)


func _check_custom_move(moves: Dictionary, move_id: String, config_id: String, label: String) -> void:
	var move := moves.get(move_id, {}) as Dictionary
	_check(not move.is_empty(), "%s exists in the move catalog" % label)
	_check(not bool(move.get("show_sheet_sprites", true)), "%s hides the imported placeholder sheet" % label)
	_check(str(move.get("sheet_path", "")) == "", "%s is procedural-only" % label)
	var custom_config := move.get(config_id, {}) as Dictionary
	_check(bool(custom_config.get("enabled", false)), "%s enables its custom renderer" % label)
	var path := custom_config.get("path", []) as Array
	_check(path.size() >= 4, "%s defines a complete source-to-target path" % label)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
