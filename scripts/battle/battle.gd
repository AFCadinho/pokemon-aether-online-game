extends Control

signal battle_ended(result: Dictionary)

enum BattleType {
	WILD,
	TRAINER
}

enum ActionView {
	NONE,
	MOVES,
	PARTY,
	BAG
}

enum BattleActionsPanelMode {
	BATTLE,
	CALC
}

const DEBUG_TRAINER_TEAM_DISPLAY := false
const TRAINER_TEAM_DEBUG_PREFIX := "[PAO Trainer Team Display Debug]"
const STATUS_CONDITION_OVERLAY_SCRIPT := preload("res://scripts/battle/animations/status_condition_overlay.gd")
const CALC_DRAWER_FIELD_WIDTH_RATIO := 0.55
const CALC_DRAWER_FIELD_MARGIN := 8.0
const MEGA_EVOLUTION_EFFECT_KEY := "mega_evolution"

var battle_type: BattleType = BattleType.WILD
var current_action_view: ActionView = ActionView.NONE
var current_action_panel_mode: BattleActionsPanelMode = BattleActionsPanelMode.BATTLE
var battle_finished := false
var battle_input_locked := false
var battle_actions_ready := false
var queued_battle_action: Dictionary = {}
var defer_force_switch_active_hide := false
var team_preview_lead_selection_active := false
var forfeit_return_action_view: ActionView = ActionView.NONE
var mega_evolution_selected := false
var mega_evolution_pulse_tween: Tween
var mechanic_orb_style: StyleBoxFlat
var mega_mechanic_label: Label
var pending_mega_species_by_ident: Dictionary = {}
var pvp_room_code := ""
var pvp_match_id := ""
var pvp_realtime_updates: Array[Dictionary] = []
var pvp_realtime_deferred_updates: Array[Dictionary] = []
var pvp_pending_team_preview_completion: Dictionary = {}
var pvp_team_preview_recovery_requested := false
var pvp_realtime_activity_seq := 0
var pvp_pending_reconciliation_snapshot: Dictionary = {}
var pvp_pending_authoritative_terminal: Dictionary = {}
var pvp_retrying_reconciliation_snapshot := false
var pvp_idle_realtime_drain_pending := false
var pvp_idle_wait_recovery_active := false
var pvp_last_applied_server_seq := 0
var pvp_last_applied_snapshot_server_seq := 0
var pvp_last_phase := ""
var pvp_last_next_phase := ""
var pvp_last_phase_update_server_seq := 0
var pvp_last_phase_update_batch_id := ""
var pvp_last_phase_update_phase := ""
var pvp_presentation_actionable_local_msec := 0
var pvp_presentation_schedule_token := ""
var pvp_rendered_event_count := 0
var pvp_allow_setup_animation := false
var pvp_victory_message_added := false
var pvp_switch_confirmation_active := false
var pending_battle_end_result: Dictionary = {}
var battle_end_signal_emitted := false
var last_rendered_event_seq := -1
var rendered_non_pvp_event_keys: Dictionary = {}
var pvp_event_queue := preload("res://scripts/battle/battle_event_queue.gd").new()
var pvp_response_order := preload("res://scripts/battle/battle_response_order.gd").new()

#Battle State
var battle_state := BattleState.new()
var pokemon_hover_service := preload("res://scripts/battle/battle_pokemon_hover_service.gd").new()
var hover_state := preload("res://scripts/battle/battle_hover_state.gd").new()
var event_text_formatter := preload("res://scripts/battle/battle_event_text_formatter.gd").new()
var weather_presentation := preload("res://scripts/battle/battle_weather_presentation.gd").new()
var side_condition_presentation := preload("res://scripts/battle/battle_side_condition_presentation.gd").new()
var hp_event_helper := preload("res://scripts/battle/battle_hp_event_helper.gd").new()
var rewind_helper := preload("res://scripts/battle/battle_rewind_helper.gd").new()
var action_flow := preload("res://scripts/battle/battle_action_flow.gd").new()
var force_switch_flow := preload("res://scripts/battle/battle_force_switch_flow.gd").new()
var display_data_presenter := preload("res://scripts/battle/battle_display_data_presenter.gd").new()
var message_timing := preload("res://scripts/battle/battle_message_timing.gd").new()
var event_presentation := preload("res://scripts/battle/battle_event_presentation.gd").new()
var event_renderer := preload("res://scripts/battle/battle_event_renderer.gd").new()
var animation_router := preload("res://scripts/battle/battle_animation_router.gd").new()
var setup_flow := preload("res://scripts/battle/battle_setup_flow.gd").new()
var presentation_state := preload("res://scripts/battle/battle_presentation_state.gd").new()
var public_confirmed_abilities_by_ident := {}
var public_confirmed_items_by_ident := {}
var status_condition_overlays: Dictionary = {}
var volatile_conditions_by_ident: Dictionary = {}
var pending_status_condition_overlay_players: Dictionary = {}
var pending_knock_off_targets_by_ident := {}
var pending_booster_energy_modifier_targets_by_ident := {}
var stat_stages_by_ident: Dictionary = {}
var ability_stat_modifiers_by_ident: Dictionary = {}
var player_party_moves_by_key: Dictionary = {}
var damage_calc_request_token := 0
var damage_calc_request_in_flight := false
var damage_calc_refresh_queued := false
var damage_calc_catalog_request_token := 0
var damage_calc_matchup_key := ""
var damage_calc_defender_species_key := ""
var damage_calc_defender_assumptions: Dictionary = {}
var damage_calc_assumption_edited_fields: Dictionary = {}
var damage_calc_saved_assumptions: Dictionary = {}
var bag_inventory_request_token := 0
var capture_target_visibility_tween: Tween
var summon_target_visibility_tween: Tween
var summon_target_sprite_box: Control
var summon_original_z_index := 0
var summon_original_z_as_relative := true
var summon_release_audio_mode := SUMMON_RELEASE_AUDIO_BALL
var summon_release_cry_species := ""
var current_move_hover_rect := Rect2()
var current_party_hover_rect := Rect2()
const OPPONENT_RESPONSE_HOLD_SECONDS := 0.0
const CAPTURE_SUCCESS_RESULT_HOLD_SECONDS := 0.40
const BATTLE_END_RESULT_HOLD_SECONDS := 0.12
const DEBUG_PVP_REALTIME := false
const DEBUG_PVP_FLOW_TRACE := false
const DEBUG_BATTLE_HP_EVENTS := false
const DEBUG_BATTLE_MOVE_EVENTS := false
const DEBUG_SIDE_CONDITION_EFFECTS := false
const DEBUG_BATTLE_PRESENTATION_ORDER := false
const DEBUG_BATTLE_START_EVENTS := false
const SHINY_ENTRANCE_EFFECT_KEY := "shiny_sparkle"
const SUMMON_RELEASE_AUDIO_BALL := "ball"
const SUMMON_RELEASE_AUDIO_NONE := "none"
const INITIAL_TRANSFORM_REVEAL_SECONDS := 0.8
const STAT_STAGE_BADGE_BOOST_COLOR := Color(0.3882353, 0.83137256, 0.44313726, 1.0)
const STAT_STAGE_BADGE_DROP_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const VOLATILE_CONDITION_BADGE_COLOR := Color(1.0, 0.74, 0.26, 1.0)
const STAT_STAGE_BADGE_LINE_MODIFIER := "modifier"
const ABILITY_STAT_MODIFIER_SOURCE_FIELD_CONDITION := "field_condition"
const ABILITY_STAT_MODIFIER_SOURCE_BOOSTER_ENERGY := "booster_energy"
const DAMAGE_CALC_ASSUMPTIONS_PATH := "user://damage_calc_assumptions.json"
const DAMAGE_CALC_ASSUMPTIONS_VERSION := 1
const BATTLE_LOG_RESPONSIVE_COLLAPSE_WIDTH := 1200
const BATTLE_LOG_MEMORY_UNSET := -1
const BATTLE_WINDOW_OPEN_SIZE := Vector2(1500.0, 780.0)
const BATTLE_WINDOW_COLLAPSED_SIZE := Vector2(1186.0, 780.0)
const BATTLE_UI_POSITION_PATH := "user://battle_ui_position.json"
const BATTLE_UI_DEFAULT_VERTICAL_OFFSET := 44.0
const BATTLE_UI_POSITION_MARGIN := 8.0

static var remembered_battle_log_open := BATTLE_LOG_MEMORY_UNSET
static var remembered_battle_ui_position := Vector2.INF

var battle_ui_dragging := false
var battle_ui_drag_offset := Vector2.ZERO

#Active Pokemon
var active_player_pokemon: Pokemon
var active_enemy_pokemon: Pokemon

# Action Buttons
@onready var action_side_panel: Control = %ActionsDock
@onready var battle_drag_handle: Control = %BattleDragHandle
@onready var battle_mode_button: Button = %BattleModeButton
@onready var calc_mode_button: Button = %CalcModeButton
@onready var calc_log_button: Button = %CalcLogButton
@onready var action_buttons: Control = %ActionChoices
@onready var moves_grid: MovesGrid = %MovesGrid
@onready var player_party_grid: PartyGrid = %PlayerPartyGrid
@onready var player_stage_party_grid: PartyGrid = %PlayerStagePartyGrid
@onready var opponent_party_grid: PartyGrid = %OpponentPartyGrid
@onready var bag_grid: BattleBagGrid = %BagGrid
@onready var calc_panel: BattleDamageCalcPanel = %CalcPanel
@onready var battle_drawer_layer: Control = %BattleDrawerLayer
@onready var bag_drawer: Control = %BagDrawer
@onready var calc_drawer: Control = %CalcDrawer
@onready var bag_drawer_close_button: Button = %BagDrawerCloseButton
@onready var calc_drawer_close_button: Button = %CalcDrawerCloseButton
@onready var context_hint: Label = %ContextHint
@onready var pvp_switch_confirmation_label: Label = %PvpSwitchConfirmationLabel
@onready var battle_party_rail: Control = %BattlePartyRail
@onready var party_rail_state_label: Label = %PartyRailStateLabel
@onready var mechanics_panel: Control = %MechanicsPanel
@onready var mega_evolution_button: TextureButton = %MegaEvolutionIcon
@onready var mechanic_buttons: Array[TextureButton] = [
	%MegaEvolutionIcon,
	%Terra,
	%ZMove,
]

# Battle Log
@onready var battle_log_panel: BattleLogPanel = %BattleLogPanel
@onready var battle_log_rail: Control = %BattleLogRail
@onready var mini_battle_feed: MiniBattleFeed = %MiniBattleFeed
@onready var battle_log_toggle_button: Button = %BattleLogButton

# Battle Sprites
@onready var battle_frame: Control = %BattleFrame
@onready var player_battle_platform: Control = %BattlePlatform
@onready var enemy_battle_platform: Control = %BattlePlatform2
@onready var battle_stage_viewport: Control = %BattleStageViewport
@onready var battle_stage: Control = %BattleStage
@onready var enemy_sprite_box: Control = %EnemySpriteBox
@onready var player_sprite_box: Control = %PlayerSpriteBox
@onready var capture_ball_animation_player: CaptureBallAnimationPlayer = %CaptureBallAnimationPlayer
@onready var pokeball_summon_animation_player: Control = %PokeballSummonAnimationPlayer
@onready var enemy_team_preview_layer: Node2D = %EnemyTeamPreviewLayer
@onready var player_team_preview_layer: Node2D = %PlayerTeamPreviewLayer
@onready var pokemon_hover_card: Control = %PokemonHoverCard
@onready var move_hover_card: Control = %MoveHoverCard
@onready var party_hover_card: Control = %PartyHoverCard

# Pokemon HUD
@onready var player_hud_panel: Control = %PlayerHudPanel
@onready var enemy_hud_panel: Control = %EnemyHudPanel

# Turn Nodes
@onready var battle_status_panel: BattleStatusPanel = %BattleStatusPanel
@onready var vs_panel_container: BattleVsPanelContainer = %VSPanelContainer
@onready var player_side_effects_panel: Control = %SideFieldEffectsPanel
@onready var enemy_side_effects_panel: Control = %SideFieldEffectsPanel2
@onready var battle_background: TextureRect = %BattleBackground
@onready var weather_particles: GPUParticles2D = %GPUParticles2D
@onready var weather_tint: ColorRect = %WeatherTint
@onready var terrain_tint: ColorRect = %TerrainTint
@onready var sun_rays: Control = %SunRays
@onready var sun_sparkles: GPUParticles2D = %SunSparkles
@onready var desolate_land_layer: Control = %DesolateLandLayer
@onready var primordial_sea_layer: Control = %PrimordialSeaLayer
@onready var delta_stream_layer: Control = %DeltaStreamLayer
@onready var delta_stream_particles: GPUParticles2D = %DeltaStreamParticles
@onready var sandstorm_particles: GPUParticles2D = %SandstormParticles
@onready var sandstorm_swirls: Control = %SandstormSwirls
@onready var snow_particles: GPUParticles2D = %SnowParticles
@onready var grassy_terrain_layer: Control = %GrassyTerrainLayer
@onready var misty_terrain_layer: Control = %MistyTerrainLayer
@onready var psychic_terrain_layer: Control = %PsychicTerrainLayer
@onready var electric_terrain_layer: Control = %ElectricTerrainLayer
@onready var trick_room_layer: Control = %TrickRoomLayer

@onready var field_timers_panel: FieldTimersPanel = %FieldTimers
@onready var current_action_panel: CurrentActionPanel = %CurrentActionPanel
@onready var forfeit_confirm_dialog: Control = %ForfeitConfirmDialog
@onready var battle_result_overlay: Control = %BattleResultOverlay
@onready var battle_result_title: Label = %BattleResultTitle
@onready var battle_result_summary: Label = %BattleResultSummary
@onready var battle_result_reason: Label = %BattleResultReason
@onready var battle_result_continue_button: Button = %BattleResultContinueButton

# HTTP Request
@onready var battle_request: HTTPRequest = $BattleRequest
@onready var pokemon_info_request: HTTPRequest = $PokemonInfoRequest
@onready var pokemon_stats_request: HTTPRequest = $PokemonStatsRequest
@onready var damage_calc_request: HTTPRequest = $DamageCalcRequest

## Verbindt de UI-signals en zet de battle UI in de beginstand.
func _ready() -> void:
	_setup_battle_ui_position()
	_load_damage_calc_saved_assumptions()
	# GUI hit-testing follows sibling order even when a Control draws at a higher
	# z-index. Keep drawers last so stage controls cannot intercept their clicks.
	battle_drawer_layer.move_to_front()
	_setup_battle_focus_surfaces()
	# The action buttons are declared before the instanced log in the scene file;
	# keep the log visually above the compact Bag/Run row.
	if battle_log_panel.get_parent() == action_buttons.get_parent():
		battle_log_panel.get_parent().move_child(battle_log_panel, 0)
	if not action_buttons.action_selected.is_connected(_on_action_selected):
		action_buttons.action_selected.connect(_on_action_selected)
	if not battle_mode_button.pressed.is_connected(_on_battle_mode_button_pressed):
		battle_mode_button.pressed.connect(_on_battle_mode_button_pressed)
	if not calc_mode_button.pressed.is_connected(_on_calc_mode_button_pressed):
		calc_mode_button.pressed.connect(_on_calc_mode_button_pressed)
	if not calc_log_button.pressed.is_connected(_on_calc_mode_button_pressed):
		calc_log_button.pressed.connect(_on_calc_mode_button_pressed)
	if not bag_drawer_close_button.pressed.is_connected(_on_bag_drawer_close_pressed):
		bag_drawer_close_button.pressed.connect(_on_bag_drawer_close_pressed)
	if not calc_drawer_close_button.pressed.is_connected(_on_calc_drawer_close_pressed):
		calc_drawer_close_button.pressed.connect(_on_calc_drawer_close_pressed)
	if not moves_grid.move_selected.is_connected(_on_moves_grid_move_selected):
		moves_grid.move_selected.connect(_on_moves_grid_move_selected)
	if not player_party_grid.party_selected.is_connected(_on_party_grid_party_selected):
		player_party_grid.party_selected.connect(_on_party_grid_party_selected)
	if not player_party_grid.party_changed.is_connected(player_stage_party_grid.set_party):
		player_party_grid.party_changed.connect(player_stage_party_grid.set_party)
	player_stage_party_grid.set_selection_enabled(false)
	opponent_party_grid.set_selection_enabled(false)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	hover_state.setup(pokemon_info_request, pokemon_stats_request)
	pokemon_hover_service.debug_enabled = DEBUG_BATTLE_MOVE_EVENTS
	setup_flow.setup(event_text_formatter)
	_connect_pokemon_hover_signals()
	_connect_move_hover_signals()
	_connect_party_hover_signals()
	_connect_forfeit_confirm_dialog_signals()
	if not battle_result_continue_button.pressed.is_connected(_on_battle_result_continue_pressed):
		battle_result_continue_button.pressed.connect(_on_battle_result_continue_pressed)
	if not calc_panel.defender_assumptions_changed.is_connected(_on_calc_panel_defender_assumptions_changed):
		calc_panel.defender_assumptions_changed.connect(_on_calc_panel_defender_assumptions_changed)
	if not calc_panel.assumption_catalog_requested.is_connected(_on_calc_panel_assumption_catalog_requested):
		calc_panel.assumption_catalog_requested.connect(_on_calc_panel_assumption_catalog_requested)
	if not bag_grid.item_selected.is_connected(_on_bag_grid_item_selected):
		bag_grid.item_selected.connect(_on_bag_grid_item_selected)
	if player_hud_panel.has_method("set_experience_bar_enabled"):
		player_hud_panel.set_experience_bar_enabled(true)
	if enemy_hud_panel.has_method("set_experience_bar_enabled"):
		enemy_hud_panel.set_experience_bar_enabled(false)
	if enemy_sprite_box.has_method("anchor_stat_stage_panel_below"):
		enemy_sprite_box.call("anchor_stat_stage_panel_below", enemy_hud_panel)
	if not capture_ball_animation_player.ball_thrown.is_connected(_on_capture_ball_thrown):
		capture_ball_animation_player.ball_thrown.connect(_on_capture_ball_thrown)
	if not capture_ball_animation_player.ball_shook.is_connected(_on_capture_ball_shook):
		capture_ball_animation_player.ball_shook.connect(_on_capture_ball_shook)
	if not capture_ball_animation_player.capture_broke.is_connected(_on_capture_broke):
		capture_ball_animation_player.capture_broke.connect(_on_capture_broke)
	if not capture_ball_animation_player.capture_succeeded.is_connected(_on_capture_succeeded):
		capture_ball_animation_player.capture_succeeded.connect(_on_capture_succeeded)
	if not capture_ball_animation_player.target_absorbed.is_connected(_on_capture_target_absorbed):
		capture_ball_animation_player.target_absorbed.connect(_on_capture_target_absorbed)
	if not capture_ball_animation_player.target_released.is_connected(_on_capture_target_released):
		capture_ball_animation_player.target_released.connect(_on_capture_target_released)
	if not pokeball_summon_animation_player.ball_thrown.is_connected(_on_summon_ball_thrown):
		pokeball_summon_animation_player.ball_thrown.connect(_on_summon_ball_thrown)
	if not pokeball_summon_animation_player.pokemon_released.is_connected(_on_summon_pokemon_released):
		pokeball_summon_animation_player.pokemon_released.connect(_on_summon_pokemon_released)
	if not SettingsManager.settings_changed.is_connected(_on_settings_changed):
		SettingsManager.settings_changed.connect(_on_settings_changed)
	_setup_weather_presentation()
	_setup_side_condition_presentation()
	action_flow.setup(battle_state, battle_request, _remember_public_confirmed_abilities_from_response)
	force_switch_flow.setup(battle_state)
	display_data_presenter.setup(battle_state)
	event_presentation.setup(
		event_text_formatter,
		hp_event_helper,
		Callable(self, "_format_battle_actor"),
		Callable(self, "_get_player_display_name")
	)
	animation_router.setup(
		player_sprite_box,
		enemy_sprite_box,
		player_sprite_box.get_parent(),
		Callable(self, "_can_start_pvp_render_animation")
	)
	event_renderer.setup(
		battle_log_panel,
		mini_battle_feed,
		current_action_panel,
		animation_router,
		message_timing,
		self,
		Callable(self, "_set_active_hud_hp_from_event"),
		Callable(self, "_can_start_pvp_render_animation")
	)
	_setup_status_condition_overlays()
	_setup_mechanic_buttons()
	_setup_battle_log_initial_visibility()
	_update_battle_log_toggle_button()
	resized.connect(_queue_calc_drawer_layout_update)
	battle_frame.resized.connect(_queue_calc_drawer_layout_update)
	_queue_calc_drawer_layout_update()

	# Show Moves, Party or Bag
	_reset_action_choices()
	_reset_battle_effect_tracking()
	_reset_battle_status_panel()
	weather_presentation.update_weather("")
	weather_presentation.update_terrain("")
	weather_presentation.update_trick_room(false)
	current_action_panel.clear_message()
	battle_log_panel.clear_log()
	mini_battle_feed.clear()
	event_renderer.reset_battle_log_player_gap()
	calc_panel.set_defender_assumptions(damage_calc_defender_assumptions, damage_calc_assumption_edited_fields)
	calc_panel.show_idle()

	if PlayerSave.party.is_empty():
		return

func _setup_battle_ui_position() -> void:
	battle_drag_handle.move_to_front()
	if not battle_drag_handle.gui_input.is_connected(_on_battle_drag_handle_gui_input):
		battle_drag_handle.gui_input.connect(_on_battle_drag_handle_gui_input)
	var parent_control := get_parent_control()
	if parent_control == null:
		return
	if remembered_battle_ui_position == Vector2.INF:
		remembered_battle_ui_position = _load_battle_ui_position()
	var default_position := Vector2(
		(parent_control.size.x - size.x) * 0.5,
		(parent_control.size.y - size.y) * 0.5 - BATTLE_UI_DEFAULT_VERTICAL_OFFSET
	)
	position = remembered_battle_ui_position if remembered_battle_ui_position != Vector2.INF else default_position
	_clamp_battle_ui_position()
	if not parent_control.resized.is_connected(_on_battle_ui_host_resized):
		parent_control.resized.connect(_on_battle_ui_host_resized)

func _on_battle_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			battle_ui_dragging = true
			battle_ui_drag_offset = mouse_event.global_position - global_position
			_focus_battle_ui_layer()
		else:
			battle_ui_dragging = false
			_save_battle_ui_position()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and battle_ui_dragging:
		var parent_control := get_parent_control()
		if parent_control != null:
			position = parent_control.get_global_mouse_position() - parent_control.global_position - battle_ui_drag_offset
			_clamp_battle_ui_position()
		get_viewport().set_input_as_handled()

func _on_battle_ui_host_resized() -> void:
	_clamp_battle_ui_position()

func _clamp_battle_ui_position() -> void:
	var parent_control := get_parent_control()
	if parent_control == null:
		return
	position.x = clampf(position.x, BATTLE_UI_POSITION_MARGIN, maxf(parent_control.size.x - size.x - BATTLE_UI_POSITION_MARGIN, BATTLE_UI_POSITION_MARGIN))
	position.y = clampf(position.y, BATTLE_UI_POSITION_MARGIN, maxf(parent_control.size.y - size.y - BATTLE_UI_POSITION_MARGIN, BATTLE_UI_POSITION_MARGIN))

func _load_battle_ui_position() -> Vector2:
	if not FileAccess.file_exists(BATTLE_UI_POSITION_PATH):
		return Vector2.INF
	var file := FileAccess.open(BATTLE_UI_POSITION_PATH, FileAccess.READ)
	if file == null:
		return Vector2.INF
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		return Vector2.INF
	var position_data: Array = data.get("position", [])
	if position_data.size() != 2:
		return Vector2.INF
	return Vector2(float(position_data[0]), float(position_data[1]))

func _save_battle_ui_position() -> void:
	remembered_battle_ui_position = position
	var file := FileAccess.open(BATTLE_UI_POSITION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"position": [position.x, position.y]}))

func _focus_battle_ui_layer() -> void:
	get_tree().call_group("ui_overlay", "focus_battle_ui_layer")

func _setup_battle_focus_surfaces() -> void:
	_create_battle_scene_focus_surface()
	var focus_surfaces: Array[Control] = [
		battle_frame,
		battle_stage,
		battle_background,
		current_action_panel,
		action_side_panel,
		battle_party_rail,
		calc_panel,
		mechanics_panel,
		battle_log_panel,
	]
	for surface: Control in focus_surfaces:
		_register_battle_focus_surface(surface)

func _create_battle_scene_focus_surface() -> void:
	if battle_stage == null or battle_background == null:
		return

	var existing_surface: Control = battle_stage.get_node_or_null(^"BattleSceneFocusSurface") as Control
	if existing_surface != null:
		_register_battle_focus_surface(existing_surface)
		return

	var focus_surface: Control = Control.new()
	focus_surface.name = "BattleSceneFocusSurface"
	focus_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	focus_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_stage.add_child(focus_surface)
	battle_stage.move_child(focus_surface, battle_background.get_index() + 1)
	_register_battle_focus_surface(focus_surface)

func _register_battle_focus_surface(surface: Control) -> void:
	if surface == null:
		return

	if surface.name == "BattleSceneFocusSurface":
		surface.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		surface.mouse_filter = Control.MOUSE_FILTER_PASS
	var focus_callable: Callable = Callable(self, "_on_battle_focus_surface_gui_input")
	if not surface.gui_input.is_connected(focus_callable):
		surface.gui_input.connect(focus_callable)

func _on_battle_focus_surface_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_focus_battle_ui_layer()

func _setup_weather_presentation() -> void:
	weather_presentation.setup(
		weather_particles,
		weather_tint,
		battle_background,
		sun_rays,
		sun_sparkles,
		desolate_land_layer,
		primordial_sea_layer,
		delta_stream_layer,
		delta_stream_particles,
		sandstorm_particles,
		sandstorm_swirls,
		terrain_tint,
		grassy_terrain_layer,
		misty_terrain_layer,
		psychic_terrain_layer,
		electric_terrain_layer,
		trick_room_layer,
		snow_particles
	)

func _setup_side_condition_presentation() -> void:
	side_condition_presentation.setup(
		player_battle_platform,
		enemy_battle_platform,
		player_side_effects_panel,
		enemy_side_effects_panel
	)

func _on_settings_changed() -> void:
	_update_battle_status_panels()
	_update_active_sprites("settings_sprite_refresh")

func _process(delta: float) -> void:
	if hover_state.should_poll_sprite_hover():
		_update_sprite_hover()
	if pokemon_hover_card.visible:
		_position_pokemon_hover_card()
	if move_hover_card.visible:
		_position_move_hover_card()
	if party_hover_card.visible:
		_position_party_hover_card()
	weather_presentation.animate(delta)
	if _should_show_bank_timer_projection():
		vs_panel_container.show_decision_timers(
			PvpBattleRealtimeService.timer_projection.participant_display_for_local_player("p1", action_flow.local_player_id),
			PvpBattleRealtimeService.timer_projection.participant_display_for_local_player("p2", action_flow.local_player_id)
		)
	_request_pvp_team_preview_recovery_if_server_advanced()

func _connect_pokemon_hover_signals() -> void:
	if not player_sprite_box.has_method("get_single_sprite_slot"):
		return
	if not enemy_sprite_box.has_method("get_single_sprite_slot"):
		return

	var player_sprite_slot: Control = player_sprite_box.get_single_sprite_slot()
	player_sprite_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var enemy_sprite_slot: Control = enemy_sprite_box.get_single_sprite_slot()
	enemy_sprite_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _connect_move_hover_signals() -> void:
	if moves_grid.has_signal("move_hovered"):
		moves_grid.move_hovered.connect(_show_move_hover)
	if moves_grid.has_signal("move_unhovered"):
		moves_grid.move_unhovered.connect(_hide_move_hover)

func _connect_party_hover_signals() -> void:
	if player_party_grid.has_signal("pokemon_hovered"):
		player_party_grid.pokemon_hovered.connect(_show_party_hover)
	if player_party_grid.has_signal("pokemon_unhovered"):
		player_party_grid.pokemon_unhovered.connect(_hide_party_hover)
	if opponent_party_grid.has_signal("pokemon_hovered"):
		opponent_party_grid.pokemon_hovered.connect(_show_opponent_party_hover)
	if opponent_party_grid.has_signal("pokemon_unhovered"):
		opponent_party_grid.pokemon_unhovered.connect(_hide_hud_pokemon_hover)

func _show_opponent_party_hover(pokemon_data: Dictionary, _slot_rect: Rect2) -> void:
	_show_hud_pokemon_hover(pokemon_data)

func _connect_forfeit_confirm_dialog_signals() -> void:
	if forfeit_confirm_dialog.has_signal("confirmed"):
		forfeit_confirm_dialog.confirmed.connect(_on_forfeit_confirmed)
	if forfeit_confirm_dialog.has_signal("cancelled"):
		forfeit_confirm_dialog.cancelled.connect(_on_forfeit_cancelled)

func _show_move_hover(move_data: Dictionary, slot_rect: Rect2) -> void:
	current_move_hover_rect = slot_rect
	if move_hover_card.has_method("show_for_move"):
		move_hover_card.call("show_for_move", move_data)
	_position_move_hover_card()

func _hide_move_hover() -> void:
	current_move_hover_rect = Rect2()
	if move_hover_card.has_method("hide_card"):
		move_hover_card.call("hide_card")
	else:
		move_hover_card.visible = false

func _show_party_hover(pokemon_data: Dictionary, slot_rect: Rect2) -> void:
	if pokemon_data.is_empty():
		return

	_hide_pokemon_hover()
	current_party_hover_rect = slot_rect
	var hover_data := _get_owned_party_hover_data(pokemon_data)
	if party_hover_card.has_method("show_for_pokemon"):
		party_hover_card.call("show_for_pokemon", hover_data)
	else:
		party_hover_card.visible = true
	_position_party_hover_card()

func _hide_party_hover() -> void:
	current_party_hover_rect = Rect2()
	if party_hover_card.has_method("hide_card"):
		party_hover_card.call("hide_card")
	else:
		party_hover_card.visible = false

func _position_party_hover_card() -> void:
	if current_party_hover_rect.size != Vector2.ZERO and party_hover_card.has_method("position_near_rect"):
		party_hover_card.call("position_near_rect", current_party_hover_rect, get_viewport_rect().size)
	elif party_hover_card.has_method("position_near_mouse"):
		party_hover_card.call("position_near_mouse", get_global_mouse_position(), get_viewport_rect().size)

func _get_owned_party_hover_data(pokemon_data: Dictionary) -> Dictionary:
	var display_data: Dictionary = _get_display_pokemon_data("p1", pokemon_data).duplicate(true)
	var saved_pokemon := _get_player_save_pokemon_for_hover(display_data)
	if saved_pokemon == null:
		return display_data

	var hover_data := saved_pokemon.to_battle_dict()
	for key in [
		"ident",
		"active",
		"hp",
		"maxHp",
		"currentHp",
		"status",
		"condition",
		"fainted",
		"gender",
		"metadataSlot",
		"metadata_slot",
	]:
		if display_data.has(key):
			hover_data[key] = display_data.get(key)

	if not hover_data.has("hp") and hover_data.has("currentHp"):
		hover_data["hp"] = hover_data.get("currentHp")
	if not hover_data.has("maxHp") and hover_data.has("max_hp"):
		hover_data["maxHp"] = hover_data.get("max_hp")
	if not hover_data.has("hp"):
		hover_data["hp"] = saved_pokemon.current_hp
	if not hover_data.has("maxHp"):
		hover_data["maxHp"] = saved_pokemon.max_hp

	_apply_temporary_form_party_hover_data(hover_data, display_data, saved_pokemon)

	var stat_stages := _get_active_stat_stages_for_party_hover(display_data)
	if not stat_stages.is_empty():
		hover_data["statStages"] = stat_stages

	var moves: Array = _get_party_hover_moves(display_data, hover_data)
	if not moves.is_empty():
		hover_data["moves"] = moves

	return hover_data

func _apply_temporary_form_party_hover_data(
	hover_data: Dictionary,
	display_data: Dictionary,
	saved_pokemon: Pokemon
) -> void:
	var temporary_species := _get_party_hover_temporary_display_species(display_data)
	var primal_data := _get_primal_species_hover_data(temporary_species)
	if primal_data.is_empty():
		return

	hover_data["species"] = temporary_species
	hover_data["displaySpecies"] = temporary_species
	hover_data["types"] = primal_data.get("types", [])
	hover_data["ability"] = primal_data.get("ability", hover_data.get("ability", ""))
	hover_data["possibleAbilities"] = [primal_data.get("ability", "")]
	hover_data["stats"] = _calculate_battle_stats(
		primal_data.get("baseStats", {}),
		int(hover_data.get("level", saved_pokemon.level)),
		hover_data.get("ivs", saved_pokemon.ivs),
		hover_data.get("evs", saved_pokemon.evs),
		str(hover_data.get("nature", saved_pokemon.nature))
	)

func _get_party_hover_temporary_display_species(display_data: Dictionary) -> String:
	for key in ["megaSpecies", "transformedSpecies", "displaySpecies"]:
		var species := str(display_data.get(key, "")).strip_edges()
		if _is_primal_species(species):
			return species

	var ident := str(display_data.get("ident", "")).strip_edges()
	if ident != "" and battle_state != null:
		var persisted_species := battle_state.resolve_persisted_mega_species_for_ident(ident)
		if _is_primal_species(persisted_species):
			return persisted_species

	if bool(display_data.get("active", false)):
		var active_species := _get_active_display_species("p1")
		if _is_primal_species(active_species):
			return active_species

	return ""

func _is_primal_species(species: String) -> bool:
	var normalized_species := _normalize_species_for_compare(species)
	return normalized_species == "groudon-primal" or normalized_species == "kyogre-primal"

func _get_primal_species_hover_data(species: String) -> Dictionary:
	match _normalize_species_for_compare(species):
		"groudon-primal":
			return {
				"ability": "desolate-land",
				"types": ["ground", "fire"],
				"baseStats": {
					"hp": 100,
					"atk": 180,
					"def": 160,
					"spa": 150,
					"spd": 90,
					"spe": 90,
				},
			}
		"kyogre-primal":
			return {
				"ability": "primordial-sea",
				"types": ["water"],
				"baseStats": {
					"hp": 100,
					"atk": 150,
					"def": 90,
					"spa": 180,
					"spd": 160,
					"spe": 90,
				},
			}

	return {}

func _calculate_battle_stats(
	base_stats_value: Variant,
	level: int,
	ivs_value: Variant,
	evs_value: Variant,
	nature: String
) -> Dictionary:
	var base_stats: Dictionary = base_stats_value as Dictionary if base_stats_value is Dictionary else {}
	var ivs: Dictionary = ivs_value as Dictionary if ivs_value is Dictionary else {}
	var evs: Dictionary = evs_value as Dictionary if evs_value is Dictionary else {}
	var calculated_stats := {}

	for stat_key in ["hp", "atk", "def", "spa", "spd", "spe"]:
		var base_stat := int(base_stats.get(stat_key, 0))
		var iv := int(ivs.get(stat_key, 31))
		var ev := int(evs.get(stat_key, 0))
		var pre_nature := int(floor(float((2 * base_stat + iv + int(floor(float(ev) / 4.0))) * level) / 100.0))
		if stat_key == "hp":
			calculated_stats[stat_key] = pre_nature + level + 10
		else:
			calculated_stats[stat_key] = int(floor(float(pre_nature + 5) * _get_nature_stat_modifier(nature, stat_key)))

	return calculated_stats

func _get_nature_stat_modifier(nature: String, stat_key: String) -> float:
	var normalized_nature := nature.to_lower().strip_edges()
	var raised_stat := ""
	var lowered_stat := ""

	match normalized_nature:
		"lonely":
			raised_stat = "atk"
			lowered_stat = "def"
		"brave":
			raised_stat = "atk"
			lowered_stat = "spe"
		"adamant":
			raised_stat = "atk"
			lowered_stat = "spa"
		"naughty":
			raised_stat = "atk"
			lowered_stat = "spd"
		"bold":
			raised_stat = "def"
			lowered_stat = "atk"
		"relaxed":
			raised_stat = "def"
			lowered_stat = "spe"
		"impish":
			raised_stat = "def"
			lowered_stat = "spa"
		"lax":
			raised_stat = "def"
			lowered_stat = "spd"
		"timid":
			raised_stat = "spe"
			lowered_stat = "atk"
		"hasty":
			raised_stat = "spe"
			lowered_stat = "def"
		"jolly":
			raised_stat = "spe"
			lowered_stat = "spa"
		"naive":
			raised_stat = "spe"
			lowered_stat = "spd"
		"modest":
			raised_stat = "spa"
			lowered_stat = "atk"
		"mild":
			raised_stat = "spa"
			lowered_stat = "def"
		"quiet":
			raised_stat = "spa"
			lowered_stat = "spe"
		"rash":
			raised_stat = "spa"
			lowered_stat = "spd"
		"calm":
			raised_stat = "spd"
			lowered_stat = "atk"
		"gentle":
			raised_stat = "spd"
			lowered_stat = "def"
		"sassy":
			raised_stat = "spd"
			lowered_stat = "spe"
		"careful":
			raised_stat = "spd"
			lowered_stat = "spa"

	if stat_key == raised_stat:
		return 1.1
	if stat_key == lowered_stat:
		return 0.9
	return 1.0

func _get_party_hover_moves(display_data: Dictionary, fallback_data: Dictionary) -> Array:
	if bool(display_data.get("active", false)):
		var available_moves: Array = battle_state.get_available_moves("p1")
		if not available_moves.is_empty():
			return available_moves

	var cached_moves: Array = _get_cached_party_moves(display_data)
	if not cached_moves.is_empty():
		return cached_moves

	var display_moves_value: Variant = display_data.get("moves", [])
	if display_moves_value is Array:
		var display_moves: Array = display_moves_value as Array
		if not display_moves.is_empty():
			return _with_default_pp_for_moves(display_moves)

	var moves_value: Variant = fallback_data.get("moves", [])
	if moves_value is Array:
		return moves_value as Array

	return []

func _get_cached_party_moves(pokemon_data: Dictionary) -> Array:
	for key in _get_party_move_cache_keys(pokemon_data):
		var cached_value: Variant = player_party_moves_by_key.get(key, [])
		if cached_value is Array:
			var cached_moves: Array = cached_value as Array
			if not cached_moves.is_empty():
				return cached_moves.duplicate(true)

	return []

func _get_party_move_cache_keys(pokemon_data: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var instance_id: String = str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", ""))).strip_edges()
	if instance_id != "":
		keys.append("instance:%s" % instance_id)

	var ident_key: String = _normalize_battle_ident(str(pokemon_data.get("ident", "")))
	if ident_key != "":
		keys.append("ident:%s" % ident_key)

	var metadata_slot: int = int(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", -1)))
	if metadata_slot >= 0:
		keys.append("slot:%s" % metadata_slot)

	return keys

func _with_default_pp_for_moves(moves: Array) -> Array:
	var normalized_moves: Array = []
	for move_value in moves:
		if not (move_value is Dictionary):
			normalized_moves.append(move_value)
			continue

		var move_data: Dictionary = (move_value as Dictionary).duplicate(true)
		if not move_data.has("maxpp") and move_data.has("maxPp"):
			var base_max_pp: int = int(move_data.get("maxPp", 0))
			var current_pp: int = int(move_data.get("pp", base_max_pp))
			var used_pp: int = max(0, base_max_pp - current_pp)
			var max_pp: int = _calculate_max_pp(base_max_pp)
			move_data["maxpp"] = max_pp
			move_data["pp"] = max(0, max_pp - used_pp)
		elif not move_data.has("maxpp") and move_data.has("pp"):
			var max_pp: int = _calculate_max_pp(int(move_data.get("pp", 0)))
			move_data["maxpp"] = max_pp
			move_data["pp"] = max_pp

		normalized_moves.append(move_data)

	return normalized_moves

func _filter_public_opponent_hover_moves(moves: Array) -> Array:
	var public_moves: Array = []
	var normalized_moves := _with_max_pp_assumption_for_opponent_moves(moves)
	for move_value in normalized_moves:
		if not (move_value is Dictionary):
			continue

		var move_data: Dictionary = move_value as Dictionary
		if _hover_move_has_visible_pp_use(move_data):
			public_moves.append(move_data)

	return public_moves

func _with_max_pp_assumption_for_opponent_moves(moves: Array) -> Array:
	var normalized_moves: Array = []
	for move_value in moves:
		if not (move_value is Dictionary):
			continue

		var move_data: Dictionary = (move_value as Dictionary).duplicate(true)
		var current_pp := _get_hover_move_pp_value(move_data, ["pp", "currentPp", "currentPP", "current_pp"])
		var base_max_pp := _get_hover_move_pp_value(move_data, ["maxpp", "maxPp", "maxPP", "max_pp"])
		if current_pp < 0 or base_max_pp <= 0:
			normalized_moves.append(move_data)
			continue

		var used_pp: int = max(0, base_max_pp - current_pp)
		var assumed_max_pp: int = _calculate_max_pp(base_max_pp)
		move_data["maxpp"] = assumed_max_pp
		move_data["pp"] = max(0, assumed_max_pp - used_pp)
		normalized_moves.append(move_data)

	return normalized_moves

func _hover_move_has_visible_pp_use(move_data: Dictionary) -> bool:
	var current_pp := _get_hover_move_pp_value(move_data, ["pp", "currentPp", "currentPP", "current_pp"])
	var max_pp := _get_hover_move_pp_value(move_data, ["maxpp", "maxPp", "maxPP", "max_pp"])
	if current_pp < 0 or max_pp <= 0:
		return false

	return current_pp < max_pp

func _get_hover_move_pp_value(move_data: Dictionary, keys: Array[String]) -> int:
	for key in keys:
		if not move_data.has(key):
			continue

		var value: Variant = move_data.get(key)
		if value == null or str(value).strip_edges() == "":
			continue

		return int(value)

	return -1

func _calculate_max_pp(base_pp: int) -> int:
	if base_pp <= 1:
		return max(base_pp, 0)

	return int(floor(float(base_pp) * 1.6))

func _get_player_save_pokemon_for_hover(pokemon_data: Dictionary) -> Pokemon:
	return _get_player_save_pokemon_for_battle_display_data(pokemon_data)

func _get_player_save_pokemon_for_battle_display_data(pokemon_data: Dictionary, fallback_index := -1) -> Pokemon:
	var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", ""))).strip_edges()
	if instance_id != "":
		for pokemon in PlayerSave.party:
			if pokemon.instance_id == instance_id:
				return pokemon

	var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	if canonical_slot > 0:
		var slot_index := canonical_slot - 1
		if slot_index >= 0 and slot_index < PlayerSave.party.size():
			var slot_pokemon: Pokemon = PlayerSave.party[slot_index] as Pokemon
			return slot_pokemon

	if fallback_index >= 0 and fallback_index < PlayerSave.party.size():
		var fallback_pokemon: Pokemon = PlayerSave.party[fallback_index] as Pokemon
		if _saved_pokemon_matches_battle_species(fallback_pokemon, pokemon_data):
			return fallback_pokemon

	return _get_unique_player_save_pokemon_by_species(pokemon_data)

func _saved_pokemon_matches_battle_species(saved_pokemon: Pokemon, pokemon_data: Dictionary) -> bool:
	if saved_pokemon == null:
		return false
	if battle_state == null:
		return true

	var battle_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	if battle_species == "":
		return true

	return _saved_pokemon_species_is_compatible(saved_pokemon.species, battle_species)

func _get_unique_player_save_pokemon_by_species(pokemon_data: Dictionary) -> Pokemon:
	var display_species := ""
	if battle_state != null:
		display_species = battle_state.get_species_from_pokemon_data(pokemon_data)
	if display_species == "":
		display_species = str(pokemon_data.get("species", pokemon_data.get("displaySpecies", "")))

	var normalized_display_species := _normalize_species_for_compare(display_species)
	if normalized_display_species == "":
		return null

	var matched_pokemon: Pokemon = null
	for pokemon in PlayerSave.party:
		if not _saved_pokemon_species_is_compatible(pokemon.species, display_species):
			continue
		if matched_pokemon != null:
			return null
		matched_pokemon = pokemon

	return matched_pokemon


func _saved_pokemon_species_is_compatible(saved_species: String, battle_species: String) -> bool:
	var normalized_saved_species := _normalize_species_for_compare(saved_species)
	var normalized_battle_species := _normalize_species_for_compare(battle_species)
	if normalized_saved_species == "" or normalized_battle_species == "":
		return true
	if normalized_saved_species == normalized_battle_species:
		return true

	return _normalize_species_base_for_compare(normalized_saved_species) == _normalize_species_base_for_compare(normalized_battle_species)

func _position_move_hover_card() -> void:
	if current_move_hover_rect.size != Vector2.ZERO and move_hover_card.has_method("position_near_rect"):
		move_hover_card.call("position_near_rect", current_move_hover_rect, get_viewport_rect().size)
	elif move_hover_card.has_method("position_near_mouse"):
		move_hover_card.call("position_near_mouse", get_global_mouse_position(), get_viewport_rect().size)

func _update_sprite_hover() -> void:
	var hovered_player_id: String = _get_hovered_sprite_player_id()
	if hovered_player_id == hover_state.get_sprite_hover_player():
		return

	hover_state.set_sprite_hover_player(hovered_player_id)
	if hovered_player_id == "":
		_hide_pokemon_hover_card()
		_hide_party_hover()
		return

	_show_active_pokemon_hover(hovered_player_id)

func _get_hovered_sprite_player_id() -> String:
	var mouse_position: Vector2 = get_global_mouse_position()
	if player_sprite_box.has_method("is_mouse_over_single_sprite"):
		if bool(player_sprite_box.is_mouse_over_single_sprite(mouse_position)):
			return "p1"
	if enemy_sprite_box.has_method("is_mouse_over_single_sprite"):
		if bool(enemy_sprite_box.is_mouse_over_single_sprite(mouse_position)):
			return "p2"

	return ""

func _show_player_active_pokemon_hover() -> void:
	_show_active_pokemon_hover("p1")

func _show_enemy_active_pokemon_hover() -> void:
	_show_active_pokemon_hover("p2")

func _show_active_pokemon_hover(player_id: String) -> void:
	var pokemon_data: Dictionary = battle_state.get_active_player_pokemon(player_id)
	if pokemon_data.is_empty():
		return

	var source_pokemon_data: Dictionary = _get_team_pokemon_data_for_hover(player_id, pokemon_data)
	if source_pokemon_data.is_empty():
		source_pokemon_data = pokemon_data

	var display_pokemon_data: Dictionary = _get_display_pokemon_data(player_id, source_pokemon_data)
	await _show_pokemon_hover(pokemon_data, display_pokemon_data, player_id)

func _show_hud_pokemon_hover(pokemon_data: Dictionary) -> void:
	var hover_ident := str(pokemon_data.get("ident", ""))
	hover_state.begin_hud_hover(hover_ident)
	var player_id := _get_player_id_from_ident(hover_ident)
	if player_id == "":
		return

	var source_pokemon_data: Dictionary = _get_team_pokemon_data_for_hover(player_id, pokemon_data)
	if source_pokemon_data.is_empty():
		source_pokemon_data = pokemon_data

	var display_pokemon_data: Dictionary = _get_display_pokemon_data(player_id, source_pokemon_data)
	await _show_pokemon_hover(source_pokemon_data, display_pokemon_data, player_id)

func _hide_hud_pokemon_hover() -> void:
	hover_state.end_hud_hover()
	_hide_pokemon_hover()

func _show_pokemon_hover(
	request_pokemon_data: Dictionary,
	display_pokemon_data: Dictionary,
	hover_owner_player_id: String
) -> void:
	var hover_ident: String = str(request_pokemon_data.get("ident", ""))
	var hover_lookup_ident := _get_hover_info_lookup_ident(request_pokemon_data, hover_owner_player_id)
	var hover_api_ident := _get_raw_pvp_hover_ident(hover_lookup_ident)
	if hover_api_ident == "":
		hover_api_ident = hover_lookup_ident
	var request_token: int = hover_state.begin_hover_request()
	_debug_battle_move("hover begin owner=%s token=%s requestIdent=%s lookupIdent=%s apiIdent=%s requestSpecies=%s displayIdent=%s displaySpecies=%s viewerOverride=%s requestPokemon=%s displayPokemon=%s" % [
		hover_owner_player_id,
		str(request_token),
		hover_ident,
		hover_lookup_ident,
		hover_api_ident,
		battle_state.get_species_from_pokemon_data(request_pokemon_data),
		str(display_pokemon_data.get("ident", "")),
		battle_state.get_species_from_pokemon_data(display_pokemon_data),
		_get_raw_pvp_hover_viewer_id(),
		JSON.stringify(request_pokemon_data),
		JSON.stringify(display_pokemon_data),
	])
	var hover_info_request := HTTPRequest.new()
	var hover_stats_request := HTTPRequest.new()
	add_child(hover_info_request)
	add_child(hover_stats_request)
	var hover_data: Dictionary = await pokemon_hover_service.get_hover_card_data(
		battle_state,
		hover_info_request,
		hover_stats_request,
		request_pokemon_data,
		public_confirmed_abilities_by_ident,
		public_confirmed_items_by_ident,
		_get_raw_pvp_hover_viewer_id(),
		hover_api_ident,
		battle_state.get_species_from_pokemon_data(display_pokemon_data)
	)
	if is_instance_valid(hover_info_request):
		hover_info_request.queue_free()
	if is_instance_valid(hover_stats_request):
		hover_stats_request.queue_free()
	if not hover_state.is_hover_request_current(request_token, hover_ident, hover_owner_player_id):
		_debug_battle_move("hover dropped stale owner=%s token=%s requestIdent=%s hoverData=%s" % [
			hover_owner_player_id,
			str(request_token),
			hover_ident,
			JSON.stringify(hover_data),
		])
		return
	if not _hover_data_matches_pokemon_request(hover_data, request_pokemon_data):
		_debug_battle_move("hover dropped mismatch owner=%s token=%s requestIdent=%s hoverData=%s requestPokemon=%s" % [
			hover_owner_player_id,
			str(request_token),
			hover_ident,
			JSON.stringify(hover_data),
			JSON.stringify(request_pokemon_data),
		])
		return

	var confirmed_moves: Array = hover_data.get("confirmed_moves", [])
	var confirmed_item: String = str(hover_data.get("confirmed_item", ""))
	var confirmed_ability: String = str(hover_data.get("confirmed_ability", ""))
	var stat_changes: Dictionary = hover_data.get("stat_changes", {})
	var speed_data: Dictionary = hover_data.get("speed_data", {})
	var species_metadata: Dictionary = hover_data.get("species_metadata", {})
	_debug_battle_move("pokemon-info parsed player=%s moves=%s item=%s ability=%s statChanges=%s speed=%s info=%s" % [
		hover_owner_player_id,
		JSON.stringify(confirmed_moves),
		confirmed_item,
		confirmed_ability,
		JSON.stringify(stat_changes),
		JSON.stringify(speed_data),
		JSON.stringify(hover_data.get("pokemon_info", {})),
	])
	var display_data: Dictionary = display_pokemon_data.duplicate()
	display_data["ident"] = str(request_pokemon_data.get("ident", ""))
	_apply_hover_species_metadata(display_data, species_metadata)
	var display_species := battle_state.get_species_from_pokemon_data(display_pokemon_data)
	if display_species != "":
		display_data["species"] = display_species
		display_data["displaySpecies"] = display_species

	var local_hover_owner := _get_local_state_player_id()
	var is_local_hover_owner := hover_owner_player_id == local_hover_owner
	if is_local_hover_owner:
		var own_hover_moves := _get_own_pokemon_hover_moves(hover_owner_player_id, display_data)
		if not own_hover_moves.is_empty():
			confirmed_moves = own_hover_moves
			_debug_battle_move("hover own moves override owner=%s localStateOwner=%s rawLocalOwner=%s displayIdent=%s moves=%s" % [
				hover_owner_player_id,
				local_hover_owner,
				action_flow.local_player_id,
				str(display_data.get("ident", "")),
				JSON.stringify(confirmed_moves),
			])
	else:
		confirmed_moves = _filter_public_opponent_hover_moves(confirmed_moves)
		display_data.erase("moves")
		display_data.erase("moveSlots")
		display_data.erase("baseMoves")
		_debug_battle_move("hover opponent privacy strip owner=%s localStateOwner=%s rawLocalOwner=%s displayIdent=%s confirmedMoves=%s" % [
			hover_owner_player_id,
			local_hover_owner,
			action_flow.local_player_id,
			str(display_data.get("ident", "")),
			JSON.stringify(confirmed_moves),
		])

	if pokemon_hover_card.has_method("show_for_pokemon"):
		_debug_battle_move("hover render owner=%s localStateOwner=%s rawLocalOwner=%s displayIdent=%s displaySpecies=%s confirmedMoves=%s confirmedAbility=%s confirmedItem=%s" % [
			hover_owner_player_id,
			local_hover_owner,
			action_flow.local_player_id,
			str(display_data.get("ident", "")),
			battle_state.get_species_from_pokemon_data(display_data),
			JSON.stringify(confirmed_moves),
			confirmed_ability,
			confirmed_item,
		])
		pokemon_hover_card.call(
			"show_for_pokemon",
			display_data,
			confirmed_moves,
			confirmed_item,
			confirmed_ability,
			stat_changes,
			speed_data
		)
		_position_pokemon_hover_card()

func _apply_hover_species_metadata(display_data: Dictionary, species_metadata: Dictionary) -> void:
	if species_metadata.is_empty():
		return

	for key in ["species", "types", "possibleAbilities"]:
		if species_metadata.has(key):
			display_data[key] = species_metadata.get(key)

	var species := str(species_metadata.get("species", ""))
	if species != "":
		display_data["displaySpecies"] = species

func _get_player_team_pokemon_data(player_id: String, ident: String) -> Dictionary:
	for pokemon_value in battle_state.get_player_team(player_id):
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if str(pokemon_data.get("ident", "")) == ident:
			return pokemon_data

	return {}

func _get_team_pokemon_data_for_hover(player_id: String, pokemon_data: Dictionary) -> Dictionary:
	var hover_ident: String = str(pokemon_data.get("ident", ""))
	if hover_ident != "":
		var team_pokemon_data: Dictionary = _get_player_team_pokemon_data(player_id, hover_ident)
		if not team_pokemon_data.is_empty():
			return team_pokemon_data

	var hover_instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", "")))
	if hover_instance_id != "":
		for pokemon_value in battle_state.get_player_team(player_id):
			if not (pokemon_value is Dictionary):
				continue

			var team_pokemon_data: Dictionary = pokemon_value as Dictionary
			var team_instance_id := str(team_pokemon_data.get("instanceId", team_pokemon_data.get("instance_id", "")))
			if team_instance_id == hover_instance_id:
				return team_pokemon_data

	var metadata_slot: int = int(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", 0)))
	if metadata_slot > 0:
		for pokemon_value in battle_state.get_player_team(player_id):
			if not (pokemon_value is Dictionary):
				continue

			var team_pokemon_data: Dictionary = pokemon_value as Dictionary
			if int(team_pokemon_data.get("metadataSlot", team_pokemon_data.get("metadata_slot", 0))) == metadata_slot:
				return team_pokemon_data

	return {}

func _hover_data_matches_pokemon_request(hover_data: Dictionary, pokemon_data: Dictionary) -> bool:
	var requested_ident := str(hover_data.get("requested_ident", ""))
	var current_ident := str(pokemon_data.get("ident", ""))
	if requested_ident != current_ident:
		return false

	var pokemon_info_value: Variant = hover_data.get("pokemon_info", {})
	if pokemon_info_value is Dictionary:
		var pokemon_info: Dictionary = pokemon_info_value as Dictionary
		var response_ident := str(pokemon_info.get("ident", ""))
		if response_ident != "" and not _hover_response_ident_matches_pokemon_request(response_ident, hover_data, pokemon_data):
			_debug_battle_move("hover response ident mismatch current=%s lookup=%s responseIdent=%s info=%s" % [
				current_ident,
				str(hover_data.get("requested_lookup_ident", "")),
				response_ident,
				JSON.stringify(pokemon_info),
			])
			return false

	var requested_species := str(hover_data.get("requested_species", ""))
	var current_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	if requested_species == "" or current_species == "":
		return true

	return _normalize_species_for_compare(requested_species) == _normalize_species_for_compare(current_species)

func _get_own_pokemon_hover_moves(player_id: String, pokemon_data: Dictionary) -> Array:
	if _is_hover_pokemon_active(player_id, pokemon_data):
		var available_moves: Array = battle_state.get_available_moves(player_id)
		if not available_moves.is_empty():
			return available_moves

	var cached_moves: Array = _get_cached_party_moves(pokemon_data)
	if not cached_moves.is_empty():
		return cached_moves

	var moves_value: Variant = pokemon_data.get("moves", [])
	if moves_value is Array:
		var moves: Array = moves_value as Array
		if not moves.is_empty():
			return _with_default_pp_for_moves(moves)

	return []

func _is_hover_pokemon_active(player_id: String, pokemon_data: Dictionary) -> bool:
	if bool(pokemon_data.get("active", false)):
		return true

	var active_slot := _get_active_canonical_party_slot(player_id)
	return active_slot > 0 and _get_pokemon_data_canonical_party_slot(pokemon_data) == active_slot

func _hover_response_ident_matches_pokemon_request(response_ident: String, hover_data: Dictionary, pokemon_data: Dictionary) -> bool:
	var normalized_response := _normalize_battle_ident(response_ident)
	var requested_lookup_ident := str(hover_data.get("requested_lookup_ident", "")).strip_edges()
	if requested_lookup_ident != "" and normalized_response == _normalize_battle_ident(requested_lookup_ident):
		return true

	var current_ident := str(pokemon_data.get("ident", "")).strip_edges()
	if current_ident != "" and normalized_response == _normalize_battle_ident(current_ident):
		return true

	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	if _is_pokemon_info_slot_key(pokemon_key) and normalized_response == _normalize_battle_ident(pokemon_key):
		return true

	var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	var player_id := _get_player_id_from_ident(current_ident)
	if canonical_slot > 0 and (player_id == "p1" or player_id == "p2"):
		var canonical_key := "%s:slot:%d" % [player_id, canonical_slot]
		return normalized_response == _normalize_battle_ident(canonical_key)

	return false

func _get_raw_pvp_hover_viewer_id() -> String:
	if not _is_pvp_battle():
		return ""

	return action_flow.local_player_id

func _get_hover_info_lookup_ident(pokemon_data: Dictionary, hover_owner_player_id: String) -> String:
	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	if _is_pokemon_info_slot_key(pokemon_key):
		return pokemon_key

	var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	var player_id := hover_owner_player_id.strip_edges()
	if player_id == "":
		player_id = _get_player_id_from_ident(str(pokemon_data.get("ident", "")))
	if canonical_slot > 0 and (player_id == "p1" or player_id == "p2"):
		return "%s:slot:%d" % [player_id, canonical_slot]

	return str(pokemon_data.get("ident", "")).strip_edges()

func _is_pokemon_info_slot_key(value: String) -> bool:
	var cleaned := value.strip_edges()
	if not (cleaned.begins_with("p1:slot:") or cleaned.begins_with("p2:slot:")):
		return false

	var slot_text := cleaned.split(":slot:")[1]
	var slot := _safe_int(slot_text, -1)
	return slot > 0 and slot <= 6

func _get_raw_pvp_hover_ident(display_ident: String) -> String:
	var normalized_ident := display_ident.strip_edges()
	if not _is_pvp_battle():
		return ""
	if action_flow.local_player_id != "p2":
		return normalized_ident

	if normalized_ident.begins_with("p1"):
		return "p2%s" % normalized_ident.substr(2)
	if normalized_ident.begins_with("p2"):
		return "p1%s" % normalized_ident.substr(2)

	return normalized_ident

func _normalize_species_for_compare(species: String) -> String:
	return species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")


func _normalize_species_base_for_compare(species: String) -> String:
	var normalized_species := _normalize_species_for_compare(species)
	for suffix in [
		"-alola", "-galar", "-hisui", "-paldea",
		"-therian", "-incarnate", "-origin", "-altered",
		"-wash", "-heat", "-frost", "-fan", "-mow",
		"-sky", "-land", "-blade", "-shield",
	]:
		if normalized_species.ends_with(suffix):
			return normalized_species.substr(0, normalized_species.length() - suffix.length())

	return normalized_species

func _hide_pokemon_hover() -> void:
	hover_state.invalidate_hover()
	_hide_pokemon_hover_card()

func _position_pokemon_hover_card() -> void:
	if pokemon_hover_card.has_method("position_near_mouse"):
		pokemon_hover_card.call("position_near_mouse", get_global_mouse_position(), get_viewport_rect().size)

func _hide_pokemon_hover_card() -> void:
	if pokemon_hover_card.has_method("hide_card"):
		pokemon_hover_card.call("hide_card")
	else:
		pokemon_hover_card.visible = false

func _setup_mechanic_buttons() -> void:
	_apply_mechanic_orb_style()
	for button in mechanic_buttons:
		button.disabled = true
		button.modulate = Color(0.45, 0.45, 0.45, 0.65)
		button.self_modulate = Color.WHITE
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		button.tooltip_text = "Not implemented yet"
		if not button.mouse_entered.is_connected(_on_mechanic_button_mouse_entered.bind(button)):
			button.mouse_entered.connect(_on_mechanic_button_mouse_entered.bind(button))
		if not button.mouse_exited.is_connected(_on_mechanic_button_mouse_exited.bind(button)):
			button.mouse_exited.connect(_on_mechanic_button_mouse_exited.bind(button))
	if mega_evolution_button != null:
		mega_evolution_button.pressed.connect(_on_mega_evolution_pressed)
		mega_evolution_button.tooltip_text = "Mega Evolution"
	_update_mechanic_button_states()

func _apply_mechanic_orb_style() -> void:
	mechanic_orb_style = StyleBoxFlat.new()
	mechanic_orb_style.bg_color = Color(0.008, 0.022, 0.055, 0.9)
	mechanic_orb_style.border_width_left = 1
	mechanic_orb_style.border_width_top = 1
	mechanic_orb_style.border_width_right = 1
	mechanic_orb_style.border_width_bottom = 1
	mechanic_orb_style.border_color = Color(0.196, 0.816, 1.0, 0.95)
	mechanic_orb_style.corner_radius_top_left = 36
	mechanic_orb_style.corner_radius_top_right = 36
	mechanic_orb_style.corner_radius_bottom_right = 36
	mechanic_orb_style.corner_radius_bottom_left = 36
	mechanic_orb_style.shadow_color = Color(0.078, 0.722, 1.0, 0.42)
	mechanic_orb_style.shadow_size = 7
	mechanic_orb_style.shadow_offset = Vector2(0, 1)
	mechanics_panel.add_theme_stylebox_override("panel", mechanic_orb_style)
	mechanics_panel.custom_minimum_size = Vector2(68.0, 68.0)
	mechanics_panel.position = Vector2(550.0, 458.0)
	mechanics_panel.size = Vector2(68.0, 68.0)
	var mechanics_margin := mechanics_panel.get_child(0) as MarginContainer
	if mechanics_margin != null:
		for margin_name: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			mechanics_margin.add_theme_constant_override(margin_name, 6)
	var mechanics_buttons := %MechanicsButtons as HBoxContainer
	if mechanics_buttons != null:
		mechanics_buttons.add_theme_constant_override("separation", 8)
	for button: TextureButton in mechanic_buttons:
		button.custom_minimum_size = Vector2(52.0, 52.0)
	mega_mechanic_label = _create_mechanic_overlay_label(mega_evolution_button, "MEGA")

func _create_mechanic_overlay_label(button: TextureButton, text: String) -> Label:
	var label := Label.new()
	label.name = "%sLabel" % text.capitalize()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_top = 31.0
	label.offset_bottom = -1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.005, 0.015, 0.04, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.15, 0.82, 1.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 5)
	button.add_child(label)
	button.move_child(label, button.get_child_count() - 1)
	return label

func _on_mechanic_button_mouse_entered(button: TextureButton) -> void:
	if button == null or button.disabled or not button.visible:
		return
	button.pivot_offset = button.size * 0.5
	var hover_tween := button.create_tween().set_parallel()
	hover_tween.tween_property(
		button,
		"self_modulate",
		Color(1.35, 1.35, 1.35, 1.0),
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if button != mega_evolution_button or not mega_evolution_selected:
		hover_tween.tween_property(button, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mechanic_button_mouse_exited(button: TextureButton) -> void:
	if button == null:
		return
	var hover_tween := button.create_tween().set_parallel()
	hover_tween.tween_property(
		button,
		"self_modulate",
		Color.WHITE,
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if button != mega_evolution_button or not mega_evolution_selected:
		hover_tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mega_evolution_pressed() -> void:
	_focus_battle_ui_layer()
	if not _can_toggle_mega_evolution():
		return

	mega_evolution_selected = not mega_evolution_selected
	_update_mechanic_button_states()
	if mega_evolution_selected:
		current_action_panel.set_message("Mega Evolution ready. Choose a move!")
	elif current_action_view == ActionView.MOVES:
		_show_current_action_prompt()

func _clear_mega_evolution_selection() -> void:
	if not mega_evolution_selected:
		return

	mega_evolution_selected = false
	_update_mechanic_button_states()

func _can_toggle_mega_evolution() -> bool:
	var local_state_player_id := _get_local_state_player_id()
	return (
		battle_actions_ready
		and not battle_input_locked
		and not battle_finished
		and not team_preview_lead_selection_active
		and not force_switch_flow.player_needs_force_switch(local_state_player_id)
		and battle_state.can_active_pokemon_mega_evolve(local_state_player_id)
	)

func _get_local_state_player_id() -> String:
	if not _is_pvp_battle():
		return action_flow.local_player_id

	return "p1" if action_flow.local_player_id == "p2" else action_flow.local_player_id

func _get_opponent_state_player_id() -> String:
	var local_state_player_id := _get_local_state_player_id()
	return "p2" if local_state_player_id == "p1" else "p1"

func _update_mechanic_button_states() -> void:
	if mega_evolution_button == null:
		return

	var can_use_mega := _can_toggle_mega_evolution()
	mega_evolution_button.visible = can_use_mega
	mechanics_panel.visible = (
		current_action_panel_mode == BattleActionsPanelMode.BATTLE
		and can_use_mega
	)
	mega_evolution_button.disabled = not can_use_mega
	mega_evolution_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if can_use_mega else Control.CURSOR_FORBIDDEN
	)
	if not can_use_mega:
		mega_evolution_selected = false
		mega_evolution_button.modulate = Color(0.45, 0.45, 0.45, 0.65)
		mega_evolution_button.tooltip_text = "Mega Evolution unavailable"
		_stop_mega_evolution_pulse()
	elif mega_evolution_selected:
		mechanic_orb_style.border_color = Color(1.0, 0.78, 0.24, 1.0)
		mechanic_orb_style.shadow_color = Color(0.8, 0.32, 1.0, 0.55)
		mega_mechanic_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.42, 1.0))
		mega_mechanic_label.add_theme_color_override("font_shadow_color", Color(0.86, 0.25, 1.0, 1.0))
		mega_evolution_button.modulate = Color(1.0, 0.82, 0.2, 1.0)
		mega_evolution_button.tooltip_text = "Mega Evolution ready"
		_start_mega_evolution_pulse()
	else:
		mechanic_orb_style.border_color = Color(0.196, 0.816, 1.0, 0.95)
		mechanic_orb_style.shadow_color = Color(0.078, 0.722, 1.0, 0.42)
		mega_mechanic_label.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 1.0))
		mega_mechanic_label.add_theme_color_override("font_shadow_color", Color(0.15, 0.82, 1.0, 0.95))
		mega_evolution_button.modulate = Color(1.0, 1.0, 1.0, 0.95)
		mega_evolution_button.tooltip_text = "Mega Evolution"
		_stop_mega_evolution_pulse()

func _start_mega_evolution_pulse() -> void:
	if mega_evolution_button == null:
		return
	if mega_evolution_pulse_tween != null and mega_evolution_pulse_tween.is_valid():
		return

	mega_evolution_button.pivot_offset = mega_evolution_button.size * 0.5
	mega_evolution_button.scale = Vector2(1.06, 1.06)
	mega_evolution_pulse_tween = create_tween()
	mega_evolution_pulse_tween.set_loops()
	mega_evolution_pulse_tween.tween_property(
		mega_evolution_button,
		"scale",
		Vector2(1.18, 1.18),
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mega_evolution_pulse_tween.tween_property(
		mega_evolution_button,
		"scale",
		Vector2(1.06, 1.06),
		0.35
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_mega_evolution_pulse() -> void:
	if mega_evolution_pulse_tween != null and mega_evolution_pulse_tween.is_valid():
		mega_evolution_pulse_tween.kill()
	mega_evolution_pulse_tween = null
	if mega_evolution_button != null:
		mega_evolution_button.scale = Vector2.ONE

func _input(event: InputEvent) -> void:
	if _try_focus_battle_from_background_click(event):
		return

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _close_visible_battle_drawer():
		get_viewport().set_input_as_handled()
		return

	if _is_ui_typing():
		return

	if event.is_action_pressed("battle_run"):
		_focus_battle_ui_layer()
		if not battle_actions_ready:
			if not _is_pvp_battle():
				_queue_battle_action("run")
			return

		_try_run()
		return

	if event.is_action_pressed("battle_move_1"):
		_focus_battle_ui_layer()
		if not battle_actions_ready:
			_queue_battle_action("move", 1)
			return

		_try_select_move(1)
		return
	if event.is_action_pressed("battle_move_2"):
		_focus_battle_ui_layer()
		if not battle_actions_ready:
			_queue_battle_action("move", 2)
			return

		_try_select_move(2)
		return
	if event.is_action_pressed("battle_move_3"):
		_focus_battle_ui_layer()
		if not battle_actions_ready:
			_queue_battle_action("move", 3)
			return

		_try_select_move(3)
		return
	if event.is_action_pressed("battle_move_4"):
		_focus_battle_ui_layer()
		if not battle_actions_ready:
			_queue_battle_action("move", 4)
			return

		_try_select_move(4)
		return

func _try_focus_battle_from_background_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return false

	if not _is_point_inside_battle_scene(mouse_event.global_position):
		return false

	if _is_point_over_visible_overlay_ui(mouse_event.global_position):
		return false

	_focus_battle_ui_layer()
	return true

func _is_point_inside_battle_scene(global_position: Vector2) -> bool:
	if battle_stage != null and battle_stage.get_global_rect().has_point(global_position):
		return true

	if battle_background != null and battle_background.get_global_rect().has_point(global_position):
		return true

	return battle_frame != null and battle_frame.get_global_rect().has_point(global_position)

func _is_point_over_visible_overlay_ui(global_position: Vector2) -> bool:
	if mini_battle_feed != null and mini_battle_feed.visible and mini_battle_feed.get_global_rect().has_point(global_position):
		return true

	for node: Node in get_tree().get_nodes_in_group("ui_overlay"):
		if node != null and node.has_method("is_point_over_visible_ui"):
			if bool(node.call("is_point_over_visible_ui", global_position)):
				return true

	return false

func _on_battle_mode_button_pressed() -> void:
	_focus_battle_ui_layer()
	_set_action_panel_mode(BattleActionsPanelMode.BATTLE)

func _on_calc_mode_button_pressed() -> void:
	_focus_battle_ui_layer()
	_set_action_panel_mode(BattleActionsPanelMode.CALC)

func _on_bag_drawer_close_pressed() -> void:
	_focus_battle_ui_layer()
	bag_inventory_request_token += 1
	if battle_finished:
		current_action_view = ActionView.NONE
		_sync_action_panel_mode_visibility()
		return
	# Close the drawer before restoring the contextual battle view. _show_moves()
	# may legitimately redirect or return early during waits and forced switches;
	# leaving BAG active in those paths would make the close button appear broken.
	current_action_view = ActionView.MOVES
	_sync_action_panel_mode_visibility()
	_show_moves()

func _on_calc_drawer_close_pressed() -> void:
	_focus_battle_ui_layer()
	_set_action_panel_mode(BattleActionsPanelMode.BATTLE)

func _close_visible_battle_drawer() -> bool:
	if calc_drawer.visible:
		_on_calc_drawer_close_pressed()
		return true
	if bag_drawer.visible:
		_on_bag_drawer_close_pressed()
		return true
	return false

func _set_action_panel_mode(mode: BattleActionsPanelMode) -> void:
	var previous_mode := current_action_panel_mode
	current_action_panel_mode = mode
	if previous_mode == BattleActionsPanelMode.CALC and mode != BattleActionsPanelMode.CALC:
		damage_calc_request_token += 1
		damage_calc_catalog_request_token += 1
		calc_panel.close_assumption_popover()
	_sync_action_panel_mode_visibility()
	if mode == BattleActionsPanelMode.CALC:
		_refresh_damage_calc_results()

func _sync_action_panel_mode_visibility() -> void:
	var is_calc_mode := current_action_panel_mode == BattleActionsPanelMode.CALC
	var is_bag_view := current_action_view == ActionView.BAG
	if is_calc_mode:
		_update_calc_drawer_layout()
	if is_calc_mode or is_bag_view:
		battle_drawer_layer.move_to_front()
	battle_mode_button.button_pressed = not is_calc_mode
	calc_mode_button.button_pressed = is_calc_mode
	calc_log_button.button_pressed = is_calc_mode
	calc_panel.visible = is_calc_mode
	calc_drawer.visible = is_calc_mode
	var show_pvp_switch_confirmation := (
		_is_pvp_battle()
		and pvp_switch_confirmation_active
		and not is_calc_mode
		and not is_bag_view
	)
	pvp_switch_confirmation_label.visible = show_pvp_switch_confirmation
	bag_grid.visible = not is_calc_mode and is_bag_view
	bag_drawer.visible = not is_calc_mode and is_bag_view
	action_buttons.visible = not is_calc_mode
	mechanics_panel.visible = not is_calc_mode and mega_evolution_button.visible
	player_party_grid.visible = not show_pvp_switch_confirmation
	opponent_party_grid.visible = true
	if is_calc_mode:
		moves_grid.visible = false
		context_hint.visible = false
		_hide_party_hover()
		_hide_move_hover()
		_sync_party_rail_interaction()
		return

	match current_action_view:
		ActionView.MOVES:
			moves_grid.visible = true
			context_hint.visible = false
		ActionView.PARTY:
			moves_grid.visible = false
			context_hint.visible = false
		ActionView.BAG:
			moves_grid.visible = false
			context_hint.visible = false
		_:
			moves_grid.visible = false
			context_hint.visible = false

	_sync_party_rail_interaction()

func _show_pvp_switch_confirmation(incoming_name: String, replaced_name: String) -> void:
	if not _is_pvp_battle():
		return
	var safe_incoming := incoming_name.strip_edges() if incoming_name.strip_edges() != "" else "Pokemon"
	var safe_replaced := replaced_name.strip_edges() if replaced_name.strip_edges() != "" else "Pokemon"
	pvp_switch_confirmation_active = true
	pvp_switch_confirmation_label.text = "%s will switch in, replacing %s." % [safe_incoming, safe_replaced]
	_hide_party_hover()
	_sync_action_panel_mode_visibility()

func _show_pvp_lead_confirmation(lead_name: String) -> void:
	if not _is_pvp_battle():
		return
	var safe_lead_name := lead_name.strip_edges() if lead_name.strip_edges() != "" else "Pokemon"
	pvp_switch_confirmation_active = true
	pvp_switch_confirmation_label.text = "%s will lead." % safe_lead_name
	_hide_party_hover()
	_sync_action_panel_mode_visibility()

func _show_pvp_move_confirmation(pokemon_name: String, move_name: String) -> void:
	if not _is_pvp_battle():
		return
	var safe_pokemon_name := pokemon_name.strip_edges() if pokemon_name.strip_edges() != "" else "Pokemon"
	var safe_move_name := move_name.strip_edges() if move_name.strip_edges() != "" else "its selected move"
	pvp_switch_confirmation_active = true
	pvp_switch_confirmation_label.text = "%s will use %s." % [safe_pokemon_name, safe_move_name]
	_hide_party_hover()
	_sync_action_panel_mode_visibility()

func _clear_pvp_switch_confirmation() -> void:
	pvp_switch_confirmation_active = false
	pvp_switch_confirmation_label.visible = false

func _get_switch_confirmation_pokemon_name(pokemon_data: Dictionary) -> String:
	for key: String in ["displaySpecies", "displayName", "nickname", "name", "species"]:
		var value := str(pokemon_data.get(key, "")).strip_edges()
		if value != "":
			return value
	return "Pokemon"

func _get_move_confirmation_name(move_data: Dictionary) -> String:
	for key: String in ["name", "displayName", "move", "id"]:
		var value := str(move_data.get(key, "")).strip_edges()
		if value != "":
			return value
	return "its selected move"

## Houdt de calculator boven uitsluitend de spelershelft van het battlefield.
## Daardoor blijven de battle log, tegenstander en move-informatie bereikbaar.
func _queue_calc_drawer_layout_update() -> void:
	call_deferred("_update_calc_drawer_layout")

func _update_calc_drawer_layout() -> void:
	if not is_instance_valid(calc_drawer) or not is_instance_valid(battle_frame):
		return
	var frame_rect: Rect2 = battle_frame.get_global_rect()
	var drawer_layer_inverse: Transform2D = battle_drawer_layer.get_global_transform().affine_inverse()
	var local_top_left: Vector2 = drawer_layer_inverse * frame_rect.position
	var local_bottom_right: Vector2 = drawer_layer_inverse * frame_rect.end
	var frame_size: Vector2 = local_bottom_right - local_top_left
	calc_drawer.position = local_top_left + Vector2(CALC_DRAWER_FIELD_MARGIN, CALC_DRAWER_FIELD_MARGIN)
	calc_drawer.size = Vector2(
		frame_size.x * CALC_DRAWER_FIELD_WIDTH_RATIO - CALC_DRAWER_FIELD_MARGIN * 2.0,
		frame_size.y - CALC_DRAWER_FIELD_MARGIN * 2.0
	)

func _sync_party_rail_interaction() -> void:
	if player_party_grid == null:
		return

	var was_selectable := player_party_grid.is_selection_enabled()
	var party_selection_active := _is_party_rail_selection_allowed()
	player_party_grid.set_selection_enabled(party_selection_active)
	opponent_party_grid.set_selection_enabled(false)

	if party_selection_active:
		var explicit_party_selection := current_action_view == ActionView.PARTY
		party_rail_state_label.text = "Select a Pokemon" if explicit_party_selection else "Select to switch"
		party_rail_state_label.add_theme_color_override("font_color", Color(0.38431373, 0.84313726, 1.0, 1.0))
		if explicit_party_selection and not was_selectable:
			player_party_grid.call_deferred("focus_first_selectable")
	elif battle_finished:
		party_rail_state_label.text = "Battle complete"
		party_rail_state_label.remove_theme_color_override("font_color")
	elif battle_input_locked:
		party_rail_state_label.text = "Waiting..."
		party_rail_state_label.remove_theme_color_override("font_color")
	else:
		party_rail_state_label.text = "Party status"
		party_rail_state_label.remove_theme_color_override("font_color")

func _is_party_rail_selection_allowed() -> bool:
	var explicit_party_selection := current_action_view == ActionView.PARTY
	var normal_turn_direct_switch := (
		battle_actions_ready
		and current_action_view != ActionView.BAG
	)
	return PartyGrid.should_allow_selection(
		current_action_panel_mode == BattleActionsPanelMode.BATTLE,
		explicit_party_selection or normal_turn_direct_switch,
		battle_input_locked,
		battle_finished
	)

func _refresh_damage_calc_results() -> void:
	if current_action_panel_mode != BattleActionsPanelMode.CALC:
		return
	_sync_damage_calc_matchup_assumptions()
	_apply_known_damage_calc_defender_info()
	if battle_finished:
		calc_panel.show_error("Battle has ended.")
		return
	if battle_state.battle_id.strip_edges() == "":
		calc_panel.show_error("Battle is not ready yet.")
		return

	if damage_calc_request_in_flight:
		damage_calc_refresh_queued = true
		calc_panel.set_defender_assumptions(damage_calc_defender_assumptions, damage_calc_assumption_edited_fields)
		calc_panel.show_loading(_get_active_display_species("p1"), _get_active_display_species("p2"))
		return

	damage_calc_request_token += 1
	var request_token := damage_calc_request_token
	damage_calc_request_in_flight = true
	damage_calc_refresh_queued = false
	calc_panel.set_defender_assumptions(damage_calc_defender_assumptions, damage_calc_assumption_edited_fields)
	calc_panel.show_loading(_get_active_display_species("p1"), _get_active_display_species("p2"))

	var response: Dictionary = await BattleApiClient.calculate_battle_damage(
		damage_calc_request,
		battle_state.battle_id,
		action_flow.local_player_id,
		"own-to-opponent",
		_get_damage_calc_defender_assumptions_payload()
	)

	damage_calc_request_in_flight = false
	if request_token != damage_calc_request_token:
		if damage_calc_refresh_queued and current_action_panel_mode == BattleActionsPanelMode.CALC:
			_refresh_damage_calc_results()
		return
	if current_action_panel_mode != BattleActionsPanelMode.CALC:
		return
	if damage_calc_refresh_queued:
		_refresh_damage_calc_results()
		return

	if bool(response.get("success", false)):
		calc_panel.show_response(response)
	else:
		calc_panel.show_error(str(response.get("error", "Damage calculation failed.")))

func _on_calc_panel_defender_assumptions_changed(assumptions: Dictionary, edited_fields: Dictionary) -> void:
	_sync_damage_calc_matchup_assumptions()
	damage_calc_defender_assumptions = assumptions.duplicate(true)
	damage_calc_assumption_edited_fields = edited_fields.duplicate(true)
	_persist_current_damage_calc_assumptions()
	if damage_calc_request_in_flight:
		damage_calc_request_token += 1
	if current_action_panel_mode == BattleActionsPanelMode.CALC:
		_refresh_damage_calc_results()

func _on_calc_panel_assumption_catalog_requested(kind: String, query: String, species: String) -> void:
	if current_action_panel_mode != BattleActionsPanelMode.CALC:
		return

	damage_calc_catalog_request_token += 1
	var request_token := damage_calc_catalog_request_token
	calc_panel.show_assumption_catalog_loading(kind, query)

	var request_node := HTTPRequest.new()
	add_child(request_node)

	var response: Dictionary = {}
	match kind:
		"item":
			response = await PokemonDataApiClient.search_damage_calc_items(request_node, query, 30)
		"ability":
			response = await PokemonDataApiClient.search_damage_calc_abilities(request_node, query, species, 30)
		"nature":
			response = await PokemonDataApiClient.search_damage_calc_natures(request_node, query, 30)
		_:
			response = {
				"success": false,
				"error": "Unsupported assumption catalog.",
			}

	request_node.queue_free()
	if request_token != damage_calc_catalog_request_token:
		return
	if current_action_panel_mode != BattleActionsPanelMode.CALC:
		return
	if not calc_panel.is_assumption_catalog_request_current(kind, query):
		return

	if bool(response.get("success", false)):
		calc_panel.show_assumption_catalog_response(kind, response)
	else:
		calc_panel.show_assumption_catalog_error(kind, str(response.get("error", "Could not load assumptions.")))

func _sync_damage_calc_matchup_assumptions() -> void:
	var matchup_key := _get_damage_calc_matchup_key()
	if matchup_key == damage_calc_matchup_key:
		return

	damage_calc_matchup_key = matchup_key
	damage_calc_defender_species_key = _get_damage_calc_defender_species_key()
	_load_damage_calc_assumptions_for_current_defender()

func _reset_damage_calc_assumptions() -> void:
	damage_calc_defender_assumptions.clear()
	damage_calc_assumption_edited_fields.clear()
	calc_panel.set_defender_assumptions(damage_calc_defender_assumptions, damage_calc_assumption_edited_fields)

func _load_damage_calc_assumptions_for_current_defender() -> void:
	damage_calc_defender_assumptions.clear()
	damage_calc_assumption_edited_fields.clear()
	if damage_calc_defender_species_key == "":
		calc_panel.set_defender_assumptions(damage_calc_defender_assumptions, damage_calc_assumption_edited_fields)
		return

	var saved_entry: Dictionary = _damage_calc_as_dictionary(damage_calc_saved_assumptions.get(damage_calc_defender_species_key, {}))
	if not saved_entry.is_empty():
		damage_calc_defender_assumptions = _sanitize_damage_calc_assumptions(saved_entry)
		damage_calc_assumption_edited_fields = _build_damage_calc_edited_fields(damage_calc_defender_assumptions)
	_apply_known_damage_calc_defender_info(false)
	calc_panel.set_defender_assumptions(damage_calc_defender_assumptions, damage_calc_assumption_edited_fields)

func _apply_known_damage_calc_defender_info(update_panel: bool = true) -> void:
	var changed: bool = false
	if not bool(damage_calc_assumption_edited_fields.get("item", false)):
		var known_item: String = _get_known_damage_calc_defender_item()
		var current_item: String = str(damage_calc_defender_assumptions.get("item", "")).strip_edges()
		if known_item != "" and current_item != known_item:
			damage_calc_defender_assumptions["item"] = known_item
			changed = true

	if not bool(damage_calc_assumption_edited_fields.get("ability", false)):
		var known_ability: String = _get_known_damage_calc_defender_ability()
		var current_ability: String = str(damage_calc_defender_assumptions.get("ability", "")).strip_edges()
		if known_ability != "" and current_ability != known_ability:
			damage_calc_defender_assumptions["ability"] = known_ability
			changed = true

	if changed and update_panel:
		calc_panel.set_defender_assumptions(damage_calc_defender_assumptions, damage_calc_assumption_edited_fields)

func _persist_current_damage_calc_assumptions() -> void:
	if damage_calc_defender_species_key == "":
		return

	var sanitized: Dictionary = _get_persistable_damage_calc_assumptions(
		damage_calc_defender_assumptions,
		damage_calc_assumption_edited_fields
	)
	if _should_store_damage_calc_assumptions(sanitized, damage_calc_assumption_edited_fields):
		damage_calc_saved_assumptions[damage_calc_defender_species_key] = sanitized
	else:
		damage_calc_saved_assumptions.erase(damage_calc_defender_species_key)
	_save_damage_calc_saved_assumptions()

func _load_damage_calc_saved_assumptions() -> void:
	damage_calc_saved_assumptions.clear()
	if not FileAccess.file_exists(DAMAGE_CALC_ASSUMPTIONS_PATH):
		return

	var file_text: String = FileAccess.get_file_as_string(DAMAGE_CALC_ASSUMPTIONS_PATH)
	var parsed_data: Variant = JSON.parse_string(file_text)
	if not (parsed_data is Dictionary):
		return

	var data: Dictionary = parsed_data as Dictionary
	var species_data: Dictionary = _damage_calc_as_dictionary(data.get("species", data))
	for key_value: Variant in species_data.keys():
		var species_key: String = str(key_value).strip_edges()
		if species_key == "":
			continue
		var assumptions: Dictionary = _sanitize_damage_calc_assumptions(_damage_calc_as_dictionary(species_data.get(key_value, {})))
		if not assumptions.is_empty():
			damage_calc_saved_assumptions[species_key] = assumptions

func _save_damage_calc_saved_assumptions() -> void:
	var file: FileAccess = FileAccess.open(DAMAGE_CALC_ASSUMPTIONS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save damage calc assumptions to %s" % DAMAGE_CALC_ASSUMPTIONS_PATH)
		return

	file.store_string(JSON.stringify({
		"version": DAMAGE_CALC_ASSUMPTIONS_VERSION,
		"species": damage_calc_saved_assumptions,
	}, "\t"))

func _sanitize_damage_calc_assumptions(assumptions: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	var item: String = str(assumptions.get("item", "")).strip_edges()
	if item != "" and item != "<null>":
		sanitized["item"] = item

	var ability: String = str(assumptions.get("ability", "")).strip_edges()
	if ability != "" and ability != "<null>":
		sanitized["ability"] = ability

	var nature: String = str(assumptions.get("nature", "")).strip_edges()
	if nature != "" and nature != "<null>":
		sanitized["nature"] = nature

	var evs: Dictionary = _sanitize_damage_calc_stat_table(_damage_calc_as_dictionary(assumptions.get("evs", {})), false)
	if not evs.is_empty():
		sanitized["evs"] = evs

	var ivs: Dictionary = _sanitize_damage_calc_stat_table(_damage_calc_as_dictionary(assumptions.get("ivs", {})), true)
	if not ivs.is_empty():
		sanitized["ivs"] = ivs

	return sanitized

func _get_persistable_damage_calc_assumptions(assumptions: Dictionary, edited_fields: Dictionary) -> Dictionary:
	var edited_assumptions: Dictionary = {}
	for key: String in ["item", "ability", "nature", "evs", "ivs"]:
		if bool(edited_fields.get(key, false)) and assumptions.has(key):
			edited_assumptions[key] = assumptions.get(key)
	return _sanitize_damage_calc_assumptions(edited_assumptions)

func _sanitize_damage_calc_stat_table(stats: Dictionary, omit_default_ivs: bool) -> Dictionary:
	var sanitized: Dictionary = {}
	for stat_key: String in ["hp", "atk", "def", "spa", "spd", "spe"]:
		if not stats.has(stat_key):
			continue
		var value: int = clampi(int(stats.get(stat_key, 0)), 0, 31 if omit_default_ivs else 252)
		if omit_default_ivs and value == 31:
			continue
		if not omit_default_ivs and value == 0:
			continue
		sanitized[stat_key] = value
	return sanitized

func _build_damage_calc_edited_fields(assumptions: Dictionary) -> Dictionary:
	var edited: Dictionary = {}
	for key: String in ["item", "ability", "nature", "evs", "ivs"]:
		if not assumptions.has(key):
			continue
		var value: Variant = assumptions.get(key)
		if value is Dictionary and (value as Dictionary).is_empty():
			continue
		if str(value).strip_edges() == "":
			continue
		edited[key] = true
	return edited

func _should_store_damage_calc_assumptions(assumptions: Dictionary, edited_fields: Dictionary) -> bool:
	for key: String in ["item", "ability", "nature", "evs", "ivs"]:
		if not bool(edited_fields.get(key, false)):
			continue
		if not assumptions.has(key):
			continue
		var value: Variant = assumptions.get(key)
		if value is Dictionary:
			if not (value as Dictionary).is_empty():
				return true
		elif str(value).strip_edges() != "":
			return true
	return false

func _get_damage_calc_defender_species_key() -> String:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon("p2")
	var species: String = str(active_pokemon.get("species", "")).strip_edges()
	if species == "":
		species = _get_active_display_species("p2")
	return _slugify_damage_calc_species(species)

func _slugify_damage_calc_species(species: String) -> String:
	return species.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "").replace(".", "")

func _get_known_damage_calc_defender_item() -> String:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon("p2")
	var ident_key: String = _normalize_battle_ident(str(active_pokemon.get("ident", "")))
	if ident_key != "" and public_confirmed_items_by_ident.has(ident_key):
		var confirmed_item: String = str(public_confirmed_items_by_ident.get(ident_key, "")).strip_edges()
		if confirmed_item != "":
			return confirmed_item

	for key: String in ["confirmedItem", "confirmed_item", "revealedItem", "revealed_item", "publicItem", "public_item"]:
		var value: String = str(active_pokemon.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""

func _get_known_damage_calc_defender_ability() -> String:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon("p2")
	var ident_key: String = _normalize_battle_ident(str(active_pokemon.get("ident", "")))
	if ident_key != "" and public_confirmed_abilities_by_ident.has(ident_key):
		var confirmed_ability: String = str(public_confirmed_abilities_by_ident.get(ident_key, "")).strip_edges()
		if confirmed_ability != "":
			return confirmed_ability

	for key: String in ["confirmedAbility", "confirmed_ability", "revealedAbility", "revealed_ability", "publicAbility", "public_ability"]:
		var value: String = str(active_pokemon.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""

func _damage_calc_as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}

func _get_damage_calc_matchup_key() -> String:
	return "%s|%s|%s|%s" % [
		battle_state.battle_id,
		action_flow.local_player_id,
		_get_damage_calc_active_key("p1"),
		_get_damage_calc_active_key("p2"),
	]

func _get_damage_calc_active_key(player_id: String) -> String:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	var species := str(active_pokemon.get("species", "")).strip_edges()
	if species == "":
		species = _get_active_display_species(player_id)
	var ident := _normalize_battle_ident(str(active_pokemon.get("ident", "")))
	if ident != "":
		return "%s:%s" % [ident, species.strip_edges().to_lower()]

	return "%s:%s" % [player_id, species.strip_edges().to_lower()]

func _get_damage_calc_defender_assumptions_payload() -> Dictionary:
	var payload: Dictionary = damage_calc_defender_assumptions.duplicate(true)
	for key: String in ["item", "ability"]:
		if str(payload.get(key, "")).strip_edges() == "":
			payload.erase(key)
	return payload

## Handelt de gekozen hoofdactie af.
func _on_action_selected(action: String) -> void:
	_focus_battle_ui_layer()
	if current_action_panel_mode == BattleActionsPanelMode.CALC:
		return

	if team_preview_lead_selection_active:
		_restore_team_preview_lead_selection_ui()
		return

	if not battle_actions_ready and not team_preview_lead_selection_active:
		if action == "run" and not _is_pvp_battle():
			_queue_battle_action("run")
		return

	if battle_input_locked:
		return
	if not _pvp_timer_allows_control():
		return

	if _local_player_needs_force_switch_ui():
		if action == "party":
			_show_force_switch_if_needed()
			return

		current_action_panel.set_message("Choose a Pokemon!")
		if not _show_force_switch_if_needed():
			if not _is_pvp_battle():
				_show_party(true)
		return

	if action == "fight":
		_show_moves()
	elif action == "bag":
		if not _can_use_bag_in_current_battle():
			current_action_panel.set_message("Bag cannot be used in this battle.")
			_refresh_bag_action_disabled()
			return
		_open_bag()
	elif action == "party":
		if _is_pvp_opponent_force_switch_waiting():
			_show_pvp_opponent_force_switch_wait()
			return
		_show_party()
	elif action == "run":
		_try_run()

## Klapt de battle log open of dicht.
func _on_battle_log_toggle_pressed() -> void:
	_focus_battle_ui_layer()
	var requested_open := not _get_requested_battle_log_open()
	remembered_battle_log_open = 1 if requested_open else 0
	_set_battle_log_open(requested_open)
	_update_battle_log_toggle_button()

## Zet de battle log bij battle start op de sessiekeuze, of anders op basis van viewport-breedte.
func _setup_battle_log_initial_visibility() -> void:
	var should_open := (
		remembered_battle_log_open == 1
		if remembered_battle_log_open != BATTLE_LOG_MEMORY_UNSET
		else _should_open_battle_log_by_default()
	)
	_set_battle_log_open(should_open)

## Geeft de door speler of responsive default gewenste log-state terug.
func _get_requested_battle_log_open() -> bool:
	if remembered_battle_log_open != BATTLE_LOG_MEMORY_UNSET:
		return remembered_battle_log_open == 1
	return battle_log_rail.visible

## Bepaalt alleen de eerste default voor deze client-sessie.
func _should_open_battle_log_by_default() -> bool:
	return _can_show_full_battle_log()

## Bepaalt of de grote battle log op dit scherm mag worden getoond.
func _can_show_full_battle_log() -> bool:
	return get_viewport_rect().size.x >= BATTLE_LOG_RESPONSIVE_COLLAPSE_WIDTH

## Past de log-state toe zonder de sessiekeuze te overschrijven.
func _set_battle_log_open(open: bool) -> void:
	battle_log_rail.visible = open
	var target_size := BATTLE_WINDOW_OPEN_SIZE if open else BATTLE_WINDOW_COLLAPSED_SIZE
	var previous_center := position + size * 0.5
	custom_minimum_size = target_size
	size = target_size
	position = previous_center - size * 0.5
	_clamp_battle_ui_position()
	_queue_calc_drawer_layout_update()

## Zet de tekst van de battle log toggle op basis van de open/dicht state.
func _update_battle_log_toggle_button() -> void:
	var is_open := battle_log_rail.visible
	battle_log_toggle_button.visible = true
	battle_log_toggle_button.text = "›" if is_open else "‹"
	battle_log_toggle_button.tooltip_text = "Collapse Battle Log" if is_open else "Open Battle Log"
	if mini_battle_feed != null:
		mini_battle_feed.set_feed_enabled(false)

## Verbergt alle action views en reset de geselecteerde action state.
func _reset_action_choices() -> void:
	_clear_pvp_switch_confirmation()
	current_action_view = ActionView.NONE
	_hide_party_hover()
	_clear_mega_evolution_selection()
	_sync_action_panel_mode_visibility()
	_update_mechanic_button_states()

## Toont de move keuzes in het action panel.
func _show_moves() -> void:
	_clear_pvp_switch_confirmation()
	pvp_idle_wait_recovery_active = false
	if team_preview_lead_selection_active:
		_restore_team_preview_lead_selection_ui()
		return

	if not _is_pvp_battle() and _local_player_needs_force_switch_ui():
		_show_force_switch_if_needed()
		return

	if _is_pvp_battle():
		var local_state_player_id := _get_local_state_player_id()
		var opponent_state_player_id := _get_opponent_state_player_id()
		var local_needs_force_switch := _local_player_needs_force_switch_ui()
		var opponent_needs_force_switch := _opponent_player_needs_force_switch_ui()
		if pvp_last_phase != "turn_open":
			if local_needs_force_switch:
				_show_force_switch_if_needed()
				return
			if opponent_needs_force_switch:
				_show_pvp_opponent_force_switch_wait()
				return
			if _pvp_local_request_allows_action_recovery(local_state_player_id):
				_log_pvp_realtime(
					"Recovering PvP moves open from local request",
					"source=_show_moves phase=%s local_state_player_id=%s" % [pvp_last_phase, local_state_player_id]
				)
				_set_battle_input_locked(false)
			else:
				_log_pvp_realtime(
					"Blocked PvP moves open",
					"source=_show_moves phase=%s expected=turn_open" % pvp_last_phase
				)
				_set_battle_input_locked(true)
				return
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Show moves force-switch check",
				"local_player_id=%s local_state_player_id=%s opponent_state_player_id=%s local_force_switch=%s opponent_force_switch=%s" % [
					action_flow.local_player_id,
					local_state_player_id,
					opponent_state_player_id,
					local_needs_force_switch,
					opponent_needs_force_switch,
				]
			)
		if local_needs_force_switch:
			_show_force_switch_if_needed()
			return
		if opponent_needs_force_switch:
			_show_pvp_opponent_force_switch_wait()
			return

	action_buttons.set_action_disabled("fight", false)
	action_buttons.set_action_disabled("party", false)
	_refresh_bag_action_disabled()
	action_buttons.set_action_disabled("run", false)
	_update_move_slots()
	current_action_view = ActionView.MOVES
	moves_grid.visible = true
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	_hide_party_hover()
	action_buttons.set_selected_action("fight")
	_show_current_action_prompt()
	_sync_action_panel_mode_visibility()
	_update_mechanic_button_states()

func _pvp_local_request_allows_action_recovery(local_state_player_id: String) -> bool:
	if not _is_pvp_battle():
		return false
	var available_moves: Array = battle_state.get_available_moves(local_state_player_id)
	return _pvp_local_request_allows_choice(local_state_player_id) and not available_moves.is_empty()

func _show_current_action_prompt() -> void:
	var player_species: String = _get_active_display_species("p1")
	current_action_panel.set_message(event_text_formatter.format_action_prompt(player_species))

func _set_battle_input_locked(is_locked: bool) -> void:
	if not is_locked and _is_pvp_presentation_hold_active():
		is_locked = true
	battle_input_locked = is_locked
	if action_buttons.has_method("set_all_actions_disabled"):
		action_buttons.set_all_actions_disabled(is_locked)
	if moves_grid.has_method("set_input_disabled"):
		moves_grid.set_input_disabled(is_locked)
	if player_party_grid.has_method("set_input_disabled"):
		player_party_grid.set_input_disabled(is_locked)
	if bag_grid.has_method("set_input_disabled"):
		bag_grid.set_input_disabled(is_locked)
	if not is_locked:
		_refresh_bag_action_disabled()
		if team_preview_lead_selection_active:
			_restore_team_preview_lead_selection_ui()
	_sync_party_rail_interaction()
	_update_mechanic_button_states()

func _update_pvp_presentation_schedule(response: Dictionary) -> void:
	if not _is_pvp_battle():
		return
	var presentation: Dictionary = response.get("presentation", {})
	var decisions: Dictionary = presentation.get("decisions", {})
	var schedule: Dictionary = decisions.get(_get_local_state_player_id(), decisions.get(action_flow.local_player_id, {}))
	if schedule.is_empty() or str(schedule.get("status", "")) != "SCHEDULED":
		pvp_presentation_actionable_local_msec = 0
		pvp_presentation_schedule_token = ""
		return
	var remaining := maxi(0, int(schedule.get("actionableAtMs", 0)) - int(presentation.get("serverNowMs", 0)))
	pvp_presentation_actionable_local_msec = Time.get_ticks_msec() + remaining
	pvp_presentation_schedule_token = "%s:%s" % [schedule.get("decisionId", ""), schedule.get("decisionGeneration", 0)]
	_set_battle_input_locked(true)
	_release_pvp_presentation_hold_after(remaining, pvp_presentation_schedule_token)

func _release_pvp_presentation_hold_after(remaining_msec: int, token: String) -> void:
	if remaining_msec > 0:
		await get_tree().create_timer(float(remaining_msec) / 1000.0).timeout
	if token != pvp_presentation_schedule_token:
		return
	pvp_presentation_actionable_local_msec = 0
	pvp_presentation_schedule_token = ""
	_set_battle_input_locked(false)

func _is_pvp_presentation_hold_active() -> bool:
	return _is_pvp_battle() and pvp_presentation_actionable_local_msec > Time.get_ticks_msec()

func _set_battle_actions_ready(is_ready: bool) -> void:
	battle_actions_ready = is_ready
	_sync_party_rail_interaction()
	_update_mechanic_button_states()
	if battle_actions_ready:
		_process_queued_battle_action()

func _queue_battle_action(action_type: String, slot := 0) -> void:
	if team_preview_lead_selection_active or battle_finished:
		return
	if _is_pvp_battle() and action_type == "run":
		return

	queued_battle_action = {
		"type": action_type,
		"slot": slot,
	}

func _process_queued_battle_action() -> void:
	if queued_battle_action.is_empty():
		return

	var action := queued_battle_action.duplicate()
	queued_battle_action.clear()

	var action_type := str(action.get("type", ""))
	if action_type == "run":
		_try_run()
	elif action_type == "move":
		_try_select_move(int(action.get("slot", 0)))


## Toont de party keuzes in het action panel.
func _show_party(force_switch := false) -> void:
	_clear_pvp_switch_confirmation()
	if team_preview_lead_selection_active:
		_restore_team_preview_lead_selection_ui()
		return

	var local_state_player_id := _get_local_state_player_id()
	if not force_switch and _local_player_needs_force_switch_ui():
		if DEBUG_PVP_REALTIME and _is_pvp_battle():
			_log_pvp_realtime(
				"Forcing PvP party view into force-switch mode",
				"phase=%s next=%s" % [pvp_last_phase, pvp_last_next_phase]
			)
		_show_force_switch_if_needed()
		return
	if not force_switch and _is_pvp_opponent_force_switch_waiting():
		_show_pvp_opponent_force_switch_wait()
		return
	if not force_switch and force_switch_flow.is_player_trapped_outside_force_switch(local_state_player_id):
		current_action_panel.set_message("Cannot switch right now!")
		_show_moves()
		return

	_clear_mega_evolution_selection()
	action_buttons.set_action_disabled("fight", force_switch)
	action_buttons.set_action_disabled("bag", force_switch or not _can_use_bag_in_current_battle())
	action_buttons.set_action_disabled("run", force_switch)
	current_action_view = ActionView.PARTY
	_update_party_slots()
	moves_grid.visible = false
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	action_buttons.set_selected_action("party")
	_sync_action_panel_mode_visibility()
	_update_mechanic_button_states()

func _restore_team_preview_lead_selection_ui() -> void:
	current_action_panel.set_message("Choose your Lead")
	current_action_view = ActionView.PARTY
	moves_grid.visible = false
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	action_buttons.set_action_disabled("fight", true)
	action_buttons.set_action_disabled("party", false)
	action_buttons.set_action_disabled("bag", true)
	action_buttons.set_action_disabled("run", true)
	action_buttons.set_selected_action("party")
	_sync_action_panel_mode_visibility()

## Zet de UI in bag-modus.
func _open_bag() -> void:
	if not _can_use_bag_in_current_battle():
		current_action_panel.set_message("Bag cannot be used in this battle.")
		_refresh_bag_action_disabled()
		return

	_clear_mega_evolution_selection()
	current_action_view = ActionView.BAG
	moves_grid.visible = false
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	bag_grid.visible = true
	_hide_party_hover()
	_sync_action_panel_mode_visibility()
	_update_mechanic_button_states()
	_refresh_bag_inventory()

func _can_use_bag_in_current_battle() -> bool:
	return battle_type == BattleType.WILD and not _is_pvp_battle()

func _refresh_bag_action_disabled() -> void:
	action_buttons.set_action_disabled("bag", not _can_use_bag_in_current_battle())

func _refresh_bag_inventory() -> void:
	bag_inventory_request_token += 1
	var request_token := bag_inventory_request_token
	bag_grid.set_loading()

	var inventory_result: Dictionary = await InventoryService.load_inventory()
	if request_token != bag_inventory_request_token:
		return
	if current_action_view != ActionView.BAG:
		return

	if not bool(inventory_result.get("success", false)):
		bag_grid.show_message(str(inventory_result.get("error", "Could not load Bag.")))
		return

	var inventory_items_value: Variant = inventory_result.get("items", [])
	var inventory_items: Array = []
	if inventory_items_value is Array:
		inventory_items = inventory_items_value
	bag_grid.set_items(inventory_items)

func _on_bag_grid_item_selected(item_data: Dictionary) -> void:
	if battle_finished or battle_input_locked:
		return
	if not _can_use_bag_in_current_battle():
		current_action_panel.set_message("Bag cannot be used in this battle.")
		_refresh_bag_action_disabled()
		return

	var item_id := str(item_data.get("itemId", "")).strip_edges()
	if item_id.is_empty():
		return

	var item_name := str(item_data.get("name", item_id)).strip_edges()
	if item_name.is_empty():
		item_name = item_id

	var current_battle_id := ""
	if battle_state != null:
		current_battle_id = battle_state.battle_id.strip_edges()
	if current_battle_id.is_empty():
		current_action_panel.set_message("Cannot catch Pokemon without a battle id.")
		return

	_set_battle_input_locked(true)
	var use_item_message := "You used %s!" % item_name
	current_action_panel.set_message(use_item_message)
	_add_battle_log_message(use_item_message)
	SfxManager.play("battle_item_use")
	var capture_result: Dictionary = await InventoryService.catch_wild_pokemon(current_battle_id, item_id)
	if not bool(capture_result.get("success", false)):
		current_action_panel.set_message(str(capture_result.get("error", "Could not catch Pokemon.")))
		_refresh_bag_inventory()
		_set_battle_input_locked(false)
		return

	var updated_inventory_value: Variant = capture_result.get("inventory", [])
	if updated_inventory_value is Array:
		bag_grid.set_items(updated_inventory_value)

	var caught := bool(capture_result.get("caught", false))
	var shake_count := clampi(int(capture_result.get("shakeCount", 0)), 0, 3)
	_reset_capture_target_visibility()
	await capture_ball_animation_player.play_capture_preview(item_id, shake_count, caught, enemy_sprite_box.get_global_rect())

	var capture_message := str(capture_result.get("message", ""))
	if capture_message.is_empty():
		capture_message = "Gotcha!" if caught else "The Pokemon broke free."
	if caught:
		capture_message = _capture_result_message_with_storage(capture_result, capture_message)
	current_action_panel.set_message(capture_message)
	_add_battle_log_message(capture_message)

	if caught:
		var party_value: Variant = capture_result.get("party", [])
		if party_value is Array:
			PlayerSave.replace_party_from_state(party_value)
		await get_tree().create_timer(CAPTURE_SUCCESS_RESULT_HOLD_SECONDS).timeout
		_finish_battle({
			"reason": "caught",
			"winner": "p1",
			"pokemon": capture_result.get("pokemon", {}),
			"addedToParty": bool(capture_result.get("addedToParty", false)),
			"itemId": item_id,
			"skipPartyBattleSync": true,
		})
		return

	if bool(capture_result.get("requiresBattleTurn", false)):
		await _hold_opponent_response_message()
		var pass_turn_response: Dictionary = await action_flow.submit_pass_turn("p1", "p2", last_rendered_event_seq)
		if not bool(pass_turn_response.get("success", false)):
			current_action_panel.set_message(str(pass_turn_response.get("error", "Could not resolve the wild Pokemon's turn.")))
			_set_battle_input_locked(false)
			return

		await _render_opponent_response(pass_turn_response)
		await _hold_opponent_response_message()
		if await _finish_if_battle_ended():
			return
		if _show_force_switch_if_needed():
			return

	_set_battle_input_locked(false)

func _capture_result_message_with_storage(capture_result: Dictionary, fallback_message: String) -> String:
	var location: Dictionary = PokemonStorageService.normalize_storage_location(capture_result.get("storageLocation", {}))
	if location.is_empty():
		return fallback_message

	var pokemon_response: Dictionary = {}
	var pokemon_response_value: Variant = capture_result.get("pokemon", {})
	if pokemon_response_value is Dictionary:
		pokemon_response = pokemon_response_value as Dictionary

	var pokemon_payload: Dictionary = {}
	var pokemon_payload_value: Variant = pokemon_response.get("pokemon", {})
	if pokemon_payload_value is Dictionary:
		pokemon_payload = pokemon_payload_value as Dictionary

	var species := str(pokemon_payload.get("displaySpecies", pokemon_payload.get("species", "Pokemon"))).strip_edges()
	if species == "":
		species = "Pokemon"

	match str(location.get("type", "")):
		"party":
			return "Gotcha! %s was caught and added to party." % species
		"box":
			return "Gotcha! %s was caught and sent to %s." % [
				species,
				PokemonStorageService.storage_location_label(location),
			]
	return fallback_message

func _on_capture_ball_thrown() -> void:
	SfxManager.play("capture_throw")

func _on_capture_ball_shook() -> void:
	SfxManager.play("capture_shake")

func _on_capture_broke() -> void:
	SfxManager.play("capture_break")

func _on_capture_succeeded() -> void:
	SfxManager.play("capture_success")

func _on_capture_target_absorbed() -> void:
	SfxManager.play("capture_absorb")
	_fade_capture_target_to_alpha(0.0, 0.14, true)

func _on_capture_target_released() -> void:
	_fade_capture_target_to_alpha(1.0, 0.18, false)

func _reset_capture_target_visibility() -> void:
	_stop_capture_target_visibility_tween()
	if enemy_sprite_box == null:
		return

	enemy_sprite_box.visible = true
	var color: Color = enemy_sprite_box.modulate
	color.a = 1.0
	enemy_sprite_box.modulate = color

func _fade_capture_target_to_alpha(target_alpha: float, duration: float, hide_after_fade: bool) -> void:
	_stop_capture_target_visibility_tween()
	if enemy_sprite_box == null:
		return

	enemy_sprite_box.visible = true
	capture_target_visibility_tween = create_tween()
	capture_target_visibility_tween.tween_property(enemy_sprite_box, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hide_after_fade:
		capture_target_visibility_tween.finished.connect(_hide_capture_target_after_fade, CONNECT_ONE_SHOT)

func _hide_capture_target_after_fade() -> void:
	if enemy_sprite_box == null:
		return
	if enemy_sprite_box.modulate.a <= 0.02:
		enemy_sprite_box.visible = false

func _stop_capture_target_visibility_tween() -> void:
	if capture_target_visibility_tween != null and capture_target_visibility_tween.is_valid():
		capture_target_visibility_tween.kill()

	capture_target_visibility_tween = null

## Probeert de battle te verlaten.
func _try_run() -> void:
	var local_state_player_id := _get_local_state_player_id()
	if not battle_actions_ready:
		return

	if team_preview_lead_selection_active:
		return

	if battle_finished or battle_input_locked or force_switch_flow.player_needs_force_switch(local_state_player_id):
		return

	if battle_type != BattleType.WILD:
		_clear_mega_evolution_selection()
		_show_forfeit_confirm_dialog()
		return

	_clear_mega_evolution_selection()
	_set_battle_input_locked(true)
	var response: Dictionary = await action_flow.submit_player_choice("run", 1, false, last_rendered_event_seq)
	_set_battle_input_locked(false)
	if not bool(response.get("success", false)):
		var error_message := str(response.get("error", "Could not run from the battle."))
		current_action_panel.set_message(error_message)
		_add_battle_log_message(error_message)
		return

	_add_battle_log_message("Got away safely!")
	_finish_battle({"reason": "flee"})

func _show_forfeit_confirm_dialog() -> void:
	forfeit_return_action_view = current_action_view
	_set_battle_input_locked(true)
	if forfeit_confirm_dialog.has_method("show_dialog"):
		forfeit_confirm_dialog.call("show_dialog")
	else:
		forfeit_confirm_dialog.visible = true

func _on_forfeit_confirmed() -> void:
	_set_battle_input_locked(false)
	_add_battle_log_message("You forfeited the battle.")
	if not _is_pvp_battle():
		_set_battle_input_locked(true)
		var response: Dictionary = await action_flow.submit_player_choice("forfeit", 1, false, last_rendered_event_seq)
		_set_battle_input_locked(false)
		if not bool(response.get("success", false)):
			var error_message := str(response.get("error", "Could not forfeit the battle."))
			current_action_panel.set_message(error_message)
			_add_battle_log_message(error_message)
			return

		_finish_battle({"reason": "forfeit"})
		return

	_set_battle_input_locked(true)
	var response: Dictionary = await _submit_pvp_realtime_forfeit()
	# A durable battle.ended event can confirm the forfeit before the correlated
	# action response arrives. Its terminal handler already owns the result UI;
	# do not unlock the finished battle or replace it with a timeout message.
	if battle_finished:
		return
	_set_battle_input_locked(false)
	if not bool(response.get("success", false)):
		var error_message := str(response.get("error", "Could not forfeit the battle."))
		current_action_panel.set_message(error_message)
		_add_battle_log_message(error_message)
		return

	# A confirmed forfeit has no move, switch or faint animation to render. Loading
	# it through the regular event queue can leave a duplicate terminal projection
	# pending (notably on the local legacy backend) and strand the result flow.
	_finish_confirmed_pvp_forfeit(response, _get_local_state_player_id(), "pvp_forfeit_submit")

func _on_forfeit_cancelled() -> void:
	_set_battle_input_locked(false)
	if forfeit_return_action_view == ActionView.PARTY:
		_show_party()
	elif forfeit_return_action_view == ActionView.BAG:
		_open_bag()
	else:
		_show_moves()
	forfeit_return_action_view = ActionView.NONE

## Vult de move slots met de huidige beschikbare moves.
func _update_move_slots() -> void:
	if active_player_pokemon == null:
		return

	moves_grid.set_moves(battle_state.get_available_moves())

## Vult beide vaste partyrails vanuit de huidige battle state.
func _update_party_slots() -> void:
	var player_display_team := _get_display_team_data("p1")
	var opponent_display_team := _get_display_team_data("p2")
	_mark_active_party_slot(player_display_team, "p1")
	_mark_active_party_slot(opponent_display_team, "p2")
	player_party_grid.set_party(player_display_team)
	opponent_party_grid.set_party(opponent_display_team)
	opponent_party_grid.set_selection_enabled(false)

func _mark_active_party_slot(display_team: Array, player_id: String) -> void:
	var active_slot := _get_active_canonical_party_slot(player_id)
	if active_slot <= 0:
		return

	for index in range(display_team.size()):
		var pokemon_value: Variant = display_team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		pokemon_data["active"] = _get_pokemon_data_canonical_party_slot(pokemon_data) == active_slot

func _get_active_canonical_party_slot(player_id: String) -> int:
	if battle_state == null:
		return -1

	var active_pokemon := battle_state.get_active_player_pokemon(player_id)
	if active_pokemon.is_empty():
		return -1

	return _get_pokemon_data_canonical_party_slot(active_pokemon)

func _finish_battle(result: Dictionary) -> void:
	if battle_finished:
		return

	pvp_pending_authoritative_terminal.clear()
	var allows_gameplay_persistence := PvpBattleRealtimeService.allows_gameplay_persistence_for_terminal(result)
	_warn_if_pvp_finish_has_pending_render_work(result)
	if allows_gameplay_persistence:
		_add_pvp_victory_message_if_needed(result)
	battle_finished = true
	_sync_party_rail_interaction()
	pending_mega_species_by_ident.clear()
	_reset_damage_calc_assumptions()
	if _is_pvp_battle():
		PvpBattleRealtimeService.disconnect_room()
		pvp_match_id = ""
		_clear_pvp_party_hud_display_override()
		if allows_gameplay_persistence:
			_heal_local_party_after_pvp_battle()
			_heal_party_after_pvp_battle.call_deferred()
	if not result.has("localPartyDefeated"):
		result["localPartyDefeated"] = _is_local_battle_party_defeated()
	var skip_party_battle_sync := bool(result.get("skipPartyBattleSync", false)) or _should_skip_party_battle_sync_for_blackout(result)
	if not skip_party_battle_sync:
		_sync_player_save_from_battle_state()
		PlayerPartyStateService.save_current_battle_party_state_deferred()
	if _should_present_pvp_battle_result(result):
		_show_pvp_battle_result(result)
		return
	_emit_battle_ended(result)


func _should_present_pvp_battle_result(result: Dictionary) -> bool:
	if not _is_pvp_battle():
		return false
	var reason := str(result.get("reason", "")).strip_edges().to_lower()
	return (
		bool(result.get("noContest", false))
		or str(result.get("winner", "")).strip_edges() != ""
		or reason in ["win", "ended", "battle_end", "forfeit", "timeout", "disconnect"]
	)


func _show_pvp_battle_result(result: Dictionary) -> void:
	pending_battle_end_result = result.duplicate(true)
	_set_battle_input_locked(true)
	moves_grid.visible = false
	action_buttons.visible = false
	mechanics_panel.visible = false

	var is_no_contest := bool(result.get("noContest", false))
	var winner_identity := PvpBattleRealtimeService.normalize_terminal_winner(result.get("winner", battle_state.get_winner()))
	var local_state_player_id := _get_local_state_player_id()
	var local_won := PvpBattleRealtimeService.is_local_terminal_winner(
		winner_identity,
		local_state_player_id,
		_get_player_display_name(local_state_player_id)
	)
	if is_no_contest:
		battle_result_title.text = "No Contest"
		battle_result_title.modulate = Color("f5df9a")
	elif local_won:
		battle_result_title.text = "Victory"
		battle_result_title.modulate = Color("65e38b")
	else:
		battle_result_title.text = "Defeat"
		battle_result_title.modulate = Color("ff7a7a")

	var winner_name := _resolve_pvp_winner_name(result)
	var loser_name := _resolve_pvp_loser_name(result, winner_name)
	if is_no_contest:
		battle_result_summary.text = "The battle ended without a winner."
	elif winner_name != "" and loser_name != "":
		battle_result_summary.text = "%s defeated %s." % [winner_name, loser_name]
	elif winner_name != "":
		battle_result_summary.text = "%s won the battle." % winner_name
	else:
		battle_result_summary.text = "The battle has ended."

	var reason := str(result.get("reason", "")).strip_edges().to_lower()
	battle_result_reason.text = _format_battle_result_reason(reason)
	battle_result_reason.visible = battle_result_reason.text != ""
	battle_result_overlay.visible = true
	battle_result_overlay.move_to_front()
	battle_result_continue_button.grab_focus.call_deferred()


func _format_battle_result_reason(reason: String) -> String:
	match reason:
		"forfeit":
			return "Battle ended by forfeit"
		"timeout":
			return "Battle ended on time"
		"disconnect":
			return "Battle ended by disconnect"
		"infrastructure_no_contest":
			return "Battle authority was lost"
		_:
			return ""


func _on_battle_result_continue_pressed() -> void:
	battle_result_overlay.visible = false
	_emit_battle_ended(pending_battle_end_result)


func _emit_battle_ended(result: Dictionary) -> void:
	if battle_end_signal_emitted:
		return
	battle_end_signal_emitted = true
	pending_battle_end_result.clear()
	battle_ended.emit(result)


func _should_skip_party_battle_sync_for_blackout(result: Dictionary) -> bool:
	if _is_pvp_battle():
		return true

	var reason := str(result.get("reason", "")).strip_edges().to_lower()
	if reason in ["caught", "flee"]:
		return false
	if reason in ["forfeit", "loss", "blackout"]:
		return true

	var winner := str(result.get("winner", "")).strip_edges().to_lower()
	if winner.is_empty():
		return false
	return winner not in ["p1", "player 1", "player1"] and bool(result.get("localPartyDefeated", false))


func _is_local_battle_party_defeated() -> bool:
	var team: Array = battle_state.get_player_team(_get_local_state_player_id())
	var has_pokemon := false
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			continue
		has_pokemon = true
		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if not bool(pokemon_data.get("fainted", false)) and _safe_int(
			pokemon_data.get("hp", pokemon_data.get("currentHp", pokemon_data.get("current_hp", 1))),
			1
		) > 0:
			return false
	return has_pokemon

func _heal_local_party_after_pvp_battle() -> void:
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save == null:
		return

	var party_value: Variant = player_save.get("party")
	if not (party_value is Array):
		return

	PartyHealService.heal_party_locally(party_value as Array)

func _heal_party_after_pvp_battle() -> void:
	var result: Dictionary = await PartyHealService.heal_current_party_and_save()
	if not bool(result.get("success", false)):
		push_warning("Battle: could not heal party after PvP battle: %s" % str(result.get("error", "Unknown error")))

func _warn_if_pvp_finish_has_pending_render_work(result: Dictionary) -> void:
	if not _is_pvp_battle():
		return

	var current_batch_id := str(pvp_event_queue.current_event_batch_id)
	var has_pending := pvp_event_queue.has_pending()
	if current_batch_id == "" and not has_pending:
		return

	push_warning(
		"PvP battle finished with render work still active. reason=%s winner=%s currentBatch=%s pending=%s phase=%s nextPhase=%s lastRenderedSeq=%d" % [
			str(result.get("reason", "")),
			str(result.get("winner", "")),
			current_batch_id if current_batch_id != "" else "none",
			str(has_pending),
			pvp_last_phase if pvp_last_phase != "" else "unknown",
			pvp_last_next_phase if pvp_last_next_phase != "" else "unknown",
			pvp_event_queue.last_rendered_seq,
		]
	)

func _add_pvp_victory_message_if_needed(result: Dictionary) -> void:
	if not _is_pvp_battle():
		return
	if pvp_victory_message_added:
		return

	var winner_name := _resolve_pvp_winner_name(result)
	if winner_name == "":
		return

	var message := "🏆 %s won the battle!" % winner_name
	_add_battle_log_message(message)
	_add_pvp_victory_system_chat_message(_format_pvp_victory_system_chat_message(result, winner_name))
	pvp_victory_message_added = true

func _add_pvp_victory_system_chat_message(message: String) -> void:
	if message == "":
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group("ui_overlay", "add_system_message", message)

func _format_pvp_victory_system_chat_message(result: Dictionary, winner_name: String) -> String:
	var loser_name := _resolve_pvp_loser_name(result, winner_name)
	if loser_name == "":
		return "🏆 %s won the battle!" % winner_name
	return "%s has defeated %s in battle." % [winner_name, loser_name]

func _resolve_pvp_winner_name(result: Dictionary) -> String:
	var winner_name := PvpBattleRealtimeService.normalize_terminal_winner(result.get("winner", ""))
	if winner_name == "":
		winner_name = PvpBattleRealtimeService.normalize_terminal_winner(battle_state.get_winner())

	if winner_name in ["p1", "p2"]:
		return _get_player_display_name(winner_name)
	if winner_name != "":
		return winner_name

	var forfeiting_player_id := str(result.get("forfeitingPlayerId", "")).strip_edges()
	if forfeiting_player_id == "p1":
		return _get_player_display_name("p2")
	if forfeiting_player_id == "p2":
		return _get_player_display_name("p1")

	return ""

func _resolve_pvp_loser_name(result: Dictionary, winner_name: String) -> String:
	var forfeiting_player_id := str(result.get("forfeitingPlayerId", "")).strip_edges()
	if forfeiting_player_id in ["p1", "p2"]:
		return _get_player_display_name(forfeiting_player_id)

	for player_id in ["p1", "p2"]:
		var player_name := _get_player_display_name(player_id)
		if player_name != "" and player_name != winner_name:
			return player_name

	return ""

func _get_pvp_state_player_id_for_raw_player_id(player_id: String) -> String:
	if player_id != "p1" and player_id != "p2":
		return ""
	if not _is_pvp_battle() or action_flow.local_player_id != "p2":
		return player_id
	return "p1" if player_id == "p2" else "p2"

func _finish_confirmed_pvp_forfeit(response: Dictionary, forfeiting_player_id: String, source: String) -> void:
	if battle_finished:
		return

	var response_state_value: Variant = response.get("state", {})
	if response_state_value is Dictionary and not (response_state_value as Dictionary).is_empty():
		var mapped_response := action_flow.map_response_for_local_player(response)
		if not mapped_response.is_empty():
			# Reconcile the terminal projection without replaying the response's
			# historical event trail. Manual forfeit has no visual battle event.
			_apply_pvp_snapshot_reconciliation({
				"type": "pvp.snapshot",
				"battleId": str(response.get("battleId", battle_state.battle_id)),
				"roomCode": pvp_room_code,
				"serverSeq": _get_pvp_response_server_seq(response),
				"response": response,
			}, mapped_response, source)

	var winner_side := PvpBattleRealtimeService.normalize_terminal_winner(battle_state.get_winner())
	if winner_side == "" and forfeiting_player_id in ["p1", "p2"]:
		winner_side = "p2" if forfeiting_player_id == "p1" else "p1"

	_finish_battle({
		"reason": "forfeit",
		"winner": winner_side,
		"forfeitingPlayerId": forfeiting_player_id,
	})

## Laadt een API-response in de battle state en geeft terug of dat gelukt is.
func _apply_api_response(response: Dictionary, apply_event_conditions: bool = true, source: String = "") -> bool:
	var display_response: Dictionary = action_flow.map_response_for_local_player(response)
	if _is_pvp_battle() and pvp_response_order.is_stale(display_response):
		_trace_pvp_flow(
			"apply.skip_stale_projection",
			display_response,
			"source=%s incoming=%s latest=%s" % [
				source,
				JSON.stringify(pvp_response_order.cursor_for_response(display_response)),
				JSON.stringify(pvp_response_order.latest_cursor),
			]
		)
		return true

	var defer_state_load := _should_defer_pvp_canonical_state_until_render(display_response)
	var success: bool = action_flow.apply_response(response, apply_event_conditions, not defer_state_load)
	if success:
		if _is_pvp_battle():
			pvp_response_order.remember(display_response)
		_update_pvp_presentation_schedule(response)
		if not defer_state_load:
			_apply_party_state_from_api_response(response)
			_sync_player_save_party_status_from_battle_state()
			_remember_active_player_party_moves()
			_prewarm_current_battle_move_animations()
			_prewarm_current_battle_mega_assets()
		_update_pvp_phase_contract_from_response(response, source)
		_mark_pvp_response_applied(response)
		if not defer_state_load and _should_sync_presentation_field_from_response(response, source):
			_sync_presentation_field_from_battle_state()
		_refresh_damage_calc_results()

	return success

func _should_defer_pvp_canonical_state_until_render(response: Dictionary) -> bool:
	if not _is_pvp_battle() or battle_state.battle_id == "":
		return false
	# Team Preview and initial lead setup establish the first presentation state
	# before an authoritative render cursor exists.
	if pvp_event_queue.last_rendered_seq < 0:
		return false
	var response_event_seq := _get_pvp_response_event_seq_end(response)
	if response_event_seq > pvp_event_queue.last_rendered_seq:
		return true
	return _response_has_renderable_battle_events(response)

func _should_sync_presentation_field_from_response(response: Dictionary, source: String = "") -> bool:
	if source.begins_with("pvp_snapshot"):
		return true

	var events_value: Variant = response.get("events", [])
	var events: Array = events_value as Array if events_value is Array else []
	return events.is_empty()

func _sync_presentation_field_from_battle_state() -> void:
	# Large realtime packets may deliberately omit the field snapshot to stay
	# below the WebSocket limit. In that case the ordered fieldEffect events are
	# the only authoritative presentation source; an omitted field must not be
	# interpreted as an empty field and erase active weather or screens.
	if not battle_state.field.has("effects"):
		return
	presentation_state.sync_field_from_snapshot(battle_state.field)

func _update_pvp_phase_contract_from_response(response: Dictionary, source: String = "") -> void:
	if not _is_pvp_battle():
		return
	if not (response is Dictionary):
		return

	var current_phase := str(response.get("phase", "")).strip_edges()
	var current_next_phase := str(response.get("nextPhase", current_phase)).strip_edges()
	if current_phase == "":
		return

	var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1))
	var response_batch_seq := _get_int_from_variant(response.get("batchSeq", -1))

	if pvp_last_phase != current_phase or pvp_last_next_phase != current_next_phase:
		_log_pvp_realtime(
			"PvP phase transition",
			"old=%s new=%s next=%s source=%s eventSeq=%d batchSeq=%d" % [
				pvp_last_phase if pvp_last_phase != "" else "unknown",
				current_phase,
				current_next_phase,
				source,
				response_event_seq,
				response_batch_seq,
			]
		)
	if _response_has_renderable_battle_events(response) and current_phase != "rendering_events":
		_log_pvp_phase_warning(
			"Renderable events present while phase is not rendering_events",
			"phase=%s source=%s eventSeq=%d batchSeq=%d" % [
				current_phase,
				source,
				response_event_seq,
				response_batch_seq,
			]
		)

	var state_value: Variant = response.get("state", {})
	if state_value is Dictionary and bool((state_value as Dictionary).get("ended", false)) and current_phase != "ended":
		_log_pvp_phase_warning(
			"Battle state ended while phase is not ended",
			"phase=%s source=%s eventSeq=%d batchSeq=%d" % [
				current_phase,
				source,
				response_event_seq,
				response_batch_seq,
			]
		)

	var force_switch_waiting_for_release := (
		current_phase == "rendering_events"
		and current_next_phase == "awaiting_force_switch"
	)
	if _response_has_force_switch_request(response) and current_phase != "awaiting_force_switch" and not force_switch_waiting_for_release:
		_log_pvp_phase_warning(
			"Force-switch request present while phase is not awaiting_force_switch",
			"phase=%s source=%s eventSeq=%d batchSeq=%d" % [
				current_phase,
				source,
				response_event_seq,
				response_batch_seq,
			]
		)

	pvp_last_phase = current_phase
	pvp_last_next_phase = current_next_phase

func _log_pvp_phase_warning(message: String, details: String) -> void:
	if not DEBUG_PVP_REALTIME:
		return
	_log_pvp_realtime("Phase contract warning", "%s | %s" % [message, details])

func _enqueue_pvp_battle_response(response: Dictionary, source: String, apply_event_conditions: bool = true, metadata: Dictionary = {}) -> bool:
	if not _is_pvp_battle():
		return _apply_api_response(response, apply_event_conditions)

	if not response is Dictionary:
		return false

	var queue_metadata := metadata.duplicate(true)
	if _response_has_renderable_battle_events(response) and not _is_authoritative_pvp_render_batch_response(response):
		queue_metadata["defer_event_dedupe"] = true

	_trace_pvp_flow("enqueue.begin", response, "source=%s apply=%s metadata=%s" % [source, str(apply_event_conditions), JSON.stringify(queue_metadata)])
	var queue_result: Dictionary = pvp_event_queue.enqueue_response(response.duplicate(true), source, apply_event_conditions, queue_metadata)
	_trace_pvp_flow("enqueue.result", response, "source=%s result=%s" % [source, JSON.stringify(queue_result)])
	if not bool(queue_result.get("enqueued", false)):
		if bool(queue_result.get("duplicate", false)) and bool(queue_result.get("dropped", false)):
			return true
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Failed enqueueing PvP battle response",
				"source=%s key=%s reason=%s" % [source, str(queue_result.get("key", "")), str(queue_result.get("reason", ""))]
			)
		return true

	if pvp_event_queue.is_rendering:
		return true

	return await _drain_pvp_event_queue()

func _drain_pvp_event_queue() -> bool:
	if pvp_event_queue.is_rendering:
		return true

	pvp_event_queue.is_rendering = true
	var all_success := true
	while pvp_event_queue.has_pending():
		var queue_entry: Dictionary = pvp_event_queue.dequeue_next()
		if queue_entry.is_empty():
			continue

		var queue_response: Dictionary = queue_entry.get("response", {})
		if not (queue_response is Dictionary):
			continue

		var apply_event_conditions := bool(queue_entry.get("apply_event_conditions", true))
		var skip_render := bool(queue_entry.get("skip_render", false))
		var source := str(queue_entry.get("source", ""))
		var metadata: Variant = queue_entry.get("metadata", {})
		_trace_pvp_flow("drain.entry", queue_response, "source=%s skipRender=%s apply=%s metadata=%s" % [
			source,
			str(skip_render),
			str(apply_event_conditions),
			JSON.stringify(metadata) if metadata is Dictionary else str(metadata),
		])
		var success := _apply_api_response(queue_response, apply_event_conditions, source)
		_trace_pvp_flow("drain.after_apply", queue_response, "source=%s success=%s skipRender=%s process=%s" % [
			source,
			str(success),
			str(skip_render),
			str(_should_process_pvp_choice_queue_entry(queue_response, source, metadata)),
		])
		if success and _should_process_pvp_choice_queue_entry(queue_response, source, metadata):
			var entry_metadata: Dictionary = {}
			if metadata is Dictionary:
				entry_metadata = metadata as Dictionary
			if not await _process_pvp_choice_queue_entry(queue_response, source, entry_metadata, skip_render):
				success = false
		elif not success and DEBUG_PVP_REALTIME:
			_log_pvp_realtime("Failed applying queued PvP battle response", "source=%s" % source)

		all_success = all_success and success

	pvp_event_queue.is_rendering = false
	return all_success

func _should_process_pvp_choice_queue_entry(response: Dictionary, source: String, metadata: Variant) -> bool:
	# Lead-completion responses establish the canonical active Pokemon, but their
	# switch events belong to the explicit post-preview intro below. Rendering an
	# authoritative batch here would play its Pokeball/cry while the six preview
	# sprites are still intentionally visible.
	if team_preview_lead_selection_active and source in [
		"pvp_choose_lead",
		"pvp_team_preview_complete",
		"pvp_team_preview_recovery",
		"pvp_room_polling_team_preview",
	]:
		return false
	if metadata is Dictionary and bool((metadata as Dictionary).get("is_local_choice", false)):
		return true
	if _is_authoritative_pvp_render_batch_response(response):
		return true
	return source in ["pvp_choose_move", "pvp_choose_switch"]

func _process_pvp_choice_queue_entry(response: Dictionary, source: String, metadata: Dictionary, skip_render: bool) -> bool:
	var is_local_choice: bool = bool(metadata.get("is_local_choice", false))
	var choice_type: String = str(metadata.get("choice_type", "switch" if source == "pvp_choose_switch" else "move"))
	var was_force_switch: bool = bool(metadata.get("was_force_switch", false))
	var pending_player_choice_events_value: Variant = metadata.get("pending_player_choice_events", [])
	var pending_player_choice_events: Array = pending_player_choice_events_value as Array if pending_player_choice_events_value is Array else []

	var batch_display_response: Dictionary = action_flow.map_response_for_local_player(response)
	var display_response := pvp_response_order.merge_latest_projection_with_events(batch_display_response)
	pending_player_choice_events = _get_pending_player_choice_events(display_response, pending_player_choice_events)

	if choice_type == "switch":
		if is_local_choice and was_force_switch:
			if not skip_render:
				if _response_has_renderable_battle_events(display_response) and not _is_authoritative_pvp_render_batch_response(response):
					current_action_panel.set_message("Waiting for opponent switch...")
					if DEBUG_PVP_REALTIME:
						_log_pvp_realtime(
							"Deferred non-authoritative PvP force-switch render",
							"source=%s batch=%s" % [source, pvp_event_queue.get_response_event_batch_id(response)]
						)
					return true
				var player_events: Array = _filter_already_rendered_events(display_response.get("events", []), {}, display_response)
				_rewind_active_hud_hp_for_events(player_events)
				_rewind_party_slots_for_events(player_events)
				if not await _render_pvp_event_batch(display_response, player_events, true, source):
					return false
				# The response can still contain already-rendered historical damage.
				# Its presentation rewind must never survive the local forced-switch
				# render path, otherwise a fainted party member appears healthy again.
				_restore_pvp_authoritative_presentation(batch_display_response, player_events)

			if await _finish_if_battle_ended():
				return true

			_clear_force_switch_request_for_player(_get_local_state_player_id())
			_update_move_slots()

			if await _hold_pvp_moves_until_force_switch_phase_release(display_response, source):
				return true

			if _show_force_switch_if_needed():
				_set_battle_input_locked(false)
				return true

			if _is_pvp_battle() and (_response_has_opponent_force_switch(display_response) or _opponent_player_needs_force_switch_ui()):
				if not await _wait_for_pvp_opponent_force_switch_and_render():
					_show_party(true)
					_set_battle_input_locked(false)
					return false

				return true

			_show_moves()
			_set_battle_input_locked(false)
			return true

		if not skip_render and _response_has_renderable_battle_events(display_response):
			if not _is_authoritative_pvp_render_batch_response(response):
				current_action_panel.set_message("Waiting for opponent...")
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Deferred non-authoritative PvP switch render",
						"source=%s batch=%s" % [source, pvp_event_queue.get_response_event_batch_id(response)]
					)
				return true
			if not await _render_pvp_opponent_response(batch_display_response, {}, [], source):
				return false
			await _hold_opponent_response_message()
		elif is_local_choice:
			if not await _wait_for_pvp_opponent_choice_and_render():
				_show_moves()
				_set_battle_input_locked(false)
				return false
		else:
			_update_battle_presentation()

		if await _finish_if_battle_ended():
			return true

		if await _hold_pvp_moves_until_force_switch_phase_release(display_response, source):
			return true

		if _show_force_switch_if_needed():
			_set_battle_input_locked(false)
			return true

		if _opponent_player_needs_force_switch_ui():
			if not await _wait_for_pvp_opponent_force_switch_and_render():
				_show_moves()
				_set_battle_input_locked(false)
				return false

			return true

		_set_battle_input_locked(false)
		_show_moves()
		return true

	if not skip_render and _response_has_renderable_battle_events(display_response):
		if not _is_authoritative_pvp_render_batch_response(response):
			current_action_panel.set_message("Waiting for opponent...")
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Deferred non-authoritative PvP move render",
					"source=%s batch=%s" % [source, pvp_event_queue.get_response_event_batch_id(response)]
				)
			return true
		if not await _render_pvp_opponent_response(batch_display_response, {}, pending_player_choice_events, source):
			return false
		await _hold_opponent_response_message()
	elif is_local_choice:
		if not await _wait_for_pvp_opponent_choice_and_render(pending_player_choice_events):
			_show_moves()
			_set_battle_input_locked(false)
			return false
	else:
		_update_battle_presentation()

	if await _finish_if_battle_ended():
		return true

	if await _hold_pvp_moves_until_force_switch_phase_release(display_response, source):
		return true

	if _show_force_switch_if_needed():
		_set_battle_input_locked(false)
		return true

	if _opponent_player_needs_force_switch_ui():
		if not await _wait_for_pvp_opponent_force_switch_and_render():
			_show_moves()
			_set_battle_input_locked(false)
			return false

		return true

	_set_battle_input_locked(false)
	_show_moves()
	return true

func _hold_pvp_moves_until_force_switch_phase_release(display_response: Dictionary, source: String) -> bool:
	if not _pvp_should_wait_for_force_switch_phase_release(display_response):
		return false

	if not _local_player_needs_force_switch_ui() and _opponent_player_needs_force_switch_ui():
		_show_pvp_opponent_force_switch_wait()
		return await _wait_for_pvp_opponent_force_switch_and_render()

	_set_battle_input_locked(true)
	current_action_panel.set_message("Waiting for switch prompt...")
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Skipping PvP moves open while force-switch phase release is pending",
			"source=%s phase=%s next=%s localForce=%s opponentForce=%s hasRequest=%s" % [
				source,
				pvp_last_phase,
				pvp_last_next_phase,
				_local_player_needs_force_switch_ui(),
				_opponent_player_needs_force_switch_ui(),
				_response_has_force_switch_request(display_response),
			]
		)

	var released := await _wait_for_pvp_force_switch_phase_release(source)
	if released:
		if _show_force_switch_if_needed():
			_set_battle_input_locked(false)
			return true
		if _opponent_player_needs_force_switch_ui():
			return await _wait_for_pvp_opponent_force_switch_and_render()
		return true

	return _pvp_is_waiting_for_force_switch_phase_release()

func _pvp_should_wait_for_force_switch_phase_release(display_response: Dictionary) -> bool:
	if not _pvp_is_waiting_for_force_switch_phase_release():
		return false
	return (
		_response_has_force_switch_request(display_response)
		or _local_player_needs_force_switch_ui()
		or _opponent_player_needs_force_switch_ui()
	)

func _apply_party_state_from_api_response(response: Dictionary) -> void:
	if not response.has("party"):
		return

	var party_value: Variant = response.get("party")
	if party_value is Array:
		var party_data: Array = party_value as Array
		if not party_data.is_empty():
			PlayerSave.replace_party_from_state(party_data)

func _sync_player_save_party_status_from_battle_state() -> void:
	var team: Array = battle_state.get_player_team(_get_local_state_player_id())
	if team.is_empty() or PlayerSave.party.is_empty():
		return

	var changed := false
	for team_index in range(team.size()):
		var team_value: Variant = team[team_index]
		if not (team_value is Dictionary):
			continue

		var team_pokemon: Dictionary = team_value as Dictionary
		var saved_pokemon := _find_saved_party_pokemon_for_battle_data(team_pokemon, team_index)
		if saved_pokemon == null:
			continue

		var next_status := _get_status_from_battle_pokemon_data(team_pokemon)
		if saved_pokemon.status != next_status:
			saved_pokemon.status = next_status
			changed = true

		var hp_snapshot: Dictionary = _get_hp_snapshot_from_battle_pokemon_data(team_pokemon)
		if not hp_snapshot.is_empty():
			var next_max_hp: int = max(int(hp_snapshot.get("max_hp", saved_pokemon.max_hp)), 1)
			var next_current_hp: int = clampi(int(hp_snapshot.get("current_hp", saved_pokemon.current_hp)), 0, next_max_hp)
			if saved_pokemon.max_hp != next_max_hp or saved_pokemon.current_hp != next_current_hp or not saved_pokemon.has_saved_hp_state:
				saved_pokemon.max_hp = next_max_hp
				saved_pokemon.current_hp = next_current_hp
				saved_pokemon.has_saved_hp_state = true
				changed = true

	if changed:
		PlayerSave.party_changed.emit()

func _find_saved_party_pokemon_for_battle_data(pokemon_data: Dictionary, fallback_index: int) -> Pokemon:
	var owned_pokemon_id := int(pokemon_data.get("ownedPokemonId", pokemon_data.get("owned_pokemon_id", 0)))
	if owned_pokemon_id > 0:
		for saved_pokemon: Pokemon in PlayerSave.party:
			if saved_pokemon != null and saved_pokemon.owned_pokemon_id == owned_pokemon_id:
				return saved_pokemon

	var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", ""))).strip_edges()
	if instance_id != "":
		for saved_pokemon: Pokemon in PlayerSave.party:
			if saved_pokemon != null and saved_pokemon.instance_id == instance_id:
				return saved_pokemon

	var metadata_slot := int(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", fallback_index + 1)))
	if metadata_slot > 0:
		var party_index := metadata_slot - 1
		if party_index >= 0 and party_index < PlayerSave.party.size():
			return PlayerSave.party[party_index]

	if fallback_index >= 0 and fallback_index < PlayerSave.party.size():
		return PlayerSave.party[fallback_index]

	return null

func _get_status_from_battle_pokemon_data(pokemon_data: Dictionary) -> String:
	var direct_status := _normalize_party_status(str(pokemon_data.get("status", "")))
	if direct_status != "":
		return direct_status

	return _get_status_from_condition_text(str(pokemon_data.get("condition", "")))

func _get_status_from_condition_text(condition: String) -> String:
	for part_value: String in condition.strip_edges().split(" ", false):
		var status := _normalize_party_status(part_value)
		if status != "":
			return status

	return ""

func _normalize_party_status(status: String) -> String:
	match status.strip_edges().to_lower():
		"psn", "poison", "poisoned":
			return "psn"
		"tox", "toxic", "badly_poisoned", "badlypoisoned":
			return "tox"
		"brn", "burn", "burned":
			return "brn"
		"par", "paralysis", "paralyzed":
			return "par"
		"slp", "sleep", "sleeping", "asleep":
			return "slp"
		"frz", "freeze", "frozen":
			return "frz"

	return ""

func _get_hp_snapshot_from_battle_pokemon_data(pokemon_data: Dictionary) -> Dictionary:
	var condition := str(pokemon_data.get("condition", "")).strip_edges()
	if condition.contains("/") and not condition.contains("fnt"):
		var hp_part := str(condition.split(" ", false)[0])
		var hp_values := hp_part.split("/", false)
		if hp_values.size() >= 2:
			return {
				"current_hp": int(hp_values[0]),
				"max_hp": max(int(hp_values[1]), 1),
			}

	if pokemon_data.has("hp") and pokemon_data.has("maxHp"):
		return {
			"current_hp": int(pokemon_data.get("hp", 0)),
			"max_hp": max(int(pokemon_data.get("maxHp", 1)), 1),
		}

	if pokemon_data.has("currentHp") and pokemon_data.has("maxHp"):
		return {
			"current_hp": int(pokemon_data.get("currentHp", 0)),
			"max_hp": max(int(pokemon_data.get("maxHp", 1)), 1),
		}

	if condition.contains("fnt"):
		return {
			"current_hp": 0,
			"max_hp": max(int(pokemon_data.get("maxHp", pokemon_data.get("max_hp", 1))), 1),
		}

	return {}

func _prewarm_current_battle_move_animations() -> void:
	var move_names: Array[String] = []
	_append_available_move_names(move_names, "p1")
	_append_available_move_names(move_names, "p2")
	_append_team_move_names(move_names, battle_state.get_player_team("p1"))
	_append_team_move_names(move_names, battle_state.get_player_team("p2"))
	_append_saved_party_move_names(move_names)

	animation_router.prewarm_move_animations(move_names)

func _prewarm_current_battle_mega_assets() -> void:
	animation_router.prewarm_effect_animations([MEGA_EVOLUTION_EFFECT_KEY])
	for player_id: String in ["p1", "p2"]:
		var mega_species := battle_state.resolve_active_mega_species(player_id)
		if mega_species == "":
			continue
		var sprite_box: Control = player_sprite_box if player_id == "p1" else enemy_sprite_box
		var side := "back" if player_id == "p1" else "front"
		if sprite_box != null and sprite_box.has_method("prewarm_species"):
			sprite_box.call("prewarm_species", mega_species, side, _get_active_pokemon_is_shiny(player_id))

func _append_available_move_names(move_names: Array[String], player_id: String) -> void:
	for move_value: Variant in battle_state.get_available_moves(player_id):
		_append_move_name_from_value(move_names, move_value)

func _append_team_move_names(move_names: Array[String], team: Array) -> void:
	for pokemon_value: Variant in team:
		if pokemon_value is Dictionary:
			var pokemon_data: Dictionary = pokemon_value as Dictionary
			_append_move_names_from_value(move_names, pokemon_data.get("moves", []))
			_append_move_names_from_value(move_names, pokemon_data.get("moveSlots", []))
			_append_move_names_from_value(move_names, pokemon_data.get("baseMoves", []))
		elif pokemon_value is Pokemon:
			var pokemon: Pokemon = pokemon_value as Pokemon
			_append_move_names_from_value(move_names, pokemon.moves)

func _append_saved_party_move_names(move_names: Array[String]) -> void:
	for pokemon_value: Variant in PlayerSave.party:
		if not pokemon_value is Pokemon:
			continue

		var pokemon: Pokemon = pokemon_value as Pokemon
		_append_move_names_from_value(move_names, pokemon.moves)

func _append_move_names_from_value(move_names: Array[String], moves_value: Variant) -> void:
	if moves_value is Array:
		for move_value: Variant in moves_value:
			_append_move_name_from_value(move_names, move_value)
		return

	_append_move_name_from_value(move_names, moves_value)

func _append_move_name_from_value(move_names: Array[String], move_value: Variant) -> void:
	var move_name: String = ""
	if move_value is Dictionary:
		var move_data: Dictionary = move_value as Dictionary
		move_name = str(move_data.get("name", move_data.get("move", move_data.get("id", ""))))
	else:
		move_name = str(move_value)

	move_name = move_name.strip_edges()
	if move_name == "" or move_names.has(move_name):
		return

	move_names.append(move_name)

func _prewarm_battle_event_animations(events: Array) -> void:
	var move_names: Array[String] = []
	var effect_keys: Array[String] = []
	var needs_damage_sound: bool = false

	for event_value: Variant in events:
		if not event_value is Dictionary:
			continue

		var event_data: Dictionary = event_value as Dictionary
		var preload_keys: Dictionary = event_presentation.get_animation_preload_keys_for_event(event_data)
		for move_name_value: Variant in preload_keys.get("move_names", []):
			var move_name: String = str(move_name_value)
			if move_name != "":
				move_names.append(move_name)
		for effect_key_value: Variant in preload_keys.get("effect_keys", []):
			var effect_key: String = str(effect_key_value)
			if effect_key != "":
				effect_keys.append(effect_key)
		if _is_switch_like_event(event_data) and not effect_keys.has(SHINY_ENTRANCE_EFFECT_KEY):
			effect_keys.append(SHINY_ENTRANCE_EFFECT_KEY)
		needs_damage_sound = needs_damage_sound or bool(preload_keys.get("needs_damage_sound", false))

	animation_router.prewarm_move_animations(move_names)
	animation_router.prewarm_effect_animations(effect_keys)
	if needs_damage_sound:
		animation_router.prewarm_common_battle_sounds()

func _remember_active_player_party_moves() -> void:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon("p1")
	if active_pokemon.is_empty():
		return

	var available_moves: Array = battle_state.get_available_moves("p1")
	if available_moves.is_empty():
		return

	var moves: Array = available_moves.duplicate(true)
	for key in _get_party_move_cache_keys(active_pokemon):
		player_party_moves_by_key[key] = moves

func _sync_player_save_from_battle_state() -> void:
	var player_team := battle_state.get_player_team("p1")
	if player_team.is_empty():
		return

	if not _team_has_move_pp_data(player_team):
		var player_request: Dictionary = battle_state.get_player_request("p1")
		var active_slots_value: Variant = player_request.get("active", [])
		if active_slots_value is Array:
			var active_slots: Array = active_slots_value as Array
			if not active_slots.is_empty():
				player_team = _inject_player_active_moves(player_team, active_slots)

	PlayerSave.apply_battle_team_state(player_team)

func _team_has_move_pp_data(team: Array) -> bool:
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var moves_value: Variant = pokemon_data.get("moves", [])
		if not (moves_value is Array):
			continue

		for move_value: Variant in moves_value:
			if not (move_value is Dictionary):
				continue

			var move_data: Dictionary = move_value as Dictionary
			if move_data.has("pp") or move_data.has("currentPp") or move_data.has("currentPP") or move_data.has("current_pp"):
				return true

	return false

func _inject_player_active_moves(team: Array, active_slots: Array) -> Array:
	var team_copy: Array = []
	for pokemon_value: Variant in team:
		if pokemon_value is Dictionary:
			team_copy.append((pokemon_value as Dictionary).duplicate(true))
		else:
			team_copy.append(pokemon_value)

	var active_team_indices: Array[int] = []
	for pokemon_index in range(team_copy.size()):
		var pokemon_value: Variant = team_copy[pokemon_index]
		if not (pokemon_value is Dictionary):
			continue

		var team_pokemon: Dictionary = pokemon_value as Dictionary
		if bool(team_pokemon.get("active", false)):
			active_team_indices.append(pokemon_index)

	var used_active_indices: Dictionary = {}
	for active_index in range(active_slots.size()):
		var active_slot_value: Variant = active_slots[active_index]
		if not (active_slot_value is Dictionary):
			continue

		var active_slot: Dictionary = active_slot_value as Dictionary
		var active_moves: Array = _get_active_slot_moves(active_slot)
		if active_moves.is_empty():
			continue

		var team_index: int = -1
		if active_index < active_team_indices.size():
			team_index = active_team_indices[active_index]

		if team_index < 0 or team_index >= team_copy.size():
			team_index = _find_matching_team_index_for_active_slot(team_copy, active_slot)

		if team_index < 0 or team_index >= team_copy.size():
			continue

		if used_active_indices.has(team_index):
			continue

		var team_pokemon: Dictionary = team_copy[team_index] as Dictionary
		team_pokemon["moves"] = active_moves
		used_active_indices[team_index] = true

	return team_copy

func _get_active_slot_moves(active_slot: Dictionary) -> Array:
	var moves_value: Variant = active_slot.get("moves", [])
	if moves_value is Array:
		return (moves_value as Array).duplicate(true)

	return []

func _find_matching_team_index_for_active_slot(team: Array, active_slot: Dictionary) -> int:
	var candidate_index: int = -1
	var candidate_names: Array[String] = []
	for key in ["activeIdent", "ident", "pokemon", "species", "name", "displaySpecies"]:
		var raw_candidate: String = str(active_slot.get(key, "")).strip_edges()
		if raw_candidate != "":
			candidate_names.append(_normalize_species_for_compare(_normalize_active_ident_to_species(raw_candidate)))

	var active_mega_slot: int = _safe_int(active_slot.get("slot", -1), -1)
	if active_mega_slot > 0 and active_mega_slot <= team.size():
		return active_mega_slot - 1

	for pokemon_index in range(team.size()):
		var pokemon_value: Variant = team[pokemon_index]
		if not (pokemon_value is Dictionary):
			continue

		var team_pokemon: Dictionary = pokemon_value as Dictionary
		var team_species_value: String = str(team_pokemon.get("species", team_pokemon.get("ident", "")))
		var team_species: String = _normalize_species_for_compare(_normalize_active_ident_to_species(team_species_value))
		if team_species == "":
			continue

		for candidate_name in candidate_names:
			if candidate_name != "" and team_species == candidate_name:
				candidate_index = pokemon_index if candidate_index == -1 else candidate_index

	if candidate_index >= 0:
		return candidate_index

	var metadata_slot_value: Variant = active_slot.get("slot", active_slot.get("metadataSlot", active_slot.get("metadata_slot", 0)))
	var metadata_slot: int = _safe_int(metadata_slot_value, -1)
	if metadata_slot > 0:
		for pokemon_index in range(team.size()):
			var pokemon_value: Variant = team[pokemon_index]
			if not (pokemon_value is Dictionary):
				continue

			var team_pokemon: Dictionary = pokemon_value as Dictionary
			if int(team_pokemon.get("metadataSlot", team_pokemon.get("metadata_slot", 0))) == metadata_slot:
				return pokemon_index

	return -1

func _normalize_active_ident_to_species(raw_ident: String) -> String:
	if raw_ident == "":
		return ""

	if raw_ident.contains(": "):
		return raw_ident.split(": ", false)[1]

	return raw_ident

func _safe_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	if value is String:
		var text: String = value.strip_edges()
		if text.is_valid_int():
			return text.to_int()
	return fallback

## Werkt actieve HP-HUDs en de losse partyrail bij vanuit de battle state.
func _update_hud_panels(include_team_data := true) -> void:
	_debug_battle_presentation_order("update_hud_panels.begin include_team=%s" % str(include_team_data))
	_update_active_hud_panel("p1", player_hud_panel)
	_update_active_hud_panel("p2", enemy_hud_panel)

	if not include_team_data:
		_debug_battle_presentation_order("update_hud_panels.skip_team")
		_sync_status_condition_overlays()
		return

	var player_display_team := _get_display_team_data("p1")
	var enemy_display_team := _get_display_team_data("p2")
	_debug_battle_presentation_order("update_party_rails.set_team_data p1=%s p2=%s" % [
		JSON.stringify(_summarize_team_for_order_debug(player_display_team)),
		JSON.stringify(_summarize_team_for_order_debug(enemy_display_team)),
	])
	_debug_trainer_team_display("party rail set_team_data", {
		"enemyTeam": _debug_summarize_display_team(enemy_display_team),
	})
	_mark_active_party_slot(player_display_team, "p1")
	_mark_active_party_slot(enemy_display_team, "p2")
	player_party_grid.set_party(player_display_team)
	opponent_party_grid.set_party(enemy_display_team)
	opponent_party_grid.set_selection_enabled(false)
	_sync_status_condition_overlays()

func _update_active_hud_panel(player_id: String, hud_panel: Node) -> void:
	if _should_hide_active_pokemon_for_force_switch(player_id):
		hud_panel.set_pokemon_data(
			_get_active_display_species(player_id),
			battle_state.get_active_pokemon_level(player_id),
			0,
			max(battle_state.get_active_pokemon_max_hp(player_id), 1),
			battle_state.get_active_pokemon_status(player_id),
			battle_state.get_active_pokemon_gender(player_id),
			_get_active_pokemon_is_shiny(player_id),
			_get_active_player_experience_data(player_id),
		)
		return

	hud_panel.set_pokemon_data(
		_get_active_display_species(player_id),
		battle_state.get_active_pokemon_level(player_id),
		battle_state.get_active_pokemon_current_hp(player_id),
		battle_state.get_active_pokemon_max_hp(player_id),
		battle_state.get_active_pokemon_status(player_id),
		battle_state.get_active_pokemon_gender(player_id),
		_get_active_pokemon_is_shiny(player_id),
		_get_active_player_experience_data(player_id),
	)

func _setup_status_condition_overlays() -> void:
	_attach_status_condition_overlay("p1", player_sprite_box, status_condition_overlays, "StatusConditionOverlay", 80)
	_attach_status_condition_overlay("p2", enemy_sprite_box, status_condition_overlays, "StatusConditionOverlay", 80)
	Callable(self, "_sync_status_condition_overlays").call_deferred()

func _attach_status_condition_overlay(player_id: String, sprite_box: Node, overlay_store: Dictionary, suffix: String, overlay_z_index: int) -> void:
	if sprite_box == null or not sprite_box.has_method("get_single_sprite_slot"):
		return

	var sprite_slot := sprite_box.call("get_single_sprite_slot") as Control
	if sprite_slot == null:
		return

	var overlay := STATUS_CONDITION_OVERLAY_SCRIPT.new()
	overlay.name = "%s%s" % [player_id.to_upper(), suffix]
	overlay.z_index = overlay_z_index
	sprite_slot.add_child(overlay)
	overlay_store[player_id] = overlay

func _sync_status_condition_overlays() -> void:
	_sync_status_condition_overlay_for_player("p1")
	_sync_status_condition_overlay_for_player("p2")

func _sync_status_condition_overlay_for_player(player_id: String) -> void:
	var overlay: Node = status_condition_overlays.get(player_id, null) as Node
	if overlay == null or not is_instance_valid(overlay):
		return

	var condition_key := ""
	if pending_status_condition_overlay_players.has(player_id):
		condition_key = ""
	elif SettingsManager.battle_animations:
		var pokemon_data := battle_state.get_active_player_pokemon(player_id)
		if not pokemon_data.is_empty() and not _active_status_overlay_should_hide(pokemon_data):
			condition_key = _get_persistent_status_condition_key(str(pokemon_data.get("status", "")))

	if overlay.has_method("set_condition"):
		overlay.call("set_condition", condition_key)

func _prepare_pending_status_condition_overlays(events: Array) -> void:
	pending_status_condition_overlay_players.clear()
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		if str(event_data.get("type", "")) != "status":
			continue
		if not _status_event_starts_persistent_condition(event_data):
			continue

		var player_id := _get_player_id_from_ident(str(event_data.get("target", event_data.get("pokemon", ""))))
		if player_id == "":
			continue

		pending_status_condition_overlay_players[player_id] = true

	if not pending_status_condition_overlay_players.is_empty():
		_sync_status_condition_overlays()

func _release_pending_status_condition_overlay(event_data: Dictionary) -> void:
	var player_id := _get_player_id_from_ident(str(event_data.get("target", event_data.get("pokemon", ""))))
	if player_id == "":
		return

	pending_status_condition_overlay_players.erase(player_id)

func _apply_volatile_condition_event(event_data: Dictionary) -> void:
	var condition_key := _get_volatile_condition_key(str(event_data.get("effect", "")))
	if condition_key == "":
		return

	var ident_key := _normalize_battle_ident(str(event_data.get("target", event_data.get("pokemon", ""))))
	if ident_key == "":
		return

	match str(event_data.get("state", "")).strip_edges().to_lower():
		"start", "activate":
			_add_volatile_condition_for_ident(ident_key, condition_key, event_data)
		"end", "cure", "cured":
			_remove_volatile_condition_for_ident(ident_key, condition_key)

func _clear_volatile_condition_for_ident(ident: String) -> void:
	var ident_key := _normalize_battle_ident(ident)
	if ident_key == "":
		return

	volatile_conditions_by_ident.erase(ident_key)
	_update_stat_stage_panels()

func _add_volatile_condition_for_ident(ident_key: String, condition_key: String, event_data: Dictionary = {}) -> void:
	var conditions: Dictionary = {}
	var existing_value: Variant = volatile_conditions_by_ident.get(ident_key, {})
	if existing_value is Dictionary:
		conditions = (existing_value as Dictionary).duplicate()

	conditions[condition_key] = _get_volatile_condition_badge_data(condition_key, event_data)
	volatile_conditions_by_ident[ident_key] = conditions
	_update_stat_stage_panels()

func _remove_volatile_condition_for_ident(ident_key: String, condition_key: String) -> void:
	var existing_value: Variant = volatile_conditions_by_ident.get(ident_key, {})
	if not existing_value is Dictionary:
		return

	var conditions := (existing_value as Dictionary).duplicate()
	conditions.erase(condition_key)
	if conditions.is_empty():
		volatile_conditions_by_ident.erase(ident_key)
	else:
		volatile_conditions_by_ident[ident_key] = conditions
	_update_stat_stage_panels()

func _get_volatile_condition_key(effect: String) -> String:
	var cleaned_effect := effect.strip_edges().to_lower()
	if cleaned_effect.begins_with("move:"):
		cleaned_effect = cleaned_effect.substr("move:".length()).strip_edges()
	match cleaned_effect.replace(" ", "").replace("_", "").replace("-", ""):
		"confusion", "confused":
			return "confused"
		"taunt", "taunted":
			return "taunt"
		"encore", "encored":
			return "encore"
		_:
			return ""

func _get_volatile_condition_badge_data(condition_key: String, event_data: Dictionary) -> Dictionary:
	var data := {
		"condition": condition_key,
	}
	var turns := _get_volatile_condition_turns(event_data)
	if turns > 0:
		data["turns"] = turns
		data["turns_started_turn"] = int(event_data.get("startedTurn", battle_state.get_turn()))

	var duration := _get_volatile_condition_duration(event_data)
	if duration > 0:
		data["duration"] = duration
		data["started_turn"] = int(event_data.get("startedTurn", battle_state.get_turn()))

	return data

func _get_volatile_condition_turns(event_data: Dictionary) -> int:
	for key in ["remainingTurns", "remaining_turns", "turns", "turnsRemaining", "turns_remaining"]:
		if not event_data.has(key):
			continue

		var turns := int(event_data.get(key, 0))
		if turns > 0:
			return turns

	return 0

func _get_volatile_condition_duration(event_data: Dictionary) -> int:
	for key in ["duration", "maxDuration", "minDuration"]:
		if not event_data.has(key):
			continue

		var duration := int(event_data.get(key, 0))
		if duration > 0:
			return duration

	return 0

func _status_event_starts_persistent_condition(event_data: Dictionary) -> bool:
	var state := str(event_data.get("state", "start")).strip_edges().to_lower()
	if state == "end" or state == "cure" or state == "cured":
		return false

	return _get_persistent_status_condition_key(str(event_data.get("status", event_data.get("condition", "")))) != ""

func _active_status_overlay_should_hide(pokemon_data: Dictionary) -> bool:
	if bool(pokemon_data.get("fainted", false)):
		return true
	if int(pokemon_data.get("hp", 1)) <= 0:
		return true
	return false

func _get_persistent_status_condition_key(status: String) -> String:
	match status.strip_edges().to_lower().replace(" ", ""):
		"par", "paralysis", "paralyzed":
			return "paralysis"
		"psn", "poison", "poisoned":
			return "poisoned"
		"tox", "toxic", "badlypoisoned", "toxicpoison":
			return "badly_poisoned"
		"brn", "burn", "burned":
			return "burned"
		"frz", "freeze", "frozen":
			return "frozen"
		"slp", "sleep", "sleeping", "asleep":
			return "sleeping"
		_:
			return ""

func _debug_summarize_display_team(team: Array) -> Array:
	var output: Array = []
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			output.append({"index": index, "value": str(pokemon_value)})
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		output.append({
			"index": index,
			"ident": str(pokemon_data.get("ident", "")),
			"active": bool(pokemon_data.get("active", false)),
			"species": str(pokemon_data.get("species", "")),
			"displaySpecies": str(pokemon_data.get("displaySpecies", "")),
			"condition": str(pokemon_data.get("condition", "")),
			"hp": str(pokemon_data.get("hp", "")),
			"maxHp": str(pokemon_data.get("maxHp", "")),
			"fainted": bool(pokemon_data.get("fainted", false)),
			"partySlot": str(pokemon_data.get("partySlot", pokemon_data.get("party_slot", ""))),
			"metadataSlot": str(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", ""))),
			"pokemonKey": str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))),
			"requestIndex": str(pokemon_data.get("requestIndex", "")),
		})

	return output

func _debug_trainer_team_display(stage: String, payload: Dictionary) -> void:
	if not DEBUG_TRAINER_TEAM_DISPLAY:
		return

	print(TRAINER_TEAM_DEBUG_PREFIX, " ", stage, " ", JSON.stringify(payload))

## Reset de battle status UI naar een lege beginstand.
func _reset_battle_status_panel() -> void:
	battle_status_panel.reset_status()
	vs_panel_container.hide_decision_timers(true)
	field_timers_panel.reset_timers()
	_update_side_condition_ui([])

func _reset_battle_effect_tracking() -> void:
	public_confirmed_abilities_by_ident.clear()
	public_confirmed_items_by_ident.clear()
	volatile_conditions_by_ident.clear()
	pending_knock_off_targets_by_ident.clear()
	pending_booster_energy_modifier_targets_by_ident.clear()
	stat_stages_by_ident.clear()
	ability_stat_modifiers_by_ident.clear()
	player_party_moves_by_key.clear()
	_update_stat_stage_panels()
	event_presentation.reset()

func _remember_public_confirmed_abilities_from_response(response: Dictionary) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		_remember_public_confirmed_item_from_event(event)
		var ability: String = _get_public_confirmed_ability_from_event(event)
		if ability == "":
			continue

		var ident: String = _get_public_confirmed_ability_ident_from_event(event)
		var ident_key: String = _normalize_battle_ident(ident)
		if ident_key == "":
			continue

		public_confirmed_abilities_by_ident[ident_key] = ability

func _remember_public_confirmed_item_from_event(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	if event_type == "move" and _normalize_item_key(str(event.get("move", ""))) == "knockoff":
		var knock_target_key := _normalize_battle_ident(str(event.get("target", "")))
		if knock_target_key != "":
			pending_knock_off_targets_by_ident[knock_target_key] = true
			if public_confirmed_items_by_ident.has(knock_target_key):
				public_confirmed_items_by_ident[knock_target_key] = _mark_item_knocked_off(str(public_confirmed_items_by_ident.get(knock_target_key, "")))
		return

	var item_ident := _get_public_confirmed_item_ident_from_event(event)
	var item_name := _get_public_confirmed_item_from_event(event)
	var ident_key := _normalize_battle_ident(item_ident)
	if ident_key == "" or item_name == "":
		return

	var target_key := _normalize_battle_ident(str(event.get("target", "")))
	if target_key != "" and target_key != ident_key and not public_confirmed_items_by_ident.has(target_key):
		public_confirmed_items_by_ident[target_key] = ""

	if event_type == "item" and str(event.get("state", "")) == "end":
		if _is_knock_off_item_end_event(event):
			public_confirmed_items_by_ident[ident_key] = _mark_item_knocked_off(item_name)
		else:
			public_confirmed_items_by_ident[ident_key] = _mark_item_consumed(item_name)
			if _normalize_item_key(item_name) == "boosterenergy":
				pending_booster_energy_modifier_targets_by_ident[ident_key] = true
		pending_knock_off_targets_by_ident.erase(ident_key)
		return

	if pending_knock_off_targets_by_ident.has(ident_key):
		public_confirmed_items_by_ident[ident_key] = _mark_item_knocked_off(item_name)
		pending_knock_off_targets_by_ident.erase(ident_key)
		return

	public_confirmed_items_by_ident[ident_key] = item_name

func _remember_battle_modifier_event(event: Dictionary) -> void:
	_remember_public_confirmed_item_from_event(event)
	match str(event.get("type", "")):
		"switch", "drag":
			_clear_volatile_condition_for_ident(str(event.get("fromIdent", "")))
			_clear_volatile_condition_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))
			_clear_stat_stages_for_ident(str(event.get("fromIdent", "")))
			_clear_stat_stages_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))
			_clear_ability_stat_modifier_for_ident(str(event.get("fromIdent", "")))
			_clear_ability_stat_modifier_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))
			_clear_pending_booster_energy_modifier_for_ident(str(event.get("fromIdent", "")))
			_clear_pending_booster_energy_modifier_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))
		"faint":
			_clear_volatile_condition_for_ident(str(event.get("target", "")))
			_clear_stat_stages_for_ident(str(event.get("target", "")))
			_clear_ability_stat_modifier_for_ident(str(event.get("target", "")))
			_clear_pending_booster_energy_modifier_for_ident(str(event.get("target", "")))
		"pokemonEffect":
			_apply_pokemon_effect_modifier_event(event)
		"ability":
			_apply_ability_stat_modifier_event(event)
		"statChange":
			_apply_stat_stage_event(event)

func _apply_stat_stage_event(event: Dictionary) -> void:
	var ident_key: String = _normalize_battle_ident(str(event.get("target", "")))
	if ident_key == "":
		return

	var stat_key: String = _normalize_stat_stage_key(str(event.get("stat", "")))
	if stat_key == "":
		return

	var stages: Dictionary = {}
	var stages_value: Variant = stat_stages_by_ident.get(ident_key, {})
	if stages_value is Dictionary:
		stages = (stages_value as Dictionary).duplicate()

	var current_stage: int = int(stages.get(stat_key, 0))
	var stage_change := event_text_formatter.get_stat_change_amount(event)
	var new_stage: int = mini(maxi(current_stage + stage_change, -6), 6)
	if new_stage == 0:
		stages.erase(stat_key)
	else:
		stages[stat_key] = new_stage

	if stages.is_empty():
		stat_stages_by_ident.erase(ident_key)
	else:
		stat_stages_by_ident[ident_key] = stages

	_update_stat_stage_panels()

func _clear_stat_stages_for_ident(ident: String) -> void:
	var ident_key: String = _normalize_battle_ident(ident)
	if ident_key == "":
		return

	stat_stages_by_ident.erase(ident_key)
	_update_stat_stage_panels()

func _apply_ability_stat_modifier_event(event: Dictionary) -> void:
	if str(event.get("effect", "")) != "boost":
		return

	var ability_name: String = str(event.get("ability", event.get("abilityName", ""))).strip_edges()
	if not _is_ability_stat_modifier_name(ability_name):
		return

	var stat_key: String = _normalize_stat_stage_key(str(event.get("stat", "")))
	if stat_key == "":
		return

	var ident_key: String = _normalize_battle_ident(str(event.get("target", event.get("actor", ""))))
	if ident_key == "":
		return

	ability_stat_modifiers_by_ident[ident_key] = {
		"ability": ability_name,
		"stat": stat_key,
		"source": _get_ability_stat_modifier_source(event),
	}
	_update_stat_stage_panels()

func _apply_pokemon_effect_modifier_event(event: Dictionary) -> void:
	var modifier: Dictionary = _get_ability_stat_modifier_from_effect(str(event.get("effect", "")))
	if modifier.is_empty():
		return

	var state: String = str(event.get("state", ""))
	if state == "activate" or state == "start":
		var ident_key: String = _normalize_battle_ident(str(event.get("target", event.get("actor", ""))))
		if ident_key == "":
			return

		modifier["source"] = _get_ability_stat_modifier_source(event)
		ability_stat_modifiers_by_ident[ident_key] = modifier
		_update_stat_stage_panels()
		return

	if state == "end":
		_clear_ability_stat_modifier_for_ident(str(event.get("target", "")))

func _clear_ability_stat_modifier_for_ident(ident: String) -> void:
	var ident_key: String = _normalize_battle_ident(ident)
	if ident_key == "":
		return

	ability_stat_modifiers_by_ident.erase(ident_key)
	_update_stat_stage_panels()

func _clear_pending_booster_energy_modifier_for_ident(ident: String) -> void:
	var ident_key: String = _normalize_battle_ident(ident)
	if ident_key == "":
		return

	pending_booster_energy_modifier_targets_by_ident.erase(ident_key)

func _get_active_stat_stages_for_party_hover(pokemon_data: Dictionary) -> Dictionary:
	if not bool(pokemon_data.get("active", false)):
		return {}

	var ident_key: String = _normalize_battle_ident(str(pokemon_data.get("ident", "")))
	if ident_key == "":
		return {}

	var stages_value: Variant = stat_stages_by_ident.get(ident_key, {})
	if stages_value is Dictionary:
		return (stages_value as Dictionary).duplicate()

	return {}

func _normalize_stat_stage_key(stat: String) -> String:
	match stat.to_lower().replace(" ", ""):
		"atk", "attack":
			return "atk"
		"def", "defense", "defence":
			return "def"
		"spa", "spatk", "specialattack":
			return "spa"
		"spd", "spdef", "specialdefense", "specialdefence":
			return "spd"
		"spe", "speed":
			return "spe"
		"acc", "accuracy":
			return "accuracy"
		"eva", "evasion":
			return "evasion"

	return ""

func _update_stat_stage_panels() -> void:
	_update_stat_stage_panel_for_player("p1", player_sprite_box)
	_update_stat_stage_panel_for_player("p2", enemy_sprite_box)

func _update_stat_stage_panel_for_player(player_id: String, sprite_box: Node) -> void:
	if sprite_box == null:
		return

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	var ident_key: String = _normalize_battle_ident(str(active_pokemon.get("ident", "")))
	if ident_key == "":
		_set_sprite_box_stat_stage_badges(sprite_box, [])
		return

	_set_sprite_box_stat_stage_badges(sprite_box, _get_stat_stage_badges_for_ident(ident_key))

func _set_sprite_box_stat_stage_badges(sprite_box: Node, badges: Array) -> void:
	if sprite_box.has_method("set_stat_stage_badges"):
		sprite_box.call("set_stat_stage_badges", badges)
	elif sprite_box.has_method("set_stat_stages"):
		sprite_box.call("set_stat_stages", {})

func _get_stat_stage_badges_for_ident(ident_key: String) -> Array:
	var badges: Array[Dictionary] = []
	var stages_value: Variant = stat_stages_by_ident.get(ident_key, {})
	if stages_value is Dictionary:
		var stages: Dictionary = stages_value as Dictionary
		for stat_key in ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]:
			var stage_value: int = int(stages.get(stat_key, 0))
			if stage_value == 0:
				continue

			badges.append({
				"label": _format_stat_badge_name(stat_key),
				"value": _format_stat_stage_badge_value(stage_value),
				"color": STAT_STAGE_BADGE_BOOST_COLOR if stage_value > 0 else STAT_STAGE_BADGE_DROP_COLOR,
			})

	var modifier_value: Variant = ability_stat_modifiers_by_ident.get(ident_key, {})
	if modifier_value is Dictionary:
		var modifier: Dictionary = modifier_value as Dictionary
		var ability_name: String = str(modifier.get("ability", "")).strip_edges()
		var stat_key: String = _normalize_stat_stage_key(str(modifier.get("stat", "")))
		if ability_name != "" and stat_key != "":
			badges.append({
				"label": "%s:" % ability_name,
				"value": _format_stat_badge_name(stat_key),
				"color": STAT_STAGE_BADGE_BOOST_COLOR,
				"line": STAT_STAGE_BADGE_LINE_MODIFIER,
			})

	var volatile_value: Variant = volatile_conditions_by_ident.get(ident_key, {})
	if volatile_value is Dictionary:
		var volatile_conditions: Dictionary = volatile_value as Dictionary
		for condition_key in ["confused", "taunt", "encore"]:
			if not volatile_conditions.has(condition_key):
				continue

			var condition_data: Dictionary = {}
			var condition_value: Variant = volatile_conditions.get(condition_key, {})
			if condition_value is Dictionary:
				condition_data = condition_value as Dictionary

			badges.append({
				"label": _format_volatile_condition_badge_name(condition_key),
				"value": _format_volatile_condition_badge_value(condition_key, condition_data),
				"color": VOLATILE_CONDITION_BADGE_COLOR,
				"line": STAT_STAGE_BADGE_LINE_MODIFIER,
			})

	return badges

func _format_volatile_condition_badge_name(condition_key: String) -> String:
	match condition_key:
		"confused":
			return "Confused"
		"taunt":
			return "Taunt:"
		"encore":
			return "Encore:"

	return condition_key.capitalize()

func _format_volatile_condition_badge_value(condition_key: String, condition_data: Dictionary) -> String:
	var turns := _get_volatile_condition_display_turns(condition_key, condition_data)
	if turns <= 0:
		return ""

	return str(turns)

func _get_volatile_condition_display_turns(condition_key: String, condition_data: Dictionary) -> int:
	var direct_turns := int(condition_data.get("turns", 0))
	if direct_turns > 0:
		var turns_started_turn := int(condition_data.get("turns_started_turn", 0))
		var direct_current_turn := battle_state.get_turn()
		if turns_started_turn > 0 and direct_current_turn > 0:
			return max(direct_turns - max(direct_current_turn - turns_started_turn, 0), 0)
		return direct_turns

	var duration := int(condition_data.get("duration", 0))
	var started_turn := int(condition_data.get("started_turn", 0))
	var current_turn := battle_state.get_turn()
	if duration > 0 and started_turn > 0 and current_turn > 0:
		return max(duration - max(current_turn - started_turn, 0), 0)

	match condition_key:
		"taunt", "encore":
			return 3

	return 0

func _format_stat_badge_name(stat_key: String) -> String:
	match stat_key:
		"atk":
			return "Atk"
		"def":
			return "Def"
		"spa":
			return "SpA"
		"spd":
			return "SpD"
		"spe":
			return "Spe"
		"accuracy":
			return "Acc"
		"evasion":
			return "Eva"

	return stat_key.capitalize()

func _format_stat_stage_badge_value(stage_value: int) -> String:
	if stage_value > 0:
		return "+%s" % stage_value

	return str(stage_value)

func _is_ability_stat_modifier_name(ability_name: String) -> bool:
	match ability_name.to_lower().replace(" ", "").replace("-", ""):
		"quarkdrive", "protosynthesis":
			return true

	return false

func _get_ability_stat_modifier_from_effect(effect: String) -> Dictionary:
	var effect_key: String = effect.to_lower().replace(" ", "").replace("-", "")
	for ability_key in ["protosynthesis", "quarkdrive"]:
		if not effect_key.begins_with(ability_key):
			continue

		var stat_key: String = _normalize_stat_stage_key(effect_key.substr(ability_key.length()))
		if stat_key == "":
			return {}

		return {
			"ability": "Quark Drive" if ability_key == "quarkdrive" else "Protosynthesis",
			"stat": stat_key,
		}

	return {}

func _get_ability_stat_modifier_source(event: Dictionary) -> String:
	if _event_mentions_booster_energy(event):
		return ABILITY_STAT_MODIFIER_SOURCE_BOOSTER_ENERGY

	var ident_key: String = _normalize_battle_ident(str(event.get("target", event.get("actor", ""))))
	if ident_key != "" and pending_booster_energy_modifier_targets_by_ident.has(ident_key):
		pending_booster_energy_modifier_targets_by_ident.erase(ident_key)
		return ABILITY_STAT_MODIFIER_SOURCE_BOOSTER_ENERGY

	return ABILITY_STAT_MODIFIER_SOURCE_FIELD_CONDITION

func _event_mentions_booster_energy(event: Dictionary) -> bool:
	for key in ["source", "sourceName", "item", "itemName", "effect", "from"]:
		var value: String = str(event.get(key, ""))
		if _normalize_field_effect_key(value).contains("boosterenergy"):
			return true

	return false

func _events_have_explicit_item_events(events: Array) -> bool:
	for event_value: Variant in events:
		if event_value is Dictionary and str((event_value as Dictionary).get("type", "")) == "item":
			return true

	return false

func _get_fallback_knock_off_item_message(event: Dictionary) -> String:
	var item_ident := _get_public_confirmed_item_ident_from_event(event)
	var ident_key := _normalize_battle_ident(item_ident)
	if ident_key == "":
		return ""

	var item_name := _get_public_confirmed_item_from_event(event)
	if item_name == "":
		return ""

	var current_item := str(public_confirmed_items_by_ident.get(ident_key, ""))
	if not pending_knock_off_targets_by_ident.has(ident_key) and not current_item.to_lower().contains("knocked off"):
		return ""

	return "%s's %s got knocked off!" % [_get_public_item_display_name(item_ident), item_name]

func _get_public_confirmed_item_from_event(event: Dictionary) -> String:
	match str(event.get("type", "")):
		"item":
			return str(event.get("item", "")).strip_edges()
		"damage", "heal", "status", "fieldEffect", "pokemonEffect":
			return _get_item_name_from_source(str(event.get("source", "")))

	return _get_item_name_from_source(str(event.get("source", "")))

func _get_public_confirmed_item_ident_from_event(event: Dictionary) -> String:
	if str(event.get("type", "")) == "item":
		return str(event.get("target", ""))

	var item_name := _get_item_name_from_source(str(event.get("source", "")))
	if item_name == "":
		return ""

	var source_target := str(event.get("sourceTarget", ""))
	if source_target != "":
		return source_target

	return _get_first_event_text_value(event, ["target", "pokemon", "actor", "sourcePokemon"])

func _get_item_name_from_source(source: String) -> String:
	var cleaned := source.strip_edges()
	if not cleaned.to_lower().begins_with("item:"):
		return ""

	return cleaned.split(":", false, 1)[1].strip_edges()

func _mark_item_knocked_off(item_name: String) -> String:
	var cleaned := item_name.strip_edges()
	if cleaned == "":
		return ""
	if cleaned.to_lower().contains("knocked off"):
		return cleaned

	return "%s (Knocked off)" % cleaned

func _mark_item_consumed(item_name: String) -> String:
	var cleaned := item_name.strip_edges()
	if cleaned == "":
		return ""
	if cleaned.to_lower().contains("consumed"):
		return cleaned

	return "%s (Consumed)" % cleaned

func _is_knock_off_item_end_event(event: Dictionary) -> bool:
	return _normalize_item_source_key(str(event.get("source", ""))) == "moveknockoff"

func _normalize_item_key(item_name: String) -> String:
	return item_name.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "")

func _normalize_item_source_key(source: String) -> String:
	return _normalize_item_key(source).replace(":", "")

func _get_public_item_display_name(ident: String) -> String:
	if ident.contains(": "):
		return str(ident.split(": ", false, 1)[1]).strip_edges()

	return ident.strip_edges()

func _get_public_confirmed_ability_from_event(event: Dictionary) -> String:
	for key in ["sourceAbility", "ability", "abilityName"]:
		var ability_name := str(event.get(key, "")).strip_edges()
		if ability_name != "":
			return ability_name

	var event_type: String = str(event.get("type", ""))
	match event_type:
		"ability":
			return str(event.get("ability", event.get("abilityName", ""))).strip_edges()
		"fieldEffect":
			return _get_ability_name_from_source(str(event.get("source", "")))
		"pokemonEffect":
			return _get_ability_name_from_source(str(event.get("effect", "")))

	return _get_ability_name_from_source(str(event.get("source", "")))

func _get_public_confirmed_ability_ident_from_event(event: Dictionary) -> String:
	match str(event.get("type", "")):
		"fieldEffect":
			return _get_first_event_text_value(event, ["sourceTarget", "sourcePokemon", "actor", "target", "pokemon"])
		"ability", "pokemonEffect":
			return _get_first_event_text_value(event, ["target", "actor", "pokemon", "sourceTarget", "sourcePokemon"])

	return _get_first_event_text_value(event, ["sourceTarget", "sourcePokemon", "target", "actor", "pokemon"])

func _get_ability_name_from_source(source: String) -> String:
	var cleaned: String = source.strip_edges()
	if cleaned.to_lower().begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()
	var cleaned_lower: String = cleaned.to_lower()
	if cleaned_lower.begins_with("ability:"):
		return cleaned.split(":", false, 1)[1].strip_edges()

	if cleaned_lower.begins_with("move:") or cleaned_lower.begins_with("item:"):
		return ""

	match cleaned_lower.replace("-", " ").replace("_", " "):
		"grassy surge", "electric surge", "misty surge", "psychic surge":
			return cleaned
		"drizzle", "drought", "sand stream", "snow warning":
			return cleaned

	return ""

## Werkt turn en field timer status bij vanuit de presentatie-state.
func _update_battle_status_panels() -> void:
	battle_status_panel.set_turn(battle_state.get_turn())
	battle_status_panel.hide_timer()
	vs_panel_container.hide_decision_timers()
	if _should_show_bank_timer_projection():
		vs_panel_container.show_decision_timers(
			PvpBattleRealtimeService.timer_projection.participant_display_for_local_player("p1", action_flow.local_player_id),
			PvpBattleRealtimeService.timer_projection.participant_display_for_local_player("p2", action_flow.local_player_id)
		)
	var field_effects := _get_display_field_effects()
	_prune_inactive_field_condition_ability_modifiers(field_effects)
	field_timers_panel.set_effects(field_effects, battle_state.get_turn())
	_update_side_condition_ui(field_effects)
	weather_presentation.update_weather(_get_active_weather_effect_id(field_effects))
	weather_presentation.update_terrain(_get_active_terrain_effect_id(field_effects))
	weather_presentation.update_trick_room(_is_trick_room_active(field_effects))

func _should_show_bank_timer_projection() -> bool:
	return PvpBattleRealtimeService.timer_projection.should_present(
		_is_pvp_battle(),
		bool(ProjectSettings.get_setting("battle/show_shadow_bank_timer", true))
	)

func _get_display_field_effects() -> Array:
	if presentation_state.has_field_snapshot:
		return presentation_state.get_field_effects()

	return battle_state.get_field_effects()

func _update_side_condition_ui(field_effects: Array) -> void:
	var player_side_effects: Array = _get_side_condition_effects("p1", field_effects)
	var enemy_side_effects: Array = _get_side_condition_effects("p2", field_effects)
	side_condition_presentation.update(player_side_effects, enemy_side_effects, battle_state.get_turn())

func _get_side_condition_effects(side_id: String, field_effects: Array) -> Array:
	var side_effects: Array = []
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if str(effect_data.get("scope", "")) != "side":
			continue
		if str(effect_data.get("effectType", "")) != "sideCondition":
			continue
		if str(effect_data.get("side", "")) != side_id:
			continue

		side_effects.append(effect_data)

	return side_effects

func _get_active_weather_effect_id(field_effects: Array) -> String:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if str(effect_data.get("effectType", "")) == "weather":
			return _get_field_effect_identifier(effect_data)

	return ""

func _get_field_effect_identifier(effect_data: Dictionary) -> String:
	var effect_id := str(effect_data.get("effectId", "")).strip_edges()
	if effect_id != "":
		return effect_id

	return str(effect_data.get("effect", "")).strip_edges()

func _get_active_terrain_effect_id(field_effects: Array) -> String:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if str(effect_data.get("effectGroup", "")) == "terrain":
			return str(effect_data.get("effectId", ""))

	return ""

func _is_trick_room_active(field_effects: Array) -> bool:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if str(effect_data.get("effectId", "")) == "TrickRoom":
			return true

	return false

func _prune_inactive_field_condition_ability_modifiers(field_effects: Array) -> void:
	if ability_stat_modifiers_by_ident.is_empty():
		return

	var has_sun: bool = _field_effects_include_any_key(field_effects, ["sun", "sunnyday", "harshsun", "desolateland"])
	var has_electric_terrain: bool = _field_effects_include_any_key(field_effects, ["electricterrain"])
	var changed: bool = false
	var ident_keys: Array = ability_stat_modifiers_by_ident.keys()
	for ident_key_value in ident_keys:
		var ident_key: String = str(ident_key_value)
		var modifier_value: Variant = ability_stat_modifiers_by_ident.get(ident_key, {})
		if not (modifier_value is Dictionary):
			continue

		var modifier: Dictionary = modifier_value as Dictionary
		var ability_key: String = _normalize_ability_stat_modifier_key(str(modifier.get("ability", "")))
		var modifier_source: String = str(modifier.get("source", ABILITY_STAT_MODIFIER_SOURCE_FIELD_CONDITION))
		if modifier_source != ABILITY_STAT_MODIFIER_SOURCE_FIELD_CONDITION:
			continue

		if ability_key == "protosynthesis" and not has_sun:
			ability_stat_modifiers_by_ident.erase(ident_key)
			changed = true
		elif ability_key == "quarkdrive" and not has_electric_terrain:
			ability_stat_modifiers_by_ident.erase(ident_key)
			changed = true

	if changed:
		_update_stat_stage_panels()

func _field_effects_include_any_key(field_effects: Array, expected_keys: Array) -> bool:
	for effect_value in field_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		for key in ["effectId", "effect", "name"]:
			var effect_key: String = _normalize_field_effect_key(str(effect_data.get(key, "")))
			if effect_key != "" and expected_keys.has(effect_key):
				return true

	return false

func _normalize_field_effect_key(effect: String) -> String:
	var cleaned: String = effect.strip_edges()
	if cleaned.to_lower().begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()
	if cleaned.contains(":"):
		cleaned = str(cleaned.split(":", false, 1)[1]).strip_edges()

	return cleaned.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "")

func _normalize_ability_stat_modifier_key(ability_name: String) -> String:
	return ability_name.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "")

func _update_battle_platform_hazards() -> void:
	_update_side_condition_ui(_get_display_field_effects())

## Initialiseert een wild battle vanuit een al gemaakte API battle response.
func setup_wild_battle_from_response(player_pokemon: Pokemon, enemy_pokemon: Pokemon, api_response: Dictionary) -> void:
	_prepare_battle_setup(BattleType.WILD, player_pokemon, enemy_pokemon)

	player_sprite_box.set_single_pokemon(player_pokemon, "back")
	enemy_sprite_box.set_single_pokemon(enemy_pokemon, "front")

	if not _apply_initial_battle_response(api_response):
		return

	var player_species := _get_original_active_player_species(player_pokemon.species)
	var opponent_species := _get_active_display_species("p2")
	_debug_battle_start_response("wild.setup.after_apply", api_response)
	_debug_battle_start_active_snapshot("wild.setup.after_apply")

	_add_battle_log_messages(setup_flow.get_wild_battle_start_messages(player_species, opponent_species))
	_show_original_player_lead_before_initial_events(player_species, player_pokemon)
	await get_tree().process_frame
	_debug_battle_start("wild.setup.before_player_lead_summon playerSpecies=%s opponentSpecies=%s lastRenderedSeq=%d" % [
		player_species,
		opponent_species,
		last_rendered_event_seq,
	])
	await _play_lead_summon(_get_active_summon_ball_item_id("p1", player_pokemon.ball_item_id), player_species, player_sprite_box, "back")
	_debug_battle_start("wild.setup.after_player_lead_summon lastRenderedSeq=%d" % last_rendered_event_seq)
	await _render_initial_battle_events(api_response)
	_show_battle_controls_after_initial_events()
	_set_battle_actions_ready(true)

func setup_trainer_battle_from_response(player_pokemon: Pokemon, trainer_data: Dictionary, api_response: Dictionary) -> void:
	_prepare_battle_setup(BattleType.TRAINER, player_pokemon, null)
	display_data_presenter.set_trainer_team(api_response.get("trainerTeam", []))

	if not _apply_team_preview_battle_response(api_response):
		return

	if not _should_show_team_preview(api_response):
		_show_default_trainer_leads_before_selection(player_pokemon, api_response)

	var lead_response := await _run_trainer_lead_selection(api_response)
	if lead_response.is_empty():
		return

	var player_species := _get_original_active_player_species(_get_active_display_species("p1"))
	var opponent_species := _get_active_display_species("p2")
	_debug_battle_start_response("trainer.lead.after_selection", lead_response)
	_debug_battle_start_active_snapshot("trainer.lead.after_selection")
	_add_battle_log_messages(setup_flow.get_trainer_battle_start_messages(
		player_species,
		opponent_species,
		trainer_data,
		_get_player_display_name("p2")
	))
	# Team Preview owns the field until both preview layers have been cleared.
	# Keep the real lead containers hidden while their sprites are populated so
	# they can only become visible at the Pokeball release frame.
	await _prepare_team_preview_lead_summon_transition()
	_show_original_player_lead_before_initial_events(player_species, player_pokemon)
	_show_original_active_pokemon_for_player("p2", opponent_species)
	await get_tree().process_frame
	_debug_battle_start("trainer.setup.before_lead_summons playerSpecies=%s opponentSpecies=%s lastRenderedSeq=%d" % [
		player_species,
		opponent_species,
		last_rendered_event_seq,
	])
	await _play_lead_summon(_get_active_summon_ball_item_id("p1", player_pokemon.ball_item_id), player_species, player_sprite_box, "back")
	await _play_lead_summon(_get_active_summon_ball_item_id("p2", "poke-ball"), opponent_species, enemy_sprite_box, "front")
	_debug_battle_start("trainer.setup.after_lead_summons lastRenderedSeq=%d" % last_rendered_event_seq)
	await _render_initial_battle_events(lead_response)
	_show_battle_controls_after_initial_events()
	_set_battle_actions_ready(true)

func setup_pvp_battle_from_response(player_pokemon: Pokemon, api_response: Dictionary) -> void:
	var local_player_id := str(api_response.get("playerId", "p1"))
	action_flow.set_local_player_id(local_player_id)
	pvp_room_code = str(api_response.get("roomCode", "")).strip_edges()
	pvp_match_id = str(api_response.get("matchId", "")).strip_edges()
	var display_response: Dictionary = action_flow.map_response_for_local_player(api_response)
	_prepare_battle_setup(BattleType.TRAINER, player_pokemon, null)

	var is_team_preview_response := _should_show_team_preview(display_response)
	var restored_history_log := false
	var lead_response: Dictionary = display_response
	if is_team_preview_response:
		if not _apply_team_preview_battle_response(api_response):
			return
		_set_pvp_party_hud_display_override()
		_connect_pvp_realtime(local_player_id, str(api_response.get("battleId", "")), api_response)
		lead_response = await _run_pvp_team_preview_lead_selection(local_player_id)
		if lead_response.is_empty():
			return
	else:
		if not _apply_initial_battle_response(api_response):
			return
		_set_pvp_party_hud_display_override()
		_show_default_trainer_leads_before_selection(player_pokemon, display_response)
		_connect_pvp_realtime(local_player_id, str(api_response.get("battleId", "")), api_response)

	restored_history_log = _restore_battle_log_from_history_response(display_response)
	if not restored_history_log:
		_add_battle_log_messages([
			"%s wants to battle!" % _get_player_display_name("p2"),
			"Go! %s!" % _get_active_display_species("p1"),
			"%s sent out %s!" % [_get_player_display_name("p2"), _get_active_display_species("p2")],
		])
	var player_species := _get_original_active_player_species(_get_active_display_species("p1"))
	var opponent_species := _get_active_display_species("p2")
	# A realtime Team Preview completion can arrive in the same frame as the
	# lead intro. Clear both preview layers again at the presentation boundary so
	# their six sprites can never overlap the Pokeball summon animation.
	await _prepare_team_preview_lead_summon_transition()
	_show_original_player_lead_before_initial_events(player_species, player_pokemon)
	_show_original_active_pokemon_for_player("p2", opponent_species)
	await get_tree().process_frame
	await _play_lead_summon(_get_active_summon_ball_item_id("p1", player_pokemon.ball_item_id), player_species, player_sprite_box, "back")
	await _play_lead_summon(_get_active_summon_ball_item_id("p2", "poke-ball"), opponent_species, enemy_sprite_box, "front")
	if not restored_history_log:
		await _render_initial_battle_events(lead_response)
	_show_battle_controls_after_initial_events()
	_set_battle_actions_ready(true)

func _set_pvp_party_hud_display_override() -> void:
	if not _is_pvp_battle():
		return
	get_tree().call_group("ui_overlay", "set_party_display_override", _get_lead_selection_team_data("p1"))

func _clear_pvp_party_hud_display_override() -> void:
	get_tree().call_group("ui_overlay", "clear_party_display_override")

func _prepare_battle_setup(type: BattleType, player_pokemon: Pokemon, enemy_pokemon: Pokemon) -> void:
	battle_type = type
	if action_buttons.has_method("set_action_label"):
		action_buttons.set_action_label("run", "Run" if battle_type == BattleType.WILD else "Forfeit")
	_set_battle_actions_ready(false)
	queued_battle_action.clear()
	pvp_last_phase = ""
	pvp_last_next_phase = ""
	pvp_last_phase_update_server_seq = 0
	pvp_last_phase_update_batch_id = ""
	pvp_last_phase_update_phase = ""
	pvp_presentation_actionable_local_msec = 0
	pvp_presentation_schedule_token = ""
	pvp_response_order.reset()
	pending_battle_end_result.clear()
	battle_end_signal_emitted = false
	battle_result_overlay.visible = false
	last_rendered_event_seq = -1
	rendered_non_pvp_event_keys.clear()
	active_player_pokemon = player_pokemon
	active_enemy_pokemon = enemy_pokemon
	display_data_presenter.set_battle_context(type, active_enemy_pokemon)
	_reset_battle_effect_tracking()
	presentation_state.reset()
	pending_mega_species_by_ident.clear()
	animation_router.prewarm_effect_animations([SHINY_ENTRANCE_EFFECT_KEY, MEGA_EVOLUTION_EFFECT_KEY])

func _apply_initial_battle_response(api_response: Dictionary) -> bool:
	if not _apply_api_response(api_response, false):
		return false

	_update_battle_status_panels()
	_update_party_slots()
	_update_vs_panel_names()
	return true

func _apply_team_preview_battle_response(api_response: Dictionary) -> bool:
	if not _apply_api_response(api_response):
		return false

	_update_battle_status_panels()
	player_hud_panel.clear_active_pokemon_data()
	enemy_hud_panel.clear_active_pokemon_data()
	_update_party_slots()
	_update_vs_panel_names()
	return true

func _show_default_trainer_leads_before_selection(player_pokemon: Pokemon, api_response: Dictionary) -> void:
	player_sprite_box.set_single_pokemon(player_pokemon, "back")
	player_hud_panel.set_pokemon_data(
		player_pokemon.species,
		player_pokemon.level,
		player_pokemon.current_hp,
		max(player_pokemon.max_hp, 1),
		"",
		"",
		player_pokemon.shiny,
		_pokemon_experience_data_from_saved_pokemon(player_pokemon)
	)

	var trainer_team_value: Variant = api_response.get("trainerTeam", [])
	if not (trainer_team_value is Array):
		return

	var trainer_team: Array = trainer_team_value as Array
	if trainer_team.is_empty():
		return

	var lead_value: Variant = trainer_team[0]
	if not (lead_value is Dictionary):
		return

	var lead_data: Dictionary = lead_value as Dictionary
	var species: String = str(lead_data.get("displaySpecies", lead_data.get("species", "")))
	if species == "":
		return

	var level: int = int(lead_data.get("level", 100))
	var max_hp: int = max(int(lead_data.get("maxHp", lead_data.get("max_hp", 1))), 1)
	var hp: int = int(lead_data.get("hp", lead_data.get("currentHp", lead_data.get("current_hp", max_hp))))
	var status: String = str(lead_data.get("status", ""))
	var gender: String = str(lead_data.get("gender", ""))
	var is_shiny: bool = bool(lead_data.get("shiny", false))
	_set_single_pokemon_species_with_pvp_warning(enemy_sprite_box, species, "front", is_shiny, "initial_setup")
	enemy_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)

func _render_initial_battle_events(api_response: Dictionary) -> void:
	_debug_battle_start_response("initial.render.enter", api_response)
	_debug_battle_start_active_snapshot("initial.render.enter")
	event_renderer.add_turn_header(battle_state.get_turn())
	_remember_initial_non_pvp_setup_events()
	var start_events := _get_wild_battle_start_events(api_response.get("events", []))
	_debug_battle_start("initial.render.start_events selected=%s" % _summarize_battle_events(start_events))
	if _show_original_transform_targets_before_initial_events(start_events):
		await get_tree().process_frame
		await get_tree().create_timer(INITIAL_TRANSFORM_REVEAL_SECONDS).timeout
	else:
		await get_tree().process_frame
	if _is_pvp_battle():
		# Initial shiny entrances are setup-only presentation before the first render batch exists.
		pvp_allow_setup_animation = true
		await _play_initial_shiny_entrance_effects()
		pvp_allow_setup_animation = false
	else:
		await _play_initial_shiny_entrance_effects()
	if _is_pvp_battle():
		await _render_pvp_event_batch(api_response, start_events, false, "initial_battle_events")
	else:
		await _render_battle_events(start_events, false, "initial_battle_events")
		_mark_initial_non_pvp_response_events_consumed(api_response)
	_debug_battle_start_active_snapshot("initial.render.exit")
	_debug_battle_start("initial.render.exit lastRenderedSeq=%d" % last_rendered_event_seq)

func _show_battle_controls_after_initial_events() -> void:
	_update_battle_presentation("initial_setup")
	_show_moves()
	if current_action_view == ActionView.MOVES and not battle_input_locked:
		_show_current_action_prompt()

func _show_original_player_lead_before_initial_events(species: String, fallback_pokemon: Pokemon = null) -> void:
	if species == "":
		return

	var level: int = battle_state.get_active_pokemon_level("p1")
	var hp: int = battle_state.get_active_pokemon_current_hp("p1")
	var max_hp: int = max(battle_state.get_active_pokemon_max_hp("p1"), 1)
	var status: String = battle_state.get_active_pokemon_status("p1")
	var gender: String = battle_state.get_active_pokemon_gender("p1")
	# Use the exact same resolved identity as the entrance sparkle. Team Preview
	# projections can temporarily omit instanceId while still retaining canonical
	# slot/species identity; the old strict save lookup then loaded normal frames
	# before the correctly resolved shiny entrance ran.
	var is_shiny := _get_active_pokemon_is_shiny_for_entrance("p1")

	_set_single_pokemon_species_with_pvp_warning(player_sprite_box, species, "back", is_shiny, "initial_setup")
	player_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny, _get_active_player_experience_data("p1", fallback_pokemon))

func _play_lead_summon(ball_item_id: String, cry_species: String, sprite_box: Control, side: String) -> void:
	if sprite_box == null:
		return
	if pokeball_summon_animation_player == null:
		return

	var target_rect: Rect2 = _get_summon_target_rect(sprite_box)
	var arena_rect: Rect2 = _get_battle_arena_global_rect()
	_prepare_summon_target_hidden(sprite_box)
	summon_target_sprite_box = sprite_box
	var previous_release_audio_mode := summon_release_audio_mode
	var previous_release_cry_species := summon_release_cry_species
	summon_release_audio_mode = SUMMON_RELEASE_AUDIO_BALL
	summon_release_cry_species = cry_species
	await pokeball_summon_animation_player.play_summon(ball_item_id, target_rect, side, arena_rect)
	summon_release_audio_mode = previous_release_audio_mode
	summon_release_cry_species = previous_release_cry_species
	_reset_summon_target_visibility(sprite_box)
	if summon_target_sprite_box == sprite_box:
		summon_target_sprite_box = null

func _on_summon_ball_thrown() -> void:
	SfxManager.play("summon_throw")

func _on_summon_pokemon_released() -> void:
	_play_summon_release_audio()
	_play_summon_release_cry()
	_fade_summon_target_to_alpha(summon_target_sprite_box, 1.0, 0.16)

func _play_summon_release_audio() -> void:
	match summon_release_audio_mode:
		SUMMON_RELEASE_AUDIO_BALL:
			SfxManager.play("summon_release")
		SUMMON_RELEASE_AUDIO_NONE:
			pass

func _play_summon_release_cry() -> void:
	if summon_release_cry_species.strip_edges() == "":
		return

	SfxManager.play_pokemon_cry(summon_release_cry_species)

func _play_switch_recall(ball_item_id: String, sprite_box: Control, side: String) -> void:
	if sprite_box == null:
		return
	if pokeball_summon_animation_player == null:
		return

	var original_z_index := sprite_box.z_index
	var original_z_as_relative := sprite_box.z_as_relative
	var original_scale := sprite_box.scale
	var original_modulate := sprite_box.modulate
	var original_pivot_offset := sprite_box.pivot_offset
	var target_rect: Rect2 = _get_summon_target_rect(sprite_box)
	var arena_rect: Rect2 = _get_battle_arena_global_rect()

	sprite_box.visible = true
	sprite_box.z_index = 80
	sprite_box.z_as_relative = true
	sprite_box.pivot_offset = sprite_box.size * 0.5

	var recall_tween := create_tween()
	recall_tween.set_parallel(true)
	recall_tween.tween_property(sprite_box, "scale", original_scale * 0.12, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	recall_tween.tween_property(sprite_box, "modulate", Color(0.72, 0.92, 1.0, 0.0), 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	SfxManager.play("summon_release")
	await pokeball_summon_animation_player.play_recall(ball_item_id, target_rect, side, arena_rect)
	if recall_tween != null and recall_tween.is_valid():
		recall_tween.kill()

	sprite_box.visible = false
	sprite_box.scale = original_scale
	sprite_box.modulate = original_modulate
	sprite_box.pivot_offset = original_pivot_offset
	sprite_box.z_index = original_z_index
	sprite_box.z_as_relative = original_z_as_relative

func _play_switch_release(ball_item_id: String, cry_species: String, sprite_box: Control, side: String) -> void:
	if sprite_box == null:
		return
	if pokeball_summon_animation_player == null:
		return

	var target_rect: Rect2 = _get_summon_target_rect(sprite_box)
	var arena_rect: Rect2 = _get_battle_arena_global_rect()
	_prepare_summon_target_hidden(sprite_box)
	summon_target_sprite_box = sprite_box
	var previous_release_audio_mode := summon_release_audio_mode
	var previous_release_cry_species := summon_release_cry_species
	summon_release_audio_mode = SUMMON_RELEASE_AUDIO_NONE
	summon_release_cry_species = cry_species
	await pokeball_summon_animation_player.play_release(ball_item_id, target_rect, side, arena_rect)
	summon_release_audio_mode = previous_release_audio_mode
	summon_release_cry_species = previous_release_cry_species
	_reset_summon_target_visibility(sprite_box)
	if summon_target_sprite_box == sprite_box:
		summon_target_sprite_box = null

func _play_switch_recall_for_event(event_data: Dictionary, player_id: String) -> void:
	if not _should_play_switch_ball_animation(player_id):
		return

	var sprite_box := _get_switch_animation_sprite_box(player_id)
	if sprite_box == null or not sprite_box.visible or sprite_box.modulate.a <= 0.02:
		return

	await _play_switch_recall(_get_switch_recall_ball_item_id(event_data, player_id), sprite_box, _get_switch_animation_side(player_id))

func _play_switch_release_for_event(event_data: Dictionary, player_id: String) -> void:
	if not _should_play_switch_ball_animation(player_id):
		return

	var sprite_box := _get_switch_animation_sprite_box(player_id)
	if sprite_box == null:
		return

	var switch_ident := _get_switch_event_ident(event_data)
	var species := _get_switch_event_species(event_data, switch_ident)
	await _play_switch_release(_get_switch_release_ball_item_id(event_data, player_id), species, sprite_box, _get_switch_animation_side(player_id))

func _should_play_switch_ball_animation(player_id: String) -> bool:
	if player_id == "p1":
		return true
	if player_id == "p2":
		return battle_type != BattleType.WILD

	return false

func _get_switch_animation_sprite_box(player_id: String) -> Control:
	match player_id:
		"p1":
			return player_sprite_box
		"p2":
			return enemy_sprite_box

	return null

func _get_switch_animation_side(player_id: String) -> String:
	return "back" if player_id == "p1" else "front"

func _get_switch_recall_ball_item_id(event_data: Dictionary, player_id: String) -> String:
	var from_ident := str(event_data.get("fromIdent", event_data.get("from_ident", ""))).strip_edges()
	var pokemon_data := _get_player_team_pokemon_data_by_ident(player_id, from_ident)
	if pokemon_data.is_empty():
		pokemon_data = battle_state.get_active_player_pokemon(player_id)
	return _get_player_pokemon_data_ball_item_id(pokemon_data, "poke-ball")

func _get_switch_release_ball_item_id(event_data: Dictionary, player_id: String) -> String:
	var switch_ident := _get_switch_event_ident(event_data)
	var team := battle_state.get_player_team(player_id)
	var target_index := _find_temporary_switch_target_index(team, switch_ident, event_data)
	if target_index >= 0 and target_index < team.size():
		var pokemon_value: Variant = team[target_index]
		if pokemon_value is Dictionary:
			return _get_player_pokemon_data_ball_item_id(pokemon_value as Dictionary, "poke-ball")

	if player_id == "p1":
		return _get_active_summon_ball_item_id(player_id, "poke-ball")

	return "poke-ball"

func _get_player_team_pokemon_data_by_ident(player_id: String, ident: String) -> Dictionary:
	var normalized_ident := _normalize_battle_ident(ident)
	if normalized_ident == "":
		return {}

	for pokemon_value: Variant in battle_state.get_player_team(player_id):
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _normalize_battle_ident(str(pokemon_data.get("ident", ""))) == normalized_ident:
			return pokemon_data

	return {}

func _get_player_pokemon_data_ball_item_id(pokemon_data: Dictionary, fallback_item_id: String = "poke-ball") -> String:
	if pokemon_data.is_empty():
		return fallback_item_id

	var saved_ball_item_id := _get_saved_pokemon_ball_item_id_for_data(pokemon_data)
	if saved_ball_item_id != "":
		return saved_ball_item_id

	for key in ["ballItemId", "ball_item_id", "summonBallItemId", "summon_ball_item_id", "caughtBallItemId", "caught_ball_item_id", "caughtWith", "caught_with"]:
		var item_id := _normalize_pokeball_item_id(str(pokemon_data.get(key, "")))
		if item_id != "":
			return item_id

	return fallback_item_id

func _get_saved_pokemon_ball_item_id_for_data(pokemon_data: Dictionary) -> String:
	var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", ""))).strip_edges()
	if instance_id == "":
		return ""

	for pokemon_value in PlayerSave.party:
		var pokemon: Pokemon = pokemon_value as Pokemon
		if pokemon == null:
			continue

		if pokemon.instance_id == instance_id:
			return _normalize_pokeball_item_id(pokemon.ball_item_id)

	return ""

func _normalize_pokeball_item_id(item_id: String) -> String:
	return item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")

func _get_summon_target_rect(sprite_box: Control) -> Rect2:
	if sprite_box != null and sprite_box.has_method("get_single_sprite_slot"):
		var sprite_slot: Control = sprite_box.get_single_sprite_slot()
		if sprite_slot != null and sprite_slot.get_global_rect().size != Vector2.ZERO:
			return sprite_slot.get_global_rect()

	return sprite_box.get_global_rect()

func _get_battle_arena_global_rect() -> Rect2:
	if battle_stage != null and battle_stage.get_global_rect().size != Vector2.ZERO:
		return battle_stage.get_global_rect()
	if battle_background != null and battle_background.get_global_rect().size != Vector2.ZERO:
		return battle_background.get_global_rect()
	if player_sprite_box != null and player_sprite_box.get_parent() is Control:
		var arena_control := player_sprite_box.get_parent() as Control
		return arena_control.get_global_rect()
	return Rect2()

func _get_active_summon_ball_item_id(player_id: String, fallback_item_id: String = "poke-ball") -> String:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	var active_ball_item_id := _get_player_pokemon_data_ball_item_id(active_pokemon, "")
	if active_ball_item_id != "":
		return active_ball_item_id

	if player_id == "p1":
		var saved_pokemon := _get_saved_pokemon_for_active_data(active_pokemon)
		if saved_pokemon != null and saved_pokemon.ball_item_id.strip_edges() != "":
			return saved_pokemon.ball_item_id

	var fallback := fallback_item_id.strip_edges()
	if fallback == "":
		return "poke-ball"

	return fallback

func _prepare_summon_target_hidden(sprite_box: Control) -> void:
	_stop_summon_target_visibility_tween()
	if sprite_box == null:
		return

	summon_original_z_index = sprite_box.z_index
	summon_original_z_as_relative = sprite_box.z_as_relative
	sprite_box.z_index = 80
	sprite_box.z_as_relative = true
	sprite_box.visible = false
	var color: Color = sprite_box.modulate
	color.a = 0.0
	sprite_box.modulate = color

func _reset_summon_target_visibility(sprite_box: Control) -> void:
	_stop_summon_target_visibility_tween()
	if sprite_box == null:
		return

	sprite_box.visible = true
	sprite_box.z_index = summon_original_z_index
	sprite_box.z_as_relative = summon_original_z_as_relative
	var color: Color = sprite_box.modulate
	color.a = 1.0
	sprite_box.modulate = color

func _fade_summon_target_to_alpha(sprite_box: Control, target_alpha: float, duration: float) -> void:
	_stop_summon_target_visibility_tween()
	if sprite_box == null:
		return

	sprite_box.visible = true
	summon_target_visibility_tween = create_tween()
	summon_target_visibility_tween.tween_property(sprite_box, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _stop_summon_target_visibility_tween() -> void:
	if summon_target_visibility_tween != null and summon_target_visibility_tween.is_valid():
		summon_target_visibility_tween.kill()

	summon_target_visibility_tween = null

func _show_original_transform_targets_before_initial_events(events: Array) -> bool:
	var showed_original_target := false

	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) != "transform":
			continue

		var target_ident := str(event.get("target", ""))
		var player_id := _get_player_id_from_ident(target_ident)
		var original_species := _get_species_from_ident(target_ident)
		if player_id == "" or original_species == "":
			continue

		_show_original_active_pokemon_for_player(player_id, original_species)
		showed_original_target = true

	return showed_original_target

func _show_original_active_pokemon_for_player(player_id: String, species: String) -> void:
	if species == "":
		return

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	var level: int = battle_state.get_active_pokemon_level(player_id)
	var hp: int = battle_state.get_active_pokemon_current_hp(player_id)
	var max_hp: int = max(battle_state.get_active_pokemon_max_hp(player_id), 1)
	var status: String = battle_state.get_active_pokemon_status(player_id)
	var gender: String = battle_state.get_active_pokemon_gender(player_id)
	var is_shiny := _get_active_pokemon_is_shiny(player_id)

	if player_id == "p1":
		var saved_shiny := _get_saved_pokemon_shiny_for_active_data(active_pokemon)
		is_shiny = saved_shiny
		_set_single_pokemon_species_with_pvp_warning(player_sprite_box, species, "back", is_shiny, "initial_setup")
		player_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny, _get_active_player_experience_data("p1"))
	elif player_id == "p2":
		_set_single_pokemon_species_with_pvp_warning(enemy_sprite_box, species, "front", is_shiny, "initial_setup")
		enemy_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)

func _get_original_active_player_species(fallback_species: String = "") -> String:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon("p1")
	var saved_pokemon := _get_saved_pokemon_for_active_data(active_pokemon)
	if saved_pokemon != null:
		return saved_pokemon.species

	if _is_specific_battle_form_species(fallback_species):
		return fallback_species

	var ident := str(active_pokemon.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return fallback_species

func _get_saved_pokemon_shiny_for_active_data(active_pokemon: Dictionary) -> bool:
	var saved_pokemon := _get_saved_pokemon_for_active_data(active_pokemon)
	if saved_pokemon == null:
		return false

	return saved_pokemon.shiny

func _get_active_player_experience_data(player_id: String, fallback_pokemon: Pokemon = null) -> Dictionary:
	if player_id != "p1":
		return {}

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	var saved_pokemon := _get_player_save_pokemon_for_battle_display_data(active_pokemon)
	if saved_pokemon == null:
		saved_pokemon = fallback_pokemon
	return _pokemon_experience_data_from_saved_pokemon(saved_pokemon)

func _pokemon_experience_data_from_saved_pokemon(pokemon: Pokemon) -> Dictionary:
	if pokemon == null:
		return {}
	if pokemon.next_level_exp <= pokemon.current_level_exp:
		return {}

	return {
		"experience": pokemon.experience,
		"currentLevelExp": pokemon.current_level_exp,
		"nextLevelExp": pokemon.next_level_exp,
	}

func _get_saved_pokemon_for_active_data(active_pokemon: Dictionary) -> Pokemon:
	var instance_id := str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", ""))).strip_edges()
	if instance_id == "":
		return null

	for pokemon_value in PlayerSave.party:
		var pokemon: Pokemon = pokemon_value as Pokemon
		if pokemon == null:
			continue

		if pokemon.instance_id == instance_id:
			return pokemon

	return null

func _run_trainer_lead_selection(api_response: Dictionary) -> Dictionary:
	if _should_show_team_preview(api_response):
		return await _run_trainer_team_preview_lead_selection()

	return await _run_default_trainer_lead_selection()

func _should_show_team_preview(api_response: Dictionary) -> bool:
	var battle_options_value: Variant = api_response.get("battleOptions", {})
	if battle_options_value is Dictionary:
		var battle_options: Dictionary = battle_options_value as Dictionary
		if bool(battle_options.get("teamPreview", false)):
			return true

	var requests_value: Variant = api_response.get("requests", {})
	if not (requests_value is Dictionary):
		return false

	var requests: Dictionary = requests_value as Dictionary
	for request_value: Variant in requests.values():
		if not (request_value is Dictionary):
			continue

		var request: Dictionary = request_value as Dictionary
		if bool(request.get("teamPreview", false)):
			return true

	return false

func _run_default_trainer_lead_selection() -> Dictionary:
	_set_battle_input_locked(true)
	var player_lead_response := await _submit_lead("p1", 1)
	if not bool(player_lead_response.get("success", false)):
		var error_message := str(player_lead_response.get("error", "Cannot choose player lead!"))
		current_action_panel.set_message(error_message)
		_add_battle_log_message(error_message)
		_set_battle_input_locked(false)
		return {}

	var npc_lead_response := await _submit_npc_lead()
	if not bool(npc_lead_response.get("success", false)):
		var error_message := str(npc_lead_response.get("error", "The trainer could not choose a lead!"))
		current_action_panel.set_message(error_message)
		_add_battle_log_message(error_message)
		_set_battle_input_locked(false)
		return {}

	_set_battle_input_locked(false)
	return npc_lead_response

func _run_trainer_team_preview_lead_selection() -> Dictionary:
	team_preview_lead_selection_active = true
	queued_battle_action.clear()
	_show_team_preview_layers()
	_set_battle_input_locked(false)
	current_action_panel.set_message("Choose your Lead")
	current_action_view = ActionView.PARTY
	moves_grid.visible = false
	player_party_grid.set_party(_get_trainer_lead_selection_party_data())
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	action_buttons.set_action_disabled("fight", true)
	action_buttons.set_action_disabled("bag", true)
	action_buttons.set_action_disabled("run", true)
	action_buttons.set_selected_action("party")
	_sync_action_panel_mode_visibility()

	while team_preview_lead_selection_active:
		var selected_slot: int = int(await player_party_grid.party_selected)
		if not _can_choose_trainer_lead_slot(selected_slot):
			current_action_panel.set_message("Choose another Pokemon!")
			continue

		_set_battle_input_locked(true)
		var lead_response := await _submit_lead("p1", selected_slot)
		if not bool(lead_response.get("success", false)):
			var error_message := str(lead_response.get("error", "Cannot choose that lead!"))
			current_action_panel.set_message(error_message)
			_add_battle_log_message(error_message)
			_set_battle_input_locked(false)
			continue

		var npc_lead_response := await _submit_npc_lead()
		if not bool(npc_lead_response.get("success", false)):
			var error_message := str(npc_lead_response.get("error", "The trainer could not choose a lead!"))
			current_action_panel.set_message(error_message)
			_add_battle_log_message(error_message)
			_set_battle_input_locked(false)
			continue

		team_preview_lead_selection_active = false
		_hide_team_preview_layers()
		player_party_grid.visible = true
		opponent_party_grid.visible = true
		current_action_view = ActionView.NONE
		_set_battle_input_locked(false)
		_sync_action_panel_mode_visibility()
		return npc_lead_response

	return {}

func _get_trainer_lead_selection_party_data() -> Array:
	var party: Array = []
	for pokemon_value: Variant in PlayerSave.party:
		var pokemon: Pokemon = pokemon_value as Pokemon
		if pokemon == null:
			party.append({
				"species": "",
				"fainted": true,
				"hp": 0,
				"currentHp": 0,
				"maxHp": 1,
			})
			continue

		var max_hp: int = max(pokemon.max_hp, int(pokemon.stats.get("hp", pokemon.max_hp)), 1)
		var current_hp: int = pokemon.current_hp
		if not pokemon.has_saved_hp_state and current_hp <= 0:
			current_hp = max_hp

		var pokemon_data: Dictionary = pokemon.to_battle_dict()
		pokemon_data["hp"] = clamp(current_hp, 0, max_hp)
		pokemon_data["currentHp"] = clamp(current_hp, 0, max_hp)
		pokemon_data["maxHp"] = max_hp
		pokemon_data["condition"] = "0 fnt" if current_hp <= 0 else "%s/%s" % [current_hp, max_hp]
		pokemon_data["fainted"] = current_hp <= 0
		pokemon_data["active"] = false
		party.append(pokemon_data)

	return party

func _can_choose_trainer_lead_slot(slot: int) -> bool:
	if slot < 1 or slot > PlayerSave.party.size():
		return false

	var pokemon: Pokemon = PlayerSave.party[slot - 1] as Pokemon
	if pokemon == null:
		return false

	if pokemon.species.strip_edges() == "":
		return false

	if pokemon.has_saved_hp_state and pokemon.current_hp <= 0:
		return false

	return true

func _run_pvp_team_preview_lead_selection(local_player_id: String) -> Dictionary:
	team_preview_lead_selection_active = true
	queued_battle_action.clear()
	_show_team_preview_layers()
	_set_battle_input_locked(false)
	current_action_panel.set_message("Choose your Lead")
	current_action_view = ActionView.PARTY
	moves_grid.visible = false
	player_party_grid.set_party(_get_lead_selection_team_data("p1"))
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	action_buttons.set_action_disabled("fight", true)
	action_buttons.set_action_disabled("bag", true)
	action_buttons.set_action_disabled("run", true)
	action_buttons.set_selected_action("party")
	_sync_action_panel_mode_visibility()

	while team_preview_lead_selection_active:
		var selected_slot: int = int(await player_party_grid.party_selected)
		var pending_completion := await _consume_pending_pvp_team_preview_completion()
		if not pending_completion.is_empty():
			return _finish_pvp_team_preview_selection(pending_completion)
		var selected_pokemon_data := _get_party_grid_selected_pokemon_data(selected_slot)
		var submit_slot := _get_canonical_lead_submit_slot(selected_slot, selected_pokemon_data)
		if DEBUG_PVP_REALTIME:
			var local_state_player_id := _get_local_state_player_id()
			_log_pvp_realtime(
				"PvP lead selected",
				"visualSlot=%d canonicalSlot=%d selected=%s canonicalTeam=%s" % [
					selected_slot,
					submit_slot,
					_describe_pokemon_debug_ref(selected_pokemon_data),
					_describe_pokemon_debug_ref(_get_team_pokemon_data_for_canonical_party_slot(local_state_player_id, submit_slot)),
				]
			)

		if not _can_choose_lead_slot(submit_slot, selected_pokemon_data):
			current_action_panel.set_message("Choose another Pokemon!")
			continue

		var selected_lead_name := _get_switch_confirmation_pokemon_name(selected_pokemon_data)
		_set_battle_input_locked(true)
		var lead_response: Dictionary = await _submit_lead(local_player_id, submit_slot)
		pending_completion = await _consume_pending_pvp_team_preview_completion()
		if not pending_completion.is_empty():
			return _finish_pvp_team_preview_selection(pending_completion)
		if not bool(lead_response.get("success", false)):
			var error_message := str(lead_response.get("error", "Cannot choose that lead!"))
			current_action_panel.set_message(error_message)
			_add_battle_log_message(error_message)
			_set_battle_input_locked(false)
			continue

		if _should_show_team_preview(lead_response):
			_show_pvp_lead_confirmation(selected_lead_name)
			current_action_panel.set_message("Waiting for the other player...")
			current_action_view = ActionView.NONE
			moves_grid.visible = false
			opponent_party_grid.visible = true
			_sync_action_panel_mode_visibility()
			lead_response = await _wait_for_pvp_team_preview_complete(local_player_id)
			if lead_response.is_empty():
				_clear_pvp_switch_confirmation()
				current_action_view = ActionView.PARTY
				_sync_action_panel_mode_visibility()
				_set_battle_input_locked(false)
				continue

		return _finish_pvp_team_preview_selection(lead_response)

	return {}

func _finish_pvp_team_preview_selection(lead_response: Dictionary) -> Dictionary:
	team_preview_lead_selection_active = false
	pvp_team_preview_recovery_requested = false
	pvp_pending_team_preview_completion.clear()
	_clear_pvp_switch_confirmation()
	_hide_team_preview_layers()
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	current_action_view = ActionView.NONE
	_set_battle_input_locked(false)
	_sync_action_panel_mode_visibility()
	return lead_response

func _wait_for_pvp_team_preview_complete(local_player_id: String) -> Dictionary:
	if pvp_room_code == "":
		return {}

	for _attempt in range(600):
		var pending_completion := await _consume_pending_pvp_team_preview_completion()
		if not pending_completion.is_empty():
			return pending_completion
		var message: Dictionary = await _wait_for_next_pvp_realtime_update(0.1)
		if message.is_empty():
			continue
		var message_type := str(message.get("type", "")).strip_edges().to_lower()
		if message_type == "pvp.phase_update" and str(message.get("phase", "")).strip_edges() == "turn_open":
			var polled_response: Dictionary = await _get_pvp_team_preview_complete_room_response(local_player_id)
			if not polled_response.is_empty():
				return polled_response
			continue
		if str(message.get("action", "")) != "choose_lead":
			continue
		if str(message.get("playerId", "")) == local_player_id:
			continue

		var response: Dictionary = _response_from_pvp_realtime_message(message)
		if response.is_empty():
			continue

		var display_response: Dictionary = action_flow.map_response_for_local_player(response)
		if _should_show_team_preview(display_response):
			continue

		if not await _enqueue_pvp_battle_response(response, "pvp_team_preview_complete", false):
			return {}

		return display_response

	current_action_panel.set_message("Opponent lead timed out.")
	return {}

func _consume_pending_pvp_team_preview_completion() -> Dictionary:
	if pvp_pending_team_preview_completion.is_empty():
		return {}
	var response := pvp_pending_team_preview_completion.duplicate(true)
	pvp_pending_team_preview_completion.clear()
	if not await _enqueue_pvp_battle_response(response, "pvp_team_preview_recovery", false):
		return {}
	return action_flow.map_response_for_local_player(response)

func _request_pvp_team_preview_recovery_if_server_advanced() -> void:
	if not team_preview_lead_selection_active or pvp_team_preview_recovery_requested:
		return
	if not pvp_pending_team_preview_completion.is_empty():
		return
	var projection := PvpBattleRealtimeService.timer_projection
	if not projection.has_advanced_beyond_team_preview():
		return
	pvp_team_preview_recovery_requested = true
	_recover_pvp_team_preview_from_room.call_deferred()

func _recover_pvp_team_preview_from_room() -> void:
	if not team_preview_lead_selection_active or pvp_room_code == "":
		pvp_team_preview_recovery_requested = false
		return
	var response: Dictionary = await BattleApiClient.get_pvp_room(
		battle_request,
		pvp_room_code,
		action_flow.local_player_id
	)
	pvp_team_preview_recovery_requested = false
	if not team_preview_lead_selection_active or not bool(response.get("success", false)):
		return
	var display_response := action_flow.map_response_for_local_player(response)
	if display_response.is_empty() or _should_show_team_preview(display_response):
		return
	pvp_pending_team_preview_completion = response.duplicate(true)
	player_party_grid.party_selected.emit(0)

func _get_pvp_team_preview_complete_room_response(local_player_id: String) -> Dictionary:
	var response: Dictionary = await BattleApiClient.get_pvp_room(battle_request, pvp_room_code, local_player_id)
	if not bool(response.get("success", false)):
		return {}

	var display_response: Dictionary = action_flow.map_response_for_local_player(response)
	if _should_show_team_preview(display_response):
		return {}

	if not await _enqueue_pvp_battle_response(response, "pvp_room_polling_team_preview", false):
		return {}

	return display_response

func _poll_pvp_room_until_team_preview_complete(local_player_id: String) -> Dictionary:
	if pvp_room_code == "":
		return {}

	while team_preview_lead_selection_active:
		await get_tree().create_timer(1.0).timeout
		var completed_response: Dictionary = await _get_pvp_team_preview_complete_room_response(local_player_id)
		if completed_response.is_empty():
			continue

		return completed_response

	return {}

func _show_team_preview_layers() -> void:
	# A delayed recovery/update must never redraw Team Preview after lead choice.
	if not team_preview_lead_selection_active:
		return

	player_sprite_box.visible = false
	enemy_sprite_box.visible = false
	player_hud_panel.visible = false
	enemy_hud_panel.visible = false

	if player_team_preview_layer.has_method("show_team"):
		player_team_preview_layer.call("show_team", _get_display_team_data("p1"), "back")
	if enemy_team_preview_layer.has_method("show_team"):
		enemy_team_preview_layer.call("show_team", _get_display_team_data("p2"), "front")


func _hide_team_preview_layers() -> void:
	_clear_team_preview_visuals()
	player_hud_panel.visible = true
	enemy_hud_panel.visible = true

func _prepare_team_preview_lead_summon_transition() -> void:
	_clear_team_preview_visuals()
	player_sprite_box.visible = false
	enemy_sprite_box.visible = false

	# process_frame resumes before the viewport has necessarily drawn. Waiting for
	# frame_post_draw guarantees one complete frame with no preview Pokemon before
	# the Pokeball throw signal, release sound, or cry can begin.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# Close over any delayed preview redraw that arrived during the frame barrier.
	_clear_team_preview_visuals()

func _clear_team_preview_visuals() -> void:
	if player_team_preview_layer.has_method("clear"):
		player_team_preview_layer.call("clear")
	if enemy_team_preview_layer.has_method("clear"):
		enemy_team_preview_layer.call("clear")

	player_team_preview_layer.visible = false
	enemy_team_preview_layer.visible = false

func _get_lead_selection_team_data(player_id: String) -> Array:
	var lead_team: Array = []
	var display_team: Array = _get_display_team_data(player_id)
	for index in range(display_team.size()):
		var pokemon_value: Variant = display_team[index]
		if pokemon_value is Dictionary:
			var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate(true)
			_enrich_lead_selection_slot_data(pokemon_data, index, player_id)
			_apply_lead_selection_availability(player_id, pokemon_data, index)
			pokemon_data["active"] = false
			lead_team.append(pokemon_data)
		else:
			lead_team.append(pokemon_value)

	return lead_team

func _enrich_lead_selection_slot_data(pokemon_data: Dictionary, index: int, player_id: String = "") -> void:
	var saved_pokemon := _get_player_save_pokemon_for_battle_display_data(pokemon_data, index)
	if saved_pokemon == null:
		return

	var types_value: Variant = pokemon_data.get("types", [])
	var missing_types := not (types_value is Array) or (types_value as Array).is_empty()
	if not pokemon_data.has("types") or missing_types:
		pokemon_data["types"] = saved_pokemon.types
	if not pokemon_data.has("possibleAbilities"):
		pokemon_data["possibleAbilities"] = saved_pokemon.possible_abilities
	if not pokemon_data.has("shiny"):
		pokemon_data["shiny"] = saved_pokemon.shiny
	if not pokemon_data.has("instanceId") and saved_pokemon.instance_id != "":
		pokemon_data["instanceId"] = saved_pokemon.instance_id
	if _should_show_battle_ready_pvp_lead_hp(player_id):
		_apply_battle_ready_lead_selection_hp(pokemon_data, saved_pokemon)
		return
	_apply_saved_lead_selection_hp(pokemon_data, saved_pokemon)

func _should_show_battle_ready_pvp_lead_hp(player_id: String) -> bool:
	return _is_pvp_battle() and player_id == _get_local_state_player_id()

func _apply_battle_ready_lead_selection_hp(pokemon_data: Dictionary, saved_pokemon: Pokemon) -> void:
	var max_hp: int = max(saved_pokemon.max_hp, int(saved_pokemon.stats.get("hp", saved_pokemon.max_hp)), 1)
	pokemon_data["hp"] = max_hp
	pokemon_data["maxHp"] = max_hp
	pokemon_data["currentHp"] = max_hp
	pokemon_data["fainted"] = false
	pokemon_data["condition"] = "%s/%s" % [max_hp, max_hp]

func _apply_saved_lead_selection_hp(pokemon_data: Dictionary, saved_pokemon: Pokemon) -> void:
	if saved_pokemon == null or not saved_pokemon.has_saved_hp_state:
		return

	var max_hp: int = max(saved_pokemon.max_hp, 1)
	var hp: int = clamp(saved_pokemon.current_hp, 0, max_hp)
	pokemon_data["hp"] = hp
	pokemon_data["maxHp"] = max_hp
	pokemon_data["currentHp"] = hp
	pokemon_data["fainted"] = hp <= 0
	pokemon_data["condition"] = "0 fnt" if hp <= 0 else "%s/%s" % [hp, max_hp]

func _apply_lead_selection_availability(player_id: String, pokemon_data: Dictionary, fallback_index: int) -> void:
	if _should_show_battle_ready_pvp_lead_hp(player_id):
		return

	var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	if canonical_slot <= 0:
		canonical_slot = fallback_index + 1

	var canonical_pokemon := _get_team_pokemon_data_for_canonical_party_slot(player_id, canonical_slot)
	if canonical_pokemon.is_empty():
		return

	if _is_pokemon_data_usable_for_lead(canonical_pokemon):
		return

	pokemon_data["fainted"] = true
	pokemon_data["hp"] = 0
	if canonical_pokemon.has("maxHp"):
		pokemon_data["maxHp"] = max(int(canonical_pokemon.get("maxHp", 1)), 1)
	elif not pokemon_data.has("maxHp"):
		pokemon_data["maxHp"] = 1
	pokemon_data["condition"] = "0 fnt"

func _add_battle_log_messages(messages: Array[String]) -> void:
	for message in messages:
		if message == "":
			continue

		_add_battle_log_message(message)

func _add_battle_log_message(message: String) -> void:
	if message == "":
		return

	battle_log_panel.add_message(message)
	if mini_battle_feed != null:
		mini_battle_feed.add_message(message)

func _restore_battle_log_from_snapshot(response: Dictionary) -> void:
	if _restore_battle_log_from_history_response(response):
		return

	var log_value: Variant = response.get("log", [])
	if not (log_value is Array):
		return
	if (log_value as Array).is_empty():
		return

	battle_log_panel.clear_log()
	if mini_battle_feed != null:
		mini_battle_feed.clear()
	event_renderer.reset_battle_log_player_gap()

	for log_entry: Variant in log_value as Array:
		var line := str(log_entry).strip_edges()
		if line == "":
			continue

		var turn_number := _parse_battle_log_turn_header(line)
		if turn_number > 0:
			event_renderer.add_turn_header(turn_number)
			continue

		_add_battle_log_message(line)

func _restore_battle_log_from_history_response(response: Dictionary) -> bool:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array) or (events_value as Array).is_empty():
		return false

	battle_log_panel.clear_log()
	if mini_battle_feed != null:
		mini_battle_feed.clear()
	event_renderer.reset_battle_log_player_gap()

	var restored_count := 0
	for event_value: Variant in events_value as Array:
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		var presentation: Dictionary = event_presentation.build(event_data)
		var turn := int(presentation.get("turn", 0))
		if turn > 0:
			event_renderer.add_turn_header(turn)
			restored_count += 1
			continue

		var pre_log_message := str(presentation.get("pre_log_message", ""))
		var log_message := str(presentation.get("log_message", ""))
		if pre_log_message != "":
			_add_battle_log_message(pre_log_message)
			restored_count += 1
		if log_message != "":
			_add_battle_log_message(log_message)
			restored_count += 1

	if restored_count > 0:
		var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
		if response_event_seq >= 0:
			pvp_event_queue.last_rendered_seq = max(pvp_event_queue.last_rendered_seq, response_event_seq)
			last_rendered_event_seq = max(last_rendered_event_seq, response_event_seq)
		pvp_rendered_event_count = max(pvp_rendered_event_count, (events_value as Array).size())
	return restored_count > 0

func _parse_battle_log_turn_header(line: String) -> int:
	var normalized := line.strip_edges().to_lower()
	if not normalized.begins_with("turn "):
		return -1

	var raw_turn := normalized.substr(5).strip_edges()
	var end_index := 0
	while end_index < raw_turn.length():
		var character := raw_turn.substr(end_index, 1)
		if not character.is_valid_int():
			break
		end_index += 1

	if end_index <= 0:
		return -1

	return int(raw_turn.substr(0, end_index))

## Stuurt de gekozen player move door en laat de backend de NPC-keuze verwerken.
func _on_moves_grid_move_selected(slot: int) -> void:
	_focus_battle_ui_layer()
	if current_action_panel_mode == BattleActionsPanelMode.CALC:
		return

	if battle_input_locked:
		return
	if not _pvp_timer_allows_control():
		return

	var use_mega := mega_evolution_selected
	var pending_player_choice_events: Array = _build_pending_player_mega_events(use_mega)
	var local_state_player_id := _get_local_state_player_id()
	var available_moves := battle_state.get_available_moves(local_state_player_id)
	var selected_move_data: Dictionary = available_moves[slot - 1] if slot > 0 and slot <= available_moves.size() and available_moves[slot - 1] is Dictionary else {}
	var pvp_move_context := {
		"pokemon_name": _get_active_display_species(local_state_player_id),
		"move_name": _get_move_confirmation_name(selected_move_data),
	}
	_hide_move_hover()
	_set_battle_input_locked(true)
	moves_grid.visible = false
	if use_mega:
		current_action_panel.set_message("Preparing Mega Evolution...")
	_clear_mega_evolution_selection()
	var player_response: Dictionary = {}
	if _is_pvp_battle():
		player_response = await _submit_player_choice("move", slot, use_mega, pending_player_choice_events, pvp_move_context)
	else:
		player_response = await _submit_player_choice_and_resolve("move", slot, use_mega)

	if not player_response.get("success", false):
		_clear_pending_mega_species_for_events(pending_player_choice_events)
		_show_moves()
		_set_battle_input_locked(false)
		return

	pending_player_choice_events = _get_pending_player_choice_events(player_response, pending_player_choice_events)
	if _is_pvp_battle():
		return

	if not await _render_resolved_player_choice_response(player_response, pending_player_choice_events):
		_clear_pending_mega_species_for_events(pending_player_choice_events)
		_show_moves()
		_set_battle_input_locked(false)
		return

	if await _finish_if_battle_ended():
		return

	if await _auto_force_switch_opponent_if_needed():
		if await _finish_if_battle_ended():
			return

	if _show_force_switch_if_needed():
		_set_battle_input_locked(false)
		return

	_update_move_slots()
	_set_battle_input_locked(false)
	_show_moves()

func _render_pvp_event_batch(response: Dictionary, events: Array, render_turn_headers := true, source := "") -> bool:
	if not _is_pvp_battle():
		await _render_battle_events(events, render_turn_headers, source)
		return true

	var render_batch_response := pvp_response_order.render_batch_projection_for(response)
	_trace_pvp_flow("render_batch.enter", response, "source=%s events=%d renderTurns=%s" % [source, events.size(), str(render_turn_headers)])
	if events.is_empty():
		if _pvp_response_has_render_batch_metadata(response):
			var empty_batch_context: Dictionary = pvp_event_queue.begin_render_batch(render_batch_response, source)
			if not bool(empty_batch_context.get("started", false)):
				_trace_pvp_flow("render_batch.empty_rejected", response, "source=%s context=%s" % [source, JSON.stringify(empty_batch_context)])
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Empty PvP render batch rejected",
						"source=%s current=%s reason=%s" % [
							source,
							str(empty_batch_context.get("current_event_batch_id", "")),
							str(empty_batch_context.get("reason", "")),
						]
					)
				return false
			_trace_pvp_flow("render_batch.empty_complete", response, "source=%s context=%s" % [source, JSON.stringify(empty_batch_context)])
			pvp_event_queue.complete_render_batch(empty_batch_context, true)
			return true
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping empty PvP render batch",
				"source=%s phase=%s next=%s eventSeq=%d batchSeq=%d" % [
					source,
					str(response.get("phase", "")),
					str(response.get("nextPhase", response.get("next_phase", ""))),
					_get_int_from_variant(response.get("eventSeq", -1), -1),
					_get_int_from_variant(response.get("batchSeq", -1), -1),
				]
			)
		return true

	var batch_context: Dictionary = pvp_event_queue.begin_render_batch(render_batch_response, source)
	if not bool(batch_context.get("started", false)):
		_trace_pvp_flow("render_batch.rejected", response, "source=%s context=%s" % [source, JSON.stringify(batch_context)])
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"PvP render batch rejected",
				"source=%s current=%s reason=%s" % [
					source,
					str(batch_context.get("current_event_batch_id", "")),
					str(batch_context.get("reason", "")),
				]
			)
		return false

	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Starting PvP render batch",
			"source=%s batch=%s batchSeq=%d eventSeqEnd=%d events=%d phase=%s next=%s" % [
				source,
				str(batch_context.get("event_batch_id", "")),
				_get_int_from_variant(batch_context.get("batch_seq", -1), -1),
				_get_int_from_variant(batch_context.get("event_seq_end", -1), -1),
				events.size(),
				str(render_batch_response.get("phase", "")),
				str(render_batch_response.get("nextPhase", render_batch_response.get("next_phase", ""))),
			]
		)

	var success := false
	await _render_battle_events(events, render_turn_headers, "pvp_event_batch:%s" % source)
	success = true
	if success:
		_mark_pvp_response_events_rendered(response)
		_update_battle_status_panels()
	_trace_pvp_flow("render_batch.complete", response, "source=%s success=%s context=%s" % [source, str(success), JSON.stringify(batch_context)])
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Completing PvP render batch",
			"source=%s batch=%s success=%s lastRenderedBeforeComplete=%d" % [
				source,
				str(batch_context.get("event_batch_id", "")),
				success,
				pvp_event_queue.last_rendered_seq,
			]
		)
	pvp_event_queue.complete_render_batch(batch_context, success)
	return success

func _guard_pvp_render_runner(source := "") -> bool:
	if not _is_pvp_battle():
		return true
	var current_batch_id := str(pvp_event_queue.current_event_batch_id)
	if current_batch_id != "":
		return true

	var context := source if source != "" else "unknown"
	var details := "source=%s phase=%s nextPhase=%s currentBatch=%s lastRenderedSeq=%d" % [
		context,
		pvp_last_phase if pvp_last_phase != "" else "unknown",
		pvp_last_next_phase if pvp_last_next_phase != "" else "unknown",
		current_batch_id if current_batch_id != "" else "none",
		pvp_event_queue.last_rendered_seq,
	]
	push_warning("PvP render bypassed BattleEventQueue runner; skipping render. %s" % details)
	_log_pvp_realtime("PvP render bypassed BattleEventQueue runner", details)
	return false

func _can_start_pvp_render_animation(source: String, details: Dictionary = {}) -> bool:
	if not _is_pvp_battle():
		return true
	if str(pvp_event_queue.current_event_batch_id) != "":
		return true
	if pvp_allow_setup_animation:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime("Allowed PvP setup animation outside render batch", "source=%s details=%s" % [source, str(details)])
		return true

	var warning_details := "source=%s details=%s phase=%s nextPhase=%s lastRenderedSeq=%d" % [
		source,
		str(details),
		pvp_last_phase if pvp_last_phase != "" else "unknown",
		pvp_last_next_phase if pvp_last_next_phase != "" else "unknown",
		pvp_event_queue.last_rendered_seq,
	]
	push_warning("Unauthorized PvP animation outside active render batch; skipping. %s" % warning_details)
	_log_pvp_realtime("Unauthorized PvP animation outside active render batch", warning_details)
	return false

func _set_single_pokemon_species_with_pvp_warning(
	sprite_box: Node,
	species: String,
	side: String,
	is_shiny: bool,
	context: String
) -> void:
	_debug_battle_start("sprite.set context=%s side=%s species=%s shiny=%s current=%s" % [
		context,
		side,
		species,
		str(is_shiny),
		_get_sprite_box_debug_species(sprite_box),
	])
	_warn_if_pvp_species_change_outside_batch(sprite_box, species, context)
	sprite_box.set_single_pokemon_species(species, side, is_shiny)

func _warn_if_pvp_species_change_outside_batch(sprite_box: Node, species: String, context: String) -> void:
	if not _is_pvp_battle():
		return
	if str(pvp_event_queue.current_event_batch_id) != "":
		return
	if context in ["initial_setup", "team_preview_setup", "snapshot_reconciliation", "settings_sprite_refresh"]:
		return
	if sprite_box != null and sprite_box.has_method("is_showing_species") and bool(sprite_box.call("is_showing_species", species)):
		return

	var details := "context=%s species=%s phase=%s nextPhase=%s lastRenderedSeq=%d" % [
		context,
		species,
		pvp_last_phase if pvp_last_phase != "" else "unknown",
		pvp_last_next_phase if pvp_last_next_phase != "" else "unknown",
		pvp_event_queue.last_rendered_seq,
	]
	push_warning("PvP sprite species changed outside active render batch. %s" % details)
	_log_pvp_realtime("PvP sprite species changed outside active render batch", details)

func _render_battle_events(events: Array, render_turn_headers := true, source := "") -> void:
	if not _guard_pvp_render_runner(source):
		return
	var ordered_events: Array = _order_switch_out_heals_before_switches(_order_form_change_events_before_moves(events))
	_debug_battle_start("render.begin source=%s renderTurns=%s input=%s ordered=%s lastRenderedSeq=%d" % [
		source,
		str(render_turn_headers),
		_summarize_battle_events(events),
		_summarize_battle_events(ordered_events),
		last_rendered_event_seq,
	])
	var has_explicit_item_events := _events_have_explicit_item_events(ordered_events)
	var should_play_switch_ball_animations := source != "initial_battle_events"
	_prewarm_battle_event_animations(ordered_events)
	_prepare_pending_status_condition_overlays(ordered_events)
	event_presentation.reset_recent_context()

	for event_index: int in range(ordered_events.size()):
		var event: Variant = ordered_events[event_index]
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		var fallback_knock_off_message := _get_fallback_knock_off_item_message(event_data) if not has_explicit_item_events else ""
		_remember_battle_modifier_event(event_data)

		var event_type: String = str(event_data.get("type", ""))
		if _should_debug_battle_start_event(event_data):
			_debug_battle_start("render.event.before source=%s index=%d event=%s active=%s" % [
				source,
				event_index,
				_summarize_battle_event(event_data),
				_summarize_active_battle_state(),
			])
		if event_type == "mega" or event_type == "primal":
			_fill_mega_event_species(event_data)
			battle_state.apply_event_conditions([event_data])
			_update_active_pokemon_presentation_for_ident(str(event_data.get("target", "")))
			_clear_pending_mega_species_for_event(event_data)

		var presentation: Dictionary = event_presentation.build(event_data)
		if event_type == "move":
			var starts_charge_turn := _move_event_starts_a_charge_turn(ordered_events, event_index)
			if starts_charge_turn:
				_suppress_charge_turn_move_presentation(presentation)
			else:
				var move_animation_result := _get_move_animation_result_for_event(ordered_events, event_index)
				if move_animation_result != "":
					presentation["move_animation_result"] = move_animation_result
		elif event_type == "damage":
			var direct_release_move := _get_direct_prepare_release_move(ordered_events, event_index, event_data)
			if not direct_release_move.is_empty():
				presentation["attack_actor_ident"] = str(direct_release_move.get("actor", ""))
				presentation["move_animation_name"] = str(direct_release_move.get("move", ""))
				presentation["move_animation_actor_ident"] = str(direct_release_move.get("actor", ""))
				presentation["move_animation_target_ident"] = str(direct_release_move.get("target", ""))
		var turn := int(presentation.get("turn", 0))
		if turn > 0:
			if render_turn_headers:
				event_renderer.add_turn_header(turn)
			_update_stat_stage_panels()
			continue

		_show_switch_out_heal_target_if_needed(event_data, ordered_events, event_index)
		if event_type == "fieldEffect":
			_apply_field_presentation_event(event_data)
		if event_type == "damage" or event_type == "heal" or event_type == "faint":
			_debug_battle_presentation_order("render_event.before type=%s event=%s" % [
				event_type,
				_summarize_hp_event_for_order_debug(event_data),
			])
		await event_renderer.render_event(event_data, presentation)
		if event_type == "pokemonEffect":
			_apply_volatile_condition_event(event_data)
		if event_type == "damage" or event_type == "heal" or event_type == "faint":
			_debug_battle_presentation_order("render_event.after type=%s event=%s" % [
				event_type,
				_summarize_hp_event_for_order_debug(event_data),
			])
		if fallback_knock_off_message != "":
			_add_battle_log_message(fallback_knock_off_message)
			current_action_panel.set_message(fallback_knock_off_message)
		if event_type == "damage" or event_type == "heal" or event_type == "faint":
			_debug_battle_presentation_order("apply_event_conditions.before type=%s" % event_type)
			battle_state.apply_event_conditions([event_data])
			_debug_battle_presentation_order("apply_event_conditions.after p1=%s p2=%s" % [
				JSON.stringify(_summarize_team_for_order_debug(_get_display_team_data("p1"))),
				JSON.stringify(_summarize_team_for_order_debug(_get_display_team_data("p2"))),
			])
		if event_type == "status":
			battle_state.apply_event_conditions([event_data])
			_release_pending_status_condition_overlay(event_data)
			_update_hud_panels()
			_update_party_slots()
		if event_type == "switch" or event_type == "drag":
			var switch_player_id := _get_switch_event_player_id(event_data)
			if should_play_switch_ball_animations:
				await _play_switch_recall_for_event(event_data, switch_player_id)
			battle_state.apply_event_conditions([event_data])
			_update_hud_panels()
			_show_switch_event_active_pokemon(event_data)
			if should_play_switch_ball_animations:
				await _play_switch_release_for_event(event_data, switch_player_id)
			await _play_shiny_entrance_if_needed(event_data)
		if event_type == "transform":
			battle_state.apply_event_conditions([event_data])
			_update_hud_panels()
			_update_active_sprites()
		if _should_debug_battle_start_event(event_data):
			_debug_battle_start("render.event.after source=%s index=%d event=%s active=%s" % [
				source,
				event_index,
				_summarize_battle_event(event_data),
				_summarize_active_battle_state(),
			])

	_remember_rendered_non_pvp_event_keys(ordered_events)
	# PvP presentation advances through ordered fieldEffect events. Replacing it
	# with a canonical projection here can erase Light Screen or weather before
	# the render cursor reaches the projection that ended it.
	if not _is_pvp_battle():
		_sync_presentation_field_from_battle_state()
	_prune_inactive_field_condition_ability_modifiers(_get_display_field_effects())
	_update_battle_status_panels()
	pending_status_condition_overlay_players.clear()
	_update_hud_panels()
	_update_party_slots()
	_update_vs_panel_names()
	_sync_player_save_from_battle_state()
	_debug_battle_start("render.end source=%s lastRenderedSeq=%d active=%s" % [
		source,
		last_rendered_event_seq,
		_summarize_active_battle_state(),
	])

func _get_move_animation_result_for_event(events: Array, event_index: int) -> String:
	if event_index < 0 or event_index >= events.size():
		return ""
	if not (events[event_index] is Dictionary):
		return ""

	var move_event: Dictionary = events[event_index] as Dictionary
	if str(move_event.get("type", "")) != "move":
		return ""

	for next_index: int in range(event_index + 1, events.size()):
		var next_value: Variant = events[next_index]
		if not (next_value is Dictionary):
			continue

		var next_event: Dictionary = next_value as Dictionary
		var next_type := str(next_event.get("type", ""))
		if next_type == "miss":
			return "miss" if _miss_event_matches_move_event(move_event, next_event) else ""
		if _is_move_animation_result_boundary_event(next_event):
			return ""

	return ""


func _move_event_starts_a_charge_turn(events: Array, event_index: int) -> bool:
	if event_index < 0 or event_index >= events.size():
		return false
	if not (events[event_index] is Dictionary):
		return false

	var move_event: Dictionary = events[event_index] as Dictionary
	if str(move_event.get("type", "")) != "move":
		return false

	for next_index: int in range(event_index + 1, events.size()):
		var next_value: Variant = events[next_index]
		if not (next_value is Dictionary):
			continue
		var next_event: Dictionary = next_value as Dictionary
		var next_type := str(next_event.get("type", ""))
		if next_type == "prepare":
			var matching_prepare := _normalize_battle_ident(str(next_event.get("actor", ""))) == _normalize_battle_ident(str(move_event.get("actor", ""))) \
				and _normalize_item_key(str(next_event.get("move", ""))) == _normalize_item_key(str(move_event.get("move", "")))
			return matching_prepare
		if _is_move_animation_result_boundary_event(next_event):
			return false

	return false


func _get_direct_prepare_release_move(events: Array, damage_index: int, damage_event: Dictionary) -> Dictionary:
	var damage_target := _normalize_battle_ident(str(damage_event.get("target", "")))
	if damage_target == "":
		return {}

	for previous_index: int in range(damage_index - 1, -1, -1):
		var previous_value: Variant = events[previous_index]
		if not (previous_value is Dictionary):
			continue
		var prepare_event: Dictionary = previous_value as Dictionary
		var previous_type := str(prepare_event.get("type", ""))
		if previous_type == "turn":
			return {}
		if previous_type != "prepare":
			continue

		var prepare_actor := _normalize_battle_ident(str(prepare_event.get("actor", "")))
		var prepare_move := _normalize_item_key(str(prepare_event.get("move", "")))
		for move_index: int in range(previous_index - 1, -1, -1):
			var move_value: Variant = events[move_index]
			if not (move_value is Dictionary):
				continue
			var move_event: Dictionary = move_value as Dictionary
			if str(move_event.get("type", "")) == "turn":
				return {}
			if str(move_event.get("type", "")) != "move":
				continue
			if _normalize_battle_ident(str(move_event.get("actor", ""))) != prepare_actor:
				continue
			if _normalize_item_key(str(move_event.get("move", ""))) != prepare_move:
				continue
			var move_target := _normalize_battle_ident(str(move_event.get("target", "")))
			if move_target != "" and move_target != damage_target:
				return {}
			if move_target == "" and damage_target == _normalize_battle_ident(str(move_event.get("actor", ""))):
				return {}
			return move_event

	return {}


func _suppress_charge_turn_move_presentation(presentation: Dictionary) -> void:
	presentation["pre_log_message"] = ""
	presentation["log_message"] = ""
	presentation["battle_message"] = ""
	presentation["attack_actor_ident"] = ""
	presentation["move_animation_name"] = ""
	presentation["move_animation_actor_ident"] = ""
	presentation["move_animation_target_ident"] = ""


func _miss_event_matches_move_event(move_event: Dictionary, miss_event: Dictionary) -> bool:
	var move_actor := _normalize_battle_ident(str(move_event.get("actor", "")))
	var miss_actor := _normalize_battle_ident(str(miss_event.get("actor", "")))
	if move_actor != "" and miss_actor != "" and move_actor != miss_actor:
		return false

	var move_target := _normalize_battle_ident(str(move_event.get("target", "")))
	var miss_target := _normalize_battle_ident(str(miss_event.get("target", "")))
	if move_target != "" and miss_target != "" and move_target != miss_target:
		return false

	return true

func _is_move_animation_result_boundary_event(event_data: Dictionary) -> bool:
	match str(event_data.get("type", "")):
		"move", "damage", "heal", "faint", "status", "statChange", "effectiveness", "hitCount", "criticalHit", "fail", "cant", "switch", "drag", "turn":
			return true
		_:
			return false

func _apply_field_presentation_event(event_data: Dictionary) -> void:
	if presentation_state.apply_event(event_data, battle_state.get_turn()):
		_update_battle_status_panels()

func _fill_mega_event_species(event_data: Dictionary) -> void:
	var mega_species := battle_state.resolve_mega_species_for_event(event_data)
	if mega_species == "":
		mega_species = _get_pending_mega_species_for_event(event_data)
	if mega_species != "":
		event_data["species"] = mega_species

func _build_pending_player_mega_events(use_mega: bool) -> Array:
	var pending_events: Array = []
	if not use_mega:
		return pending_events

	var local_state_player_id := _get_local_state_player_id()
	var target_ident := battle_state.get_active_pokemon_ident(local_state_player_id)
	var mega_species := battle_state.resolve_active_mega_species(local_state_player_id)
	if target_ident == "" or mega_species == "":
		return pending_events

	var event_data: Dictionary = {
		"type": "mega",
		"target": target_ident,
		"species": mega_species,
	}
	_remember_pending_mega_species(event_data)
	pending_events.append(event_data)
	return pending_events

func _get_pending_player_choice_events(response: Dictionary, fallback_events: Array) -> Array:
	var response_events: Array = _filter_pvp_pending_player_choice_events(response) if _is_pvp_battle() else _filter_incremental_non_pvp_response_events(response)
	var pending_events: Array = _get_pending_mega_events_from_response(response_events)
	if pending_events.is_empty():
		return fallback_events

	for event_value: Variant in pending_events:
		if event_value is Dictionary:
			var event_data: Dictionary = event_value as Dictionary
			_fill_mega_event_species(event_data)
			_remember_pending_mega_species(event_data)

	return pending_events

func _filter_pvp_pending_player_choice_events(response: Dictionary) -> Array:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return []

	var events: Array = events_value as Array
	if events.is_empty():
		return []

	var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
	var last_rendered_seq := pvp_event_queue.last_rendered_seq
	if response_event_seq >= 0 and last_rendered_seq >= 0:
		var first_event_seq := response_event_seq - events.size() + 1
		var filtered_by_seq: Array = []
		for index: int in range(events.size()):
			var event_seq := first_event_seq + index
			if event_seq > last_rendered_seq:
				filtered_by_seq.append(events[index])
		return filtered_by_seq

	var filtered_by_count: Array = []
	var start_index: int = max(pvp_rendered_event_count, 0)
	for index: int in range(start_index, events.size()):
		filtered_by_count.append(events[index])
	return filtered_by_count

func _get_pending_mega_events_from_response(events_value: Variant) -> Array:
	var pending_events: Array = []
	if not (events_value is Array):
		return pending_events

	var events: Array = events_value as Array
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		if str(event_data.get("type", "")) == "mega":
			pending_events.append(event_data.duplicate(true))

	return pending_events

func _merge_pending_player_choice_events(pending_events: Array, turn_events: Array) -> Array:
	var merged_events: Array = []
	for event_value: Variant in turn_events:
		if event_value is Dictionary:
			merged_events.append((event_value as Dictionary).duplicate(true))
		else:
			merged_events.append(event_value)

	if pending_events.is_empty():
		return merged_events

	var pending_by_key: Dictionary = {}
	for pending_value: Variant in pending_events:
		if not (pending_value is Dictionary):
			continue

		var pending_event: Dictionary = (pending_value as Dictionary).duplicate(true)
		if str(pending_event.get("type", "")) != "mega":
			continue

		_fill_mega_event_species(pending_event)
		var pending_key := _get_pending_mega_key_from_event(pending_event)
		if pending_key == "":
			continue

		pending_by_key[pending_key] = pending_event

	if pending_by_key.is_empty():
		return merged_events

	var matched_keys: Dictionary = {}
	for index: int in range(merged_events.size()):
		var event_value: Variant = merged_events[index]
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		if str(event_data.get("type", "")) != "mega":
			continue

		_fill_mega_event_species(event_data)
		var event_key := _get_pending_mega_key_from_event(event_data)
		if event_key == "" or not pending_by_key.has(event_key):
			continue

		var pending_event_for_key: Dictionary = pending_by_key[event_key] as Dictionary
		_merge_mega_event_data(event_data, pending_event_for_key)
		matched_keys[event_key] = true

	var insert_index := _get_form_change_insert_index(merged_events)
	var pending_keys: Array = pending_by_key.keys()
	pending_keys.sort()
	for key_value: Variant in pending_keys:
		var pending_key := str(key_value)
		if matched_keys.has(pending_key):
			continue

		var pending_event_to_insert: Dictionary = pending_by_key[pending_key] as Dictionary
		merged_events.insert(insert_index, pending_event_to_insert)
		insert_index += 1

	return merged_events

func _merge_mega_event_data(event_data: Dictionary, pending_event: Dictionary) -> void:
	var event_species := str(event_data.get("species", "")).strip_edges()
	var pending_species := str(pending_event.get("species", "")).strip_edges()
	if pending_species != "" and not event_species.to_lower().contains("mega"):
		event_data["species"] = pending_species
	if str(event_data.get("target", "")) == "":
		event_data["target"] = str(pending_event.get("target", ""))

func _get_form_change_insert_index(events: Array) -> int:
	var insert_index := 0
	while insert_index < events.size():
		var event_value: Variant = events[insert_index]
		if not (event_value is Dictionary):
			break

		var event_type := str((event_value as Dictionary).get("type", ""))
		if event_type != "turn":
			break

		insert_index += 1

	return insert_index

func _filter_already_rendered_events(events_value: Variant, rendered_event_keys: Dictionary, response: Dictionary = {}) -> Array:
	var filtered_events: Array = []
	if not (events_value is Array):
		return filtered_events

	var events: Array = events_value as Array
	if _is_pvp_battle() and rendered_event_keys.is_empty():
		return _filter_unrendered_pvp_events(events, response)

	for event_value in events:
		if event_value is Dictionary:
			var event_data: Dictionary = event_value as Dictionary
			var event_key := _get_battle_event_key(event_data)
			if event_key != "" and rendered_event_keys.has(event_key):
				continue
			if not _is_pvp_battle() and event_key != "" and rendered_non_pvp_event_keys.has(event_key):
				continue

		filtered_events.append(event_value)

	return filtered_events

func _filter_incremental_non_pvp_response_events(response: Dictionary) -> Array:
	var events_value: Variant = response.get("events", [])
	var events: Array = events_value as Array if events_value is Array else []
	if _is_pvp_battle() or events.is_empty():
		_debug_battle_start("filter.non_pvp.skip isPvp=%s events=%d lastRenderedSeq=%d" % [
			str(_is_pvp_battle()),
			events.size(),
			last_rendered_event_seq,
		])
		return events

	var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
	if response_event_seq < 0:
		_debug_battle_start("filter.non_pvp.no_seq events=%s lastRenderedSeq=%d" % [
			_summarize_battle_events(events),
			last_rendered_event_seq,
		])
		return events

	var first_event_seq := response_event_seq - events.size() + 1
	var filtered_events: Array = []
	for index: int in range(events.size()):
		var event_seq := first_event_seq + index
		if event_seq > last_rendered_event_seq:
			filtered_events.append(events[index])

	_debug_battle_start("filter.non_pvp result firstSeq=%d responseSeq=%d lastRenderedBefore=%d input=%s output=%s" % [
		first_event_seq,
		response_event_seq,
		last_rendered_event_seq,
		_summarize_battle_events(events),
		_summarize_battle_events(filtered_events),
	])
	return filtered_events

func _filter_unrendered_pvp_events(events: Array, response: Dictionary = {}) -> Array:
	var filtered_events: Array = []
	var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
	var last_rendered_seq := pvp_event_queue.last_rendered_seq
	if response_event_seq >= 0 and last_rendered_seq >= 0:
		var first_event_seq := response_event_seq - events.size() + 1
		for index: int in range(events.size()):
			var event_seq := first_event_seq + index
			if event_seq > last_rendered_seq:
				filtered_events.append(events[index])
		return filtered_events

	if events.size() <= pvp_rendered_event_count:
		return filtered_events
	var start_index: int = max(pvp_rendered_event_count, 0)
	for index: int in range(start_index, events.size()):
		filtered_events.append(events[index])

	pvp_rendered_event_count = events.size()
	return filtered_events

func _mark_pvp_response_events_rendered(response: Dictionary) -> void:
	if not _is_pvp_battle():
		return

	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	pvp_rendered_event_count = max(pvp_rendered_event_count, events.size())

func _mark_non_pvp_response_events_rendered(response: Dictionary, rendered_events: Array) -> void:
	if _is_pvp_battle() or rendered_events.is_empty():
		return

	_mark_non_pvp_response_event_seq_consumed(response)

func _mark_non_pvp_response_event_seq_consumed(response: Dictionary) -> void:
	if _is_pvp_battle():
		return

	var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
	if response_event_seq < 0:
		return

	var previous_seq := last_rendered_event_seq
	last_rendered_event_seq = max(last_rendered_event_seq, response_event_seq)
	_debug_battle_start("cursor.mark_full previous=%d responseSeq=%d next=%d" % [
		previous_seq,
		response_event_seq,
		last_rendered_event_seq,
	])

func _mark_initial_non_pvp_response_events_consumed(response: Dictionary) -> void:
	if _is_pvp_battle():
		return

	var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
	if response_event_seq < 0:
		return

	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	var last_start_event_index := _get_battle_start_event_end_index(events)
	if last_start_event_index < 0:
		_debug_battle_start("cursor.mark_initial.no_start_events responseSeq=%d events=%s previous=%d" % [
			response_event_seq,
			_summarize_battle_events(events),
			last_rendered_event_seq,
		])
		return

	var first_event_seq := response_event_seq - events.size() + 1
	var previous_seq := last_rendered_event_seq
	var next_seq := first_event_seq + last_start_event_index
	last_rendered_event_seq = max(last_rendered_event_seq, next_seq)
	_debug_battle_start("cursor.mark_initial firstSeq=%d responseSeq=%d lastStartIndex=%d previous=%d nextCandidate=%d next=%d events=%s" % [
		first_event_seq,
		response_event_seq,
		last_start_event_index,
		previous_seq,
		next_seq,
		last_rendered_event_seq,
		_summarize_battle_events(events),
	])

func _get_battle_event_key(event_data: Dictionary) -> String:
	var event_type := str(event_data.get("type", ""))
	if event_type == "turn":
		return "%s|%d" % [event_type, int(event_data.get("turn", 0))]
	if event_type == "switch" or event_type == "drag":
		return "%s|%s|%s|%s" % [
			event_type,
			str(event_data.get("playerId", "")),
			_normalize_species_base_for_compare(_get_switch_event_source_species(event_data)),
			_normalize_species_base_for_compare(_get_switch_event_dedupe_species(event_data)),
		]
	if event_type == "mega" or event_type == "primal":
		return "%s|%s" % [event_type, str(event_data.get("target", ""))]

	return "%s|%s|%s|%s|%s" % [
		str(event_data.get("type", "")),
		str(event_data.get("target", "")),
		str(event_data.get("actor", "")),
		str(event_data.get("species", "")),
		str(event_data.get("to", "")),
	]

func _should_dedupe_rendered_non_pvp_event(event_data: Dictionary) -> bool:
	var event_type := str(event_data.get("type", ""))
	return event_type == "turn"

func _get_switch_event_dedupe_species(event_data: Dictionary) -> String:
	var species := str(event_data.get("to", "")).strip_edges()
	if species != "":
		return species

	species = str(event_data.get("species", "")).strip_edges()
	if species != "":
		return species

	species = _get_species_from_ident(str(event_data.get("toIdent", "")))
	if species != "":
		return species

	return _get_species_from_ident(str(event_data.get("pokemon", "")))

func _get_switch_event_source_species(event_data: Dictionary) -> String:
	var species := str(event_data.get("from", "")).strip_edges()
	if species != "":
		return species

	species = _get_species_from_ident(str(event_data.get("fromIdent", "")))
	if species != "":
		return species

	return _get_species_from_ident(str(event_data.get("source", "")))

func _remember_rendered_non_pvp_event_keys(events: Array) -> void:
	if _is_pvp_battle():
		return

	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		if not _should_dedupe_rendered_non_pvp_event(event_data):
			continue

		var event_key := _get_battle_event_key(event_data)
		if event_key != "":
			rendered_non_pvp_event_keys[event_key] = true

func _remember_initial_non_pvp_setup_events() -> void:
	if _is_pvp_battle():
		return

	_remember_rendered_non_pvp_event_keys([
		{
			"type": "turn",
			"turn": battle_state.get_turn(),
		},
	])
	for player_id: String in ["p1", "p2"]:
		var event_key := _get_battle_event_key(_build_initial_switch_dedupe_event(player_id))
		if event_key != "":
			rendered_non_pvp_event_keys[event_key] = true

func _build_initial_switch_dedupe_event(player_id: String) -> Dictionary:
	var ident := battle_state.get_active_pokemon_ident(player_id)
	var species := _get_active_display_species(player_id)
	return {
		"type": "switch",
		"playerId": player_id,
		"toIdent": ident,
		"to": species,
	}

func _remember_pending_mega_species(event_data: Dictionary) -> void:
	var pending_key := _get_pending_mega_key_from_event(event_data)
	var species := str(event_data.get("species", "")).strip_edges()
	if pending_key == "" or species == "":
		return

	pending_mega_species_by_ident[pending_key] = species

func _get_pending_mega_species_for_event(event_data: Dictionary) -> String:
	var pending_key := _get_pending_mega_key_from_event(event_data)
	if pending_key == "":
		return ""

	return str(pending_mega_species_by_ident.get(pending_key, ""))

func _clear_pending_mega_species_for_event(event_data: Dictionary) -> void:
	var pending_key := _get_pending_mega_key_from_event(event_data)
	if pending_key == "":
		return

	pending_mega_species_by_ident.erase(pending_key)

func _clear_pending_mega_species_for_events(events: Array) -> void:
	for event_value: Variant in events:
		if event_value is Dictionary:
			_clear_pending_mega_species_for_event(event_value as Dictionary)

func _get_pending_mega_key_from_event(event_data: Dictionary) -> String:
	var ident := str(event_data.get("target", ""))
	if ident == "":
		ident = str(event_data.get("actor", event_data.get("pokemon", "")))

	return _get_pending_mega_key(ident)

func _get_pending_mega_key(ident: String) -> String:
	var player_id := _get_player_id_from_ident(ident)
	var pokemon_name := _get_pokemon_name_from_ident_for_key(ident)
	if player_id == "" or pokemon_name == "":
		return ""

	return "%s|%s" % [player_id, pokemon_name]

func _get_pokemon_name_from_ident_for_key(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	var pokemon_name := str(ident.split(": ")[1]).strip_edges().to_lower()
	pokemon_name = pokemon_name.replace("-mega-x", "")
	pokemon_name = pokemon_name.replace("-mega-y", "")
	pokemon_name = pokemon_name.replace("-mega", "")
	return pokemon_name

func _update_active_pokemon_presentation_for_ident(ident: String) -> void:
	var player_id := _get_player_id_from_ident(ident)
	match player_id:
		"p1":
			_update_active_hud_panel("p1", player_hud_panel)
			_update_active_sprite_box("p1", player_sprite_box, "back")
		"p2":
			_update_active_hud_panel("p2", enemy_hud_panel)
			_update_active_sprite_box("p2", enemy_sprite_box, "front")

	_update_stat_stage_panels()

func _order_form_change_events_before_moves(events: Array) -> Array:
	var ordered_events: Array = []
	var consumed_indexes: Dictionary = {}

	for index: int in range(events.size()):
		if consumed_indexes.has(index):
			continue

		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			ordered_events.append(event_value)
			continue

		var event_data: Dictionary = event_value as Dictionary
		if str(event_data.get("type", "")) == "move":
			var actor_ident: String = str(event_data.get("actor", ""))
			var form_change_index: int = _find_next_form_change_event_index(events, index + 1, actor_ident, consumed_indexes)
			if form_change_index >= 0:
				ordered_events.append(events[form_change_index])
				consumed_indexes[form_change_index] = true

		ordered_events.append(event_data)

	return ordered_events

func _order_switch_out_heals_before_switches(events: Array) -> Array:
	var ordered_events: Array = []
	var consumed_indexes: Dictionary = {}

	for index: int in range(events.size()):
		if consumed_indexes.has(index):
			continue

		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			ordered_events.append(event_value)
			continue

		var event_data: Dictionary = event_value as Dictionary
		if _is_switch_like_event(event_data):
			var heal_index := _find_next_switch_out_heal_event_index(events, index + 1, event_data, consumed_indexes)
			if heal_index >= 0:
				ordered_events.append(events[heal_index])
				consumed_indexes[heal_index] = true

		ordered_events.append(event_data)

	return ordered_events

func _find_next_switch_out_heal_event_index(
	events: Array,
	start_index: int,
	switch_event: Dictionary,
	consumed_indexes: Dictionary
) -> int:
	var switch_out_ident := _normalize_battle_ident(str(switch_event.get("fromIdent", "")))
	if switch_out_ident == "":
		return -1

	for index: int in range(start_index, events.size()):
		if consumed_indexes.has(index):
			continue

		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		var event_type := str(event_data.get("type", ""))
		if event_type == "turn" or event_type == "switch" or event_type == "drag":
			return -1
		if not bool(event_data.get("synthetic", false)):
			continue
		if not _is_ability_heal_event(event_data):
			continue

		var heal_target := _normalize_battle_ident(str(event_data.get("target", "")))
		if heal_target == switch_out_ident:
			return index

	return -1

func _show_switch_out_heal_target_if_needed(event_data: Dictionary, ordered_events: Array, event_index: int) -> void:
	if not bool(event_data.get("synthetic", false)):
		return
	if not _is_ability_heal_event(event_data):
		return

	var target_ident := str(event_data.get("target", ""))
	var target_key := _normalize_battle_ident(target_ident)
	if target_key == "":
		return
	if animation_router != null and animation_router.is_target_ident_currently_visible(target_ident):
		return

	var matching_switch := _get_next_matching_switch_event(ordered_events, event_index + 1, target_key)
	if matching_switch.is_empty():
		return
	if not _is_pivot_switch_event(matching_switch, ordered_events, event_index):
		return

	var player_id := _get_player_id_from_ident(target_ident)
	var species := _get_species_from_ident(target_ident)
	if player_id == "" or species == "":
		return

	var is_shiny := _get_switch_event_is_shiny(player_id, target_ident, species)
	match player_id:
		"p1":
			_set_single_pokemon_species_with_pvp_warning(player_sprite_box, species, "back", is_shiny, "switch_out_heal_target")
		"p2":
			_set_single_pokemon_species_with_pvp_warning(enemy_sprite_box, species, "front", is_shiny, "switch_out_heal_target")

func _get_next_matching_switch_event(events: Array, start_index: int, switch_out_ident: String) -> Dictionary:
	for index: int in range(start_index, events.size()):
		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		var event_type := str(event_data.get("type", ""))
		if event_type == "turn":
			return {}
		if event_type != "switch" and event_type != "drag":
			continue

		var from_ident := _normalize_battle_ident(str(event_data.get("fromIdent", "")))
		if from_ident == switch_out_ident:
			return event_data
		return {}

	return {}

func _is_pivot_switch_event(switch_event: Dictionary, ordered_events: Array, heal_event_index: int) -> bool:
	for key in ["source", "from", "fromMove", "move"]:
		if _is_pivot_move_name(str(switch_event.get(key, ""))):
			return true

	var switch_player_id := str(switch_event.get("playerId", ""))
	if switch_player_id == "":
		switch_player_id = _get_player_id_from_ident(str(switch_event.get("toIdent", switch_event.get("pokemon", ""))))
	if switch_player_id == "":
		return false

	for index: int in range(heal_event_index - 1, -1, -1):
		var event_value: Variant = ordered_events[index]
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		var event_type := str(event_data.get("type", ""))
		if event_type == "turn" or event_type == "switch" or event_type == "drag":
			return false
		if event_type != "move":
			continue

		var actor_player_id := _get_player_id_from_ident(str(event_data.get("actor", "")))
		if actor_player_id == switch_player_id and _is_pivot_move_name(str(event_data.get("move", ""))):
			return true

	return false

func _is_pivot_move_name(move_name: String) -> bool:
	var normalized := move_name.strip_edges()
	if normalized.begins_with("[from] "):
		normalized = normalized.substr("[from] ".length()).strip_edges()
	if normalized.begins_with("move:"):
		normalized = normalized.substr("move:".length()).strip_edges()
	normalized = normalized.to_lower().replace(" ", "").replace("-", "").replace("_", "")
	return normalized in [
		"uturn",
		"flipturn",
		"chillyreception",
		"voltswitch",
		"batonpass",
		"partingshot",
		"teleport",
	]

func _find_next_form_change_event_index(
	events: Array,
	start_index: int,
	actor_ident: String,
	consumed_indexes: Dictionary
) -> int:
	if actor_ident == "":
		return -1

	var actor_player_id: String = _get_player_id_from_ident(actor_ident)
	for index: int in range(start_index, events.size()):
		if consumed_indexes.has(index):
			continue

		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		var event_type: String = str(event_data.get("type", ""))
		if event_type != "mega" and event_type != "primal":
			continue

		var target_ident: String = str(event_data.get("target", ""))
		if target_ident == actor_ident:
			return index
		if actor_player_id != "" and _get_player_id_from_ident(target_ident) == actor_player_id:
			return index

	return -1

func _get_wild_battle_start_events(events: Array) -> Array:
	var start_events: Array = []
	_debug_battle_start("start_filter.begin input=%s" % _summarize_battle_events(events))

	for event in events:
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		match str(event_data.get("type", "")):
			"turn", "switch", "drag":
				_debug_battle_start("start_filter.skip_setup event=%s" % _summarize_battle_event(event_data))
				continue
			"fieldEffect", "pokemonEffect", "ability", "statChange", "item", "transform", "mega", "primal":
				_debug_battle_start("start_filter.include event=%s" % _summarize_battle_event(event_data))
				start_events.append(event_data)
			_:
				_debug_battle_start("start_filter.break event=%s selected=%s" % [
					_summarize_battle_event(event_data),
					_summarize_battle_events(start_events),
				])
				break

	_debug_battle_start("start_filter.end selected=%s" % _summarize_battle_events(start_events))
	return start_events

func _get_battle_start_event_end_index(events: Array) -> int:
	var last_start_event_index := -1
	for index: int in range(events.size()):
		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		match str(event_data.get("type", "")):
			"turn", "switch", "drag", "fieldEffect", "pokemonEffect", "ability", "statChange", "item", "transform", "mega", "primal":
				last_start_event_index = index
			_:
				_debug_battle_start("start_boundary.break index=%d event=%s lastStartIndex=%d" % [
					index,
					_summarize_battle_event(event_data),
					last_start_event_index,
				])
				break

	_debug_battle_start("start_boundary.end lastStartIndex=%d events=%s" % [
		last_start_event_index,
		_summarize_battle_events(events),
	])
	return last_start_event_index

func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"

	if ident.begins_with("p2"):
		return "p2"

	return ""

func _play_shiny_entrance_if_needed(event_data: Dictionary) -> void:
	var player_id := str(event_data.get("playerId", ""))
	if player_id == "":
		player_id = _get_player_id_from_ident(str(event_data.get("toIdent", event_data.get("pokemon", ""))))
	if player_id == "":
		return

	var target_ident := str(event_data.get("toIdent", ""))
	if target_ident == "":
		target_ident = str(event_data.get("pokemon", ""))

	await _play_shiny_entrance_for_player(player_id, target_ident)

func _play_initial_shiny_entrance_effects() -> void:
	await _play_shiny_entrance_for_player("p2")
	await _play_shiny_entrance_for_player("p1")

func _play_shiny_entrance_for_player(player_id: String, target_ident := "") -> void:
	if player_id == "":
		return
	if not _get_active_pokemon_is_shiny_for_entrance(player_id):
		return

	if _get_player_id_from_ident(target_ident) == "":
		target_ident = "%sa: %s" % [player_id, _get_active_display_species(player_id)]

	await animation_router.play_effect_animation(SHINY_ENTRANCE_EFFECT_KEY, target_ident)

func _get_active_pokemon_is_shiny_for_entrance(player_id: String) -> bool:
	if player_id == "p1":
		var saved_pokemon := _get_saved_pokemon_for_active_data(battle_state.get_active_player_pokemon(player_id))
		if saved_pokemon != null:
			return saved_pokemon.shiny

	return _get_active_pokemon_is_shiny(player_id)

func _get_species_from_ident(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges()

func _set_active_hud_hp_from_event(target_ident: String, event: Dictionary, use_previous_hp: bool) -> void:
	var player_id := _get_player_id_from_ident(target_ident)
	if player_id == "":
		return

	var hp_data: Dictionary = hp_event_helper.get_event_hp_snapshot(event, use_previous_hp)
	if hp_data.is_empty():
		hp_data = _get_event_hp_snapshot_with_state_fallback(event, player_id, use_previous_hp)
	if hp_data.is_empty() and not use_previous_hp:
		hp_data = _get_active_state_hp_snapshot(player_id)
	if hp_data.is_empty():
		_debug_battle_hp("HUD hp event missing snapshot target=%s previous=%s event=%s" % [
			target_ident,
			str(use_previous_hp),
			JSON.stringify(event),
		])
		return

	var hp: int = int(hp_data.get("hp", 0))
	var max_hp: int = max(int(hp_data.get("max_hp", 1)), 1)
	_debug_battle_presentation_order("active_hud_hp_from_event target=%s mode=%s hp=%d/%d event=%s" % [
		target_ident,
		"previous" if use_previous_hp else "current",
		hp,
		max_hp,
		_summarize_hp_event_for_order_debug(event),
	])
	var species: String = _get_active_display_species(player_id)
	var level: int = battle_state.get_active_pokemon_level(player_id)
	var status: String = _get_status_from_event_or_state(event, player_id, use_previous_hp)
	var gender: String = battle_state.get_active_pokemon_gender(player_id)
	var is_shiny: bool = _get_active_pokemon_is_shiny(player_id)

	match player_id:
		"p1":
			player_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny, _get_active_player_experience_data("p1"))
		"p2":
			enemy_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)
	_sync_status_condition_overlays()

func _get_event_hp_snapshot_with_state_fallback(event: Dictionary, player_id: String, use_previous_hp: bool) -> Dictionary:
	var hp_key: String = "previousHp" if use_previous_hp else "hp"
	if not event.has(hp_key):
		return {}

	var state_hp_data: Dictionary = _get_active_state_hp_snapshot(player_id)
	if state_hp_data.is_empty():
		return {}

	return {
		"hp": int(event.get(hp_key, 0)),
		"max_hp": max(int(state_hp_data.get("max_hp", 1)), 1),
	}

func _get_active_state_hp_snapshot(player_id: String) -> Dictionary:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	if active_pokemon.is_empty():
		return {}

	var condition_snapshot: Dictionary = hp_event_helper.parse_condition_hp_snapshot(str(active_pokemon.get("condition", "")))
	if not condition_snapshot.is_empty():
		return condition_snapshot

	var hp: int = int(active_pokemon.get("hp", active_pokemon.get("currentHp", 0)))
	var max_hp: int = int(active_pokemon.get("maxHp", active_pokemon.get("max_hp", 0)))
	if max_hp <= 0:
		return {}

	return {
		"hp": hp,
		"max_hp": max_hp,
	}

func _get_status_from_event_or_state(event: Dictionary, player_id: String, use_previous_hp: bool) -> String:
	var event_status: String = hp_event_helper.get_event_status(event, use_previous_hp)
	if event_status != "":
		return event_status

	return battle_state.get_active_pokemon_status(player_id)

func _rewind_active_hud_hp_for_events(events: Array) -> void:
	_debug_battle_presentation_order("rewind_active_hud_hp.begin events=%s" % JSON.stringify(_summarize_events_for_order_debug(events)))
	var rewound_player_ids: Dictionary = {}

	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident: String = str(event.get("target", ""))
		var player_id: String = _get_player_id_from_ident(target_ident)
		if player_id == "" or rewound_player_ids.has(player_id):
			continue

		_set_active_hud_hp_from_event(target_ident, event, true)
		rewound_player_ids[player_id] = true

func _rewind_party_slots_for_events(events: Array) -> void:
	_debug_battle_presentation_order("rewind_party_slots.begin events=%s" % JSON.stringify(_summarize_events_for_order_debug(events)))
	var player_team: Array = rewind_helper.get_rewound_team_data_for_events("p1", _get_display_team_data("p1"), events)
	if not player_team.is_empty():
		_debug_battle_presentation_order("rewind_party_slots.apply p1=%s" % JSON.stringify(_summarize_team_for_order_debug(player_team)))
		_mark_active_party_slot(player_team, "p1")
		player_party_grid.set_party(player_team)

	var enemy_team: Array = rewind_helper.get_rewound_team_data_for_events("p2", _get_display_team_data("p2"), events)
	if not enemy_team.is_empty():
		_debug_battle_presentation_order("rewind_party_slots.apply p2=%s" % JSON.stringify(_summarize_team_for_order_debug(enemy_team)))
		_mark_active_party_slot(enemy_team, "p2")
		opponent_party_grid.set_party(enemy_team)
		opponent_party_grid.set_selection_enabled(false)

func _debug_battle_hp(message: String) -> void:
	if DEBUG_BATTLE_HP_EVENTS:
		print("[battle-hp] " + message)

func _debug_battle_presentation_order(message: String) -> void:
	if DEBUG_BATTLE_PRESENTATION_ORDER:
		print("[battle-order] " + message)

func _summarize_events_for_order_debug(events: Array) -> Array:
	var summary: Array = []
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type := str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint" and event_type != "switch" and event_type != "drag":
			continue

		summary.append({
			"type": event_type,
			"target": str(event.get("target", "")),
			"pokemon": str(event.get("pokemon", event.get("toIdent", ""))),
			"previousCondition": str(event.get("previousCondition", "")),
			"condition": str(event.get("condition", "")),
			"previousHp": event.get("previousHp", ""),
			"hp": event.get("hp", ""),
			"maxHp": event.get("maxHp", ""),
			"pokemonKey": str(event.get("pokemonKey", event.get("pokemon_key", ""))),
			"metadataSlot": event.get("metadataSlot", event.get("metadata_slot", "")),
			"targetRef": event.get("targetRef", event.get("target_ref", {})),
		})

	return summary

func _summarize_hp_event_for_order_debug(event: Dictionary) -> String:
	return JSON.stringify(_summarize_events_for_order_debug([event])[0] if not _summarize_events_for_order_debug([event]).is_empty() else event)

func _summarize_team_for_order_debug(team: Array) -> Array:
	var summary: Array = []
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		summary.append({
			"idx": index,
			"ident": str(pokemon.get("ident", "")),
			"species": str(pokemon.get("species", pokemon.get("displaySpecies", ""))),
			"active": bool(pokemon.get("active", false)),
			"fainted": bool(pokemon.get("fainted", false)),
			"condition": str(pokemon.get("condition", "")),
			"hp": pokemon.get("hp", ""),
			"maxHp": pokemon.get("maxHp", ""),
			"pokemonKey": str(pokemon.get("pokemonKey", pokemon.get("pokemon_key", ""))),
			"metadataSlot": pokemon.get("metadataSlot", pokemon.get("metadata_slot", "")),
			"partySlot": pokemon.get("partySlot", pokemon.get("party_slot", "")),
		})

	return summary

func _debug_team_identity_snapshot(player_id: String) -> Array:
	var snapshot: Array = []
	for pokemon_value: Variant in battle_state.get_player_team(player_id):
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		snapshot.append({
			"key": str(pokemon.get("pokemonKey", pokemon.get("pokemon_key", ""))),
			"slot": pokemon.get("partySlot", pokemon.get("metadataSlot", "")),
			"ident": str(pokemon.get("ident", "")),
			"active": bool(pokemon.get("active", false)),
			"condition": str(pokemon.get("condition", "")),
			"hp": pokemon.get("hp", ""),
			"maxHp": pokemon.get("maxHp", ""),
			"fainted": bool(pokemon.get("fainted", false)),
		})

	return snapshot

func _is_ability_heal_event(event_data: Dictionary) -> bool:
	if str(event_data.get("type", "")) != "heal":
		return false
	if str(event_data.get("sourceAbility", "")).strip_edges() != "":
		return true
	var source := str(event_data.get("source", "")).strip_edges().to_lower()
	if source.begins_with("[from] "):
		source = source.substr("[from] ".length()).strip_edges()
	return source.begins_with("ability:")

func _debug_battle_move(message: String) -> void:
	if DEBUG_BATTLE_MOVE_EVENTS:
		print("[battle-move] " + message)

func _debug_battle_start(message: String) -> void:
	if DEBUG_BATTLE_START_EVENTS:
		print("[battle-start] " + message)

func _debug_battle_start_response(label: String, response: Dictionary) -> void:
	if not DEBUG_BATTLE_START_EVENTS:
		return

	var events_value: Variant = response.get("events", [])
	var events_count := (events_value as Array).size() if events_value is Array else 0
	_debug_battle_start("%s battleId=%s eventSeq=%d batchSeq=%d turn=%d eventsCount=%d events=%s" % [
		label,
		str(response.get("battleId", "")),
		_get_int_from_variant(response.get("eventSeq", -1), -1),
		_get_int_from_variant(response.get("batchSeq", -1), -1),
		battle_state.get_turn(),
		events_count,
		_summarize_battle_events(events_value),
	])

func _debug_battle_start_active_snapshot(label: String) -> void:
	_debug_battle_start("%s active=%s lastRenderedSeq=%d" % [
		label,
		_summarize_active_battle_state(),
		last_rendered_event_seq,
	])

func _should_debug_battle_start_event(event_data: Dictionary) -> bool:
	match str(event_data.get("type", "")):
		"turn", "switch", "drag", "ability", "statChange", "transform", "mega", "primal", "fieldEffect", "pokemonEffect", "move":
			return true
		_:
			return false

func _summarize_battle_events(events_value: Variant) -> String:
	if not (events_value is Array):
		return "[]"

	var summary: Array = []
	var events: Array = events_value as Array
	for index: int in range(events.size()):
		var event_value: Variant = events[index]
		if not (event_value is Dictionary):
			continue

		var event_summary: Dictionary = _summarize_battle_event_dictionary(event_value as Dictionary)
		event_summary["idx"] = index
		summary.append(event_summary)

	return JSON.stringify(summary)

func _summarize_battle_event(event_data: Dictionary) -> String:
	return JSON.stringify(_summarize_battle_event_dictionary(event_data))

func _summarize_battle_event_dictionary(event_data: Dictionary) -> Dictionary:
	var summary := {}
	for key in [
		"type",
		"turn",
		"playerId",
		"target",
		"actor",
		"pokemon",
		"ident",
		"from",
		"fromIdent",
		"to",
		"toIdent",
		"species",
		"ability",
		"abilityName",
		"effect",
		"source",
		"sourceTarget",
		"sourcePokemon",
		"stat",
		"amount",
		"condition",
		"previousCondition",
		"hp",
		"previousHp",
		"maxHp",
		"pokemonKey",
		"metadataSlot",
	]:
		if event_data.has(key):
			summary[key] = event_data.get(key)

	return summary

func _summarize_active_battle_state() -> String:
	var summary := {}
	for player_id in ["p1", "p2"]:
		var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
		summary[player_id] = {
			"ident": str(active_pokemon.get("ident", "")),
			"species": str(active_pokemon.get("species", active_pokemon.get("displaySpecies", ""))),
			"displaySpecies": _get_active_display_species(player_id),
			"level": battle_state.get_active_pokemon_level(player_id),
			"hp": battle_state.get_active_pokemon_current_hp(player_id),
			"maxHp": battle_state.get_active_pokemon_max_hp(player_id),
			"status": battle_state.get_active_pokemon_status(player_id),
			"gender": battle_state.get_active_pokemon_gender(player_id),
			"shiny": _get_active_pokemon_is_shiny(player_id),
			"sprite": _get_sprite_box_debug_species(player_sprite_box if player_id == "p1" else enemy_sprite_box),
		}

	return JSON.stringify(summary)

func _get_sprite_box_debug_species(sprite_box: Node) -> String:
	if sprite_box == null:
		return "null"
	if sprite_box.has_method("get_debug_species"):
		return str(sprite_box.call("get_debug_species"))
	if sprite_box.has_method("get_current_species"):
		return str(sprite_box.call("get_current_species"))
	return "%s:%s" % [sprite_box.name, sprite_box.get_class()]

func _format_battle_actor(actor: String, include_side_prefix := true) -> String:
	var player_id := _get_player_id_from_ident(actor)
	var actor_name := actor
	if actor_name.contains(": "):
		actor_name = actor_name.split(": ")[1]

	if include_side_prefix and player_id == "p2" and actor_name != "":
		return "The opposing %s" % actor_name

	return actor_name

func _normalize_battle_ident(ident: String) -> String:
	var cleaned := ident.strip_edges()
	if cleaned.contains(": "):
		var player_id := cleaned.split(": ")[0].substr(0, 2)
		var pokemon_name := cleaned.split(": ")[1]
		return "%s:%s" % [player_id, pokemon_name.to_lower()]

	return cleaned.to_lower()

func _format_stat_name(stat: String) -> String:
	match stat.to_lower().replace(" ", ""):
		"atk", "attack":
			return "Attack"
		"def", "defense", "defence":
			return "Defense"
		"spa", "spatk", "specialattack":
			return "Sp. Atk"
		"spd", "spdef", "specialdefense", "specialdefence":
			return "Sp. Def"
		"spe", "speed":
			return "Speed"
		"accuracy":
			return "accuracy"
		"evasion":
			return "evasion"

	return _format_compact_effect_name(stat)

func _get_first_event_text_value(event: Dictionary, keys: Array) -> String:
	for key in keys:
		var value := str(event.get(str(key), ""))
		if value != "":
			return value

	return ""

func _format_compact_effect_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	cleaned = cleaned.replace("-", " ")
	cleaned = _split_camel_case_text(cleaned)
	var words := PackedStringArray()
	for raw_word in cleaned.split(" "):
		var word := str(raw_word).strip_edges()
		if word == "":
			continue

		words.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())

	return " ".join(words)

func _split_camel_case_text(value: String) -> String:
	var result := ""

	for index in range(value.length()):
		var character := value.substr(index, 1)
		var lower_character := character.to_lower()
		var is_uppercase := character == character.to_upper() and character != lower_character

		if is_uppercase and result != "" and not result.ends_with(" "):
			result += " "

		result += character

	return result

func _normalize_event_source(source: String) -> String:
	var cleaned := source.strip_edges()
	if cleaned.begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()

	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.strip_edges()

func _on_party_grid_party_selected(slot: int) -> void:
	_focus_battle_ui_layer()
	if current_action_panel_mode == BattleActionsPanelMode.CALC:
		return

	if team_preview_lead_selection_active:
		return

	if battle_input_locked:
		return

	if _is_pvp_battle() and not _can_submit_pvp_switch_choice():
		if _opponent_player_needs_force_switch_ui():
			_show_pvp_opponent_force_switch_wait()
		return

	var selected_pokemon_data := _get_party_grid_selected_pokemon_data(slot)
	if not _can_switch_to_selected_pokemon(slot, selected_pokemon_data):
		return

	var submit_slot := _get_canonical_switch_submit_slot(slot, selected_pokemon_data)
	var pvp_switch_context := {
		"incoming_name": _get_switch_confirmation_pokemon_name(selected_pokemon_data),
		"replaced_name": _get_active_display_species(_get_local_state_player_id()),
	}
	_set_battle_input_locked(true)
	var was_force_switch := force_switch_flow.player_needs_force_switch(_get_local_state_player_id())
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	_hide_party_hover()

	var player_response: Dictionary = {}
	if _is_pvp_battle() or was_force_switch:
		player_response = await _submit_player_choice("switch", submit_slot, false, [], pvp_switch_context)
	else:
		player_response = await _submit_player_choice_and_resolve("switch", submit_slot)

	if not player_response.get("success", false):
		var error_message := str(player_response.get("error", "Cannot switch right now!"))
		current_action_panel.set_message(error_message)
		_add_battle_log_message(error_message)
		if was_force_switch:
			_show_party(true)
		else:
			_show_moves()
		_set_battle_input_locked(false)
		return

	if was_force_switch:
		if not _is_pvp_battle():
			var response_events: Array = _filter_incremental_non_pvp_response_events(player_response)
			var player_events: Array = _filter_already_rendered_events(response_events, {})
			_rewind_active_hud_hp_for_events(player_events)
			_rewind_party_slots_for_events(player_events)
			await _render_battle_events(player_events, true, "force_switch_player_non_pvp")
			_mark_non_pvp_response_events_rendered(player_response, player_events)

			if await _finish_if_battle_ended():
				return

			if _opponent_player_needs_force_switch_ui():
				if not await _auto_force_switch_opponent_if_needed():
					_set_battle_input_locked(false)
					return

				if await _finish_if_battle_ended():
					return

			if _show_force_switch_if_needed():
				_set_battle_input_locked(false)
				return

			_update_move_slots()
			_show_moves()
			_set_battle_input_locked(false)
		return

	if _is_pvp_battle():
		return

	if not await _render_resolved_player_choice_response(player_response):
		_set_battle_input_locked(false)
		return

	if await _finish_if_battle_ended():
		return

	if await _auto_force_switch_opponent_if_needed():
		if await _finish_if_battle_ended():
			return

	if _show_force_switch_if_needed():
		_set_battle_input_locked(false)
		return

	_update_move_slots()
	_set_battle_input_locked(false)
	_show_moves()

func _show_force_switch_if_needed() -> bool:
	_trace_pvp_flow("show_force_switch.check", {}, "localNeeds=%s" % str(_local_player_needs_force_switch_ui()))
	if not _local_player_needs_force_switch_ui():
		return false
	if _is_pvp_battle() and not _can_open_pvp_local_force_switch_ui():
		_trace_pvp_flow("show_force_switch.blocked_phase", {}, "phase=%s" % pvp_last_phase)
		_log_pvp_realtime(
			"Blocked PvP force-switch open",
			"source=_show_force_switch_if_needed phase=%s next=%s expected=awaiting_force_switch" % [pvp_last_phase, pvp_last_next_phase]
		)
		_set_battle_input_locked(true)
		return false

	_refresh_force_switch_transition_presentation()
	current_action_panel.set_message("Choose a Pokemon!")
	_trace_pvp_flow("show_force_switch.open", {}, "")
	_show_party(true)
	return true

func _can_open_pvp_local_force_switch_ui() -> bool:
	if not _is_pvp_battle():
		return true
	if pvp_last_phase == "awaiting_force_switch":
		return true
	if pvp_last_phase == "":
		return true
	return pvp_last_phase == "rendering_events" and pvp_last_next_phase == "awaiting_force_switch"

func _clear_force_switch_request_for_player(player_id: String) -> void:
	var request := battle_state.get_player_request(player_id)
	var force_switch_value: Variant = request.get("forceSwitch", [])
	if not (force_switch_value is Array):
		return

	var force_switch: Array = force_switch_value as Array
	for index in range(force_switch.size()):
		force_switch[index] = false
	request["forceSwitch"] = force_switch
	_trace_pvp_flow("force_switch.clear", {}, "player=%s" % player_id)

func _pvp_is_waiting_for_force_switch_phase_release() -> bool:
	return (
		_is_pvp_battle()
		and pvp_last_phase == "rendering_events"
		and pvp_last_next_phase == "awaiting_force_switch"
	)

func _wait_for_pvp_force_switch_phase_release(source: String) -> bool:
	if not _pvp_is_waiting_for_force_switch_phase_release():
		return pvp_last_phase == "awaiting_force_switch"

	var wait_start_server_seq := pvp_last_phase_update_server_seq
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Waiting for PvP force-switch phase release",
			"source=%s phase=%s next=%s startSeq=%d" % [
				source,
				pvp_last_phase,
				pvp_last_next_phase,
				wait_start_server_seq,
			]
		)

	while _pvp_is_waiting_for_force_switch_phase_release():
		await get_tree().process_frame
		if _has_newer_pvp_phase_update(wait_start_server_seq, ["awaiting_force_switch"]):
			break

	var released := pvp_last_phase == "awaiting_force_switch"
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"PvP force-switch phase release wait ended",
			"source=%s released=%s phase=%s next=%s serverSeq=%d" % [
				source,
				released,
				pvp_last_phase,
				pvp_last_next_phase,
				pvp_last_phase_update_server_seq,
			]
		)
	return released

func _is_pvp_opponent_force_switch_waiting() -> bool:
	return (
		_is_pvp_battle()
		and pvp_last_phase == "awaiting_force_switch"
		and not _local_player_needs_force_switch_ui()
		and _opponent_player_needs_force_switch_ui()
	)

func _show_pvp_opponent_force_switch_wait() -> void:
	_trace_pvp_flow("show_opponent_force_switch_wait", {}, "")
	pvp_idle_wait_recovery_active = true
	_refresh_force_switch_transition_presentation()
	moves_grid.visible = false
	player_party_grid.visible = true
	opponent_party_grid.visible = true
	_hide_party_hover()
	current_action_view = ActionView.NONE
	current_action_panel.set_message("Waiting for opponent switch...")
	action_buttons.set_action_disabled("fight", true)
	action_buttons.set_action_disabled("party", true)
	action_buttons.set_action_disabled("bag", true)
	_set_battle_input_locked(true)
	_sync_action_panel_mode_visibility()

func _refresh_force_switch_transition_presentation() -> void:
	_trace_pvp_flow("force_switch_transition.refresh", {}, "p1=%s p2=%s" % [
		_get_active_display_species("p1"),
		_get_active_display_species("p2"),
	])
	defer_force_switch_active_hide = true
	_update_hud_panels()
	_update_active_sprites("force_switch_transition")
	defer_force_switch_active_hide = false

func _can_submit_pvp_switch_choice() -> bool:
	if not _is_pvp_battle():
		return true
	if not _pvp_timer_allows_control():
		return false

	if pvp_last_phase == "awaiting_force_switch":
		return _local_player_needs_force_switch_ui()

	return pvp_last_phase == "turn_open" or _pvp_local_request_allows_choice(_get_local_state_player_id())

func _pvp_timer_allows_control() -> bool:
	if _is_pvp_battle() and not battle_state.actions_enabled():
		return false
	if not _is_pvp_battle() or not PvpBattleRealtimeService.timer_projection.contract_enabled:
		return true
	# Only the server-owned presentation hold disables controls. Displayed zero never blocks sending.
	return str(PvpBattleRealtimeService.timer_projection.participant_display(_get_local_state_player_id()).get("state", "WAITING")) != "SCHEDULED"

func _pvp_local_request_allows_choice(local_state_player_id: String) -> bool:
	if not _is_pvp_battle():
		return false
	if _player_request_is_waiting(local_state_player_id):
		return false
	if force_switch_flow.player_needs_force_switch(local_state_player_id):
		return true
	return not battle_state.get_player_request(local_state_player_id).is_empty()

func _local_player_needs_force_switch_ui() -> bool:
	var candidate_player_ids := _get_force_switch_candidate_player_ids(_get_local_state_player_id(), "p1")
	for player_id in candidate_player_ids:
		if _is_pvp_battle() and _player_request_is_waiting(player_id):
			return false

		if force_switch_flow.player_needs_force_switch(player_id):
			return true

		if _is_pvp_battle():
			continue

		if _player_active_fainted_with_available_switch(player_id):
			return true

	return false

func _opponent_player_needs_force_switch_ui() -> bool:
	var candidate_player_ids := _get_force_switch_candidate_player_ids(_get_opponent_state_player_id(), "p2")
	for player_id in candidate_player_ids:
		if _is_pvp_battle() and _player_request_is_waiting(player_id):
			return false

		if force_switch_flow.player_needs_force_switch(player_id):
			return true

		if _is_pvp_battle():
			continue

		if _player_active_fainted_with_available_switch(player_id):
			return true

	return false

func _get_force_switch_candidate_player_ids(primary_player_id: String, display_fallback_player_id: String) -> Array[String]:
	var candidate_player_ids: Array[String] = []
	if primary_player_id != "":
		candidate_player_ids.append(primary_player_id)
	if _is_pvp_battle():
		return candidate_player_ids
	if display_fallback_player_id != "" and not candidate_player_ids.has(display_fallback_player_id):
		candidate_player_ids.append(display_fallback_player_id)
	return candidate_player_ids

func _player_request_is_waiting(player_id: String) -> bool:
	if player_id == "":
		return false
	var request := battle_state.get_player_request(player_id)
	return bool(request.get("wait", false))

func _player_active_fainted_with_available_switch(player_id: String) -> bool:
	if battle_state.is_battle_ended():
		return false
	if not battle_state.is_active_pokemon_fainted(player_id):
		return false

	var team: Array = battle_state.get_player_team(player_id)
	for slot_index in range(team.size()):
		if force_switch_flow.can_switch_to_slot(slot_index + 1, player_id):
			return true

	return false

func _finish_if_battle_ended(result_overrides: Dictionary = {}) -> bool:
	if not battle_state.is_battle_ended():
		return false

	var finish_result := {
		"reason": "win",
		"winner": battle_state.get_winner()
	}
	finish_result.merge(result_overrides, true)
	_add_pvp_victory_message_if_needed(finish_result)
	await get_tree().create_timer(BATTLE_END_RESULT_HOLD_SECONDS).timeout
	_finish_battle(finish_result)
	return true

func _submit_player_choice(
	choice_type: String,
	slot: int,
	mega := false,
	pending_player_choice_events: Array = [],
	choice_context: Dictionary = {}
) -> Dictionary:
	if (choice_type == "item" or choice_type == "bag") and not _can_use_bag_in_current_battle():
		return {
			"success": false,
			"error": "Bag cannot be used in this battle.",
		}

	var local_state_player_id := _get_local_state_player_id()
	if choice_type == "move" and mega and not battle_state.can_active_pokemon_mega_evolve(local_state_player_id):
		if _is_pvp_battle() and DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Ignoring stale mega selection",
				"choice_type=%s slot=%s api_player=%s state_player=%s" % [
					choice_type,
					slot,
					action_flow.local_player_id,
					local_state_player_id,
				]
			)
		if mega_evolution_selected:
			_clear_mega_evolution_selection()
		mega = false
	if _is_pvp_battle():
		return await _submit_pvp_realtime_choice(choice_type, slot, mega, pending_player_choice_events, choice_context)
	return await action_flow.submit_player_choice(choice_type, slot, mega, last_rendered_event_seq)

func _submit_player_choice_and_resolve(choice_type: String, slot: int, mega := false) -> Dictionary:
	if _is_pvp_battle():
		return await _submit_player_choice(choice_type, slot, mega)
	if (choice_type == "item" or choice_type == "bag") and not _can_use_bag_in_current_battle():
		return {
			"success": false,
			"error": "Bag cannot be used in this battle.",
		}

	var local_state_player_id := _get_local_state_player_id()
	if choice_type == "move" and mega and not battle_state.can_active_pokemon_mega_evolve(local_state_player_id):
		if mega_evolution_selected:
			_clear_mega_evolution_selection()
		mega = false

	return await action_flow.submit_player_choice_and_resolve(choice_type, slot, mega, last_rendered_event_seq)

func _submit_lead(player_id: String, slot: int) -> Dictionary:
	if _is_pvp_battle():
		return await _submit_pvp_realtime_lead(player_id, slot)

	var response: Dictionary = await BattleApiClient.choose_lead(
		battle_request,
		battle_state.battle_id,
		player_id,
		slot,
		last_rendered_event_seq
	)
	if not bool(response.get("success", false)):
		return response

	if not _apply_api_response(response, false):
		return action_flow.map_response_for_local_player(response)

	return action_flow.map_response_for_local_player(response)

func _submit_npc_lead() -> Dictionary:
	var response: Dictionary = await BattleApiClient.send_npc_lead(
		battle_request,
		battle_state.battle_id,
		"p2",
		"basic",
		last_rendered_event_seq
	)
	if not bool(response.get("success", false)):
		return response

	if not _apply_api_response(response, false):
		return response

	return response

func _auto_force_switch_opponent_if_needed() -> bool:
	if _is_pvp_battle():
		return false
	if not _opponent_player_needs_force_switch_ui():
		return false

	return await _submit_npc_choice_and_render()

func _pvp_response_has_render_batch_metadata(response: Dictionary) -> bool:
	return (
		pvp_event_queue.get_response_event_batch_id(response) != ""
		and pvp_event_queue.get_response_event_seq_end(response) >= 0
	)

func _is_pvp_battle() -> bool:
	return pvp_room_code.strip_edges() != ""

func _connect_pvp_realtime(local_player_id: String, battle_id: String, initial_response: Dictionary = {}) -> void:
	pvp_event_queue.debug_enabled = DEBUG_PVP_REALTIME
	pvp_event_queue.set_render_completed_callback(Callable(self, "_on_pvp_render_batch_completed"))
	pvp_event_queue.clear()
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Connecting PvP realtime room",
			"local_player_id=%s battle_id=%s room=%s" % [local_player_id, battle_id, pvp_room_code]
		)
	pvp_realtime_updates.clear()
	pvp_realtime_deferred_updates.clear()
	pvp_pending_team_preview_completion.clear()
	pvp_team_preview_recovery_requested = false
	pvp_realtime_activity_seq = 0
	pvp_pending_reconciliation_snapshot.clear()
	pvp_pending_authoritative_terminal.clear()
	pvp_retrying_reconciliation_snapshot = false
	pvp_idle_realtime_drain_pending = false
	pvp_idle_wait_recovery_active = false
	pvp_last_applied_server_seq = 0
	pvp_last_applied_snapshot_server_seq = 0
	var initial_display_response: Dictionary = action_flow.map_response_for_local_player(initial_response)
	pvp_response_order.reset(initial_display_response)
	pvp_rendered_event_count = 0
	pvp_victory_message_added = false
	_clear_pvp_switch_confirmation()
	if not PvpBattleRealtimeService.battle_update_received.is_connected(_on_pvp_realtime_battle_update):
		PvpBattleRealtimeService.battle_update_received.connect(_on_pvp_realtime_battle_update)
	PvpBattleRealtimeService.connect_room(pvp_room_code, local_player_id, battle_id, pvp_match_id)

func _on_pvp_render_batch_completed(completion: Dictionary) -> void:
	_trace_pvp_flow("render_completed", {}, "completion=%s" % JSON.stringify(completion))
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"PvP render batch completed",
			"batch=%s batchSeq=%d eventSeqEnd=%d lastRenderedSeq=%d success=%s phase=%s source=%s" % [
				str(completion.get("event_batch_id", "")),
				_get_int_from_variant(completion.get("batch_seq", -1), -1),
				_get_int_from_variant(completion.get("event_seq_end", -1), -1),
				_get_int_from_variant(completion.get("last_rendered_seq", -1), -1),
				bool(completion.get("success", false)),
				str(completion.get("phase", "")),
				str(completion.get("source", "")),
			]
		)
	if bool(completion.get("success", false)):
		_send_pvp_render_ack(completion)
		_retry_pending_pvp_reconciliation_snapshot.call_deferred()
		_retry_pending_pvp_authoritative_terminal.call_deferred()

func _send_pvp_render_ack(completion: Dictionary) -> void:
	if not _is_pvp_battle():
		return
	if not bool(completion.get("success", false)):
		_trace_pvp_flow("ack.skip_failed_completion", {}, "completion=%s" % JSON.stringify(completion))
		return

	var event_batch_id := str(completion.get("event_batch_id", "")).strip_edges()
	var event_seq_end := _get_int_from_variant(completion.get("event_seq_end", -1), -1)
	var last_rendered_seq := _get_int_from_variant(completion.get("last_rendered_seq", -1), -1)
	if event_batch_id == "" or event_seq_end < 0 or last_rendered_seq < 0:
		_trace_pvp_flow("ack.skip_missing_metadata", {}, "completion=%s" % JSON.stringify(completion))
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping PvP render ACK",
				"batch=%s eventSeqEnd=%d lastRenderedSeq=%d" % [
					event_batch_id if event_batch_id != "" else "none",
					event_seq_end,
					last_rendered_seq,
				]
			)
		return

	var phase := str(completion.get("phase", "")).strip_edges()
	if phase == "":
		phase = pvp_last_phase

	var turn := _get_int_from_variant(completion.get("turn", -1), -1)
	if turn < 0:
		turn = battle_state.get_turn()

	_trace_pvp_flow("ack.send", {}, "batch=%s batchSeq=%d eventSeqEnd=%d lastRendered=%d turn=%d phase=%s completion=%s" % [
		event_batch_id,
		_get_int_from_variant(completion.get("batch_seq", -1), -1),
		event_seq_end,
		last_rendered_seq,
		turn,
		phase,
		JSON.stringify(completion),
	])
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Sending PvP render ACK from battle",
			"batch=%s batchSeq=%d lastRenderedSeq=%d turn=%d phase=%s currentPhase=%s next=%s" % [
				event_batch_id,
				_get_int_from_variant(completion.get("batch_seq", -1), -1),
				last_rendered_seq,
				turn,
				phase,
				pvp_last_phase,
				pvp_last_next_phase,
			]
		)

	PvpBattleRealtimeService.send_render_ack(
		battle_state.battle_id,
		action_flow.local_player_id,
		event_batch_id,
		_get_int_from_variant(completion.get("batch_seq", -1), -1),
		last_rendered_seq,
		turn,
		phase
	)

func _on_pvp_realtime_battle_update(message: Dictionary) -> void:
	var room_code := str(message.get("roomCode", "")).strip_edges().to_upper()
	if room_code != "" and room_code != pvp_room_code.strip_edges().to_upper():
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping PvP realtime update due room mismatch",
				"message_room=%s current_room=%s type=%s" % [room_code, pvp_room_code, str(message.get("type", ""))]
			)
			return

	var message_type := str(message.get("type", "")).strip_edges().to_lower()
	if _apply_pvp_connection_log_event(message_type, message):
		return
	if PvpBattleRealtimeService.is_infrastructure_no_contest_message(message):
		_finish_pvp_infrastructure_no_contest.call_deferred(message.duplicate(true))
		return
	if message_type == "pvp.authoritative_terminal":
		_finish_pvp_authoritative_terminal.call_deferred(message.duplicate(true))
		return

	var is_snapshot_message := message_type == "pvp.snapshot"
	if is_snapshot_message:
		var snapshot_response: Dictionary = _response_from_pvp_realtime_message(message)
		var mapped_snapshot: Dictionary = {}
		if not snapshot_response.is_empty():
			mapped_snapshot = action_flow.map_response_for_local_player(snapshot_response)
		if _is_stale_pvp_snapshot_response(message, mapped_snapshot):
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Snapshot ignored as stale",
					"message=%s snapshot_last_seq=%d" % [_describe_pvp_realtime_message(message), pvp_last_applied_snapshot_server_seq]
				)
			return
	elif _is_stale_pvp_realtime_message(message):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping stale PvP realtime update",
				"message=%s last_seq=%d" % [_describe_pvp_realtime_message(message), pvp_last_applied_server_seq]
			)
		return

	if message_type == "pvp.phase_update":
		pvp_realtime_activity_seq += 1
		_apply_pvp_phase_update(message)
		return

	if _should_apply_pvp_realtime_end_immediately(message):
		if DEBUG_PVP_REALTIME and _get_pvp_realtime_message_kind(message) == "snapshot":
			_log_pvp_realtime(
				"Explicit ended/forfeit recovery path used",
				"message=%s" % _describe_pvp_realtime_message(message)
			)
		if _get_pvp_realtime_message_kind(message) == "snapshot":
			_finish_pvp_realtime_battle_from_snapshot.call_deferred(message.duplicate(true))
		else:
			_finish_pvp_realtime_battle_from_message.call_deferred(message.duplicate(true))
		return

	if _capture_local_pvp_team_preview_timeout(message):
		return
	if _capture_local_pvp_forced_switch_timeout(message):
		return

	pvp_realtime_updates.append(message.duplicate(true))
	pvp_realtime_activity_seq += 1
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Queued PvP realtime update",
			"queue_size=%d message=%s" % [pvp_realtime_updates.size(), _describe_pvp_realtime_message(message)]
		)
	if _should_drain_idle_pvp_realtime_updates():
		_drain_idle_pvp_realtime_updates.call_deferred()

func _apply_pvp_connection_log_event(message_type: String, message: Dictionary) -> bool:
	var log_message := ""
	var player_name := _get_pvp_connection_event_display_name(message)
	match message_type:
		"pvp.opponent_disconnected":
			log_message = "%s disconnected." % player_name
		"pvp.reconnect_grace_started":
			var grace_seconds := _get_int_from_variant(message.get("disconnectGraceSeconds", 0), 0)
			vs_panel_container.show_reconnect_timer(
				_get_pvp_connection_event_display_side(message),
				str(message.get("reconnectDeadlineAt", "")),
				grace_seconds,
				str(message.get("serverNow", ""))
			)
			_sync_pvp_reconnect_timer_pause()
			if grace_seconds > 0:
				log_message = "%s has %s seconds to reconnect." % [player_name, grace_seconds]
			else:
				log_message = "Waiting for %s to reconnect." % player_name
		"pvp.opponent_reconnected":
			vs_panel_container.clear_reconnect_timer(_get_pvp_connection_event_display_side(message))
			_sync_pvp_reconnect_timer_pause()
			log_message = "%s reconnected." % player_name
		_:
			return false

	_add_battle_log_message(log_message)
	current_action_panel.set_message(log_message)
	return true

func _sync_pvp_reconnect_timer_pause() -> void:
	if vs_panel_container.has_active_reconnect_timer():
		PvpBattleRealtimeService.timer_projection.pause_for_reconnect()
	else:
		PvpBattleRealtimeService.timer_projection.resume_after_reconnect()

func _get_pvp_connection_event_display_name(message: Dictionary) -> String:
	var display_side := _get_pvp_connection_event_display_side(message)
	if display_side == "p1" or display_side == "p2":
		return _get_player_display_name(display_side)

	return "Player"

func _get_pvp_connection_event_display_side(message: Dictionary) -> String:
	var server_side := str(message.get("side", "")).strip_edges()
	var display_side := server_side
	if action_flow.local_player_id == "p2":
		if server_side == "p1":
			display_side = "p2"
		elif server_side == "p2":
			display_side = "p1"

	return display_side

func _apply_pvp_phase_update(message: Dictionary) -> void:
	_trace_pvp_flow("phase_update.received", {}, "message=%s" % _describe_pvp_realtime_message(message))
	var battle_id := str(message.get("battleId", "")).strip_edges()
	if battle_state.battle_id != "" and battle_id != "" and battle_id != battle_state.battle_id:
		_trace_pvp_flow("phase_update.skip_battle_mismatch", {}, "messageBattle=%s currentBattle=%s" % [battle_id, battle_state.battle_id])
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping PvP phase update due battle mismatch",
				"message_battle=%s current_battle=%s" % [battle_id, battle_state.battle_id]
			)
		return

	var server_seq := _get_pvp_message_server_seq(message)
	var phase := str(message.get("phase", "")).strip_edges()
	if server_seq > 0 and server_seq < pvp_last_applied_server_seq:
		_trace_pvp_flow("phase_update.skip_stale", {}, "serverSeq=%d lastSeq=%d phase=%s" % [server_seq, pvp_last_applied_server_seq, phase])
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping stale PvP phase update",
				"serverSeq=%d lastSeq=%d phase=%s" % [server_seq, pvp_last_applied_server_seq, phase]
			)
		return
	if server_seq > 0 and server_seq == pvp_last_applied_server_seq and phase == pvp_last_phase:
		_trace_pvp_flow("phase_update.skip_duplicate", {}, "serverSeq=%d phase=%s" % [server_seq, phase])
		return
	if phase == "":
		return

	var previous_phase := pvp_last_phase if pvp_last_phase != "" else str(message.get("previousPhase", "unknown"))
	pvp_last_phase = phase
	pvp_last_next_phase = phase
	pvp_last_phase_update_server_seq = server_seq
	pvp_last_phase_update_batch_id = str(message.get("eventBatchId", "")).strip_edges()
	pvp_last_phase_update_phase = phase
	if server_seq > pvp_last_applied_server_seq:
		pvp_last_applied_server_seq = server_seq

	_trace_pvp_flow("phase_update.applied", {}, "old=%s new=%s serverSeq=%d batch=%s lastRenderedSeq=%s" % [
		previous_phase,
		phase,
		server_seq,
		str(message.get("eventBatchId", "")),
		str(message.get("lastRenderedSeq", "")),
	])
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Applied PvP phase update",
			"old=%s new=%s serverSeq=%d batch=%s lastRenderedSeq=%s" % [
				previous_phase,
				phase,
				server_seq,
				str(message.get("eventBatchId", "")),
				str(message.get("lastRenderedSeq", "")),
			]
		)
	if team_preview_lead_selection_active and phase == "turn_open":
		_queue_pvp_team_preview_completion_from_room.call_deferred()
		return
	_open_pvp_released_phase(phase)

func _capture_local_pvp_team_preview_timeout(message: Dictionary) -> bool:
	if not team_preview_lead_selection_active or current_action_view != ActionView.PARTY:
		return false
	if not PvpBattleRealtimeService.is_unrequested_local_team_preview_lead(message, action_flow.local_player_id):
		return false

	var response := _response_from_pvp_realtime_message(message)
	if response.is_empty():
		return false
	var display_response := action_flow.map_response_for_local_player(response)
	if display_response.is_empty() or _should_show_team_preview(display_response):
		return false

	pvp_pending_team_preview_completion = response.duplicate(true)
	pvp_realtime_activity_seq += 1
	player_party_grid.party_selected.emit(0)
	return true

func _capture_local_pvp_forced_switch_timeout(message: Dictionary) -> bool:
	if not PvpBattleRealtimeService.is_unrequested_local_forced_switch(message, action_flow.local_player_id):
		return false
	var response := _response_from_pvp_realtime_message(message)
	if response.is_empty():
		return false
	pvp_realtime_activity_seq += 1
	_apply_local_pvp_forced_switch_timeout.call_deferred(response)
	return true

func _apply_local_pvp_forced_switch_timeout(response: Dictionary) -> void:
	if battle_finished or response.is_empty():
		return
	_set_battle_input_locked(true)
	if not await _enqueue_pvp_battle_response(
		response,
		"pvp_choose_switch",
		not action_flow._response_has_deferred_display_event(response)
	):
		_set_battle_input_locked(false)
		_show_force_switch_if_needed()

func _open_pvp_released_phase(phase: String) -> void:
	if battle_finished:
		return

	_trace_pvp_flow("phase_release.open", {}, "phase=%s" % phase)
	if phase == "turn_open":
		_set_battle_input_locked(false)
		_show_moves()
		return

	if phase == "awaiting_force_switch":
		var local_needs_force_switch := _local_player_needs_force_switch_ui()
		var opponent_needs_force_switch := _opponent_player_needs_force_switch_ui()
		_trace_pvp_flow("phase_release.force_switch", {}, "localNeeds=%s opponentNeeds=%s" % [str(local_needs_force_switch), str(opponent_needs_force_switch)])
		if local_needs_force_switch:
			_set_battle_input_locked(false)
			_show_force_switch_if_needed()
			return
		if opponent_needs_force_switch:
			_show_pvp_opponent_force_switch_wait()
			return
		pvp_idle_wait_recovery_active = true
		current_action_panel.set_message("Waiting for opponent switch...")
		return

func _queue_pvp_team_preview_completion_from_room() -> void:
	if not team_preview_lead_selection_active:
		return
	if pvp_room_code == "":
		return

	var local_player_id := action_flow.local_player_id
	var response: Dictionary = await BattleApiClient.get_pvp_room(battle_request, pvp_room_code, local_player_id)
	if not bool(response.get("success", false)):
		return

	var display_response: Dictionary = action_flow.map_response_for_local_player(response)
	if _should_show_team_preview(display_response):
		return

	var opponent_player_id := "p1" if local_player_id == "p2" else "p2"
	pvp_realtime_updates.append({
		"type": "pvp.battle_update",
		"action": "choose_lead",
		"playerId": opponent_player_id,
		"battleId": str(response.get("battleId", battle_state.battle_id)),
		"roomCode": pvp_room_code,
		"response": response,
	})

func _has_newer_pvp_phase_update(wait_start_server_seq: int, accepted_phases: Array) -> bool:
	if pvp_last_phase_update_server_seq <= wait_start_server_seq:
		return false
	return pvp_last_phase_update_phase in accepted_phases

func _reconcile_pvp_battle_from_room(source: String) -> bool:
	if pvp_room_code == "" or action_flow.local_player_id == "":
		return false

	var response: Dictionary = await BattleApiClient.get_pvp_room(
		battle_request,
		pvp_room_code,
		action_flow.local_player_id
	)
	if not bool(response.get("success", false)):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime("Canonical room reconciliation failed", "source=%s" % source)
		return false

	var mapped_response: Dictionary = action_flow.map_response_for_local_player(response)
	if mapped_response.is_empty():
		return false

	var message := {
		"type": "pvp.snapshot",
		"battleId": str(response.get("battleId", battle_state.battle_id)),
		"roomCode": pvp_room_code,
		"serverSeq": response.get("serverSeq", pvp_last_phase_update_server_seq),
		"response": response,
	}
	var applied := _apply_pvp_snapshot_reconciliation(message, mapped_response, source)
	if applied and DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Canonical room reconciliation applied",
			"source=%s phase=%s turn=%s" % [source, str(response.get("phase", "")), str(response.get("turn", ""))]
		)
	return applied

func _submit_pvp_realtime_lead(player_id: String, slot: int) -> Dictionary:
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Submitting PvP realtime lead",
			"player_id=%s slot=%s identity=%s" % [
				player_id,
				slot,
				_describe_pokemon_debug_ref(_get_team_pokemon_data_for_canonical_party_slot(_get_local_state_player_id(), slot)),
			]
		)
	var response: Dictionary = await _send_pvp_realtime_action_and_wait("choose_lead", player_id, slot)
	if not bool(response.get("success", false)):
		return response
	var display_response: Dictionary = action_flow.map_response_for_local_player(response)
	if _should_show_team_preview(display_response):
		return display_response
	if not await _enqueue_pvp_battle_response(response, "pvp_choose_lead", false):
		return display_response
	return display_response

func _submit_pvp_realtime_choice(
	choice_type: String,
	slot: int,
	mega := false,
	pending_player_choice_events: Array = [],
	choice_context: Dictionary = {}
) -> Dictionary:
	var action := "choose_switch" if choice_type == "switch" else "choose_move"
	if DEBUG_PVP_REALTIME:
		var choice_identity := _get_debug_choice_identity(choice_type, slot)
		_log_pvp_realtime(
			"Submitting PvP realtime choice",
			"choice_type=%s action=%s slot=%s mega=%s local_player_id=%s identity=%s" % [choice_type, action, slot, mega, action_flow.local_player_id, choice_identity]
		)
	var response: Dictionary = await _send_pvp_realtime_action_and_wait(action, action_flow.local_player_id, slot, mega)
	if not bool(response.get("success", false)):
		if bool(response.get("requiresBattleResync", false)) or str(response.get("code", "")) == "BATTLE_COMMAND_STALE":
			var reconciled := await _reconcile_pvp_battle_from_room("stale_local_choice")
			response["error"] = "Battle state refreshed. Choose again." if reconciled else "Battle state changed. Please try again."
		return response
	var display_response: Dictionary = action_flow.map_response_for_local_player(response)
	if choice_type == "switch" and not _response_has_renderable_battle_events(display_response):
		_show_pvp_switch_confirmation(
			str(choice_context.get("incoming_name", "Pokemon")),
			str(choice_context.get("replaced_name", "Pokemon"))
		)
	elif choice_type == "move" and not _response_has_renderable_battle_events(display_response):
		_show_pvp_move_confirmation(
			str(choice_context.get("pokemon_name", "Pokemon")),
			str(choice_context.get("move_name", "its selected move"))
		)
	var queue_metadata := {
		"is_local_choice": true,
		"choice_type": choice_type,
	}
	if choice_type == "switch":
		queue_metadata["was_force_switch"] = force_switch_flow.player_needs_force_switch(_get_local_state_player_id())
	if choice_type == "move" and pending_player_choice_events.size() > 0:
		queue_metadata["pending_player_choice_events"] = pending_player_choice_events.duplicate(true)
	if not await _enqueue_pvp_battle_response(response, "pvp_%s" % action, not action_flow._response_has_deferred_display_event(response), queue_metadata):
		if choice_type in ["switch", "move"]:
			_clear_pvp_switch_confirmation()
		return display_response
	return display_response

func _get_debug_choice_identity(choice_type: String, slot: int) -> String:
	var local_state_player_id := _get_local_state_player_id()
	if choice_type == "switch":
		return _describe_pokemon_debug_ref(_get_team_pokemon_data_for_canonical_party_slot(local_state_player_id, slot))
	if choice_type == "move":
		return _describe_pokemon_debug_ref(battle_state.get_active_player_pokemon(local_state_player_id))
	return "choice_type=%s slot=%d" % [choice_type, slot]

func _submit_pvp_realtime_forfeit() -> Dictionary:
	var response: Dictionary = await _send_pvp_realtime_action_and_wait("forfeit", action_flow.local_player_id, 1, false)
	if not bool(response.get("success", false)):
		return response
	return response

func _send_pvp_realtime_action_and_wait(action: String, player_id: String, slot: int, mega := false) -> Dictionary:
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime("Preparing PvP realtime action wait", "action=%s player_id=%s slot=%s mega=%s" % [action, player_id, slot, mega])
	var ready_deadline_msec := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < ready_deadline_msec:
		if PvpBattleRealtimeService.connected and PvpBattleRealtimeService.joined and PvpBattleRealtimeService.room_is_ready:
			break
		await get_tree().process_frame

	if not PvpBattleRealtimeService.connected or not PvpBattleRealtimeService.joined or not PvpBattleRealtimeService.room_is_ready:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"PvP realtime room not ready",
				"connected=%s joined=%s ready=%s" % [
					PvpBattleRealtimeService.connected,
					PvpBattleRealtimeService.joined,
					PvpBattleRealtimeService.room_is_ready,
				]
			)
		return {
			"success": false,
			"error": "PvP realtime room is not ready.",
		}

	# Capture the queue boundary before sending. The Gateway can answer within the
	# same frame; taking this cursor afterwards can skip that valid response and
	# leave the client waiting after the server has already advanced the battle.
	var queue_start := pvp_realtime_updates.size()
	# PvP responses are normalized so the local player is p1 in BattleState.
	# Keep the canonical player_id for the server command, but read the decision
	# identity from the normalized local side.
	var decision := PvpBattleRealtimeService.decision_for_action(
		player_id,
		battle_state.get_active_decision(_get_local_state_player_id())
	)
	var request_id := PvpBattleRealtimeService.send_action(
		action,
		battle_state.battle_id,
		player_id,
		slot,
		mega,
		str(decision.get("decisionId", "")),
		int(decision.get("decisionGeneration", 0)),
		str(decision.get("decisionKind", ""))
	)
	if request_id == "":
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime("PvP realtime action send failed", "action=%s" % action)
		return {
			"success": false,
			"error": "PvP realtime connection is not ready.",
		}
	_log_pvp_realtime("PvP realtime action sent", "action=%s request_id=%s" % [action, request_id])

	var expected_player_id := "p2" if player_id == "p2" else "p1"
	var signal_match: Dictionary = {}
	var listener := func(received_request_id: String, message: Dictionary) -> void:
		if received_request_id != request_id:
			return
		var response_value: Variant = message.get("response", {})
		if response_value is Dictionary:
			signal_match = message.duplicate(true)
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Realtime signal callback matched request",
					"request_id=%s message=%s" % [request_id, _describe_pvp_realtime_message(message)]
				)

	PvpBattleRealtimeService.action_response_received.connect(listener)

	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime("Realtime queue start", "request_id=%s queue_start=%d" % [request_id, queue_start])

	var response_deadline_msec := Time.get_ticks_msec() + 12000
	var response_wait_attempt := 0
	while Time.get_ticks_msec() < response_deadline_msec:
		if action == "forfeit" and battle_finished:
			if PvpBattleRealtimeService.action_response_received.is_connected(listener):
				PvpBattleRealtimeService.action_response_received.disconnect(listener)
			_discard_realtime_updates_for_request(request_id, action, expected_player_id, battle_state.battle_id)
			return {
				"success": true,
				"terminalConfirmed": true,
			}
		if DEBUG_PVP_REALTIME and response_wait_attempt % 60 == 0:
			_log_pvp_realtime(
				"Realtime wait attempt",
				"request_id=%s attempt=%d queue=%d" % [request_id, response_wait_attempt, pvp_realtime_updates.size()]
			)
		if not signal_match.is_empty():
			if PvpBattleRealtimeService.action_response_received.is_connected(listener):
				PvpBattleRealtimeService.action_response_received.disconnect(listener)
			var signal_response: Dictionary = _response_from_pvp_realtime_message(signal_match)
			if not signal_response.is_empty():
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Returning matched signal response",
						"request_id=%s response=%s" % [request_id, JSON.stringify(signal_response)]
					)
				_discard_realtime_updates_for_request(request_id, action, expected_player_id, battle_state.battle_id)
				return signal_response
			_discard_realtime_updates_for_request(request_id, action, expected_player_id, battle_state.battle_id)
			return {
				"success": false,
				"error": "Invalid PvP realtime response.",
			}

		var matching_message: Dictionary = _pop_matching_pvp_action_response_from_queue(
			request_id,
			action,
			expected_player_id,
			queue_start,
		)
		if not matching_message.is_empty():
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Returning matched queue response",
					"request_id=%s message=%s" % [request_id, _describe_pvp_realtime_message(matching_message)]
				)
			if PvpBattleRealtimeService.action_response_received.is_connected(listener):
				PvpBattleRealtimeService.action_response_received.disconnect(listener)
			_discard_realtime_updates_for_request(request_id, action, expected_player_id, battle_state.battle_id)
			var queued_response: Dictionary = _response_from_pvp_realtime_message(matching_message)
			if not queued_response.is_empty():
				return queued_response
			return {
				"success": false,
				"error": "Invalid PvP realtime response.",
			}
		if DEBUG_PVP_REALTIME and response_wait_attempt % 60 == 0:
			_log_pvp_realtime(
				"No realtime match yet",
				"request_id=%s action=%s player_id=%s queue_size=%d" % [request_id, action, player_id, pvp_realtime_updates.size()]
			)
		response_wait_attempt += 1
		await get_tree().process_frame
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"PvP realtime response timed out",
			"action=%s request_id=%s queue_remaining=%d" % [action, request_id, pvp_realtime_updates.size()]
		)

	if PvpBattleRealtimeService.action_response_received.is_connected(listener):
		PvpBattleRealtimeService.action_response_received.disconnect(listener)

	_discard_realtime_updates_for_request(request_id, action, expected_player_id, battle_state.battle_id)
	# The legacy local stack can commit a forfeit while its correlated websocket
	# response is lost among the terminal broadcasts. Confirm that outcome from
	# the canonical room before showing a misleading timeout or unlocking battle
	# input. This is also a safe recovery for transient response loss in production.
	if action == "forfeit":
		var reconciled_forfeit := await _reconcile_pvp_battle_from_room("pvp_forfeit_timeout_recovery")
		if reconciled_forfeit and battle_state.is_battle_ended():
			return {
				"success": true,
				"terminalConfirmed": true,
				"terminalRecovered": true,
			}
	return {
		"success": false,
		"error": "PvP realtime response timed out.",
	}

func _discard_realtime_updates_for_request(
	request_id: String,
	action: String,
	expected_player_id: String,
	expected_battle_id: String,
) -> void:
	if request_id == "":
		return

	var removed_count := 0
	removed_count += _discard_realtime_updates_for_request_from_queue(
		pvp_realtime_updates,
		request_id,
		action,
		expected_player_id,
		expected_battle_id
	)
	removed_count += _discard_realtime_updates_for_request_from_queue(
		pvp_realtime_deferred_updates,
		request_id,
		action,
		expected_player_id,
		expected_battle_id
	)

	if DEBUG_PVP_REALTIME and removed_count > 0:
		_log_pvp_realtime(
			"Discarded realtime updates for request",
			"request_id=%s action=%s player=%s removed=%d" % [request_id, action, expected_player_id, removed_count]
		)

func _discard_realtime_updates_for_request_from_queue(
	queue: Array[Dictionary],
	request_id: String,
	action: String,
	expected_player_id: String,
	expected_battle_id: String,
) -> int:
	var removed_count := 0
	var index := 0
	while index < queue.size():
		var message_value: Variant = queue[index]
		if not (message_value is Dictionary):
			index += 1
			continue

		var message := message_value as Dictionary
		var message_request_id := str(message.get("requestId", ""))
		if message_request_id != request_id:
			index += 1
			continue

		if str(message.get("action", "")) != action:
			index += 1
			continue

		if str(message.get("playerId", "")) != expected_player_id:
			index += 1
			continue

		var message_battle_id := str(message.get("battleId", ""))
		if message_battle_id != "" and expected_battle_id != "" and message_battle_id != expected_battle_id:
			index += 1
			continue

		queue.remove_at(index)
		removed_count += 1

	return removed_count

func _pop_matching_pvp_action_response_from_queue(
	request_id: String,
	action: String,
	player_id: String,
	start_index: int,
) -> Dictionary:
	var expected_player_id := "p2" if player_id == "p2" else "p1"
	var battle_id := battle_state.battle_id
	var index: int = max(0, start_index)

	while index < pvp_realtime_updates.size():
		var message: Dictionary = pvp_realtime_updates[index]
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Checking queued message",
				"index=%d request_id=%s action=%s expected_player=%s message=%s" % [index, request_id, action, expected_player_id, _describe_pvp_realtime_message(message)]
			)
		if _is_matching_pvp_action_update_message(message, request_id, action, expected_player_id, battle_id):
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Matched queued message and removing",
					"index=%d message=%s" % [index, _describe_pvp_realtime_message(message)]
				)
			pvp_realtime_updates.remove_at(index)
			return message
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime("Queued message did not match", "index=%d" % index)
		index += 1
	return {}

func _is_matching_pvp_action_update_message(
	message: Dictionary,
	request_id: String,
	action: String,
	expected_player_id: String,
	expected_battle_id: String,
) -> bool:
	if _is_stale_pvp_realtime_message(message):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Match rejected: stale realtime message",
				"request_id=%s message=%s last_seq=%d" % [request_id, _describe_pvp_realtime_message(message), pvp_last_applied_server_seq]
			)
		return false

	var message_request_id: String = str(message.get("requestId", "")).strip_edges()
	var expected_request_id: String = request_id.strip_edges()
	var response_value: Variant = message.get("response", {})
	if not (response_value is Dictionary):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Match rejected: response is not dictionary",
				"expected_request_id=%s message=%s" % [expected_request_id, _describe_pvp_realtime_message(message)]
			)
		return false

	if message_request_id != "":
		if message_request_id == expected_request_id:
			if str(message.get("battleId", "")) != "" and expected_battle_id != "" and str(message.get("battleId", "")) != expected_battle_id:
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Match rejected: requestId matches but battleId mismatch",
						"expected_request_id=%s message_request_id=%s expected_battle_id=%s message_battle_id=%s" % [expected_request_id, message_request_id, expected_battle_id, str(message.get("battleId", ""))]
					)
				return false
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Match by requestId",
					"request_id=%s action=%s player=%s" % [message_request_id, str(message.get("action", "")), str(message.get("playerId", ""))]
				)
			return true

		# Fallback for rare request-id drift in live responses.
		if str(message.get("action", "")) == action and str(message.get("playerId", "")) == expected_player_id:
			if str(message.get("battleId", "")) != "" and expected_battle_id != "" and str(message.get("battleId", "")) != expected_battle_id:
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Match rejected: fallback action+player matched but battleId mismatch",
						"request_id=%s expected_request_id=%s message_battle_id=%s expected_battle_id=%s action=%s player=%s" % [message_request_id, expected_request_id, str(message.get("battleId", "")), expected_battle_id, str(message.get("action", "")), str(message.get("playerId", ""))]
					)
				return false
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Match by fallback action+player",
					"request_id=%s expected_request_id=%s action=%s player=%s" % [message_request_id, expected_request_id, str(message.get("action", "")), str(message.get("playerId", ""))]
				)
			return true

		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Match rejected: requestId mismatch",
				"request_id=%s message_request_id=%s action=%s player=%s expected_action=%s expected_player=%s" % [expected_request_id, message_request_id, str(message.get("action", "")), str(message.get("playerId", "")), action, expected_player_id]
			)

		return false

	var message_type: String = str(message.get("type", ""))
	if message_type != "pvp.battle_update":
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime("Match rejected: unsupported message type", "request_id=%s type=%s" % [expected_request_id, message_type])
		return false

	if str(message.get("action", "")) != action:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Match rejected: action mismatch",
				"request_id=%s expected_action=%s actual_action=%s" % [expected_request_id, action, str(message.get("action", ""))]
			)
		return false
	if str(message.get("playerId", "")) != expected_player_id:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Match rejected: player mismatch",
				"request_id=%s expected_player=%s actual_player=%s" % [expected_request_id, expected_player_id, str(message.get("playerId", ""))]
			)
		return false

	var message_battle_id := str(message.get("battleId", ""))
	if message_battle_id != "" and expected_battle_id != "" and message_battle_id != expected_battle_id:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Match rejected: battleId mismatch",
				"request_id=%s expected_battle_id=%s message_battle_id=%s" % [expected_request_id, expected_battle_id, message_battle_id]
			)
		return false
	return message_type == "pvp.battle_update"

func _wait_for_pvp_opponent_choice_and_render(pending_player_choice_events: Array = []) -> bool:
	if pvp_room_code == "":
		return false
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime("Waiting for opponent move/switch", "local_player_id=%s" % action_flow.local_player_id)

	var wait_start_server_seq := pvp_last_phase_update_server_seq
	current_action_panel.set_message("Waiting for opponent...")
	var attempt := 0
	var fallback_render_response: Dictionary = {}
	var fallback_render_action := ""
	var fallback_render_message := ""
	var fallback_render_attempt := -1
	var phase_release_observed_at_attempt := -1
	var phase_reconciliation_attempted := false
	while true:
		if _has_newer_pvp_phase_update(wait_start_server_seq, ["turn_open", "awaiting_force_switch"]):
			if phase_release_observed_at_attempt < 0:
				phase_release_observed_at_attempt = attempt
			if DEBUG_PVP_REALTIME and phase_release_observed_at_attempt == attempt:
				_log_pvp_realtime(
					"Opponent choice phase advanced; waiting for its render batch",
					"phase=%s serverSeq=%d batch=%s" % [
						pvp_last_phase_update_phase,
						pvp_last_phase_update_server_seq,
						pvp_last_phase_update_batch_id,
					]
				)
			if not phase_reconciliation_attempted and attempt - phase_release_observed_at_attempt >= 20:
				phase_reconciliation_attempted = true
				if await _reconcile_pvp_battle_from_room("pvp_phase_release_recovery"):
					return true

		if not fallback_render_response.is_empty() and attempt - fallback_render_attempt >= 5:
			var promoted_response := _promote_pvp_battle_update_fallback_render(fallback_render_response)
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Processing fallback opponent choice render update",
					"attempt=%d message=%s" % [attempt, fallback_render_message]
				)
			var fallback_display_response: Dictionary = action_flow.map_response_for_local_player(promoted_response)
			if not await _enqueue_pvp_battle_response(promoted_response, "pvp_%s" % fallback_render_action, not action_flow._response_has_deferred_display_event(promoted_response)):
				return false
			if _response_has_opponent_force_switch(fallback_display_response) and DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Fallback opponent choice queued with force-switch",
					"message=%s" % fallback_render_message
				)
			return true

		var message: Dictionary = await _wait_for_next_pvp_realtime_update(0.1)
		if message.is_empty():
			attempt += 1
			continue
		if _is_stale_pvp_realtime_message(message):
			attempt += 1
			continue
		var message_type := str(message.get("type", "")).strip_edges()
		if message_type == "pvp.snapshot":
			if await _apply_pvp_realtime_battle_update(message):
				_log_pvp_realtime(
					"Applied snapshot while waiting for opponent action",
					"attempt=%d battle=%s" % [attempt, battle_state.battle_id]
				)
			if _opponent_player_needs_force_switch_ui():
				if not await _wait_for_pvp_opponent_force_switch_and_render():
					return false
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Opponent force-switch resolved while waiting for opponent action",
						"attempt=%d" % attempt
					)
				return true
			attempt += 1
			continue
		var message_action := str(message.get("action", ""))
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Opponent move/switch wait received message",
				"attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)]
			)
		var response: Dictionary = _response_from_pvp_realtime_message(message)
		if message_action == "forfeit" and str(message.get("playerId", "")) != action_flow.local_player_id:
			if response.is_empty():
				continue

			if not await _enqueue_pvp_battle_response(response, "pvp_forfeit_during_choice", not action_flow._response_has_deferred_display_event(response)):
				_finish_battle({
					"reason": "forfeit",
					"forfeitingPlayerId": _get_pvp_state_player_id_for_raw_player_id(str(message.get("playerId", ""))),
				})
				return true

			_finish_battle({
				"reason": "forfeit",
				"forfeitingPlayerId": _get_pvp_state_player_id_for_raw_player_id(str(message.get("playerId", ""))),
			})
			return true

		if not (message_action in ["choose_move", "choose_switch"]):
			attempt += 1
			continue
		if str(message.get("playerId", "")) == action_flow.local_player_id:
			attempt += 1
			continue

		response = _response_from_pvp_realtime_message(message)
		if response.is_empty():
			attempt += 1
			continue

		var display_response: Dictionary = action_flow.map_response_for_local_player(response)
		if not _is_authoritative_pvp_render_batch_response(response):
			if _response_has_renderable_battle_events(display_response):
				fallback_render_response = response.duplicate(true)
				fallback_render_action = message_action
				fallback_render_message = _describe_pvp_realtime_message(message)
				fallback_render_attempt = attempt
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Stashed non-authoritative opponent choice update as fallback render",
						"attempt=%d message=%s phase=%s next=%s" % [
							attempt,
							fallback_render_message,
							pvp_last_phase,
							pvp_last_next_phase,
						]
					)
				attempt += 1
				continue

			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Ignoring non-authoritative opponent choice update while waiting for render batch",
					"attempt=%d message=%s phase=%s next=%s" % [
						attempt,
						_describe_pvp_realtime_message(message),
						pvp_last_phase,
						pvp_last_next_phase,
					]
				)
			attempt += 1
			continue

		if not await _enqueue_pvp_battle_response(response, "pvp_%s" % message_action, not action_flow._response_has_deferred_display_event(response)):
			return false
		if _response_has_opponent_force_switch(display_response) and DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Opponent choice queued with force-switch",
				"request=%s" % str(message.get("requestId", ""))
			)
		return true

	# Unreachable, but required by GDScript's return analysis.
	return false

func _wait_for_pvp_opponent_force_switch_after_choice_response(
	display_response: Dictionary,
	pending_player_choice_events: Array = []
) -> bool:
	var response_events_value: Variant = display_response.get("events", [])
	var response_events: Array = response_events_value as Array if response_events_value is Array else []
	if not response_events.is_empty():
		if not await _render_pvp_opponent_response(display_response, {}, pending_player_choice_events, "pvp_force_switch_after_choice"):
			return false
		await _hold_opponent_response_message()
	else:
		_update_battle_presentation()

	if not await _wait_for_pvp_opponent_force_switch_and_render():
		return false

	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Opponent force-switch sequence resolved after choice response",
			"battle=%s" % battle_state.battle_id
		)
	return true

func _wait_for_pvp_opponent_force_switch_and_render() -> bool:
	if pvp_room_code == "":
		return false
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime("Waiting for opponent force-switch", "local_player_id=%s" % action_flow.local_player_id)

	var wait_start_server_seq := pvp_last_phase_update_server_seq
	current_action_panel.set_message("Waiting for opponent switch...")
	_trace_pvp_flow("wait_force_switch.start", {}, "waitStartSeq=%d" % wait_start_server_seq)
	var attempt := 0
	var fallback_render_response: Dictionary = {}
	var fallback_render_action := ""
	var fallback_render_message := ""
	var fallback_render_attempt := -1
	var phase_release_observed_at_attempt := -1
	var phase_reconciliation_attempted := false
	while true:
		if _has_newer_pvp_phase_update(wait_start_server_seq, ["turn_open"]):
			if phase_release_observed_at_attempt < 0:
				phase_release_observed_at_attempt = attempt
				_trace_pvp_flow("wait_force_switch.phase_advanced", {}, "attempt=%d phase=%s seq=%d" % [attempt, pvp_last_phase_update_phase, pvp_last_phase_update_server_seq])
			if DEBUG_PVP_REALTIME and phase_release_observed_at_attempt == attempt:
				_log_pvp_realtime(
					"Opponent force-switch phase advanced; waiting for its render batch",
					"phase=%s serverSeq=%d batch=%s" % [
						pvp_last_phase_update_phase,
						pvp_last_phase_update_server_seq,
						pvp_last_phase_update_batch_id,
					]
				)
			if not phase_reconciliation_attempted and attempt - phase_release_observed_at_attempt >= 20:
				phase_reconciliation_attempted = true
				if await _reconcile_pvp_battle_from_room("pvp_force_switch_phase_release_recovery"):
					return true

		if not fallback_render_response.is_empty() and attempt - fallback_render_attempt >= 5:
			var promoted_response := _promote_pvp_battle_update_fallback_render(fallback_render_response)
			_trace_pvp_flow("wait_force_switch.promote_fallback", promoted_response, "attempt=%d message=%s" % [attempt, fallback_render_message])
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Processing fallback opponent force-switch render update",
					"attempt=%d message=%s" % [attempt, fallback_render_message]
				)
			var fallback_display_response: Dictionary = action_flow.map_response_for_local_player(promoted_response)
			if not await _enqueue_pvp_battle_response(promoted_response, "pvp_%s" % fallback_render_action, not action_flow._response_has_deferred_display_event(promoted_response)):
				return false
			if _response_has_opponent_force_switch(fallback_display_response):
				current_action_panel.set_message("Waiting for opponent switch...")
				fallback_render_response.clear()
				fallback_render_action = ""
				fallback_render_message = ""
				fallback_render_attempt = -1
				attempt += 1
				continue
			return true

		var message: Dictionary = await _wait_for_next_pvp_realtime_update(0.1, false)
		if message.is_empty():
			if attempt % 20 == 0:
				_trace_pvp_flow("wait_force_switch.no_message", {}, "attempt=%d" % attempt)
			attempt += 1
			continue
		if _is_stale_pvp_realtime_message(message):
			_trace_pvp_flow("wait_force_switch.stale_message", {}, "attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)])
			attempt += 1
			continue
		var message_type := str(message.get("type", "")).strip_edges()
		_trace_pvp_flow("wait_force_switch.message", {}, "attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)])
		if message_type == "pvp.snapshot":
			if await _apply_pvp_realtime_battle_update(message):
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Applied snapshot while waiting for opponent force-switch",
						"attempt=%d battle=%s" % [attempt, battle_state.battle_id]
					)
			attempt += 1
			continue
		var message_action := str(message.get("action", ""))
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Opponent force-switch wait received message",
				"attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)]
			)
		var response: Dictionary = _response_from_pvp_realtime_message(message)
		if message_action == "forfeit" and str(message.get("playerId", "")) != action_flow.local_player_id:
			if not response.is_empty():
				if not await _enqueue_pvp_battle_response(response, "pvp_forfeit_during_force_switch", not action_flow._response_has_deferred_display_event(response)):
					_finish_battle({
						"reason": "forfeit",
						"forfeitingPlayerId": _get_pvp_state_player_id_for_raw_player_id(str(message.get("playerId", ""))),
					})
					return true

				_finish_battle({
					"reason": "forfeit",
					"forfeitingPlayerId": _get_pvp_state_player_id_for_raw_player_id(str(message.get("playerId", ""))),
				})
			return true

		if message_action != "choose_switch" and message_action != "choose_move":
			_trace_pvp_flow("wait_force_switch.ignore_action", response, "attempt=%d action=%s" % [attempt, message_action])
			attempt += 1
			continue
		if str(message.get("playerId", "")) == action_flow.local_player_id:
			_trace_pvp_flow("wait_force_switch.ignore_own_message", response, "attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)])
			attempt += 1
			continue

		response = _response_from_pvp_realtime_message(message)
		if response.is_empty():
			_trace_pvp_flow("wait_force_switch.empty_response", {}, "attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)])
			attempt += 1
			continue
		var display_response: Dictionary = action_flow.map_response_for_local_player(response)

		var opponent_requests_force_switch := _response_has_opponent_force_switch(display_response)
		if message_action == "choose_move" and not opponent_requests_force_switch:
			_trace_pvp_flow("wait_force_switch.defer_move", display_response, "attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)])
			_defer_pvp_realtime_update(message, "Opponent move received while waiting for force-switch")
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Opponent move deferred while waiting for force-switch",
					"request=%s" % str(message.get("requestId", ""))
				)
			attempt += 1
			continue

		if not _is_authoritative_pvp_render_batch_response(response):
			if _response_has_renderable_battle_events(display_response):
				_trace_pvp_flow("wait_force_switch.stash_fallback", display_response, "attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)])
				fallback_render_response = response.duplicate(true)
				fallback_render_action = message_action
				fallback_render_message = _describe_pvp_realtime_message(message)
				fallback_render_attempt = attempt
				if DEBUG_PVP_REALTIME:
					_log_pvp_realtime(
						"Stashed non-authoritative opponent force-switch update as fallback render",
						"attempt=%d message=%s phase=%s next=%s" % [
							attempt,
							fallback_render_message,
							pvp_last_phase,
							pvp_last_next_phase,
						]
					)
				attempt += 1
				continue

			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Ignoring non-authoritative opponent force-switch update while waiting for render batch",
					"attempt=%d message=%s phase=%s next=%s" % [
						attempt,
						_describe_pvp_realtime_message(message),
						pvp_last_phase,
						pvp_last_next_phase,
					]
				)
			attempt += 1
			continue

		_trace_pvp_flow("wait_force_switch.enqueue_authoritative", display_response, "attempt=%d action=%s message=%s" % [attempt, message_action, _describe_pvp_realtime_message(message)])
		if not await _enqueue_pvp_battle_response(response, "pvp_%s" % message_action, not action_flow._response_has_deferred_display_event(response)):
			return false

		if _response_has_opponent_force_switch(display_response):
			_trace_pvp_flow("wait_force_switch.still_needs_switch", display_response, "attempt=%d action=%s" % [attempt, message_action])
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Opponent still needs force-switch after update",
					"attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)]
				)
			current_action_panel.set_message("Waiting for opponent switch...")
			attempt += 1
			continue

		if message_action == "choose_switch":
			_trace_pvp_flow("wait_force_switch.resolved_by_switch", display_response, "attempt=%d message=%s" % [attempt, _describe_pvp_realtime_message(message)])
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Opponent force-switch resolved",
					"request=%s" % str(message.get("requestId", ""))
				)

		return true

	# Unreachable, but required by GDScript's return analysis.
	return false

func _defer_pvp_realtime_update(message: Dictionary, context: String = "") -> void:
	if message.is_empty():
		return

	pvp_realtime_deferred_updates.append(message.duplicate(true))
	pvp_realtime_activity_seq += 1
	if not DEBUG_PVP_REALTIME:
		return

	var log_context := context if context != "" else "deferred"
	_log_pvp_realtime(
		"Requeued PvP realtime update for later processing",
		"context=%s message=%s deferred_queue_size=%d" % [log_context, _describe_pvp_realtime_message(message), pvp_realtime_deferred_updates.size()]
	)

func _should_drain_idle_pvp_realtime_updates() -> bool:
	if not _is_pvp_battle():
		return false
	if battle_finished:
		return false
	if team_preview_lead_selection_active:
		return false
	if pvp_event_queue.is_rendering:
		return false
	if pvp_idle_realtime_drain_pending:
		return false
	return battle_input_locked and (current_action_view == ActionView.NONE or pvp_idle_wait_recovery_active)

func _drain_idle_pvp_realtime_updates() -> void:
	if pvp_idle_realtime_drain_pending:
		return
	if not _should_drain_idle_pvp_realtime_updates():
		return

	pvp_idle_realtime_drain_pending = true
	while _should_continue_idle_pvp_realtime_drain():
		var message: Dictionary = await _wait_for_next_pvp_realtime_update(0.0)
		if message.is_empty():
			break
		if not await _apply_pvp_realtime_battle_update(message):
			if _get_pvp_realtime_message_kind(message) == "snapshot":
				continue
			_defer_pvp_realtime_update(message, "idle_drain_unapplied")
			break
		_recover_pvp_idle_wait_ui_after_update(message)
	pvp_idle_realtime_drain_pending = false

func _recover_pvp_idle_wait_ui_after_update(message: Dictionary) -> void:
	if not _is_pvp_battle():
		return
	if battle_finished:
		return
	if team_preview_lead_selection_active:
		return

	var local_state_player_id := _get_local_state_player_id()
	var local_needs_force_switch := _local_player_needs_force_switch_ui()
	var opponent_needs_force_switch := _opponent_player_needs_force_switch_ui()
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Idle wait recovery check",
			"message=%s phase=%s localForce=%s opponentForce=%s localCanAct=%s inputLocked=%s actionView=%s" % [
				_describe_pvp_realtime_message(message),
				pvp_last_phase,
				str(local_needs_force_switch),
				str(opponent_needs_force_switch),
				str(_pvp_local_request_allows_action_recovery(local_state_player_id)),
				str(battle_input_locked),
				str(current_action_view),
			]
		)

	if local_needs_force_switch:
		_set_battle_input_locked(false)
		_show_force_switch_if_needed()
		return
	if opponent_needs_force_switch:
		_show_pvp_opponent_force_switch_wait()
		return
	if pvp_last_phase == "turn_open" or _pvp_local_request_allows_action_recovery(local_state_player_id):
		pvp_idle_wait_recovery_active = false
		_set_battle_input_locked(false)
		_update_battle_presentation("pvp_idle_wait_recovery")
		_show_moves()

func _should_continue_idle_pvp_realtime_drain() -> bool:
	if not _is_pvp_battle():
		return false
	if battle_finished:
		return false
	if team_preview_lead_selection_active:
		return false
	if pvp_event_queue.is_rendering:
		return false
	if pvp_realtime_updates.is_empty() and pvp_realtime_deferred_updates.is_empty():
		return false
	return battle_input_locked and (current_action_view == ActionView.NONE or pvp_idle_wait_recovery_active)

func _wait_for_next_pvp_realtime_update(timeout_seconds: float, include_deferred := true) -> Dictionary:
	var queued_message := _pop_next_pvp_realtime_update(include_deferred, "immediately")
	if not queued_message.is_empty() or timeout_seconds <= 0.0:
		return queued_message

	var start_activity_seq := pvp_realtime_activity_seq
	var deadline_msec := Time.get_ticks_msec() + int(max(timeout_seconds * 1000.0, 1.0))
	while Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
		var received_message := _pop_next_pvp_realtime_update(include_deferred, "after wait")
		if not received_message.is_empty():
			return received_message
		if pvp_realtime_activity_seq != start_activity_seq:
			return {}

	return _pop_next_pvp_realtime_update(include_deferred, "after timeout")

func _pop_next_pvp_realtime_update(include_deferred := true, timing_context := "") -> Dictionary:
	if not pvp_realtime_updates.is_empty():
		var queued_message: Variant = pvp_realtime_updates.pop_front()
		if queued_message is Dictionary:
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Dequeued realtime update %s" % timing_context,
					"message=%s" % _describe_pvp_realtime_message(queued_message)
				)
			return queued_message as Dictionary
		return {}
	if include_deferred and not pvp_realtime_deferred_updates.is_empty():
		var deferred_message: Variant = pvp_realtime_deferred_updates.pop_front()
		if deferred_message is Dictionary:
			if DEBUG_PVP_REALTIME:
				_log_pvp_realtime(
					"Dequeued deferred realtime update %s" % timing_context,
					"message=%s" % _describe_pvp_realtime_message(deferred_message)
				)
			return deferred_message as Dictionary
		return {}

	return {}

func _describe_pvp_realtime_message(message: Dictionary) -> String:
	var message_type := str(message.get("type", ""))
	var action := str(message.get("action", ""))
	var player_id := str(message.get("playerId", ""))
	var battle_id := str(message.get("battleId", ""))
	var request_id := str(message.get("requestId", ""))
	var server_seq := _get_pvp_message_server_seq(message)
	var has_response := message.has("response")
	return "type=%s action=%s player=%s battle=%s request=%s seq=%d has_response=%s" % [
		message_type,
		action,
		player_id,
		battle_id,
		request_id,
		server_seq,
		has_response
	]

func _log_pvp_realtime(tag: String, details: String = "") -> void:
	if not DEBUG_PVP_REALTIME:
		return
	if details == "":
		print("[PvPRealtime] %s" % tag)
	else:
		print("[PvPRealtime] %s | %s" % [tag, details])

func _trace_pvp_flow(tag: String, response: Dictionary = {}, details: String = "") -> void:
	if not DEBUG_PVP_FLOW_TRACE:
		return

	var events_value: Variant = response.get("events", [])
	var events_count := 0
	if events_value is Array:
		events_count = (events_value as Array).size()

	var response_phase := str(response.get("phase", "")).strip_edges()
	var response_next := str(response.get("nextPhase", response.get("next_phase", ""))).strip_edges()
	var batch_id := pvp_event_queue.get_response_event_batch_id(response) if not response.is_empty() else ""
	var batch_seq := pvp_event_queue.get_response_batch_seq(response) if not response.is_empty() else -1
	var event_seq := pvp_event_queue.get_response_event_seq_end(response) if not response.is_empty() else -1
	var auth := _is_authoritative_pvp_render_batch_response(response) if not response.is_empty() else false
	var has_force := _response_has_force_switch_request(response) if not response.is_empty() else false
	var opponent_force_response := _response_has_opponent_force_switch(response) if not response.is_empty() else false
	var local_force_ui := _local_player_needs_force_switch_ui() if _is_pvp_battle() else false
	var opponent_force_ui := _opponent_player_needs_force_switch_ui() if _is_pvp_battle() else false
	var current_batch := str(pvp_event_queue.current_event_batch_id)
	if current_batch == "":
		current_batch = "none"
	var printable_details := details
	if printable_details == "":
		printable_details = "-"

	print("[pvp-flow-debug] %s | battle=%s local=%s phase=%s next=%s respPhase=%s respNext=%s serverSeq=%d phaseSeq=%d batch=%s batchSeq=%d eventSeq=%d events=%d auth=%s hasForce=%s oppForceResp=%s localForceUI=%s oppForceUI=%s inputLocked=%s currentBatch=%s lastRendered=%d pending=%d deferred=%d details=%s" % [
		tag,
		battle_state.battle_id,
		action_flow.local_player_id,
		pvp_last_phase if pvp_last_phase != "" else "unknown",
		pvp_last_next_phase if pvp_last_next_phase != "" else "unknown",
		response_phase if response_phase != "" else "none",
		response_next if response_next != "" else "none",
		pvp_last_applied_server_seq,
		pvp_last_phase_update_server_seq,
		batch_id if batch_id != "" else "none",
		batch_seq,
		event_seq,
		events_count,
		str(auth),
		str(has_force),
		str(opponent_force_response),
		str(local_force_ui),
		str(opponent_force_ui),
		str(battle_input_locked),
		current_batch,
		pvp_event_queue.last_rendered_seq,
		pvp_realtime_updates.size(),
		pvp_realtime_deferred_updates.size(),
		printable_details,
	])

func _describe_pokemon_debug_ref(pokemon_data: Dictionary) -> String:
	if pokemon_data.is_empty():
		return "none"
	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", ""))).strip_edges()
	var identity := pokemon_key
	if identity == "" and canonical_slot > 0:
		identity = "slot:%d" % canonical_slot
	if identity == "":
		identity = instance_id
	if identity == "":
		identity = str(pokemon_data.get("ident", "")).strip_edges()
	if identity == "":
		identity = str(pokemon_data.get("species", pokemon_data.get("species_id", pokemon_data.get("displaySpecies", "")))).strip_edges()
	return "identity=%s species=%s speciesId=%s ident=%s key=%s canonicalSlot=%s partySlot=%s metadataSlot=%s instanceId=%s hp=%s fainted=%s active=%s" % [
		identity,
		str(pokemon_data.get("species", pokemon_data.get("displaySpecies", pokemon_data.get("species_id", "")))),
		str(pokemon_data.get("speciesId", pokemon_data.get("species_id", pokemon_data.get("pokedexId", pokemon_data.get("pokedex_id", ""))))),
		str(pokemon_data.get("ident", "")),
		pokemon_key,
		str(canonical_slot),
		str(pokemon_data.get("partySlot", pokemon_data.get("party_slot", ""))),
		str(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", ""))),
		instance_id,
		str(pokemon_data.get("hp", pokemon_data.get("currentHp", pokemon_data.get("current_hp", "")))),
		str(pokemon_data.get("fainted", "")),
		str(pokemon_data.get("active", "")),
	]

func _response_from_pvp_realtime_message(message: Dictionary) -> Dictionary:
	var response_value: Variant = message.get("response", {})
	if response_value is Dictionary:
		var response: Dictionary = (response_value as Dictionary).duplicate(true)
		var server_seq := _get_pvp_message_server_seq(message)
		if server_seq > 0:
			response["pvpServerSeq"] = server_seq
		response["pvpRealtimeMessageType"] = str(message.get("type", "")).strip_edges().to_lower()
		return response
	return {}

func _is_authoritative_pvp_render_batch_response(response: Dictionary) -> bool:
	if bool(response.get("pvpBattleUpdateFallbackRender", false)):
		return true
	return str(response.get("pvpRealtimeMessageType", "")).strip_edges().to_lower() == "pvp.render_batch"

func _promote_pvp_battle_update_fallback_render(response: Dictionary) -> Dictionary:
	var promoted_response := response.duplicate(true)
	promoted_response["pvpBattleUpdateFallbackRender"] = true
	return promoted_response

func _should_apply_pvp_realtime_end_immediately(message: Dictionary) -> bool:
	if battle_finished:
		return false
	return PvpBattleRealtimeService.should_apply_terminal_action_immediately(message, action_flow.local_player_id)

func _finish_pvp_infrastructure_no_contest(message: Dictionary) -> void:
	if battle_finished or not PvpBattleRealtimeService.is_infrastructure_no_contest_message(message):
		return
	_add_battle_log_message("The battle ended as a no contest because battle authority was lost.")
	current_action_panel.set_message("Battle ended as a no contest.")
	_finish_battle({
		"reason": "infrastructure_no_contest",
		"terminalCategory": "INFRASTRUCTURE_NO_CONTEST",
		"terminalResultId": str(message.get("terminalResultId", "")),
		"battleEventSeq": message.get("battleEventSeq", -1),
		"noContest": true,
		"noPenalty": true,
		"skipPartyBattleSync": true,
	})

func _finish_pvp_authoritative_terminal(message: Dictionary) -> void:
	if battle_finished:
		return
	var end_reason := str(message.get("endReason", "ended")).strip_edges().to_lower()
	# A manual forfeit has no final move batch to animate. The durable terminal
	# event is the canonical outcome, so waiting for a separate ended snapshot or
	# direct action response can strand the forfeiter in the battle indefinitely.
	var is_forfeit_terminal := end_reason == "forfeit"
	if not is_forfeit_terminal and PvpBattleRealtimeService.should_defer_authoritative_terminal_until_render(
		battle_state.is_battle_ended(),
		pvp_event_queue.is_rendering,
		str(pvp_event_queue.current_event_batch_id),
		pvp_event_queue.has_pending()
			or not pvp_realtime_updates.is_empty()
			or not pvp_realtime_deferred_updates.is_empty()
	):
		pvp_pending_authoritative_terminal = message.duplicate(true)
		return
	pvp_pending_authoritative_terminal.clear()
	var winner_side := _get_pvp_state_player_id_for_raw_player_id(str(message.get("winnerSide", "")))
	var loser_side := _get_pvp_state_player_id_for_raw_player_id(str(message.get("loserSide", "")))
	_finish_battle({
		"reason": end_reason if end_reason != "" else "ended",
		"winner": winner_side,
		"forfeitingPlayerId": loser_side,
		"battleEventSeq": message.get("battleEventSeq", -1),
		"terminalSource": str(message.get("source", "DURABLE_BATTLE_EVENT")),
	})


func _retry_pending_pvp_authoritative_terminal() -> void:
	if battle_finished or pvp_pending_authoritative_terminal.is_empty():
		return
	_finish_pvp_authoritative_terminal(pvp_pending_authoritative_terminal.duplicate(true))

func _finish_pvp_realtime_battle_from_message(message: Dictionary) -> void:
	if battle_finished:
		return

	var response: Dictionary = _response_from_pvp_realtime_message(message)
	if response.is_empty():
		return

	_finish_confirmed_pvp_forfeit(
		response,
		_get_pvp_state_player_id_for_raw_player_id(str(message.get("playerId", ""))),
		"pvp_forfeit_end"
	)

func _finish_pvp_realtime_battle_from_snapshot(message: Dictionary) -> void:
	if battle_finished:
		return

	var response: Dictionary = _response_from_pvp_realtime_message(message)
	if response.is_empty():
		return

	var mapped_update: Dictionary = action_flow.map_response_for_local_player(response)
	if mapped_update.is_empty():
		return

	if not _apply_pvp_realtime_snapshot_when_safe(message, mapped_update):
		return

	var finish_context := {
		"reason": "forfeit",
		"forfeitingPlayerId": _get_pvp_state_player_id_for_raw_player_id(str(message.get("playerId", ""))),
	}
	if await _finish_if_battle_ended(finish_context):
		return

	finish_context["winner"] = battle_state.get_winner()
	_finish_battle(finish_context)

func _apply_pvp_realtime_battle_update(message: Dictionary) -> bool:
	if message.is_empty():
		return false

	var update_payload: Dictionary = {}
	var message_type := str(message.get("type", "")).strip_edges()
	var realtime_message_kind := _get_pvp_realtime_message_kind(message)
	if realtime_message_kind == "snapshot" or (message.has("response") and (message.get("response") is Dictionary)):
		update_payload = _response_from_pvp_realtime_message(message)
	else:
		update_payload = message.duplicate(true)

	if update_payload.is_empty():
		return false

	var mapped_update := action_flow.map_response_for_local_player(update_payload)
	if mapped_update.is_empty():
		return false
	if realtime_message_kind == "snapshot":
		return await _apply_pvp_realtime_snapshot_when_safe(message, mapped_update)
	var is_required_render_batch := _is_unrendered_authoritative_pvp_render_batch_response(mapped_update)
	if not is_required_render_batch and _is_stale_pvp_realtime_response(mapped_update):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping stale PvP realtime payload apply",
				"seq=%d last_seq=%d turn=%d current_turn=%d" % [
					_get_pvp_response_server_seq(mapped_update),
					pvp_last_applied_server_seq,
					_get_pvp_response_turn(mapped_update),
					battle_state.get_turn(),
				]
		)
		return false

	_warn_if_pvp_battle_update_event_gap(mapped_update)
	var queue_source := "pvp_realtime_update"
	var queue_metadata: Dictionary = {}
	var message_action := str(message.get("action", "")).strip_edges().to_lower()
	if is_required_render_batch and message_action in ["choose_move", "choose_switch"]:
		queue_source = "pvp_%s" % message_action
		queue_metadata["choice_type"] = "switch" if message_action == "choose_switch" else "move"
	if not await _enqueue_pvp_battle_response(update_payload, queue_source, true, queue_metadata):
		return false

	return true

func _apply_pvp_realtime_snapshot_when_safe(message: Dictionary, mapped_update: Dictionary) -> bool:
	if mapped_update.is_empty():
		return false

	if _is_stale_pvp_snapshot_response(message, mapped_update):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Snapshot ignored as stale",
				"message=%s snapshot_last_seq=%d" % [_describe_pvp_realtime_message(message), pvp_last_applied_snapshot_server_seq]
			)
		return false

	var snapshot_event_seq := _get_pvp_response_event_seq_end(mapped_update)
	var last_rendered_seq := pvp_event_queue.last_rendered_seq
	if _is_initial_pvp_snapshot(message, mapped_update):
		pvp_pending_reconciliation_snapshot.clear()
		return _apply_pvp_snapshot_reconciliation(message, mapped_update, "pvp_snapshot_bootstrap")

	if snapshot_event_seq >= 0 and snapshot_event_seq > last_rendered_seq:
		_buffer_pvp_reconciliation_snapshot(message, mapped_update, snapshot_event_seq, last_rendered_seq)
		return false

	if snapshot_event_seq < 0:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Snapshot blocked due missing eventSeq",
				"message=%s lastRenderedSeq=%d" % [_describe_pvp_realtime_message(message), last_rendered_seq]
			)
		return false

	pvp_pending_reconciliation_snapshot.clear()
	return _apply_pvp_snapshot_reconciliation(message, mapped_update, "pvp_snapshot_reconciliation")

func _apply_pvp_snapshot_reconciliation(message: Dictionary, mapped_update: Dictionary, source: String) -> bool:
	var reconciliation := mapped_update.duplicate(true)
	reconciliation["events"] = []
	reconciliation["eventBatches"] = []

	if not bool(reconciliation.get("success", false)):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Snapshot reconciliation skipped",
				"source=%s message=%s reason=unsuccessful_response" % [source, _describe_pvp_realtime_message(message)]
			)
		return false
	if pvp_response_order.is_stale(reconciliation):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Snapshot reconciliation skipped",
				"source=%s reason=older_canonical_projection" % source
			)
		return false

	_preserve_terminal_presentation_requests(reconciliation)
	battle_state.load_from_api_response(reconciliation, false)
	pvp_response_order.remember(reconciliation)
	_apply_party_state_from_api_response(reconciliation)
	_remember_active_player_party_moves()
	_prewarm_current_battle_move_animations()
	_sync_presentation_field_from_battle_state()
	_update_battle_presentation("snapshot_reconciliation")

	var snapshot_server_seq := _get_pvp_response_server_seq(reconciliation)
	if snapshot_server_seq > pvp_last_applied_snapshot_server_seq:
		pvp_last_applied_snapshot_server_seq = snapshot_server_seq

	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Snapshot reconciliation applied",
			"source=%s snapshotEventSeq=%d lastRenderedSeq=%d snapshotServerSeq=%d phase=%s ended=%s" % [
				source,
				_get_pvp_response_event_seq_end(mapped_update),
				pvp_event_queue.last_rendered_seq,
				snapshot_server_seq,
				str(mapped_update.get("phase", "")),
				str(_pvp_response_state_ended(mapped_update)),
			]
		)
	return true

func _buffer_pvp_reconciliation_snapshot(message: Dictionary, mapped_update: Dictionary, snapshot_event_seq: int, last_rendered_seq: int) -> void:
	var existing_response_value: Variant = pvp_pending_reconciliation_snapshot.get("mapped_update", {})
	var existing_response: Dictionary = existing_response_value as Dictionary if existing_response_value is Dictionary else {}
	var existing_server_seq := _get_pvp_response_server_seq(existing_response)
	var incoming_server_seq := _get_pvp_response_server_seq(mapped_update)
	if not pvp_pending_reconciliation_snapshot.is_empty() and incoming_server_seq > 0 and existing_server_seq > incoming_server_seq:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Skipping older buffered PvP snapshot",
				"incomingServerSeq=%d existingServerSeq=%d snapshotEventSeq=%d lastRenderedSeq=%d" % [
					incoming_server_seq,
					existing_server_seq,
					snapshot_event_seq,
					last_rendered_seq,
				]
			)
		return

	pvp_pending_reconciliation_snapshot = {
		"message": message.duplicate(true),
		"mapped_update": mapped_update.duplicate(true),
		"snapshot_event_seq": snapshot_event_seq,
	}
	if DEBUG_PVP_REALTIME:
		_log_pvp_realtime(
			"Buffered PvP snapshot ahead of render",
			"snapshotEventSeq=%d lastRenderedSeq=%d message=%s" % [
				snapshot_event_seq,
				last_rendered_seq,
				_describe_pvp_realtime_message(message),
			]
		)

func _retry_pending_pvp_reconciliation_snapshot() -> void:
	if pvp_retrying_reconciliation_snapshot:
		return
	if pvp_pending_reconciliation_snapshot.is_empty():
		return

	pvp_retrying_reconciliation_snapshot = true
	var pending_snapshot := pvp_pending_reconciliation_snapshot.duplicate(true)
	var mapped_update_value: Variant = pending_snapshot.get("mapped_update", {})
	var mapped_update: Dictionary = mapped_update_value as Dictionary if mapped_update_value is Dictionary else {}
	var message_value: Variant = pending_snapshot.get("message", {})
	var message: Dictionary = message_value as Dictionary if message_value is Dictionary else {}
	var snapshot_event_seq := _get_int_from_variant(
		pending_snapshot.get("snapshot_event_seq", _get_pvp_response_event_seq_end(mapped_update)),
		-1
	)
	var last_rendered_seq := pvp_event_queue.last_rendered_seq
	if mapped_update.is_empty():
		pvp_pending_reconciliation_snapshot.clear()
		pvp_retrying_reconciliation_snapshot = false
		return

	if snapshot_event_seq >= 0 and snapshot_event_seq > last_rendered_seq:
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Pending PvP snapshot still ahead after render",
				"snapshotEventSeq=%d lastRenderedSeq=%d" % [snapshot_event_seq, last_rendered_seq]
			)
		pvp_retrying_reconciliation_snapshot = false
		return

	if _is_stale_pvp_snapshot_response(message, mapped_update):
		if DEBUG_PVP_REALTIME:
			_log_pvp_realtime(
				"Discarding stale buffered PvP snapshot after render",
				"snapshotEventSeq=%d lastRenderedSeq=%d message=%s" % [
					snapshot_event_seq,
					last_rendered_seq,
					_describe_pvp_realtime_message(message),
				]
			)
		pvp_pending_reconciliation_snapshot.clear()
		pvp_retrying_reconciliation_snapshot = false
		return

	pvp_pending_reconciliation_snapshot.clear()

	if not _apply_pvp_snapshot_reconciliation(message, mapped_update, "pvp_snapshot_reconciliation_retry"):
		pvp_pending_reconciliation_snapshot = pending_snapshot
	pvp_retrying_reconciliation_snapshot = false

func _get_pvp_realtime_message_kind(message: Dictionary) -> String:
	var message_type := str(message.get("type", "")).strip_edges().to_lower()
	if message_type == "pvp.snapshot":
		return "snapshot"
	if message_type == "pvp.battle_update":
		return "battle_update"
	return message_type

func _is_initial_pvp_snapshot(message: Dictionary, response: Dictionary) -> bool:
	if _get_pvp_realtime_message_kind(message) != "snapshot":
		return false
	if _get_pvp_message_server_seq(message) > 0:
		return false
	if pvp_last_applied_server_seq > 0:
		return false
	if pvp_last_applied_snapshot_server_seq > 0:
		return false
	if pvp_event_queue.last_rendered_seq >= 0:
		return false
	return true

func _pvp_response_state_ended(response: Dictionary) -> bool:
	var state_value: Variant = response.get("state", {})
	return state_value is Dictionary and bool((state_value as Dictionary).get("ended", false))

func _warn_if_pvp_battle_update_event_gap(response: Dictionary) -> void:
	if not DEBUG_PVP_REALTIME:
		return
	var last_rendered_seq := pvp_event_queue.last_rendered_seq
	if last_rendered_seq < 0:
		return

	var first_event_seq := _get_pvp_response_first_event_seq(response)
	if first_event_seq < 0:
		return
	if first_event_seq > last_rendered_seq + 1:
		_log_pvp_realtime(
			"PvP event gap warning",
			"firstEventSeq=%d lastRenderedSeq=%d eventSeq=%d batchSeq=%d" % [
				first_event_seq,
				last_rendered_seq,
				_get_pvp_response_event_seq_end(response),
				_get_int_from_variant(response.get("batchSeq", -1), -1),
			]
		)

func _is_stale_pvp_realtime_message(message: Dictionary) -> bool:
	if _get_pvp_realtime_message_kind(message) == "snapshot":
		var snapshot_response: Dictionary = _response_from_pvp_realtime_message(message)
		var mapped_snapshot: Dictionary = {}
		if not snapshot_response.is_empty():
			mapped_snapshot = action_flow.map_response_for_local_player(snapshot_response)
		return _is_stale_pvp_snapshot_response(message, mapped_snapshot)
	var render_response := _response_from_pvp_realtime_message(message)
	if _is_unrendered_authoritative_pvp_render_batch_response(render_response):
		return false

	var server_seq := _get_pvp_message_server_seq(message)
	if server_seq > 0 and server_seq <= pvp_last_applied_server_seq:
		return true

	var response: Dictionary = _response_from_pvp_realtime_message(message)
	if response.is_empty():
		return false

	return _is_stale_pvp_realtime_response(action_flow.map_response_for_local_player(response))

func _is_unrendered_authoritative_pvp_render_batch_response(response: Dictionary) -> bool:
	if not _is_authoritative_pvp_render_batch_response(response):
		return false
	var event_seq_end := _get_pvp_response_event_seq_end(response)
	return event_seq_end >= 0 and event_seq_end > pvp_event_queue.last_rendered_seq

func _is_stale_pvp_snapshot_response(message: Dictionary, response: Dictionary) -> bool:
	if response.is_empty():
		return false

	var response_battle_id := str(response.get("battleId", "")).strip_edges()
	if battle_state.battle_id != "" and response_battle_id != "" and response_battle_id != battle_state.battle_id:
		return true
	if pvp_response_order.is_stale(response):
		return true

	var server_seq := _get_pvp_message_server_seq(message)
	if server_seq <= 0:
		server_seq = _get_pvp_response_server_seq(response)
	if server_seq > 0 and server_seq <= pvp_last_applied_snapshot_server_seq:
		return true

	var response_turn := _get_pvp_response_turn(response)
	var current_turn := battle_state.get_turn()
	if response_turn > 0 and current_turn > 0 and response_turn < current_turn:
		return true

	if _response_has_any_team_preview(response) and not _battle_state_has_any_team_preview():
		return true

	return false

func _is_stale_pvp_realtime_response(response: Dictionary) -> bool:
	if response.is_empty():
		return false

	var response_battle_id := str(response.get("battleId", "")).strip_edges()
	if battle_state.battle_id != "" and response_battle_id != "" and response_battle_id != battle_state.battle_id:
		return true
	if pvp_response_order.is_stale(response):
		return true

	var server_seq := _get_pvp_response_server_seq(response)
	if server_seq > 0 and server_seq <= pvp_last_applied_server_seq:
		return true

	var response_turn := _get_pvp_response_turn(response)
	var current_turn := battle_state.get_turn()
	if response_turn > 0 and current_turn > 0 and response_turn < current_turn:
		return true

	if _response_has_any_team_preview(response) and not _battle_state_has_any_team_preview():
		return true

	return false

func _mark_pvp_response_applied(response: Dictionary) -> void:
	if not _is_pvp_battle():
		return

	var server_seq := _get_pvp_response_server_seq(response)
	if server_seq > pvp_last_applied_server_seq:
		pvp_last_applied_server_seq = server_seq

func _get_pvp_message_server_seq(message: Dictionary) -> int:
	var server_seq := _get_int_from_variant(message.get("serverSeq", 0))
	if server_seq > 0:
		return server_seq

	var response_value: Variant = message.get("response", {})
	if response_value is Dictionary:
		return _get_pvp_response_server_seq((response_value as Dictionary))

	return 0

func _get_pvp_response_server_seq(response: Dictionary) -> int:
	var server_seq := _get_int_from_variant(response.get("pvpServerSeq", 0))
	if server_seq > 0:
		return server_seq
	return _get_int_from_variant(response.get("serverSeq", 0))

func _get_pvp_response_event_seq_end(response: Dictionary) -> int:
	var event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
	if event_seq >= 0:
		return event_seq

	var event_batches_value: Variant = response.get("eventBatches", [])
	if event_batches_value is Array:
		var event_batches: Array = event_batches_value as Array
		for index: int in range(event_batches.size() - 1, -1, -1):
			var batch_value: Variant = event_batches[index]
			if not (batch_value is Dictionary):
				continue
			var batch: Dictionary = batch_value as Dictionary
			var event_seq_end := _get_int_from_variant(batch.get("eventSeqEnd", -1), -1)
			if event_seq_end >= 0:
				return event_seq_end

	return -1

func _get_pvp_response_first_event_seq(response: Dictionary) -> int:
	var event_batches_value: Variant = response.get("eventBatches", [])
	if event_batches_value is Array:
		var event_batches: Array = event_batches_value as Array
		for batch_value: Variant in event_batches:
			if not (batch_value is Dictionary):
				continue
			var batch: Dictionary = batch_value as Dictionary
			var event_seq_start := _get_int_from_variant(batch.get("eventSeqStart", -1), -1)
			if event_seq_start >= 0:
				return event_seq_start

	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return -1
	var events: Array = events_value as Array
	if events.is_empty():
		return -1

	var event_seq_end := _get_pvp_response_event_seq_end(response)
	if event_seq_end < 0:
		return -1
	return event_seq_end - events.size() + 1

func _get_pvp_response_turn(response: Dictionary) -> int:
	var state_value: Variant = response.get("state", {})
	if state_value is Dictionary:
		var state_turn := _get_int_from_variant((state_value as Dictionary).get("turn", 0))
		if state_turn > 0:
			return state_turn

	return _get_int_from_variant(response.get("turn", 0))

func _get_int_from_variant(value: Variant, fallback := 0) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)

	var text_value := str(value).strip_edges()
	if text_value.is_valid_int():
		return int(text_value)

	return fallback

func _response_has_any_team_preview(response: Dictionary) -> bool:
	var requests_value: Variant = response.get("requests", {})
	if not (requests_value is Dictionary):
		return false

	var requests: Dictionary = requests_value as Dictionary
	for request_value: Variant in requests.values():
		if request_value is Dictionary and bool((request_value as Dictionary).get("teamPreview", false)):
			return true

	return false

func _battle_state_has_any_team_preview() -> bool:
	for player_id in ["p1", "p2"]:
		if battle_state.is_team_preview(str(player_id)):
			return true

	return false

func _response_has_renderable_battle_events(response: Dictionary) -> bool:
	var events_value: Variant = response.get("events", [])
	var events: Array = events_value as Array if events_value is Array else []
	var state_value: Variant = response.get("state", {})
	var state: Dictionary = state_value as Dictionary if state_value is Dictionary else {}
	if _is_pvp_battle():
		return _response_has_unrendered_pvp_events(response) or bool(state.get("ended", false))

	if not events.is_empty():
		return true

	return bool(state.get("ended", false))

func _response_has_unrendered_pvp_events(response: Dictionary) -> bool:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return false

	var events: Array = events_value as Array
	if events.is_empty():
		return false

	var response_event_seq := _get_int_from_variant(response.get("eventSeq", -1), -1)
	var last_rendered_seq := pvp_event_queue.last_rendered_seq
	if response_event_seq >= 0 and last_rendered_seq >= 0:
		return response_event_seq > last_rendered_seq

	return events.size() > pvp_rendered_event_count

func _response_has_opponent_force_switch(response: Dictionary) -> bool:
	var requests_value: Variant = response.get("requests", {})
	if not (requests_value is Dictionary):
		return false

	var requests: Dictionary = requests_value as Dictionary
	var candidate_player_ids := _get_force_switch_candidate_player_ids(_get_opponent_state_player_id(), "p2")
	for opponent_player_id in candidate_player_ids:
		var opponent_request_value: Variant = requests.get(opponent_player_id, {})
		if not (opponent_request_value is Dictionary):
			continue

		var opponent_request: Dictionary = opponent_request_value as Dictionary
		var force_switch_value: Variant = opponent_request.get("forceSwitch", [])
		if force_switch_value is Array:
			var force_switches: Array = force_switch_value as Array
			for value: Variant in force_switches:
				if bool(value):
					if not _response_player_active_is_non_fainted(response, opponent_player_id):
						return true

		if _response_player_active_fainted_with_available_switch(response, opponent_player_id):
			return true

	return false

func _response_has_force_switch_request(response: Dictionary) -> bool:
	var requests_value: Variant = response.get("requests", {})
	if not (requests_value is Dictionary):
		return false

	var requests: Dictionary = requests_value as Dictionary
	for request_value: Variant in requests.values():
		if not (request_value is Dictionary):
			continue

		var request_data: Dictionary = request_value as Dictionary
		var force_switch_value: Variant = request_data.get("forceSwitch", [])
		if force_switch_value is Array:
			for value: Variant in force_switch_value as Array:
				if bool(value):
					return true

	return false

func _response_player_active_is_non_fainted(response: Dictionary, player_id: String) -> bool:
	var requests_value: Variant = response.get("requests", {})
	if not (requests_value is Dictionary):
		return false

	var requests: Dictionary = requests_value as Dictionary
	var request_value: Variant = requests.get(player_id, {})
	if not (request_value is Dictionary):
		return false

	var side_value: Variant = (request_value as Dictionary).get("side", {})
	if not (side_value is Dictionary):
		return false

	var team_value: Variant = (side_value as Dictionary).get("pokemon", [])
	if not (team_value is Array):
		return false

	for pokemon_value: Variant in team_value:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if not bool(pokemon.get("active", false)):
			continue

		var condition := str(pokemon.get("condition", "")).strip_edges().to_lower()
		var is_fainted := bool(pokemon.get("fainted", false)) or condition == "0 fnt" or condition.ends_with(" fnt")
		if not is_fainted and int(pokemon.get("hp", 1)) <= 0 and int(pokemon.get("maxHp", 0)) > 0:
			is_fainted = true
		return not is_fainted

	return false

func _response_player_active_fainted_with_available_switch(response: Dictionary, player_id: String) -> bool:
	var requests_value: Variant = response.get("requests", {})
	if not (requests_value is Dictionary):
		return false

	var requests: Dictionary = requests_value as Dictionary
	var request_value: Variant = requests.get(player_id, {})
	if not (request_value is Dictionary):
		return false

	var request: Dictionary = request_value as Dictionary
	var side_value: Variant = request.get("side", {})
	if not (side_value is Dictionary):
		return false

	var team_value: Variant = (side_value as Dictionary).get("pokemon", [])
	if not (team_value is Array):
		return false

	var active_fainted := false
	var has_switch_target := false
	for pokemon_value: Variant in team_value:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		var is_fainted := bool(pokemon.get("fainted", false)) or str(pokemon.get("condition", "")).strip_edges().to_lower().ends_with(" fnt")
		if bool(pokemon.get("active", false)):
			active_fainted = is_fainted
			continue

		if is_fainted:
			continue

		has_switch_target = true

	return active_fainted and has_switch_target

func _submit_npc_choice_and_render(
	rendered_event_keys: Dictionary = {},
	pending_player_choice_events: Array = []
) -> bool:
	var opponent_response: Dictionary = await action_flow.submit_npc_choice("p2", last_rendered_event_seq)

	if not bool(opponent_response.get("success", false)):
		return false

	await _render_opponent_response(opponent_response, rendered_event_keys, pending_player_choice_events)
	await _hold_opponent_response_message()
	return true

func _render_resolved_player_choice_response(
	resolved_response: Dictionary,
	pending_player_choice_events: Array = []
) -> bool:
	if not bool(resolved_response.get("success", false)):
		return false

	await _render_opponent_response(resolved_response, {}, pending_player_choice_events)
	await _hold_opponent_response_message()
	return true

func _render_pvp_opponent_response(
	opponent_response: Dictionary,
	rendered_event_keys: Dictionary = {},
	pending_player_choice_events: Array = [],
	source := "pvp_opponent_response"
) -> bool:
	var batch_response := opponent_response.duplicate(true)
	var render_response := pvp_response_order.merge_latest_projection_with_events(opponent_response)
	var response_events: Array = _filter_incremental_non_pvp_response_events(render_response)
	var filtered_events: Array = _filter_already_rendered_events(response_events, rendered_event_keys, render_response)
	var opponent_events: Array = _merge_pending_player_choice_events(pending_player_choice_events, filtered_events)
	_debug_battle_presentation_order("pvp_opponent_response.events source=%s events=%s" % [
		source,
		JSON.stringify(_summarize_events_for_order_debug(opponent_events)),
	])
	defer_force_switch_active_hide = true
	_prepare_switch_in_presentation_for_events(opponent_events)
	_update_battle_presentation_before_event_render(opponent_events)
	_rewind_active_hud_hp_for_events(opponent_events)
	_rewind_party_slots_for_events(opponent_events)
	var success := await _render_pvp_event_batch(render_response, opponent_events, true, source)
	defer_force_switch_active_hide = false
	_restore_pvp_authoritative_presentation(batch_response, opponent_events)
	_update_active_sprites()
	return success

func _restore_pvp_authoritative_presentation(response: Dictionary, rendered_events: Array = []) -> void:
	if response.is_empty() or not bool(response.get("success", false)):
		return
	var canonical_response := pvp_response_order.canonical_snapshot_for_render_cursor(
		response,
		pvp_event_queue.last_rendered_seq
	)
	_preserve_terminal_presentation_requests(canonical_response)
	battle_state.load_from_api_response(canonical_response, false)
	_reapply_rendered_condition_events(rendered_events)
	_sync_player_save_party_status_from_battle_state()
	_sync_presentation_field_from_battle_state()
	_reapply_rendered_field_effect_events(rendered_events)
	_update_battle_status_panels()
	_update_hud_panels()
	_update_party_slots()

func _reapply_rendered_condition_events(events: Array) -> void:
	var condition_events: Array = []
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		match str(event_data.get("type", "")):
			"damage", "heal", "faint", "status":
				condition_events.append(event_data.duplicate(true))

	if not condition_events.is_empty():
		# Only condition events are replayed. Switch events deliberately remain
		# canonical, which prevents Pursuit from reviving or fainting its intended
		# switch target while retaining hazard damage from the rendered batch.
		battle_state.apply_event_conditions(condition_events)

func _reapply_rendered_field_effect_events(events: Array) -> void:
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		if str(event_data.get("type", "")) != "fieldEffect":
			continue

		presentation_state.apply_event(event_data, battle_state.get_turn())

func _preserve_terminal_presentation_requests(response: Dictionary) -> void:
	var state_value: Variant = response.get("state", {})
	if not (state_value is Dictionary) or not bool((state_value as Dictionary).get("ended", false)):
		return
	# Ended Showdown requests can be empty. Preserve the event-applied party and
	# active winner so the final move/faint remains visible behind the result UI.
	response["requests"] = battle_state.requests.duplicate(true)

func _render_opponent_response(
	opponent_response: Dictionary,
	rendered_event_keys: Dictionary = {},
	pending_player_choice_events: Array = []
) -> void:
	var response_events: Array = _filter_incremental_non_pvp_response_events(opponent_response)
	var filtered_events: Array = _filter_already_rendered_events(response_events, rendered_event_keys, opponent_response)
	var opponent_events: Array = _merge_pending_player_choice_events(pending_player_choice_events, filtered_events)
	_debug_battle_presentation_order("opponent_response.events events=%s" % JSON.stringify(_summarize_events_for_order_debug(opponent_events)))
	defer_force_switch_active_hide = true
	_prepare_switch_in_presentation_for_events(opponent_events)
	_update_battle_presentation_before_event_render(opponent_events)
	_rewind_active_hud_hp_for_events(opponent_events)
	_rewind_party_slots_for_events(opponent_events)
	await _render_battle_events(opponent_events, true, "opponent_response_non_pvp")
	_mark_non_pvp_response_events_rendered(opponent_response, filtered_events)
	defer_force_switch_active_hide = false
	_update_hud_panels()
	_update_active_sprites()

func _prepare_switch_in_presentation_for_events(events: Array) -> void:
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		var event_data: Dictionary = event_value as Dictionary
		if not _is_switch_like_event(event_data):
			continue

		var switch_ident := _get_switch_event_ident(event_data)
		if switch_ident == "":
			continue

		var condition := _get_switch_event_condition(event_data, switch_ident)
		_set_temporary_switch_in_condition(switch_ident, condition, event_data)

func _get_switch_event_ident(event_data: Dictionary) -> String:
	for key in ["toIdent", "target", "pokemon", "ident"]:
		var ident := str(event_data.get(key, ""))
		if _get_player_id_from_ident(ident) != "":
			return ident

	var player_id := str(event_data.get("playerId", ""))
	var species := str(event_data.get("species", event_data.get("to", event_data.get("pokemon", "")))).strip_edges()
	if player_id == "" or species == "":
		return ""

	return "%sa: %s" % [player_id, species]

func _get_switch_event_condition(event_data: Dictionary, switch_ident: String) -> String:
	var condition := str(event_data.get("condition", event_data.get("toCondition", ""))).strip_edges()
	if condition != "" and not condition.ends_with(" fnt"):
		return condition

	if event_data.has("hp") and event_data.has("maxHp"):
		var event_hp := int(event_data.get("hp", 0))
		var event_max_hp: int = max(int(event_data.get("maxHp", 1)), 1)
		if event_hp > 0:
			return "%s/%s" % [event_hp, event_max_hp]

	var player_id := _get_player_id_from_ident(switch_ident)
	var team := battle_state.get_player_team(player_id)
	var target_index := _find_temporary_switch_target_index(team, switch_ident, event_data)
	if target_index >= 0 and target_index < team.size():
		var pokemon_value: Variant = team[target_index]
		if not (pokemon_value is Dictionary):
			return "1/1"

		var pokemon: Dictionary = pokemon_value as Dictionary
		var max_hp: int = max(int(pokemon.get("maxHp", 1)), 1)
		var hp: int = int(pokemon.get("hp", max_hp))
		if hp <= 0:
			hp = max_hp
		return "%s/%s" % [hp, max_hp]

	return "1/1"

func _set_temporary_switch_in_condition(switch_ident: String, condition: String, event_data: Dictionary = {}) -> void:
	var player_id := _get_player_id_from_ident(switch_ident)
	if player_id == "":
		return

	var team := battle_state.get_player_team(player_id)
	var target_index := _find_temporary_switch_target_index(team, switch_ident, event_data)
	if target_index < 0:
		return
	var target_value: Variant = team[target_index] if target_index < team.size() else null
	if target_value is Dictionary:
		var target := target_value as Dictionary
		var raw_condition := str(event_data.get("condition", event_data.get("toCondition", ""))).strip_edges().to_lower()
		var explicit_hp := int(event_data.get("hp", 0)) if event_data.has("hp") else 0
		var target_is_fainted := bool(target.get("fainted", false)) or int(target.get("hp", 1)) <= 0
		var event_proves_alive := (raw_condition != "" and not raw_condition.ends_with(" fnt")) or explicit_hp > 0
		if target_is_fainted and not event_proves_alive:
			return

	var hp_snapshot: Dictionary = hp_event_helper.parse_condition_hp_snapshot(condition)
	var hp: int = max(int(hp_snapshot.get("hp", 1)), 1)
	var max_hp: int = max(int(hp_snapshot.get("max_hp", hp)), 1)
	if condition == "" or condition.ends_with(" fnt"):
		condition = "%s/%s" % [hp, max_hp]

	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		var is_target := index == target_index
		pokemon["active"] = is_target
		if not is_target:
			continue

		pokemon["condition"] = condition
		pokemon["hp"] = hp
		pokemon["maxHp"] = max_hp
		pokemon["fainted"] = false


func _find_temporary_switch_target_index(team: Array, switch_ident: String, event_data: Dictionary) -> int:
	var event_pokemon_key := _get_switch_event_pokemon_key(event_data)
	if event_pokemon_key != "":
		var key_index := _find_unique_team_index_by_pokemon_key(team, event_pokemon_key)
		if key_index >= 0:
			return key_index
		if key_index == -2:
			return -1

	var event_slot := _get_switch_event_metadata_slot(event_data)
	if event_slot > 0:
		var slot_index := _find_unique_team_index_by_metadata_slot(team, event_slot)
		if slot_index >= 0:
			return slot_index
		if slot_index == -2:
			return -1

	var target_ident := _normalize_battle_ident(switch_ident)
	if target_ident != "":
		var ident_index := _find_unique_team_index_by_ident(team, target_ident)
		if ident_index >= 0:
			return ident_index
		if ident_index == -2:
			return -1

	var target_key := _get_pending_mega_key(switch_ident)
	if target_key == "":
		return -1

	var species_index := _find_unique_team_index_by_species_key(team, target_key)
	return species_index if species_index >= 0 else -1


func _get_switch_event_pokemon_key(event_data: Dictionary) -> String:
	for key in ["pokemonKey", "pokemon_key"]:
		var value := str(event_data.get(key, "")).strip_edges()
		if value != "":
			return value

	for ref_key in ["toRef", "to_ref", "targetRef", "target_ref"]:
		var ref_value: Variant = event_data.get(ref_key, {})
		if not (ref_value is Dictionary):
			continue

		var ref_key_value := _get_direct_switch_event_pokemon_key(ref_value as Dictionary)
		if ref_key_value != "":
			return ref_key_value

	return ""

func _get_direct_switch_event_pokemon_key(event_data: Dictionary) -> String:
	for key in ["pokemonKey", "pokemon_key"]:
		var value := str(event_data.get(key, "")).strip_edges()
		if value != "":
			return value

	return ""

func _is_switch_like_event(event_data: Dictionary) -> bool:
	var event_type := str(event_data.get("type", ""))
	return event_type == "switch" or event_type == "drag"

func _events_have_switch_like_event(events: Array) -> bool:
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue

		if _is_switch_like_event(event_value as Dictionary):
			return true

	return false


func _find_unique_team_index_by_pokemon_key(team: Array, pokemon_key: String) -> int:
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		var current_key := str(pokemon.get("pokemonKey", pokemon.get("pokemon_key", ""))).strip_edges()
		if current_key == "" or current_key != pokemon_key:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func _find_unique_team_index_by_metadata_slot(team: Array, metadata_slot: int) -> int:
	var found_index := -1
	var any_explicit_slot := false
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if not pokemon.has("metadataSlot") and not pokemon.has("metadata_slot"):
			continue

		any_explicit_slot = true
		if int(pokemon.get("metadataSlot", pokemon.get("metadata_slot", 0))) != metadata_slot:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	if found_index < 0 and not any_explicit_slot:
		var slot_index := metadata_slot - 1
		if slot_index >= 0 and slot_index < team.size():
			return slot_index

	return found_index


func _find_unique_team_index_by_ident(team: Array, normalized_ident: String) -> int:
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if _normalize_battle_ident(str(pokemon.get("ident", ""))) != normalized_ident:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func _find_unique_team_index_by_species_key(team: Array, target_key: String) -> int:
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if _get_pending_mega_key(str(pokemon.get("ident", ""))) != target_key:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func _get_switch_event_metadata_slot(event_data: Dictionary) -> int:
	for key in ["metadataSlot", "metadata_slot", "partySlot", "party_slot", "slot", "position"]:
		if not event_data.has(key):
			continue

		var slot := _safe_int(event_data.get(key), -1)
		if slot > 0:
			return slot

	for ref_key in ["toRef", "to_ref", "targetRef", "target_ref"]:
		var ref_value: Variant = event_data.get(ref_key, {})
		if not (ref_value is Dictionary):
			continue

		var ref_slot := _get_direct_switch_event_metadata_slot(ref_value as Dictionary)
		if ref_slot > 0:
			return ref_slot

	return -1

func _get_direct_switch_event_metadata_slot(event_data: Dictionary) -> int:
	for key in ["metadataSlot", "metadata_slot", "partySlot", "party_slot", "slot", "position"]:
		if not event_data.has(key):
			continue

		var slot := _safe_int(event_data.get(key), -1)
		if slot > 0:
			return slot

	return -1

func _show_switch_event_active_pokemon(event_data: Dictionary) -> void:
	var switch_ident := _get_switch_event_ident(event_data)
	var player_id := _get_switch_event_player_id(event_data)
	if player_id == "":
		return

	var species := _get_switch_event_display_species(event_data, switch_ident, player_id)
	if species == "":
		return

	var is_shiny := _get_switch_event_is_shiny(player_id, switch_ident, species)
	match player_id:
		"p1":
			_set_single_pokemon_species_with_pvp_warning(player_sprite_box, species, "back", is_shiny, "switch_event")
		"p2":
			_set_single_pokemon_species_with_pvp_warning(enemy_sprite_box, species, "front", is_shiny, "switch_event")

func _get_switch_event_player_id(event_data: Dictionary) -> String:
	var player_id := str(event_data.get("playerId", ""))
	if player_id != "":
		return player_id

	var switch_ident := _get_switch_event_ident(event_data)
	player_id = _get_player_id_from_ident(switch_ident)
	if player_id != "":
		return player_id

	return _get_player_id_from_ident(str(event_data.get("pokemon", "")))

func _get_switch_event_species(event_data: Dictionary, switch_ident: String) -> String:
	var persisted_mega_species := battle_state.resolve_persisted_mega_species_for_ident(switch_ident)
	if persisted_mega_species != "":
		return persisted_mega_species

	for key in ["to", "species", "displaySpecies"]:
		var species := str(event_data.get(key, "")).strip_edges()
		if species != "":
			return species

	if switch_ident.contains(": "):
		return str(switch_ident.split(": ")[1]).strip_edges()

	var pokemon_text := str(event_data.get("pokemon", "")).strip_edges()
	if pokemon_text.contains(": "):
		return str(pokemon_text.split(": ")[1]).strip_edges()

	return pokemon_text

func _get_switch_event_display_species(event_data: Dictionary, switch_ident: String, player_id: String) -> String:
	var persisted_mega_species := battle_state.resolve_persisted_mega_species_for_ident(switch_ident)
	if persisted_mega_species != "":
		return persisted_mega_species

	for ref_key in ["toRef", "to_ref", "targetRef", "target_ref"]:
		var ref_value: Variant = event_data.get(ref_key, {})
		if not (ref_value is Dictionary):
			continue

		var ref_data: Dictionary = ref_value as Dictionary
		for key in ["displaySpecies", "display_species", "species"]:
			var ref_species := str(ref_data.get(key, "")).strip_edges()
			if ref_species != "":
				return ref_species

	if player_id != "":
		var active_display_species := _get_active_display_species(player_id)
		if active_display_species != "":
			return active_display_species

	return _get_switch_event_species(event_data, switch_ident)

func _get_switch_event_is_shiny(player_id: String, switch_ident: String, species: String) -> bool:
	var target_key := _get_pending_mega_key(switch_ident)
	var normalized_species := _normalize_species_for_compare(species)
	for pokemon_value: Variant in battle_state.get_player_team(player_id):
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if target_key != "" and _get_pending_mega_key(str(pokemon.get("ident", ""))) == target_key:
			return bool(pokemon.get("shiny", pokemon.get("isShiny", false)))

		var pokemon_species := _normalize_species_for_compare(str(pokemon.get("species", pokemon.get("displaySpecies", ""))))
		if normalized_species != "" and pokemon_species == normalized_species:
			return bool(pokemon.get("shiny", pokemon.get("isShiny", false)))

	return false

func _hold_opponent_response_message() -> void:
	if OPPONENT_RESPONSE_HOLD_SECONDS <= 0.0:
		return
	await get_tree().create_timer(OPPONENT_RESPONSE_HOLD_SECONDS).timeout

func _can_switch_to_slot(slot: int) -> bool:
	var local_state_player_id := _get_local_state_player_id()
	if force_switch_flow.is_player_trapped_outside_force_switch(local_state_player_id):
		current_action_panel.set_message("Cannot switch right now!")
		return false

	return force_switch_flow.can_switch_to_slot(slot, local_state_player_id)

func _can_switch_to_selected_pokemon(visual_slot: int, pokemon_data: Dictionary) -> bool:
	var local_state_player_id := _get_local_state_player_id()
	if force_switch_flow.is_player_trapped_outside_force_switch(local_state_player_id):
		current_action_panel.set_message("Cannot switch right now!")
		return false

	if not pokemon_data.is_empty():
		return force_switch_flow.can_switch_to_pokemon_data(pokemon_data, local_state_player_id)

	return force_switch_flow.can_switch_to_slot(visual_slot, local_state_player_id)

func _get_party_grid_selected_pokemon_data(visual_slot: int) -> Dictionary:
	if player_party_grid != null and player_party_grid.has_method("get_pokemon_data_for_visual_slot"):
		return player_party_grid.get_pokemon_data_for_visual_slot(visual_slot)

	return {}

func _get_canonical_switch_submit_slot(visual_slot: int, pokemon_data: Dictionary) -> int:
	if _is_pvp_battle() and not pokemon_data.is_empty():
		var resolved_slot := _resolve_pvp_selected_local_party_slot(visual_slot, pokemon_data)
		if resolved_slot > 0:
			return resolved_slot

	var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	if canonical_slot > 0:
		return canonical_slot

	if _is_pvp_battle() and not pokemon_data.is_empty():
		push_warning(
			"PvP switch selection has no canonical party slot; falling back to visual slot %d pokemonKey=%s" % [
				visual_slot,
				str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))),
			]
		)

	return visual_slot

func _get_canonical_lead_submit_slot(visual_slot: int, pokemon_data: Dictionary) -> int:
	if _is_pvp_battle() and not pokemon_data.is_empty():
		var resolved_slot := _resolve_pvp_selected_local_party_slot(visual_slot, pokemon_data)
		if resolved_slot > 0:
			return resolved_slot

	var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	if canonical_slot > 0:
		return canonical_slot

	if _is_pvp_battle() and not pokemon_data.is_empty():
		push_warning(
			"PvP lead selection has no canonical party slot; falling back to visual slot %d pokemonKey=%s partySlot=%s metadataSlot=%s" % [
				visual_slot,
				str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))),
				str(pokemon_data.get("partySlot", pokemon_data.get("party_slot", ""))),
				str(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", ""))),
			]
		)

	return visual_slot

func _resolve_pvp_selected_local_party_slot(visual_slot: int, pokemon_data: Dictionary) -> int:
	var local_state_player_id := _get_local_state_player_id()
	var metadata_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
	if metadata_slot > 0:
		var metadata_team_pokemon := _get_team_pokemon_data_for_canonical_party_slot(local_state_player_id, metadata_slot)
		if not metadata_team_pokemon.is_empty() and _selected_pokemon_matches_team_pokemon(pokemon_data, metadata_team_pokemon):
			return metadata_slot

	var selected_instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", ""))).strip_edges()
	if selected_instance_id != "":
		var instance_slot := _find_local_party_slot_by_instance_id(local_state_player_id, selected_instance_id, pokemon_data)
		if instance_slot > 0:
			_log_pvp_slot_resolution_correction("instance", visual_slot, metadata_slot, instance_slot, pokemon_data)
			return instance_slot

	var species_slot := _find_unique_local_party_slot_by_species(local_state_player_id, pokemon_data)
	if species_slot > 0:
		_log_pvp_slot_resolution_correction("species", visual_slot, metadata_slot, species_slot, pokemon_data)
		return species_slot

	if metadata_slot > 0:
		_log_pvp_slot_resolution_correction("metadata-fallback", visual_slot, metadata_slot, metadata_slot, pokemon_data)
		return metadata_slot

	return -1

func _selected_pokemon_matches_team_pokemon(selected_data: Dictionary, team_data: Dictionary) -> bool:
	if team_data.is_empty():
		return false

	var selected_species := _get_pokemon_data_compare_species(selected_data)
	var team_species := _get_pokemon_data_compare_species(team_data)
	if selected_species != "" and team_species != "" and selected_species != team_species:
		return false

	var selected_instance_id := str(selected_data.get("instanceId", selected_data.get("instance_id", ""))).strip_edges()
	var team_instance_id := str(team_data.get("instanceId", team_data.get("instance_id", ""))).strip_edges()
	if selected_instance_id != "" and team_instance_id != "":
		return selected_instance_id == team_instance_id

	return selected_species != "" and selected_species == team_species

func _find_local_party_slot_by_instance_id(player_id: String, instance_id: String, selected_data: Dictionary = {}) -> int:
	var selected_species := _get_pokemon_data_compare_species(selected_data)
	var team := battle_state.get_player_team(player_id)
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var team_instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", ""))).strip_edges()
		if team_instance_id != instance_id:
			continue

		var team_species := _get_pokemon_data_compare_species(pokemon_data)
		if selected_species != "" and team_species != "" and selected_species != team_species:
			continue

		var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
		return canonical_slot if canonical_slot > 0 else index + 1

	return -1

func _find_unique_local_party_slot_by_species(player_id: String, selected_data: Dictionary) -> int:
	var selected_species := _get_pokemon_data_compare_species(selected_data)
	if selected_species == "":
		return -1

	var matched_slot := -1
	var team := battle_state.get_player_team(player_id)
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _get_pokemon_data_compare_species(pokemon_data) != selected_species:
			continue

		if matched_slot > 0:
			return -1

		var canonical_slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
		matched_slot = canonical_slot if canonical_slot > 0 else index + 1

	return matched_slot

func _get_pokemon_data_compare_species(pokemon_data: Dictionary) -> String:
	if pokemon_data.is_empty():
		return ""

	var species := battle_state.get_species_from_pokemon_data(pokemon_data) if battle_state != null else ""
	if species == "":
		species = str(pokemon_data.get("displaySpecies", pokemon_data.get("species", pokemon_data.get("details", "")))).strip_edges()
	if species.contains(","):
		species = species.split(",")[0].strip_edges()
	return _normalize_species_for_compare(species)

func _log_pvp_slot_resolution_correction(
	reason: String,
	visual_slot: int,
	metadata_slot: int,
	resolved_slot: int,
	pokemon_data: Dictionary
) -> void:
	pass

func _get_pokemon_data_canonical_party_slot(pokemon_data: Dictionary) -> int:
	var party_slot := _get_positive_slot_from_pokemon_data(pokemon_data, ["partySlot", "party_slot"])
	if party_slot > 0:
		return party_slot

	var metadata_slot := _get_positive_slot_from_pokemon_data(pokemon_data, ["metadataSlot", "metadata_slot"])
	if metadata_slot > 0:
		return metadata_slot

	return _get_pokemon_key_canonical_party_slot(pokemon_data)

func _get_pokemon_key_canonical_party_slot(pokemon_data: Dictionary) -> int:
	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	var slot_marker := ":slot:"
	if pokemon_key.contains(slot_marker):
		var slot_text := pokemon_key.split(slot_marker)[1]
		var key_slot := _safe_int(slot_text, -1)
		if key_slot > 0:
			return key_slot

	return -1

func _get_positive_slot_from_pokemon_data(pokemon_data: Dictionary, keys: Array) -> int:
	for key in keys:
		if not pokemon_data.has(key):
			continue

		var parsed_slot := _safe_int(pokemon_data.get(key), -1)
		if parsed_slot > 0:
			return parsed_slot

	return -1

func _can_choose_lead_slot(slot: int, pokemon_data: Dictionary = {}) -> bool:
	var team := battle_state.get_player_team("p1")
	if slot < 1 or slot > team.size():
		return false

	if not pokemon_data.is_empty() and not _is_pokemon_data_usable_for_lead(pokemon_data):
		return false

	var team_pokemon := _get_team_pokemon_data_for_canonical_party_slot("p1", slot)
	if team_pokemon.is_empty():
		return false

	return _is_pokemon_data_usable_for_lead(team_pokemon)

func _get_team_pokemon_data_for_canonical_party_slot(player_id: String, canonical_slot: int) -> Dictionary:
	if canonical_slot <= 0:
		return {}

	var team := battle_state.get_player_team(player_id)
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _get_pokemon_data_canonical_party_slot(pokemon_data) == canonical_slot:
			return pokemon_data

	var fallback_index := canonical_slot - 1
	if fallback_index >= 0 and fallback_index < team.size():
		var fallback_value: Variant = team[fallback_index]
		if fallback_value is Dictionary:
			return fallback_value as Dictionary

	return {}

func _is_pokemon_data_usable_for_lead(pokemon_data: Dictionary) -> bool:
	if bool(pokemon_data.get("fainted", false)):
		return false

	var condition := str(pokemon_data.get("condition", "")).strip_edges().to_lower()
	if condition == "0 fnt" or condition.ends_with(" fnt"):
		return false

	var hp_value: Variant = pokemon_data.get("hp", pokemon_data.get("currentHp", pokemon_data.get("current_hp", null)))
	if hp_value != null and _safe_int(hp_value, -1) == 0:
		return false

	return true

func _update_active_sprites(context := "sprite_refresh") -> void:
	_update_active_sprite_box("p1", player_sprite_box, "back", context)
	_update_active_sprite_box("p2", enemy_sprite_box, "front", context)
	_update_stat_stage_panels()

func _update_active_sprite_box(player_id: String, sprite_box: Node, side: String, context := "sprite_refresh") -> void:
	if _active_field_slot_is_empty(player_id, context) or _should_hide_active_pokemon_for_force_switch(player_id):
		if sprite_box.has_method("clear_pokemon"):
			sprite_box.call("clear_pokemon")
		return

	_set_single_pokemon_species_with_pvp_warning(
		sprite_box,
		_get_active_display_species(player_id),
		side,
		_get_active_pokemon_is_shiny(player_id),
		context
	)

func _active_field_slot_is_empty(player_id: String, context := "sprite_refresh") -> bool:
	if defer_force_switch_active_hide and context != "force_switch_transition":
		return false
	return battle_state.is_active_pokemon_fainted(player_id)

func _should_hide_active_pokemon_for_force_switch(player_id: String) -> bool:
	return force_switch_flow.should_hide_active_pokemon(player_id, defer_force_switch_active_hide)

func _update_battle_presentation(sprite_context := "sprite_refresh") -> void:
	_update_battle_status_panels()
	_update_hud_panels()
	_update_active_sprites(sprite_context)
	_update_move_slots()
	_update_party_slots()
	_update_vs_panel_names()
	_update_mechanic_button_states()
	_refresh_damage_calc_results()

func _update_battle_presentation_before_event_render(events: Array) -> void:
	_debug_battle_presentation_order("pre_event_presentation.begin switch_like=%s events=%s" % [
		str(_events_have_switch_like_event(events)),
		JSON.stringify(_summarize_events_for_order_debug(events)),
	])
	if not _events_have_switch_like_event(events):
		_update_battle_status_panels()
		_update_active_sprites()
		_update_move_slots()
		_update_vs_panel_names()
		_update_mechanic_button_states()
		_refresh_damage_calc_results()
		_debug_battle_presentation_order("pre_event_presentation.end no_switch_like")
		return

	_update_battle_status_panels()
	_update_move_slots()
	_update_vs_panel_names()
	_update_mechanic_button_states()
	_refresh_damage_calc_results()
	_debug_battle_presentation_order("pre_event_presentation.end switch_like")

func _update_vs_panel_names() -> void:
	if vs_panel_container != null:
		vs_panel_container.set_names(_get_vs_player_name("p1"), _get_vs_player_name("p2"))

func _get_vs_player_name(player_id: String) -> String:
	if player_id == "p1":
		var player_name: String = _get_player_display_name("p1")
		if player_name == "" or player_name == "Player":
			player_name = PlayerSave.player_name
		return player_name

	if battle_type == BattleType.WILD:
		var wild_species: String = _get_active_display_species("p2")
		if wild_species != "":
			return "Wild %s" % wild_species

	return _get_player_display_name(player_id)

func _get_active_display_species(player_id: String) -> String:
	var display_species := display_data_presenter.get_active_display_species(player_id)
	if _is_pvp_battle() and player_id == _get_local_state_player_id():
		var active_pokemon := battle_state.get_active_player_pokemon(player_id)
		var ident_species := _get_species_from_battle_ident(str(active_pokemon.get("ident", "")))
		if ident_species != "":
			var display_compare := _normalize_species_for_compare(display_species)
			var ident_compare := _normalize_species_for_compare(ident_species)
			if display_compare == "" or (display_compare != ident_compare and not _is_specific_battle_form_species(display_species)):
				return ident_species
	return display_species

func _is_specific_battle_form_species(species: String) -> bool:
	var normalized := species.strip_edges().to_lower().replace(" ", "-").replace("_", "-")
	if normalized.contains("mega") or normalized.ends_with("-primal"):
		return true

	for suffix in [
		"-alola", "-galar", "-hisui", "-paldea",
		"-therian", "-incarnate", "-origin", "-altered",
		"-wash", "-heat", "-frost", "-fan", "-mow",
		"-sky", "-land", "-blade", "-shield",
	]:
		if normalized.ends_with(suffix):
			return true

	return false

func _get_active_pokemon_is_shiny(player_id: String) -> bool:
	return display_data_presenter.get_active_pokemon_is_shiny(player_id)

func _get_display_team_data(player_id: String) -> Array:
	var display_team := display_data_presenter.get_display_team_data(player_id)
	if _is_pvp_battle() and player_id == _get_local_state_player_id():
		return _normalize_pvp_local_display_team_slots(display_team)
	return display_team

func _normalize_pvp_local_display_team_slots(display_team: Array) -> Array:
	if display_team.is_empty():
		return display_team

	var normalized_team: Array = []
	for index in range(display_team.size()):
		var pokemon_value: Variant = display_team[index]
		if not (pokemon_value is Dictionary):
			normalized_team.append(pokemon_value)
			continue

		var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate(true)
		_repair_pvp_local_display_species_from_ident(pokemon_data)
		var resolved_slot := _resolve_pvp_selected_local_party_slot(index + 1, pokemon_data)
		if resolved_slot > 0:
			pokemon_data["partySlot"] = resolved_slot
			pokemon_data["metadataSlot"] = resolved_slot
			pokemon_data["pokemonKey"] = "%s:slot:%d" % [_get_local_state_player_id(), resolved_slot]
		normalized_team.append(pokemon_data)

	return _sort_pokemon_display_team_by_canonical_slot(normalized_team)

func _repair_pvp_local_display_species_from_ident(pokemon_data: Dictionary) -> void:
	var ident_species := _get_species_from_battle_ident(str(pokemon_data.get("ident", "")))
	if ident_species == "":
		return

	var payload_species := _get_pokemon_data_compare_species(pokemon_data)
	var ident_compare_species := _normalize_species_for_compare(ident_species)
	if payload_species != "" and payload_species == ident_compare_species:
		return
	if _is_specific_battle_form_species(str(pokemon_data.get("displaySpecies", pokemon_data.get("species", "")))):
		return

	pokemon_data["species"] = ident_species
	pokemon_data["displaySpecies"] = ident_species

func _get_species_from_battle_ident(ident: String) -> String:
	var cleaned := ident.strip_edges()
	if not cleaned.contains(": "):
		return ""

	return str(cleaned.split(": ")[1]).strip_edges()

func _sort_pokemon_display_team_by_canonical_slot(display_team: Array) -> Array:
	if display_team.size() <= 1:
		return display_team

	var by_slot: Dictionary = {}
	for pokemon_value: Variant in display_team:
		if not (pokemon_value is Dictionary):
			return display_team

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var slot := _get_pokemon_data_canonical_party_slot(pokemon_data)
		if slot <= 0 or by_slot.has(slot):
			return display_team

		by_slot[slot] = pokemon_data

	var sorted_slots: Array = by_slot.keys()
	sorted_slots.sort()
	var sorted_team: Array = []
	for slot_value: Variant in sorted_slots:
		sorted_team.append(by_slot[slot_value])
	return sorted_team

func _get_display_pokemon_data(player_id: String, pokemon_data: Dictionary) -> Dictionary:
	return display_data_presenter.get_display_pokemon_data(player_id, pokemon_data)

func _get_player_display_name(player_id: String) -> String:
	var player_data: Dictionary = battle_state.players.get(player_id, {})
	var player_name := str(player_data.get("name", ""))

	if player_name != "":
		return player_name
	if player_id == "p1":
		return "Player"

	return "Opponent"

func _try_select_move(slot: int) -> void:
	_focus_battle_ui_layer()
	if current_action_panel_mode == BattleActionsPanelMode.CALC:
		return

	if not battle_actions_ready:
		return

	if battle_finished or battle_input_locked:
		return

	if current_action_view != ActionView.MOVES:
		return

	var moves := battle_state.get_available_moves()
	if slot < 1 or slot > moves.size():
		return

	var move_data: Dictionary = moves[slot - 1]
	if bool(move_data.get("disabled", false)):
		return

	_on_moves_grid_move_selected(slot)

func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit
