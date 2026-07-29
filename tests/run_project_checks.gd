extends SceneTree

const CHECK_SCRIPTS: Array[String] = [
	"res://tests/battle_display_data_presenter_check.gd",
	"res://tests/battle_party_slot_resolver_check.gd",
	"res://tests/battle_event_text_formatter_check.gd",
	"res://tests/battle_message_timing_check.gd",
	"res://tests/battle_event_presentation_check.gd",
	"res://tests/battle_presentation_state_check.gd",
	"res://tests/battle_state_field_delta_check.gd",
	"res://tests/battle_render_barrier_check.gd",
	"res://tests/battle_response_order_check.gd",
	"res://tests/battle_result_overlay_check.gd",
	"res://tests/battle_event_renderer_order_check.gd",
	"res://tests/battle_rewind_helper_check.gd",
	"res://tests/battle_event_pre_render_order_check.gd",
	"res://tests/battle_state_deferred_hp_check.gd",
	"res://tests/battle_state_hp_cursor_check.gd",
	"res://tests/battle_state_primal_forms_check.gd",
	"res://tests/battle_mechanical_suspension_state_check.gd",
	"res://tests/battle_timer_projection_check.gd",
	"res://tests/battle_timer_ui_visibility_check.gd",
	"res://tests/battle_z_move_type_icons_check.gd",
	"res://tests/battle_vs_panel_layout_check.gd",
	"res://tests/moves_grid_disabled_state_check.gd",
	"res://tests/battle_ui_layout_check.gd",
	"res://tests/battle_animation_anchor_check.gd",
	"res://tests/battle_terrain_field_visual_check.gd",
	"res://tests/status_condition_overlay_check.gd",
	"res://tests/field_timer_animated_terrain_icon_check.gd",
	"res://tests/battle_substitute_presentation_check.gd",
	"res://tests/party_slot_hp_payload_check.gd",
	"res://tests/pokemon_ball_metadata_check.gd",
	"res://tests/pokemon_home_icon_resolution_check.gd",
	"res://tests/pokemon_cry_resolver_check.gd",
	"res://tests/pokemon_cry_audio_settings_check.gd",
	"res://tests/localization_foundation_check.gd",
	"res://tests/localization_shared_ui_check.gd",
	"res://tests/localization_party_summary_check.gd",
	"res://tests/localization_bag_hotbar_check.gd",
	"res://tests/localization_battle_ui_check.gd",
	"res://tests/localization_item_data_check.gd",
	"res://tests/localization_content_data_check.gd",
	"res://tests/localization_backend_error_check.gd",
	"res://tests/localization_launcher_news_check.gd",
	"res://tests/localization_market_ui_check.gd",
	"res://tests/localization_pokedex_ui_check.gd",
	"res://tests/localization_mail_ui_check.gd",
	"res://tests/localization_friendlist_ui_check.gd",
	"res://tests/pokemon_experience_payload_check.gd",
	"res://tests/pokemon_factory_hp_snapshot_check.gd",
	"res://tests/pokemon_pc_interactable_check.gd",
	"res://tests/new_player_spawn_check.gd",
	"res://tests/blackout_respawn_contract_check.gd",
	"res://tests/gameplay_reset_contract_check.gd",
	"res://tests/floor_visibility_mask_camera_check.gd",
	"res://tests/players_house_visual_depth_check.gd",
	"res://tests/players_house_location_label_check.gd",
	"res://tests/map_music_profile_check.gd",
	"res://tests/map_layer_resolver_check.gd",
	"res://tests/pokemon_center_template_structure_check.gd",
	"res://tests/aether_atelier_check.gd",
	"res://tests/aether_atelier_runtime_check.gd",
	"res://tests/sign_interactable_check.gd",
	"res://tests/sign_content_validation_check.gd",
	"res://tests/pokemon_storage_service_contract_check.gd",
	"res://tests/pvp_ranked_banlists_check.gd",
	"res://tests/pvp_ranked_team_validation_check.gd",
	"res://tests/pvp_battle_realtime_stream_check.gd",
	"res://tests/pvp_spectator_terminal_check.gd",
	"res://tests/pvp_battle_history_reference_check.gd",
	"res://tests/map_encounter_provider_check.gd",
	"res://tests/surf_activity_presence_check.gd",
	"res://tests/fishing_inventory_check.gd",
	"res://tests/fishing_action_controller_check.gd",
	"res://tests/wild_encounter_error_rules_check.gd",
	"res://tests/wild_encounter_transition_check.gd",
	"res://tests/pallet_town_encounter_check.gd",
	"res://tests/route_2_viridian_forest_encounter_check.gd",
	"res://tests/route_2_viridian_forest_gate_transition_check.gd",
	"res://tests/wild_pokemon_map_popup_check.gd",
	"res://tests/location_status_card_check.gd",
	"res://tests/loading_screen_layout_check.gd",
	"res://tests/launcher_self_update_check.gd",
	"res://tests/credits_access_check.gd",
	"res://tests/world_time_service_check.gd",
	"res://tests/day_night_system_check.gd",
	"res://tests/night_light_check.gd",
	"res://tests/field_move_flash_light_check.gd",
	"res://tests/building_window_light_check.gd",
	"res://tests/developer_world_time_selector_check.gd",
	"res://tests/overworld_weather_controller_check.gd",
	"res://tests/pokemon_summary_move_reorder_check.gd",
	"res://tests/pokemon_summary_direct_field_move_check.gd",
	"res://tests/tmx_visual_importer_check.gd",
	"res://tests/social_service_contract_check.gd",
	"res://tests/guild_service_contract_check.gd",
	"res://tests/guild_popup_check.gd",
	"res://tests/guild_popup_runtime_check.gd",
	"res://tests/guild_invitation_dialog_check.gd",
	"res://tests/guild_nameplate_runtime_check.gd",
	"res://tests/badge_progression_check.gd",
	"res://tests/trainer_card_gym_badges_runtime_check.gd",
	"res://tests/dev_badge_progress_popup_runtime_check.gd",
	"res://tests/gym_leader_alpha_hub_check.gd",
	"res://tests/npc_definition_profile_check.gd",
	"res://tests/trade_service_contract_check.gd",
	"res://tests/trade_item_workspace_check.gd",
	"res://tests/trade_realtime_service_check.gd",
	"res://tests/trade_invitation_dialog_check.gd",
	"res://tests/trade_workspace_check.gd",
	"res://tests/localization_trade_ui_check.gd",
	"res://tests/trade_two_client_offer_check.gd",
	"res://tests/trade_disconnect_lifecycle_check.gd",
	"res://tests/trade_confirmation_completion_check.gd",
	"res://tests/trade_operations_client_check.gd",
	"res://tests/world_presence_roster_check.gd",
	"res://tests/player_interaction_coordinator_check.gd",
	"res://tests/npc_identity_check.gd",
	"res://tests/npc_dialogue_metadata_check.gd",
	"res://tests/dialogue_metadata_service_check.gd",
	"res://tests/trainer_dialogue_cleanup_check.gd",
	"res://tests/npc_content_validation_check.gd",
	"res://tests/item_gift_npc_check.gd",
	"res://tests/overworld_pokemon_check.gd",
	"res://tests/overworld_medicine_check.gd",
	"res://tests/player_action_escape_rope_check.gd",
	"res://tests/overworld_ui_side_layout_check.gd",
	"res://tests/adinho_appearance_unlock_check.gd",
	"res://tests/appearance_color_system_check.gd",
	"res://tests/donator_store_cosmetic_subtabs_check.gd",
	"res://tests/blessed_chat_badge_check.gd",
	"res://tests/player_hotbar_check.gd",
	"res://tests/player_hotbar_interactive_check.gd",
	"res://tests/legacy_market_cleanup_check.gd",
	"res://tests/wild_battle_experience_reward_check.gd",
	"res://tests/boss_battle_npc_check.gd",
]

const LOG_DIR := "/tmp/pokeaether_project_checks"

var failed := false


func _init() -> void:
	var log_error := DirAccess.make_dir_recursive_absolute(LOG_DIR)
	if log_error != OK:
		push_error("Failed to create check log directory: %s" % LOG_DIR)
		quit(1)
		return

	var executable := OS.get_executable_path()
	var project_path := ProjectSettings.globalize_path("res://")

	print("Running %d project checks..." % CHECK_SCRIPTS.size())
	for script_path in CHECK_SCRIPTS:
		_run_check(executable, project_path, script_path)

	quit(1 if failed else 0)


func _run_check(executable: String, project_path: String, script_path: String) -> void:
	var output: Array = []
	var log_file := "%s/%s.log" % [LOG_DIR, _script_log_name(script_path)]
	var exit_code := OS.execute(
		executable,
		PackedStringArray([
			"--no-header",
			"--headless",
			"--log-file",
			log_file,
			"--path",
			project_path,
			"--script",
			script_path,
		]),
		output,
		true
	)

	if exit_code == 0:
		print("PASS %s" % script_path)
		return

	failed = true
	push_error(
		"FAIL %s exit_code=%d log=%s\n%s" % [script_path, exit_code, log_file, _format_output(output)]
	)


func _format_output(output: Array) -> String:
	var parts: Array[String] = []
	for item in output:
		parts.append(str(item))
	return "\n".join(parts)


func _script_log_name(script_path: String) -> String:
	return script_path.replace("res://", "").replace("/", "_").replace(".", "_")
