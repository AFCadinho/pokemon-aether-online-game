extends SceneTree

const ROUTER_PATH := "res://scripts/battle/battle_animation_router.gd"
const PLAYER_PATH := "res://scripts/battle/animations/move_animation_player.gd"
const SPRITE_BOX_PATH := "res://scripts/battle/battle_ui/sprite_box.gd"
const CATALOG_PATH := "res://data/battle_move_animations.json"

var failed := false


func _init() -> void:
	var router_source := FileAccess.get_file_as_string(ROUTER_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var sprite_box_source := FileAccess.get_file_as_string(SPRITE_BOX_PATH)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) as Dictionary
	var moves: Dictionary = catalog.get("moves", {}) as Dictionary

	_check_contains(router_source, "_apply_move_sheet_anchor(animation_node, move_actor_ident, move_target_ident, overlay, config)", "overlay animations receive the live sheet anchor")
	_check_contains(router_source, "_apply_move_sheet_anchor(animation_node, move_actor_ident, move_target_ident, parent_node, config)", "fallback animations receive the live sheet anchor")
	_check_contains(router_source, "var source_anchor_player_id := anchor_player_id", "sheet anchors resolve their canonical source side")
	_check_contains(router_source, "animation_node.battlefield_offset_to_display(source_anchor_offset)", "sheet anchor corrections return to display coordinates after mirroring")
	_check_contains(router_source, "if animation_node == null or not animation_node.show_sheet_sprites:", "procedural-only animations cannot receive a duplicate sheet offset")
	_check_contains(router_source, "config.get(\"sheet_anchor_point\", \"center\")", "imported sheets can choose a live sprite anchor")
	_check_contains(router_source, "get_single_battle_anchor_in_node", "grounded sheet impacts can use a Pokemon's feet")
	_check_contains(router_source, "display_position_to_battlefield_source(source_position)", "projectile anchors are converted before mirrored battlefield rendering")
	_check_contains(router_source, "_reverse_battlefield_position(actor_anchor) + actor_offset", "explicit opponent projectile paths restore live actor anchors to display space")
	_check_contains(router_source, "config.get(\"projectile_actor_anchor_point\", \"center\")", "projectiles can launch from a Pokemon's feet")
	_check_contains(router_source, "_with_court_change_anchors(", "Court Change follows both live foot anchors")
	_check_contains(router_source, "var source_actor_offset := -actor_offset if reverse_battlefield else actor_offset", "projectile offsets remain screen-relative when the opponent attacks")
	_check_contains(router_source, '"field", "field_hazard", "screen":', "battlefield-wide animations remain globally anchored")
	_check_contains(router_source, '"status_buff":\n\t\t\treturn actor_id', "self-buff animations follow their actor")
	_check_contains(router_source, 'config.get("static_visual_anchor", "")', "catalog entries can override the default visual binding")
	_check_contains(router_source, "_play_move_target_hit_flash_if_needed(config, move_target_ident, animation_options)", "moves can flash their target at impact timing")
	_check_contains(router_source, "func _should_suppress_target_feedback_for_miss", "misses can suppress hit-only target feedback")
	_check_contains(router_source, "animation_node.heat_wave_config = _with_projectile_endpoint_anchors(", "heat waves receive live attacker and target anchors")
	_check_contains(router_source, "animation_node.psychic_shards_config = _with_projectile_endpoint_anchors(", "psychic shard volleys receive live attacker and target anchors")
	_check_contains(router_source, "animation_node.draco_meteor_config = _with_target_effect_anchor(", "Draco Meteor rain follows the live target anchor")
	_check_contains(router_source, "animation_node.celestial_charge_config = _with_self_effect_anchor(", "Moonblast charge effects follow the live attacker anchor")
	_check_contains(router_source, "animation_node.explosion_burst_config = _with_projectile_endpoint_anchors(", "explosion waves travel between the live user and target anchors")
	_check_contains(router_source, "actor_anchor += -center_offset if reverse_battlefield else center_offset", "self-effect offsets remain screen-relative for opposing users")
	_check_contains(router_source, "target_anchor += -center_offset if reverse_battlefield else center_offset", "target-effect offsets remain screen-relative for opposing users")
	_check_contains(router_source, "animation_node.focus_aura_config = (config.get(\"focus_aura\", {}) as Dictionary).duplicate(true)", "focus auras are configured through the move catalog")
	_check_contains(router_source, "animation_node.stat_change_config = (config.get(\"stat_change\", {}) as Dictionary).duplicate(true)", "stat-change energy is configured through the effect catalog")
	_check_contains(router_source, "animation_node.heal_energy_config = (config.get(\"heal_energy\", {}) as Dictionary).duplicate(true)", "healing energy is configured through the effect catalog")
	_check_contains(router_source, "func _create_dark_pulse_underlay_if_needed(", "Dark Pulse can split its floor and orbit particles around the actor sprite")
	_check_order(router_source, "_move_timing_background_below_sprites(animation_node, parent_node, config)", "var underlay_overlay := _create_dark_pulse_underlay_if_needed(", "Dark Pulse floor ring is layered above its opaque background")
	_check_contains(player_source, "@export var sheet_visual_offset: Vector2 = Vector2.ZERO", "sheet visual offset is explicit and defaults to no movement")
	_check_contains(player_source, 'if sheet_texture == null and sheet_path != "":', "procedural animations never ask Godot to load an empty sheet path")
	_check_contains(player_source, 'if stream == null and sound_path != "":', "animations never ask Godot to load an empty sound path")
	_check_contains(player_source, "func _fit_timing_background_to_canvas() -> void:", "short timing backgrounds can cover the complete animation canvas")
	_check_contains(router_source, "config.get(\"timing_background_fill_canvas\", false)", "moves can opt into complete timing background coverage")
	_check_contains(player_source, "func _get_sheet_frame_offset", "sheet effects can apply an offset to only selected frames")
	_check_contains(player_source, "_battlefield_position(sheet_position) + sheet_visual_offset", "sheet correction is applied after battlefield mirroring")
	_check_contains(player_source, "func display_position_to_battlefield_source(position: Vector2) -> Vector2:", "mirrored animations can convert display anchors to source coordinates")
	_check_contains(player_source, "if reverse_battlefield_vertical else position.y", "animations can preserve their vertical travel when mirrored")
	_check_contains(player_source, "func battlefield_offset_to_display(offset: Vector2) -> Vector2:", "live sheet anchors respect horizontal-only battlefield mirroring")
	_check_contains(router_source, 'config.get("reverse_battlefield_vertical", true)', "moves can opt out of vertical battlefield mirroring")
	_check_contains(player_source, "if reverse_battlefield and mirror_sheet_sprites_on_reverse:", "directional sheet sprites can face the mirrored target")
	_check_contains(router_source, 'config.get("mirror_sheet_sprites_on_reverse", false)', "moves can opt into directional sprite mirroring")
	_check_contains(player_source, "var steam_count: int = maxi(0, int(fire_stream_config.get(\"steam_count\", 0)))", "stream effects can add a steam impact without a separate sprite sheet")
	_check_contains(player_source, "if cell_pattern < sheet_pattern_min or cell_pattern > sheet_pattern_max:", "moves can show only the relevant portion of an imported sheet")
	_check_contains(player_source, "reverse_pattern_override if reverse_battlefield", "mirrored animations can select an opponent-facing sheet pattern")
	_check_contains(player_source, "if index < sheet_visible_start_frame:", "sheet impact effects can wait until their projectile arrives")
	_check_contains(player_source, "func _draw_heat_wave_visual() -> void:", "moves can render a configurable multi-lane heat wave")
	_check_contains(player_source, "func _draw_energy_blast_launch_ring", "projectiles can leave a configurable launch ring behind")
	_check_contains(player_source, "func _draw_psychic_shards_visual() -> void:", "Psyshock can render a custom psychic shard volley")
	_check_contains(player_source, "func _draw_explosion_burst_visual() -> void:", "Explosion can render a synchronized custom blast")
	_check_contains(player_source, "func _draw_court_change_visual", "Court Change can render a configurable battlefield swap")
	_check_contains(player_source, "func _draw_sound_wave_visual", "sound moves can send layered rings towards the target")
	_check_contains(player_source, "func _draw_leaf_rush_visual", "grass moves can send a configurable leaf rush towards the target")
	_check_contains(player_source, "func _draw_draco_meteor_visual() -> void:", "Draco Meteor can render staggered target-bound meteor rain")
	_check_contains(player_source, "var approach_direction := -1.0 if reverse_battlefield else 1.0", "opposing Draco Meteors approach from the opponent's side")
	_check_contains(player_source, "func _draw_draco_meteor_impact(", "Draco Meteor stops each projectile in an impact burst")
	_check_contains(player_source, "func _draw_focus_aura_visual() -> void:", "status moves can render a reusable multicolor focus aura")
	_check_contains(player_source, "func _draw_stat_change_visual() -> void:", "stat changes can render directional energy particles")
	_check_contains(player_source, "func _draw_heal_energy_visual() -> void:", "recovery events can render compact rising healing energy")
	_check_contains(player_source, 'var draw_layer := str(dark_pulse_config.get("draw_layer", "all"))', "Dark Pulse supports separate underlay and foreground passes")
	_check_contains(sprite_box_source, "motion_direction: Vector2 = Vector2.ONE", "move actor motion supports two-axis battlefield direction")
	_check_contains(sprite_box_source, "offset *= motion_direction", "opposing move actors invert both travel axes")
	_check_contains(router_source, "config.get(\"actor_motion_mirror_vertical\", true)", "jumping moves can preserve their vertical arc for opposing users")
	_check_equal(bool((moves.get("knockoff", {}) as Dictionary).get("show_sheet_sprites", false)), true, "Knock Off renders its imported impact frames")
	_check_equal(bool((moves.get("knockoff", {}) as Dictionary).get("reverse_battlefield_vertical", true)), false, "opposing Knock Off preserves its top-to-bottom travel")
	var wish_config: Dictionary = moves.get("wish", {}) as Dictionary
	_check_equal(str(wish_config.get("static_visual_anchor", "")), "battlefield", "Wish keeps its original battlefield position")
	_check_equal(bool(wish_config.get("reverse_battlefield_vertical", true)), false, "opposing Wish preserves its top-to-bottom travel")
	_check_equal(bool((moves.get("taunt", {}) as Dictionary).get("mirror_sheet_sprites_on_reverse", false)), true, "opposing Taunt points back toward the player")
	_check_equal(int(((moves.get("taunt", {}) as Dictionary).get("sprite_position_offset", []) as Array)[1]), -28, "Taunt moves symmetrically toward the battlefield center")
	_check_move_animation_assets(moves, "gigaimpact", true, true, "Giga Impact")
	_check_move_animation_assets(moves, "psyshock", true, false, "Psyshock")
	_check_move_animation_assets(moves, "explosion", true, true, "Explosion")
	_check_move_animation_assets(moves, "watershuriken", true, false, "Water Shuriken")
	_check_equal(str((moves.get("explosion", {}) as Dictionary).get("static_visual_anchor", "")), "actor", "Explosion smoke follows its user")
	_check_equal(bool(((moves.get("gigaimpact", {}) as Dictionary).get("actor_motion", {}) as Dictionary).get("enabled", false)), true, "Giga Impact moves its user into the hit")
	_check_equal(bool(((moves.get("psyshock", {}) as Dictionary).get("psychic_shards", {}) as Dictionary).get("enabled", false)), true, "Psyshock uses its custom psychic shard volley")
	_check_equal(bool((moves.get("psyshock", {}) as Dictionary).get("show_sheet_sprites", true)), false, "Psyshock hides the imported placeholder sprites")
	_check_equal(bool(((moves.get("explosion", {}) as Dictionary).get("explosion_burst", {}) as Dictionary).get("enabled", false)), true, "Explosion uses its synchronized custom blast")
	_check_equal(bool((moves.get("explosion", {}) as Dictionary).get("show_sheet_sprites", true)), false, "Explosion hides the imported smoke-only frames")
	var explosion_path: Array = (((moves.get("explosion", {}) as Dictionary).get("explosion_burst", {}) as Dictionary).get("path", []) as Array)
	_check_equal(explosion_path.size(), 2, "Explosion defines a user-to-target blast path")
	_check_equal(bool(((moves.get("explosion", {}) as Dictionary).get("target_shake", {}) as Dictionary).get("enabled", false)), true, "Explosion shakes the target when its blast front arrives")
	var water_shuriken_config: Dictionary = moves.get("watershuriken", {}) as Dictionary
	var water_shuriken_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(water_shuriken_config.get("data_path", "")))) as Dictionary
	var water_shuriken_frames: Array = water_shuriken_data.get("frames", []) as Array
	var water_shuriken_start_cell: Dictionary = (water_shuriken_frames[0] as Array)[2] as Dictionary
	var water_shuriken_impact_cell: Dictionary = (water_shuriken_frames[9] as Array)[2] as Dictionary
	_check_equal(int(water_shuriken_start_cell.get("y", 999)), 203, "Water Shuriken starts beside its user instead of below it")
	_check_equal(int(water_shuriken_impact_cell.get("y", 999)), 120, "Water Shuriken retains its tuned impact height")

	quit(1 if failed else 0)


func _check_move_animation_assets(moves: Dictionary, move_key: String, expect_sheet: bool, expect_background: bool, label: String) -> void:
	var config: Dictionary = moves.get(move_key, {}) as Dictionary
	_check_equal(FileAccess.file_exists(str(config.get("data_path", ""))), true, "%s has animation data" % label)
	if expect_sheet:
		_check_equal(FileAccess.file_exists(str(config.get("sheet_path", ""))), true, "%s has a sprite sheet" % label)
	if expect_background:
		_check_equal(FileAccess.file_exists(str(config.get("background_path", ""))), true, "%s has a background" % label)
	var sounds: Dictionary = config.get("sound_paths", {}) as Dictionary
	_check_equal(sounds.is_empty(), false, "%s has sound effects" % label)
	for sound_path: Variant in sounds.values():
		_check_equal(FileAccess.file_exists(str(sound_path)), true, "%s sound effect exists" % label)


func _check_contains(source: String, needle: String, label: String) -> void:
	if source.contains(needle):
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s: expected source contract '%s'" % [label, needle])


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])


func _check_order(source: String, first: String, second: String, label: String) -> void:
	var first_index := source.find(first)
	var second_index := source.find(second)
	if first_index >= 0 and second_index > first_index:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s: expected '%s' before '%s'" % [label, first, second])
