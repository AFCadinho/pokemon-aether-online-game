extends SceneTree

const BATTLE_PATH := "res://scripts/battle/battle.gd"
const RENDERER_PATH := "res://scripts/battle/battle_event_renderer.gd"
const ROUTER_PATH := "res://scripts/battle/battle_animation_router.gd"
const SPRITE_BOX_PATH := "res://scripts/battle/battle_ui/sprite_box.gd"
const CATALOG_PATH := "res://data/battle_move_animations.json"

var failed := false


func _init() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_PATH)
	var renderer_source := FileAccess.get_file_as_string(RENDERER_PATH)
	var router_source := FileAccess.get_file_as_string(ROUTER_PATH)
	var sprite_box_source := FileAccess.get_file_as_string(SPRITE_BOX_PATH)
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))

	_check_contains(battle_source, "await _apply_substitute_presentation_event(event_data)", "Substitute lifecycle follows pokemonEffect events")
	_check_contains(battle_source, '"substitute":\n\t\t\treturn "substitute"', "Substitute is tracked as a volatile condition")
	_check_contains(battle_source, "animation_router.clear_substitute_for_ident(substitute_switch_ident)", "switches clear the persistent Substitute")
	_check_contains(renderer_source, "reveal_pokemon_from_substitute_for_move(attack_actor_ident)", "the Pokemon is revealed before its attack")
	_check_contains(renderer_source, "restore_substitute_after_move(attack_actor_ident)", "the Substitute returns after the move animation")
	_check_contains(router_source, "func clear_all_substitutes() -> void:", "battle resets can clear both Substitute sprites")
	_check_contains(sprite_box_source, "func play_substitute_damage_tween() -> void:", "the Substitute receives its own damage feedback")
	_check_contains(sprite_box_source, "SUBSTITUTE_BACK_REGION if current_single_side == \"back\" else SUBSTITUTE_FRONT_REGION", "each side uses the correct doll facing")
	_check_contains(sprite_box_source, "get_single_battle_anchor_in_node(single_sprite_slot)", "the Substitute stands on the visible Pokemon battle anchor")
	_check_form_changes_preserve_substitute(sprite_box_source)
	_check_catalog(catalog_value)

	quit(1 if failed else 0)


func _check_form_changes_preserve_substitute(sprite_box_source: String) -> void:
	var function_start := sprite_box_source.find("func set_single_pokemon_species")
	var function_end := sprite_box_source.find("\nfunc ", function_start + 1)
	var function_source := sprite_box_source.substr(function_start, function_end - function_start)
	_check_equal(function_start >= 0, true, "Pokemon sprite replacement function exists")
	_check_equal(function_source.contains("clear_substitute_immediately()"), false, "form changes do not clear Substitute")
	_check_equal(function_source.contains("_sync_substitute_idle_pose()"), true, "form changes reposition the persistent Substitute")


func _check_catalog(catalog_value: Variant) -> void:
	if not catalog_value is Dictionary:
		_fail("Substitute catalog is valid JSON")
		return
	var moves_value: Variant = (catalog_value as Dictionary).get("moves", {})
	if not moves_value is Dictionary or not (moves_value as Dictionary).has("substitute"):
		_fail("Substitute exists in the move animation catalog")
		return
	var config_value: Variant = (moves_value as Dictionary).get("substitute", {})
	if not config_value is Dictionary:
		_fail("Substitute catalog entry is a dictionary")
		return
	var config := config_value as Dictionary
	_check_equal(str(config.get("sheet_path", "")), "res://assets/battles/animations/substitute/PRAS- Substitute.png", "Substitute uses the imported source sheet")
	_check_equal(int(config.get("pattern_override", -1)), 1, "player Substitute uses the back-facing cell")
	_check_equal(int(config.get("reverse_pattern_override", -1)), 0, "opponent Substitute uses the front-facing cell")


func _check_contains(source: String, needle: String, label: String) -> void:
	if source.contains(needle):
		return
	_fail("%s: expected source contract '%s'" % [label, needle])


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _fail(message: String) -> void:
	failed = true
	push_error(message)
