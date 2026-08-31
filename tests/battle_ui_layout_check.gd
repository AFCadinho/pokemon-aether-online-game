extends SceneTree

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BATTLE_HUD_SCENE_PATH := "res://scenes/battle/pokemon_hud_panel.tscn"
const WORLD_SCENE_PATH := "res://scenes/world.tscn"
const WORLD_SCRIPT_PATH := "res://scripts/world/world.gd"
const UI_OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"
const PartyGridScript := preload("res://scripts/battle/battle_ui/party_grid.gd")
const StageViewportScript := preload("res://scripts/battle/battle_ui/battle_stage_viewport.gd")
const STAGE_DESIGN_SIZE := Vector2(1152.0, 648.0)

var failed := false


func _init() -> void:
	_check_scene_structure()
	_check_battle_scene_script_contract()
	_check_world_battle_host()
	_check_hp_hud_structure()
	_check_mimikyu_disguise_indicator_contract()
	_check_kingambit_fallen_indicator_contract()
	_check_type_change_indicator_contract()
	_check_mimikyu_back_sprite_grounding_contract()
	await _check_stage_scaling()
	await _check_party_rail_interaction()
	_check_battle_selection_policy_contract()
	quit(1 if failed else 0)


func _check_battle_scene_script_contract() -> void:
	var scene_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	_check_contains(
		scene_source,
		"path=\"res://scripts/battle/battle.gd\"",
		"battle scene root keeps the battle controller script attached"
	)
	_check_contains(
		battle_source,
		"func setup_pvp_battle_from_response(",
		"battle controller exposes the PvP setup contract"
	)
	_check_contains(
		world_source,
		"not battle_instance.has_method(\"setup_pvp_battle_from_response\")",
		"world validates the instantiated battle root before calling its setup contract"
	)
	_check_contains(
		world_source,
		"ResourceLoader.CACHE_MODE_REPLACE",
		"world refreshes a stale battle scene cache after a detached-script instance"
	)


func _check_scene_structure() -> void:
	var scene_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	_check_contains(scene_source, "[node name=\"BattleLogRail\"", "left battle-log rail exists")
	_check_contains(scene_source, "[node name=\"CenterColumn\"", "central battle column exists")
	_check_contains(scene_source, "[node name=\"StagePartyOverlay\"", "party teams share a battlefield overlay")
	_check_contains(scene_source, "[node name=\"BattleStageViewport\"", "scaled stage viewport exists")
	_check_contains(scene_source, "[node name=\"BattleStage\"", "fixed-design battle stage exists")
	_check_contains(scene_source, "[node name=\"ActionsDock\"", "horizontal actions dock exists")
	_check_contains(scene_source, "[node name=\"BattleBackdrop\" type=\"Panel\"", "bounded battle window uses a styled shell")
	_check_contains(scene_source, "[sub_resource type=\"StyleBoxFlat\" id=\"StyleBoxFlat_battle_shell\"]", "battle shell style is defined")
	_check_contains(scene_source, "theme_override_colors/font_color = Color(1, 0.36078432, 0.6117647, 1)", "opponent party uses the pink side accent")
	_check_contains(scene_source, "theme_override_colors/font_color = Color(0.38431373, 0.84313726, 1, 1)", "player party and controls use the normal UI cyan accent")
	_check_contains(scene_source, "[node name=\"BattleLogPanel\" parent=\"HBoxContainer/BattleLogRail\"", "battle log is inside left rail")
	_check_contains(scene_source, "[node name=\"OpponentPartyGrid\" type=\"GridContainer\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage/StagePartyOverlay/OpponentStagePartyRail", "opponent party grid is beside its battlefield sprite")
	_check_contains(scene_source, "[node name=\"PlayerStagePartyGrid\" type=\"GridContainer\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage/StagePartyOverlay/PlayerStagePartyRail", "visual player party grid is beside its battlefield sprite")
	var player_stage_grid_start := scene_source.find("[node name=\"PlayerStagePartyGrid\"")
	var player_stage_grid_end := scene_source.find("\n\n", player_stage_grid_start)
	var player_stage_grid_block := scene_source.substr(player_stage_grid_start, player_stage_grid_end - player_stage_grid_start)
	var opponent_grid_start := scene_source.find("[node name=\"OpponentPartyGrid\"")
	var opponent_grid_end := scene_source.find("\n\n", opponent_grid_start)
	var opponent_grid_block := scene_source.substr(opponent_grid_start, opponent_grid_end - opponent_grid_start)
	_check_true(not player_stage_grid_block.contains("columns = 2"), "player stage party grid remains a single vertical column")
	_check_true(not opponent_grid_block.contains("columns = 2"), "opponent stage party grid remains a single vertical column")
	var player_rail_start := scene_source.find("[node name=\"PlayerStagePartyRail\"")
	var player_rail_end := scene_source.find("\n\n", player_rail_start)
	var player_rail_block := scene_source.substr(player_rail_start, player_rail_end - player_rail_start)
	var opponent_rail_start := scene_source.find("[node name=\"OpponentStagePartyRail\"")
	var opponent_rail_end := scene_source.find("\n\n", opponent_rail_start)
	var opponent_rail_block := scene_source.substr(opponent_rail_start, opponent_rail_end - opponent_rail_start)
	_check_contains(player_rail_block, "offset_left = 18.0", "player preview rail keeps its battlefield edge")
	_check_contains(player_rail_block, "offset_right = 74.0", "player preview rail wraps its 52px slot without trailing space")
	_check_contains(opponent_rail_block, "offset_left = 1078.0", "opponent preview rail mirrors the compact width")
	_check_contains(opponent_rail_block, "offset_right = 1134.0", "opponent preview rail keeps its battlefield edge")
	_check_true(scene_source.count("icon_only_mode = true") == 12, "both six-slot party groups use the icon-only stage variant")
	_check_contains(scene_source, "[node name=\"PlayerPartyGrid\" type=\"GridContainer\" parent=\"HBoxContainer/CenterColumn/ActionsDock", "interactive player party row lives below the moves")
	_check_contains(scene_source, "[node name=\"SpectatorActionPanel\" type=\"PanelContainer\" parent=\"HBoxContainer/CenterColumn/ActionsDock", "spectator controls replace the interactive party row with a styled dashboard")
	_check_contains(scene_source, "[node name=\"SpectatorModeLabel\" type=\"Label\"", "spectator dashboard identifies the read-only viewing mode")
	_check_contains(scene_source, "theme_override_styles/panel = SubResource(\"StyleBoxFlat_spectator_card\")", "spectator dashboard has a distinct card surface")
	_check_contains(scene_source, "custom_minimum_size = Vector2(0, 72)", "spectator dashboard has comfortable vertical spacing")
	_check_contains(scene_source, "text = \"battle.spectator.perspective_preview\"", "spectator dashboard describes the selected player perspective through localization")
	_check_contains(scene_source, "[node name=\"SpectatorSwitchSidesButton\" type=\"Button\"", "spectator controls expose side switching")
	_check_contains(scene_source, "[node name=\"SpectatorLeaveButton\" type=\"Button\"", "spectator controls expose a safe leave action")
	var actions_dock_start := scene_source.find("[node name=\"ActionsDock\"")
	_check_true(player_stage_grid_start < actions_dock_start, "party dock remains ordered below the battlefield")
	_check_true(not scene_source.contains("SwitchPartyLabel"), "party row does not use a floating switch pill")
	_check_contains(scene_source, "columns = 6", "all six switch slots share one horizontal row")
	_check_true(scene_source.count("compact_mode = true") == 6, "switch row uses six compact slots with HP bars")
	_check_contains(scene_source, "[node name=\"CurrentActionPanel\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage\"", "message bar is inside the scaled battle stage")
	_check_contains(scene_source, "offset_top = -96.0", "message bar sits compactly below the raised player platform")
	var player_hud_start := scene_source.find("[node name=\"PlayerHudPanel\"")
	var player_hud_end := scene_source.find("\n\n", player_hud_start)
	var player_hud_block := scene_source.substr(player_hud_start, player_hud_end - player_hud_start)
	_check_contains(player_hud_block, "offset_left = 148.0", "player HP HUD moves inward with its Pokemon")
	_check_contains(player_hud_block, "offset_right = 460.0", "player HP HUD preserves its width after moving inward")
	_check_contains(player_hud_block, "offset_top = 164.0", "player HP HUD follows the raised sprite box")
	_check_contains(player_hud_block, "offset_bottom = 246.0", "player HP HUD clears the raised sprite box with a small gap")
	var enemy_hud_start := scene_source.find("[node name=\"EnemyHudPanel\"")
	var enemy_hud_end := scene_source.find("\n\n", enemy_hud_start)
	var enemy_hud_block := scene_source.substr(enemy_hud_start, enemy_hud_end - enemy_hud_start)
	_check_contains(enemy_hud_block, "offset_left = -460.0", "enemy HP HUD moves inward with its Pokemon")
	_check_contains(enemy_hud_block, "offset_right = -148.0", "enemy HP HUD preserves its width after moving inward")
	_check_contains(enemy_hud_block, "offset_top = 64.0", "enemy HP HUD sits higher to clear persistent stat badges")
	_check_contains(enemy_hud_block, "offset_bottom = 146.0", "enemy HP HUD keeps its pill dimensions after moving up")
	var sprite_box_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/sprite_box.gd")
	_check_contains(sprite_box_source, "func anchor_stat_stage_panel_below", "stat badges support a HUD-relative anchor")
	_check_contains(sprite_box_source, '"mimikyu-disguised": ["mimikyu"]', "Mimikyu Disguised resolves to its battle-sheet asset before the HOME-icon fallback")
	_check_contains(sprite_box_source, '"pikachu-rock-star": ["pikachu-rockstar"]', "Pikachu Rock Star resolves to the existing Showdown battle-sheet directory")
	var battle_modifier_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check_contains(
		battle_modifier_source,
		'player_sprite_box.call("anchor_stat_stage_panel_below", player_hud_panel)',
		"battle anchors player stat badges below the player HUD"
	)
	_check_contains(
		battle_modifier_source,
		'enemy_sprite_box.call("anchor_stat_stage_panel_below", enemy_hud_panel)',
		"battle anchors enemy stat badges below the enemy HUD"
	)
	_check_contains(battle_modifier_source, '_add_volatile_condition_for_ident(ident_key, "air_balloon", event)', "Air Balloon reveal adds a persistent Pokemon indicator")
	_check_contains(battle_modifier_source, '_remove_volatile_condition_for_ident(ident_key, "air_balloon")', "Air Balloon end removes its Pokemon indicator")
	_check_contains(battle_modifier_source, '_t("battle.effect.air_balloon")', "Air Balloon indicator uses a localized readable label")
	var player_platform_start := scene_source.find("[node name=\"BattlePlatform\"")
	var player_platform_end := scene_source.find("\n\n", player_platform_start)
	var player_platform_block := scene_source.substr(player_platform_start, player_platform_end - player_platform_start)
	_check_contains(player_platform_block, "offset_left = 90.5", "player platform moves inward")
	_check_contains(player_platform_block, "offset_right = 690.5", "player platform preserves its width after moving inward")
	var enemy_platform_start := scene_source.find("[node name=\"BattlePlatform2\"")
	var enemy_platform_end := scene_source.find("\n\n", enemy_platform_start)
	var enemy_platform_block := scene_source.substr(enemy_platform_start, enemy_platform_end - enemy_platform_start)
	_check_contains(enemy_platform_block, "offset_left = 571.5", "enemy platform moves inward")
	_check_contains(enemy_platform_block, "offset_right = 1171.5", "enemy platform preserves its width after moving inward")
	_check_contains(enemy_platform_block, "offset_top = -496.0", "enemy platform moves down with its HUD")
	_check_contains(enemy_platform_block, "offset_bottom = -246.0", "enemy platform preserves its height")
	var enemy_sprite_start := scene_source.find("[node name=\"EnemySpriteBox\"")
	var enemy_sprite_end := scene_source.find("\n\n", enemy_sprite_start)
	var enemy_sprite_block := scene_source.substr(enemy_sprite_start, enemy_sprite_end - enemy_sprite_start)
	_check_contains(enemy_sprite_block, "offset_left = -557.5", "enemy Pokemon moves inward")
	_check_contains(enemy_sprite_block, "offset_right = -107.5", "enemy sprite box preserves its width after moving inward")
	_check_contains(enemy_sprite_block, "offset_top = -201.0", "enemy sprite moves down with its platform")
	_check_contains(enemy_sprite_block, "offset_bottom = 92.0", "enemy sprite box preserves its height")
	var player_sprite_start := scene_source.find("[node name=\"PlayerSpriteBox\"")
	var player_sprite_end := scene_source.find("\n\n", player_sprite_start)
	var player_sprite_block := scene_source.substr(player_sprite_start, player_sprite_end - player_sprite_start)
	_check_contains(player_sprite_block, "offset_left = 101.5", "player Pokemon moves inward")
	_check_contains(player_sprite_block, "offset_right = 551.5", "player sprite box preserves its width after moving inward")
	var enemy_preview_start := scene_source.find("[node name=\"EnemyTeamPreviewLayer\"")
	var enemy_preview_end := scene_source.find("\n\n", enemy_preview_start)
	var enemy_preview_block := scene_source.substr(enemy_preview_start, enemy_preview_end - enemy_preview_start)
	_check_contains(enemy_preview_block, "position = Vector2(850, 268)", "enemy Team Preview moves with the battle presentation")
	_check_contains(scene_source, "[node name=\"ActionsDock\" type=\"Panel\" parent=\"HBoxContainer/CenterColumn\"", "actions dock belongs to center column")
	_check_true(not scene_source.contains("[node name=\"FightButton\""), "retired Fight action is absent from the battle scene")
	_check_true(not scene_source.contains("[node name=\"PartyButton\""), "retired Party action is absent from the battle scene")
	var action_choices_source := FileAccess.get_file_as_string("res://scripts/battle/action_choices.gd")
	_check_true(not action_choices_source.contains("fight_button"), "retired Fight action has no controller binding")
	_check_true(not action_choices_source.contains("party_button"), "retired Party action has no controller binding")
	_check_contains(scene_source, "[node name=\"ActionChoices\" type=\"PanelContainer\" parent=\"HBoxContainer/BattleLogRail\"", "Bag and Run live below the battle log")
	_check_contains(scene_source, "[node name=\"MovesGrid\" type=\"GridContainer\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage\"", "moves live inside the scaled battlefield")
	_check_contains(scene_source, "columns = 2", "moves use a two-by-two battlefield grid")
	_check_contains(scene_source, "[node name=\"BagGrid\" type=\"MarginContainer\" parent=\"BattleDrawerLayer/BagDrawer/BagDrawerContent\"", "Bag uses separate drawer content")
	_check_contains(scene_source, "[node name=\"CalcPanel\" type=\"MarginContainer\" parent=\"BattleDrawerLayer/CalcDrawer/CalcDrawerContent\"", "Calc uses separate drawer content")
	_check_contains(scene_source, "[node name=\"CalcTimerDock\" parent=\"BattleDrawerLayer/CalcDrawer/CalcDrawerContent/CalcDrawerHeader/HeaderRow\" instance=ExtResource(\"9_pyfix\")]", "Calc keeps its dedicated timer dock in the workspace header")
	_check_contains(scene_source, "[node name=\"CalcTurnLabel\" type=\"Label\" parent=\"BattleDrawerLayer/CalcDrawer/CalcDrawerContent/CalcDrawerHeader/HeaderRow\"]", "Calc keeps the current turn visible in its header")
	_check_contains(scene_source, "[node name=\"CalcBattleLimitLabel\" type=\"Label\" parent=\"BattleDrawerLayer/CalcDrawer/CalcDrawerContent/CalcDrawerHeader/HeaderRow\"]", "Calc keeps the Clash hard limit visible in its header")
	_check_contains(scene_source, "vertical_scroll_mode = 0", "Calc removes the old full-workspace scrollbar")
	var calc_drawer_start := scene_source.find("[node name=\"CalcDrawer\"")
	var calc_drawer_end := scene_source.find("\n\n", calc_drawer_start)
	var calc_drawer_block := scene_source.substr(calc_drawer_start, calc_drawer_end - calc_drawer_start)
	_check_contains(calc_drawer_block, "offset_right = 680.0", "Calc drawer has a wider stable editor fallback size")
	_check_contains(scene_source, "[node name=\"BagDrawerCloseButton\" type=\"Button\"", "Bag drawer has a close button")
	var bag_drawer_start := scene_source.find("[node name=\"BagDrawer\"")
	var bag_drawer_end := scene_source.find("\n\n", bag_drawer_start)
	var bag_drawer_block := scene_source.substr(bag_drawer_start, bag_drawer_end - bag_drawer_start)
	_check_contains(bag_drawer_block, "offset_left = -230.0", "Bag drawer stays compact horizontally")
	_check_contains(bag_drawer_block, "offset_top = -330.0", "Bag drawer stays compact vertically")
	_check_contains(bag_drawer_block, "z_index = 6", "Bag drawer renders above battlefield move controls")
	var bag_grid_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/bag_grid.gd")
	_check_contains(bag_grid_source, "button.custom_minimum_size = Vector2(0, 50)", "battle capture items use compact full-width rows")
	_check_contains(scene_source, "[node name=\"CalcDrawerCloseButton\" type=\"Button\"", "Calc drawer has a close button")
	var battle_script_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var pokemon_info_hud_source := FileAccess.get_file_as_string("res://scenes/battle/pokemon_info_hud.tscn")
	_check_contains(pokemon_info_hud_source, "[node name=\"OwnedIcon\" type=\"TextureRect\"", "wild battle names support the owned Poké Ball marker")
	_check_contains(pokemon_info_hud_source, "[node name=\"ExpRow\" type=\"HBoxContainer\"", "battle EXP uses a dedicated row below HP")
	_check_contains(pokemon_info_hud_source, "[node name=\"ExpIndent\" type=\"Control\"", "battle EXP aligns beneath HP without a visible label")
	_check_contains(pokemon_info_hud_source, "[node name=\"ExpBar\" type=\"ProgressBar\" parent=\"MarginContainer/VBoxContainer/ExpRow\"", "battle EXP bar is aligned beneath the HP bar")
	_check_contains(pokemon_info_hud_source, "custom_minimum_size = Vector2(0, 7)", "battle EXP bar remains visually subordinate to HP")
	_check_contains(battle_script_source, "func _refresh_wild_opponent_owned_icon", "wild battles resolve OT Pokédex ownership")
	_check_contains(battle_script_source, "var drawer_width: float = frame_size.x - CALC_DRAWER_FIELD_MARGIN * 2.0", "Calc drawer fills the rendered battlefield width")
	_check_contains(battle_script_source, "size = target_size", "collapsing the battle log resizes the actual free-positioned battle window")
	_check_contains(battle_script_source, "previous_center - size * 0.5", "battle log resizing preserves the battle window center")
	_check_contains(battle_script_source, "battle_drawer_layer.get_global_transform().affine_inverse()", "Calc drawer tracks the battlefield instead of the battle log")
	_check_contains(battle_script_source, "var frame_size := frame_rect.size", "Calc drawer uses the rendered battlefield width")
	_check_contains(battle_script_source, "team_pokemon_hovered", "Calcdex team icons expose the same hover interaction as party slots")
	_check_contains(battle_script_source, "if not calcdex_active and hover_state.should_poll_sprite_hover()", "Calcdex suppresses active battlefield sprite hover polling")
	_check_contains(battle_script_source, "player_party_grid.set_hover_enabled(true)", "owned party hover remains available while selection is locked")
	_check_contains(battle_script_source, "calcdex_projection_recovery", "PvP Calcdex recovers a missing projection fence before showing an error")
	_check_contains(battle_script_source, "CALC_STALE_PROJECTION", "PvP Calcdex recognizes a stale projection response")
	_check_contains(battle_script_source, "calcdex_stale_projection_recovery", "PvP Calcdex reconciles the room before retrying a stale snapshot")
	_check_contains(battle_script_source, "_timer_panels_call(\"show_decision_timers\"", "Calc and VS timer views receive one shared timer projection")
	_check_contains(battle_script_source, "current_action_panel_mode == BattleActionsPanelMode.CALC", "Calc timer dock is scoped to calculator mode")
	_check_contains(battle_script_source, "configure_compact_timer_mode(true, true)", "Calc header keeps both compact countdowns available")
	var bag_close_start := battle_script_source.find("func _on_bag_drawer_close_pressed()")
	var bag_close_end := battle_script_source.find("\nfunc ", bag_close_start + 1)
	var bag_close_block := battle_script_source.substr(bag_close_start, bag_close_end - bag_close_start)
	_check_contains(bag_close_block, "current_action_view = ActionView.MOVES", "Bag close leaves BAG state unconditionally")
	_check_contains(bag_close_block, "_sync_action_panel_mode_visibility()", "Bag close hides the drawer before contextual flow resumes")
	var capture_start := battle_script_source.find("func _on_bag_grid_item_selected")
	var capture_end := battle_script_source.find("\nfunc ", capture_start + 1)
	var capture_block := battle_script_source.substr(capture_start, capture_end - capture_start)
	_check_contains(capture_block, "_close_bag_for_capture_attempt()", "Selecting a capture item closes the Bag before awaiting the throw request")
	_check_true(
		capture_block.find("_close_bag_for_capture_attempt()") < capture_block.find("await InventoryService.catch_wild_pokemon"),
		"Bag closes before the capture request can delay the throw presentation"
	)
	_check_contains(capture_block, "_restore_bag_after_capture_error()", "Rejected capture attempts restore the Bag for another choice")
	_check_contains(
		capture_block,
		"if _show_force_switch_if_needed():\n\t\t\t_set_battle_input_locked(false)\n\t\t\treturn",
		"A failed capture that faints the active Pokemon unlocks forced-switch selection"
	)
	_check_contains(scene_source, "[node name=\"MechanicsPanel\" type=\"PanelContainer\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage\"", "mechanics live beside the battlefield moves")
	_check_contains(scene_source, "[node name=\"CalcLogButton\" type=\"Button\" parent=\"HBoxContainer/BattleLogRail/ActionChoices", "Damage Calc lives below the battle log")
	_check_contains(scene_source, "[node name=\"UtilityActions\" type=\"PanelContainer\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage\"", "battlefield has a shared segmented utility bar")
	_check_contains(scene_source, "[node name=\"ActionSegments\" type=\"HBoxContainer\"", "utility actions share one segment container")
	_check_contains(scene_source, "[node name=\"BagButton\" type=\"Button\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage/UtilityActions/ActionSegments\"", "Bag sits in the utility bar")
	_check_contains(scene_source, "[node name=\"RunButton\" type=\"Button\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage/UtilityActions/ActionSegments\"", "Run or Forfeit sits in the utility bar")
	_check_contains(scene_source, "custom_minimum_size = Vector2(146, 34)", "segmented utility bar stays compact")
	_check_contains(scene_source, "text = \"battle.ui.bag\"", "Bag is rendered as a localized text action")
	_check_true(not scene_source.contains("res://assets/battles/ui/bag_white.svg"), "Bag no longer uses an icon")
	var bag_button_start := scene_source.find("[node name=\"BagButton\" type=\"Button\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage/UtilityActions/ActionSegments\"")
	var bag_button_end := scene_source.find("\n\n", bag_button_start)
	var bag_button_block := scene_source.substr(bag_button_start, bag_button_end - bag_button_start)
	_check_contains(bag_button_block, "visible = false", "Bag stays hidden until a wild battle is prepared")
	_check_contains(bag_button_block, "StyleBoxFlat_utility_bag_hover", "Bag uses a restrained cyan hover accent")
	_check_contains(bag_button_block, "size_flags_horizontal = 3", "Bag fills one half of the segmented utility bar")
	_check_true(not bag_button_block.contains("tooltip_text"), "Bag does not repeat its visible label in a tooltip")
	var run_button_start := scene_source.find("[node name=\"RunButton\" type=\"Button\" parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage/UtilityActions/ActionSegments\"")
	var run_button_end := scene_source.find("\n\n", run_button_start)
	var run_button_block := scene_source.substr(run_button_start, run_button_end - run_button_start)
	_check_contains(run_button_block, "StyleBoxFlat_utility_exit_hover", "Run and Forfeit use a warm warning hover accent")
	_check_contains(run_button_block, "size_flags_horizontal = 3", "Run fills the remaining utility bar width")
	_check_true(not run_button_block.contains("tooltip_text"), "Run does not repeat its visible label in a tooltip")
	_check_contains(scene_source, "[node name=\"UtilityActionDivider\" type=\"ColorRect\"", "wild utility actions use a subtle internal divider")
	_check_contains(scene_source, "text = \"battle.ui.run\"", "wild battles display a localized Run action instead of an exit icon")
	_check_true(not scene_source.contains("res://assets/battles/ui/exit_white.svg"), "Run or Forfeit does not use an ambiguous exit icon")
	for effects_panel_name: String in ["SideFieldEffectsPanel", "SideFieldEffectsPanel2"]:
		var effects_start := scene_source.find("[node name=\"%s\"" % effects_panel_name)
		var effects_end := scene_source.find("\n\n", effects_start)
		var effects_block := scene_source.substr(effects_start, effects_end - effects_start)
		_check_contains(effects_block, "z_index = 58", "%s renders above informational party icons" % effects_panel_name)
	_check_contains(scene_source, "offset_left = 130.0", "player field indicators follow the inward player field")
	_check_contains(scene_source, "offset_right = -130.0", "opponent field indicators follow the inward opponent field")
	var field_timers_start := scene_source.find("[node name=\"FieldTimers\"")
	var field_timers_end := scene_source.find("\n\n", field_timers_start)
	var field_timers_block := scene_source.substr(field_timers_start, field_timers_end - field_timers_start)
	_check_contains(field_timers_block, "anchor_left = 0.0", "global field conditions anchor to the battlefield left")
	_check_contains(field_timers_block, "offset_top = 50.0", "global field conditions stack below the turn indicator")
	_check_contains(field_timers_block, "offset_right = 10.0", "global field conditions derive width from their content")
	_check_contains(field_timers_block, "offset_bottom = 50.0", "global field conditions derive height from their content")
	var effects_script_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/side_field_effects_panel.gd")
	_check_contains(effects_script_source, "const EFFECT_SHORT_NAMES", "field effects define compact screen abbreviations")
	_check_contains(effects_script_source, "const HAZARD_EFFECT_KEYS", "field effects identify hazards that need full labels")
	_check_contains(effects_script_source, "if HAZARD_EFFECT_KEYS.has(effect_key)", "hazards render their full localized names")
	_check_contains(effects_script_source, 'return "×%s" % amount', "layered hazards use a clear multiplication marker")
	_check_contains(effects_script_source, "row.tooltip_text = full_effect_name", "field indicators retain their full name as a tooltip")
	var effects_scene_source := FileAccess.get_file_as_string("res://scenes/battle/side_field_effects_panel.tscn")
	_check_contains(effects_scene_source, "theme_override_constants/outline_size = 3", "hazard labels use a dark readability outline")
	_check_contains(effects_scene_source, "theme_override_font_sizes/font_size = 14", "hazard labels use a readable font size")
	var party_slot_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/party_slot.gd")
	_check_contains(party_slot_source, "visible = not icon_only_mode or empty_visible", "battlefield party rails can reserve visible empty slots")
	_check_contains(party_slot_source, "EMPTY_BACKGROUND", "empty battlefield party slots use a restrained disabled surface")
	_check_contains(battle_modifier_source, "player_stage_party_grid.set_empty_slots_visible(show_full_trainer_rails)", "Trainer battles reserve all six player rail slots")
	_check_contains(battle_modifier_source, "opponent_party_grid.set_empty_slots_visible(show_full_trainer_rails)", "Trainer battles reserve all six opponent rail slots")
	_check_contains(party_slot_source, "ICON_FAINTED_MODULATE", "fainted battlefield icons use a clear grayscale treatment")
	_check_contains(party_slot_source, "Vector2(46.0, 46.0)", "battlefield preview icons fill their compact slots evenly")
	_check_contains(party_slot_source, "margin_container.add_theme_constant_override(\"margin_right\", 2)", "battlefield preview icons use symmetric compact padding")
	_check_contains(party_slot_source, "ICON_PARTY_BORDER if icon_only_mode else PARTY_BORDER", "battlefield preview slots use a restrained neutral border")
	_check_contains(party_slot_source, "ACTIVE_BORDER if icon_only_mode", "battlefield preview hover is the only inactive cyan accent")
	_check_true(not party_slot_source.contains("TypeColors.get_slot_background"), "party slot backgrounds no longer encode Pokemon type")
	_check_contains(party_slot_source, '_t("battle.status.compact.fainted")', "fainted battlefield icons carry a localized FNT badge")
	_check_contains(party_slot_source, "pokemon_icon.self_modulate = ICON_FAINTED_MODULATE", "fainted sprite treatment does not dim its child FNT badge")
	_check_contains(party_slot_source, "\"fnt\": return Color(\"#e64262\")", "FNT badge remains high-contrast over a darkened sprite")
	_check_contains(party_slot_source, "func _get_compact_status_text", "battlefield icons map status conditions to compact badges")
	var party_slot_scene_source := FileAccess.get_file_as_string("res://scenes/battle/party_slot.tscn")
	_check_contains(party_slot_scene_source, "[node name=\"IconStatusBadge\" type=\"Label\"", "party slots contain an overlaid icon condition badge")
	_check_contains(party_slot_scene_source, "z_index = 5", "icon condition badge renders above the darkened Pokemon sprite")
	_check_contains(party_slot_scene_source, "theme_override_font_sizes/font_size = 9", "FNT badge retains its compact original size")
	var move_slot_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/move_slot.gd")
	_check_contains(move_slot_source, "TypeColors.get_slot_background(move_type", "move backgrounds encode move type")
	_check_contains(move_slot_source, "TypeColors.get_slot_border(move_type", "move borders encode move type")
	_check_contains(move_slot_source, "TypeColors.get_slot_accent(move_type", "move hover state uses the readable type accent")
	_check_contains(move_slot_source, "background.lerp(border, 0.18)", "move cards visibly tint their surface by type")
	_check_contains(move_slot_source, "style.border_width_left = border_width + 3", "move cards use a clear type-color edge")
	var field_timers_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/field_timers.gd")
	_check_contains(field_timers_source, "func _fit_to_content()", "global field condition container refits after content changes")

	var stage_prefix := "parent=\"HBoxContainer/CenterColumn/BattleFrame/MarginContainer/BattleStageViewport/BattleStage"
	for stage_node_name: String in [
		"BattleBackground",
		"BattlePlatform",
		"BattlePlatform2",
		"PlayerSpriteBox",
		"EnemySpriteBox",
		"PlayerHudPanel",
		"EnemyHudPanel",
		"CurrentActionPanel",
		"MovesGrid",
		"MechanicsPanel",
		"WeatherTint",
		"TerrainTint",
		"GrassyTerrainLayer",
		"TrickRoomLayer",
		"FieldTimers",
		"SideFieldEffectsPanel",
		"SideFieldEffectsPanel2",
		"PlayerTeamPreviewLayer",
		"EnemyTeamPreviewLayer",
		"CaptureBallAnimationPlayer",
		"PokeballSummonAnimationPlayer",
	]:
		var node_start := scene_source.find("[node name=\"%s\"" % stage_node_name)
		var node_end := scene_source.find("\n\n", node_start)
		var node_block := scene_source.substr(node_start, node_end - node_start) if node_start >= 0 and node_end > node_start else ""
		_check_true(node_block.contains(stage_prefix), "%s remains in scaled stage" % stage_node_name)

	var battle_log_block_start := scene_source.find("[node name=\"BattleLogPanel\"")
	var battle_log_block_end := scene_source.find("\n\n", battle_log_block_start)
	var battle_log_block := scene_source.substr(battle_log_block_start, battle_log_block_end - battle_log_block_start)
	_check_true(not battle_log_block.contains("visible = false"), "battle log rail can start visible on desktop")

	var battle_root_start := scene_source.find("[node name=\"Battle\"")
	var battle_root_end := scene_source.find("\n\n", battle_root_start)
	var battle_root_block := scene_source.substr(battle_root_start, battle_root_end - battle_root_start)
	_check_contains(battle_root_block, "custom_minimum_size = Vector2(1500, 780)", "compact battle window preserves the 16:9 stage without letterboxing")
	_check_true(not battle_root_block.contains("anchors_preset = 15"), "battle scene root no longer fills the viewport")

func _check_world_battle_host() -> void:
	var world_scene_source := FileAccess.get_file_as_string(WORLD_SCENE_PATH)
	var world_script_source := FileAccess.get_file_as_string(WORLD_SCRIPT_PATH)
	var ui_overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_SCRIPT_PATH)
	_check_contains(world_scene_source, "[node name=\"BattleUILayer\" type=\"CanvasLayer\" parent=\".\"]", "World owns a dedicated battle UI layer")
	_check_contains(world_scene_source, "[node name=\"BattleUIHost\" type=\"Control\" parent=\"BattleUILayer\"]", "World provides a free-positioned battle scene host")
	_check_contains(world_scene_source, "[node name=\"WildEncounterTransitionLayer\" type=\"CanvasLayer\" parent=\".\"]", "World owns a dedicated wild encounter transition layer")
	_check_contains(world_scene_source, "[node name=\"WildEncounterTransition\" type=\"Control\" parent=\"WildEncounterTransitionLayer\"]", "wild encounter transition is mounted declaratively")
	var host_start := world_scene_source.find("[node name=\"BattleUIHost\"")
	var host_end := world_scene_source.find("\n\n", host_start)
	var host_block := world_scene_source.substr(host_start, host_end - host_start)
	_check_contains(host_block, "mouse_filter = 2", "transparent battle margins let normal map UI receive clicks")
	_check_contains(world_script_source, "battle_ui_host.add_child(battle_instance)", "battle scene mounts inside the World battle host")
	_check_contains(world_script_source, "battle_ui_host.visible = true", "battle host opens for a battle")
	_check_contains(world_script_source, "battle_ui_host.visible = false", "battle host closes after a battle")
	_check_contains(FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH), "BATTLE_UI_POSITION_PATH := \"user://battle_ui_position.json\"", "battle UI position is persisted per client")
	_check_contains(FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH), "BattleDragHandle", "battle UI exposes a drag handle")
	_check_true(not world_script_source.contains("battle_ui_layer = CanvasLayer.new()"), "battle startup no longer creates a full-screen battle layer dynamically")
	_check_contains(ui_overlay_source, "UI_OVERLAY_FOCUSED_LAYER := 20", "clicked map UI can render above the battle layer")
	_check_contains(ui_overlay_source, "_focus_normal_ui_group(chat_panel)", "chat interaction promotes chat above the battle layer")
	_check_contains(ui_overlay_source, "func focus_battle_ui_layer()", "battle interaction can restore battle layer priority")


func _check_hp_hud_structure() -> void:
	var hud_scene_source := FileAccess.get_file_as_string(BATTLE_HUD_SCENE_PATH)
	_check_true(not hud_scene_source.contains("PlayerTeamPanel"), "HP HUD no longer owns party indicators")
	_check_true(not hud_scene_source.contains("PokemonSheetSlot"), "HP HUD contains only active Pokemon information")
	_check_contains(hud_scene_source, "custom_minimum_size = Vector2(312, 82)", "both sides share the compact HUD dimensions")
	_check_contains(hud_scene_source, "corner_radius_top_left = 36", "HP HUD uses a pill-shaped outer panel")
	_check_contains(hud_scene_source, "corner_radius_bottom_right = 36", "HP HUD pill is rounded on every side")


func _check_mimikyu_disguise_indicator_contract() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check_contains(battle_source, "BattleState.get_mimikyu_disguise_state_for_species", "battle derives Mimikyu's Disguise badge from its rendered form")
	_check_contains(battle_source, '"line": STAT_STAGE_BADGE_LINE_MODIFIER', "Disguise uses the badge row below the HP HUD alongside stat modifiers")
	_check_contains(battle_source, 'return "▲ %s" % stage_value', "stat boosts use an unambiguous upward indicator")
	_check_contains(battle_source, 'return "▼ %s" % abs(stage_value)', "stat drops use an unambiguous downward indicator")
	_check_contains(battle_source, '_t("battle.hud.disguise_active"', "active Disguise badge is localized")
	_check_contains(battle_source, '"battle.hud.disguise_inactive"', "inactive Disguise badge is localized")


func _check_kingambit_fallen_indicator_contract() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check_contains(battle_source, "supreme_overlord_fallen_by_ident", "battle tracks Showdown's Supreme Overlord fallen count")
	_check_contains(battle_source, 'canonical_species_key == "kingambit"', "Fallen indicator is scoped to canonical Kingambit")
	_check_contains(battle_source, '_t("battle.hud.fallen")', "Fallen indicator label is localized")
	_check_contains(battle_source, '"line": STAT_STAGE_BADGE_LINE_MODIFIER', "Fallen indicator uses the badge row above the sprite")


func _check_type_change_indicator_contract() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check_contains(battle_source, "type_changes_by_ident", "battle tracks temporary Pokémon type changes")
	_check_contains(battle_source, "func _apply_type_change_event", "battle handles Showdown type-change events")
	_check_contains(battle_source, '"label": "%s:" % ability', "type-change badge identifies the triggering ability")
	_check_contains(battle_source, '"value": pokemon_type.capitalize()', "type-change badge displays the current type")
	_check_contains(battle_source, "_clear_type_change_for_ident", "type-change badge clears when a Pokémon leaves battle")


func _check_mimikyu_back_sprite_grounding_contract() -> void:
	var sprite_box_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/sprite_box.gd")
	_check_contains(sprite_box_source, '"back:mimikyu": Vector2(0, 10)', "Mimikyu back sprite is grounded with a species-only vertical offset")
	_check_contains(sprite_box_source, '"back:mimikyu-busted": Vector2(0, 10)', "Busted Mimikyu uses the same grounded back-sprite baseline")
	_check_contains(sprite_box_source, '"shiny_back:mimikyu": Vector2(0, 10)', "shiny Mimikyu keeps the grounded back-sprite baseline")
	_check_contains(sprite_box_source, '"shiny_back:mimikyu-busted": Vector2(0, 10)', "shiny Busted Mimikyu keeps the grounded back-sprite baseline")
	_check_contains(sprite_box_source, '"front:mimikyu": Vector2(0, 8)', "Mimikyu front sprite is grounded with a species-only vertical offset")
	_check_contains(sprite_box_source, '"front:mimikyu-busted": Vector2(0, 8)', "Busted Mimikyu uses the grounded front-sprite baseline")
	_check_contains(sprite_box_source, '"shiny_front:mimikyu": Vector2(0, 8)', "shiny Mimikyu keeps the grounded front-sprite baseline")
	_check_contains(sprite_box_source, '"shiny_front:mimikyu-busted": Vector2(0, 8)', "shiny Busted Mimikyu keeps the grounded front-sprite baseline")


func _check_stage_scaling() -> void:
	var viewport := Control.new()
	viewport.set_script(StageViewportScript)
	viewport.name = "BattleStageViewport"
	var stage := Control.new()
	stage.name = "BattleStage"
	stage.unique_name_in_owner = true
	viewport.add_child(stage)
	stage.owner = viewport
	root.add_child(viewport)
	viewport.size = Vector2(800.0, 600.0)
	await process_frame
	viewport.call("_update_stage_transform")

	var expected_scale := 600.0 / STAGE_DESIGN_SIZE.y
	_check_vector_approx(stage.size, STAGE_DESIGN_SIZE, 0.01, "stage keeps fixed 16:9 design size")
	_check_float_approx(stage.scale.x, stage.scale.y, 0.0001, "stage uses uniform scale")
	_check_float_approx(stage.scale.x, expected_scale, 0.001, "stage uses cover scaling for the cropped battlefield")
	_check_float_approx(stage.position.x, -133.0, 0.51, "stage crops evenly on the horizontal axis when required")
	_check_float_approx(stage.position.y, 0.0, 0.01, "stage preserves its top edge while cropping")

	viewport.size = Vector2(1600.0, 700.0)
	viewport.call("_update_stage_transform")
	var wide_scale := 1600.0 / STAGE_DESIGN_SIZE.x
	_check_float_approx(stage.scale.x, wide_scale, 0.001, "wide stage scales to viewport width")
	_check_float_approx(stage.position.x, 0.0, 0.01, "wide stage fills the horizontal axis")
	_check_float_approx(stage.position.y, 0.0, 0.01, "wide stage takes its crop from the bottom")

	viewport.queue_free()
	await process_frame


func _check_party_rail_interaction() -> void:
	var party_grid := PartyGridScript.new() as GridContainer
	for index: int in range(6):
		var slot := Button.new()
		slot.name = "PartySlot%s" % (index + 1)
		slot.disabled = index == 1 or index == 2
		party_grid.add_child(slot)
	root.add_child(party_grid)
	await process_frame

	party_grid.set_selection_enabled(false)
	_check_true(not party_grid.is_selection_enabled(), "informational party rail is not selectable")
	_check_true(not party_grid.is_slot_selectable(1), "healthy slot is disabled outside Party mode")
	party_grid.set_hover_enabled(true)
	_check_true(not party_grid.is_selection_enabled(), "hover-only party rail remains non-selectable")
	_check_true(not (party_grid.get_child(0) as Button).disabled, "hover-only party rail keeps healthy slots interactive for hover")
	_check_true(not party_grid.is_slot_selectable(1), "hover-only party rail still blocks selection")

	party_grid.set_selection_enabled(true)
	_check_true(party_grid.is_selection_enabled(), "Party mode enables rail selection")
	_check_true(party_grid.is_slot_selectable(1), "healthy reserve becomes selectable")
	_check_true(not party_grid.is_slot_selectable(2), "active Pokemon remains unselectable")
	_check_true(not party_grid.is_slot_selectable(3), "fainted Pokemon remains unselectable")

	party_grid.set_input_disabled(true)
	_check_true(not party_grid.is_selection_enabled(), "battle input lock disables party rail")
	_check_true(not party_grid.is_slot_selectable(1), "locked party rail blocks reserve selection")
	party_grid.set_input_disabled(false)
	_check_true(party_grid.is_slot_selectable(1), "unlock restores eligible reserve selection")

	_check_true(PartyGridScript.should_allow_selection(true, true, false, false), "normal turn direct switching is allowed")
	_check_true(PartyGridScript.should_allow_selection(true, true, false, false), "team preview Party selection is allowed")
	_check_true(PartyGridScript.should_allow_selection(true, true, false, false), "forced-switch Party selection is allowed")
	_check_true(not PartyGridScript.should_allow_selection(true, false, false, false), "move view blocks party selection")
	_check_true(not PartyGridScript.should_allow_selection(false, true, false, false), "Calc mode blocks party selection")
	_check_true(not PartyGridScript.should_allow_selection(true, true, true, false), "waiting or submit lock blocks party selection")
	_check_true(not PartyGridScript.should_allow_selection(true, true, false, true), "battle end blocks party selection")

	var opponent_grid := PartyGridScript.new() as GridContainer
	for index: int in range(6):
		var opponent_slot := Button.new()
		opponent_slot.name = "OpponentPartySlot%s" % (index + 1)
		opponent_grid.add_child(opponent_slot)
	root.add_child(opponent_grid)
	await process_frame
	opponent_grid.set_selection_enabled(false)
	_check_true(not opponent_grid.is_selection_enabled(), "opponent party grid remains informational")
	_check_true(not opponent_grid.is_slot_selectable(1), "opponent party slots cannot submit a selection")

	party_grid.queue_free()
	opponent_grid.queue_free()
	await process_frame


func _check_battle_selection_policy_contract() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var move_slot_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/move_slot.gd")
	var battle_scene_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	_check_contains(source, "PartyGrid.should_allow_selection(", "battle delegates party interaction to tested policy")
	_check_contains(source, "current_action_view == ActionView.PARTY", "party view drives rail selection")
	_check_contains(source, "battle_actions_ready", "an open normal turn enables direct rail switching")
	_check_contains(source, "battle_actions_ready = is_ready\n\t_sync_party_rail_interaction()", "opening or closing a turn immediately refreshes rail selectability")
	_check_contains(source, "current_action_view != ActionView.BAG", "Bag blocks direct rail switching")
	_check_contains(source, "current_action_panel_mode == BattleActionsPanelMode.BATTLE", "Calc mode cannot select party")
	_check_contains(source, "func _show_pvp_switch_confirmation", "accepted PvP switches replace the party row with a confirmation")
	_check_contains(source, "func _show_pvp_lead_confirmation", "accepted PvP leads replace the party row with a confirmation")
	_check_contains(source, "func _show_pvp_move_confirmation", "accepted PvP moves replace the party row with a confirmation")
	_check_contains(source, "if not _is_pvp_battle():", "switch confirmation is restricted to PvP")
	_check_contains(source, '_t("battle.confirm.switch"', "switch confirmation names both incoming and replaced Pokemon")
	_check_contains(source, '_t("battle.confirm.lead"', "lead confirmation names the selected lead Pokemon")
	_check_contains(source, '_t("battle.confirm.move"', "move confirmation names the acting Pokemon and selected move")
	_check_contains(source, "_show_pvp_lead_confirmation(selected_lead_name)", "PvP Team Preview shows the lead confirmation while waiting")
	_check_contains(source, '_submit_player_choice("move", slot, use_mega, pending_player_choice_events, pvp_move_context, use_z_move)', "PvP move submission retains mechanics and local confirmation context")
	_check_contains(FileAccess.get_file_as_string(BATTLE_SCENE_PATH), "[node name=\"PvpSwitchConfirmationLabel\"", "actions dock contains the PvP switch confirmation label")
	_check_true(not source.contains("Select a Pokemon from the party rail"), "switch row does not repeat a redundant party instruction")
	_check_true(not source.contains("context_hint.text = \"Choose an action\""), "compact dock does not stack a redundant generic hint")
	_check_contains(source, "battle_input_locked", "battle input lock controls party rail")
	_check_contains(source, "battle_finished", "battle end controls party rail")
	_check_contains(source, "player_party_grid.visible = true", "battle keeps player party rail visible across states")
	_check_contains(source, "opponent_party_grid.visible = true", "battle keeps opponent party rail visible across states")
	_check_contains(source, "player_party_grid.set_party(", "player party data is rendered beside its stage sprite")
	_check_contains(source, "opponent_party_grid.set_party(", "opponent party data is rendered beside its stage sprite")
	_check_contains(source, "opponent_party_grid.set_selection_enabled(false)", "opponent party remains informational")
	_check_contains(source, "player_stage_party_grid.set_selection_enabled(false)", "battlefield player icons remain informational")
	_check_contains(source, "player_party_grid.party_changed.connect(player_stage_party_grid.set_party)", "interactive party data mirrors to the visual battlefield icons")
	_check_contains(source, "func _on_bag_drawer_close_pressed()", "Bag close action is implemented")
	_check_contains(source, "func _on_calc_drawer_close_pressed()", "Calc close action is implemented")
	_check_contains(source, "battle_drawer_layer.move_to_front()", "drawer layer wins GUI hit-testing over the battle stage")
	_check_contains(source, "calc_log_button.pressed.connect(_on_calc_mode_button_pressed)", "battle-log Calc button opens the existing calculator flow")
	_check_contains(source, "func _on_mechanic_button_mouse_entered", "available mechanic icons define a hover highlight")
	_check_contains(source, "\"self_modulate\"", "mechanic hover does not overwrite mechanic availability colors")
	_check_contains(source, "Vector2(1.08, 1.08)", "mechanic hover provides subtle scale feedback")
	_check_contains(source, "func _apply_mechanic_orb_style", "mechanics use a dedicated floating orb style")
	_check_contains(source, "corner_radius_top_left = 36", "mechanic orb is circular rather than a rectangular card")
	_check_contains(source, "mechanics_panel.size = Vector2(68.0, 68.0)", "mechanic orb stays compact")
	_check_contains(source, "_create_mechanic_overlay_label(mega_evolution_button, \"MEGA\")", "Mega orb carries a compact text overlay")
	_check_contains(source, "_create_mechanic_overlay_label(z_move_button, \"Z\")", "Z-Move orb carries a compact text overlay")
	_check_contains(source, "battle_state.can_active_pokemon_use_z_move(local_state_player_id)", "Z-Move orb follows authoritative request availability")
	_check_contains(source, "battle_state.can_active_pokemon_use_z_move_slot(slot, local_state_player_id)", "Z-Move submission revalidates its exact slot")
	_check_contains(source, 'base_move["zMoveUnavailable"] = true', "moves without a Z-Move are explicitly marked for the battle UI")
	_check_contains(move_slot_source, "DISABLED_MODULATE", "unavailable moves have a clearly muted visual state")
	_check_contains(move_slot_source, 'effectiveness_label.text = _t("battle.move.no_z_move")', "unavailable Z-Move slots explain why they cannot be selected")
	_check_contains(move_slot_source, "Z_MOVE_BORDER", "available Z-Moves have a distinct golden highlight")
	_check_contains(move_slot_source, 'effectiveness_label.text = _t("battle.move.z_power")', "available Z-Moves carry a compact Z-Power label")
	_check_contains(
		FileAccess.get_file_as_string("res://scripts/battle/battle_api/battle_api_client.gd"),
		'body["zMove"] = true',
		"Z-Move transport is explicit and additive"
	)
	_check_contains(source, "shadow_outline_size", "mechanic text uses a readable light glow")
	_check_contains(source, "_prewarm_current_battle_mega_assets()", "battle responses prewarm available Mega assets")
	_check_contains(source, '_t("battle.mechanic.preparing_mega")', "Mega submission gives immediate localized waiting feedback")
	var sprite_box_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/sprite_box.gd")
	_check_contains(sprite_box_source, "sprite_frames_cache", "battle sprites cache prewarmed forms")
	_check_contains(sprite_box_source, "func prewarm_species", "battle sprites expose form prewarming")
	var action_choices_source := FileAccess.get_file_as_string("res://scripts/battle/action_choices.gd")
	var action_label_start := action_choices_source.find("func set_action_label")
	var action_label_end := action_choices_source.find("\nfunc ", action_label_start + 1)
	var action_label_block := action_choices_source.substr(action_label_start, action_label_end - action_label_start)
	_check_true(not action_label_block.contains("if action == \"bag\""), "Bag follows the normal text-label path")
	_check_contains(action_label_block, "button.text = label", "Bag and Run or Forfeit are rendered as button labels")
	_check_contains(action_label_block, "action in [\"bag\", \"run\"]", "utility text buttons suppress redundant tooltips")
	_check_contains(action_choices_source, "func set_action_visible(action: String, is_visible: bool)", "action buttons expose explicit visibility control")
	_check_contains(action_choices_source, "utility_action_divider.visible = is_visible", "hiding Bag also removes the segmented divider so Forfeit fills the bar")
	_check_contains(action_choices_source, "func _apply_utility_segment_corners", "segmented utility hover styles follow the shared shell radius")
	_check_contains(action_choices_source, "button == run_button and not bag_button.visible", "standalone Forfeit rounds both outer edges")
	_check_contains(source, 'wild_capture_allowed = bool(api_response.get("captureAllowed", true))', "wild battles honor the server capture policy")
	_check_contains(source, "battle_type == BattleType.WILD and wild_capture_allowed", "Bag is visible only in catchable wild battles")
	_check_contains(source, "battle_type == BattleType.WILD and wild_capture_allowed and not _is_pvp_battle()", "uncatchable battles reject Bag shortcuts")
	_check_contains(source, "action_buttons.set_action_label(\"run\", \"Run\" if battle_type == BattleType.WILD else \"Forfeit\")", "wild battles show Run while NPC and PvP battles show Forfeit")
	_check_contains(source, "event.is_action_pressed(\"ui_cancel\")", "Escape can close the active battle drawer")
	_check_contains(source, "battle_log_rail.visible = open", "battle log toggle collapses the complete left rail")
	_check_contains(source, "BATTLE_WINDOW_COLLAPSED_SIZE := Vector2(1186.0, 780.0)", "collapsed compact window removes rail width instead of stretching the stage")
	_check_contains(source, "var target_size := BATTLE_WINDOW_OPEN_SIZE if open else BATTLE_WINDOW_COLLAPSED_SIZE", "battle window follows the rail state")
	_check_contains(source, "remembered_battle_log_open", "battle log preference is remembered for the client session")
	_check_contains(source, "BATTLE_LOG_RESPONSIVE_COLLAPSE_WIDTH", "battle log has a mobile-friendly responsive default")
	_check_contains(source, "battle_log_toggle_button.visible = true", "battle log toggle remains available in both states")
	var log_toggle_start := battle_scene_source.find("[node name=\"BattleLogButton\"")
	var log_toggle_end := battle_scene_source.find("\n\n", log_toggle_start)
	var log_toggle_block := battle_scene_source.substr(log_toggle_start, log_toggle_end - log_toggle_start)
	_check_contains(log_toggle_block, "parent=\".\"", "battle log toggle lives outside the battlefield")
	_check_contains(log_toggle_block, "z_index = 95", "battle log side tab renders above the battle shell")
	_check_contains(log_toggle_block, "custom_minimum_size = Vector2(42, 48)", "battle log toggle has a prominent click target")
	_check_contains(log_toggle_block, "offset_left = -50.0", "battle log toggle sits left of the complete log rail")
	_check_contains(log_toggle_block, "StyleBoxFlat_battle_log_toggle_normal", "battle log toggle has a distinct bordered style")
	_check_contains(source, 'battle_log_toggle_button.text = "»" if is_open else "«"', "battle log toggle uses prominent directional chevrons")
	var preview_start := source.find("func _show_team_preview_layers()")
	var preview_end := source.find("\nfunc ", preview_start + 1)
	var preview_block := source.substr(preview_start, preview_end - preview_start)
	_check_contains(preview_block, "player_team_preview_layer.call(\"show_team\"", "team preview shows the player team in its compact sprite grid")
	_check_contains(preview_block, "enemy_team_preview_layer.call(\"show_team\"", "team preview shows the opponent team in its compact sprite grid")
	_check_contains(preview_block, "player_hud_panel.visible = false", "team preview hides the empty player HP pill")
	_check_contains(preview_block, "enemy_hud_panel.visible = false", "team preview hides the empty opponent HP pill")
	var preview_layer_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/team_preview_layer.gd")
	_check_contains(preview_layer_source, "Vector2(1.35, 1.35)", "team preview preserves the original grouped sprite scale")
	var preview_scene_source := FileAccess.get_file_as_string("res://scenes/battle/team_preview_layer.tscn")
	_check_contains(preview_scene_source, "position = Vector2(-111, -8)", "team preview preserves the original close team grouping")
	_check_contains(preview_scene_source, "position = Vector2(90, -16)", "team preview keeps the grouped opposing edge")
	_check_contains(battle_scene_source, "position = Vector2(300, 412)", "player preview group follows the raised player field")
	_check_contains(battle_scene_source, "position = Vector2(850, 268)", "opponent preview group shifts down as one unit")
	_check_contains(source, "player_sprite_box.get_parent()", "move animations use the scaled stage as their parent")
	_check_contains(
		source,
		"player_party_grid.pokemon_hovered.connect(_show_party_hover)",
		"interactive player party row keeps the full owned-party hover"
	)
	_check_contains(
		source,
		"player_stage_party_grid.pokemon_hovered.connect(_show_public_party_hover)",
		"left stage party rail uses the public confirmed-information hover"
	)
	_check_contains(
		source,
		"opponent_party_grid.pokemon_hovered.connect(_show_public_party_hover)",
		"right stage party rail uses the public confirmed-information hover"
	)
	_check_contains(
		source,
		"if is_local_hover_owner and not public_confirmed_only:",
		"public party hover cannot fall through to private local move data"
	)
	_check_contains(
		source,
		'if active_species == "":',
		"empty active species clears the sprite instead of loading an empty asset path"
	)


func _check_contains(source: String, expected: String, label: String) -> void:
	_check_true(source.contains(expected), label)


func _check_true(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL %s" % label)


func _check_float_approx(actual: float, expected: float, tolerance: float, label: String) -> void:
	if absf(actual - expected) <= tolerance:
		return
	failed = true
	push_error("%s expected=%s actual=%s tolerance=%s" % [label, expected, actual, tolerance])


func _check_vector_approx(actual: Vector2, expected: Vector2, tolerance: float, label: String) -> void:
	_check_float_approx(actual.x, expected.x, tolerance, "%s x" % label)
	_check_float_approx(actual.y, expected.y, tolerance, "%s y" % label)
