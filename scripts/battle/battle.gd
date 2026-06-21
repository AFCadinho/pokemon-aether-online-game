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

var battle_type: BattleType = BattleType.WILD
var current_action_view: ActionView = ActionView.NONE
var battle_finished := false
var battle_input_locked := false
var battle_actions_ready := false
var queued_battle_action: Dictionary = {}
var defer_force_switch_active_hide := false
var team_preview_lead_selection_active := false
var forfeit_return_action_view: ActionView = ActionView.NONE
var mega_evolution_selected := false
var mega_evolution_pulse_tween: Tween
var pending_mega_species_by_ident: Dictionary = {}

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
var public_confirmed_abilities_by_ident := {}
var stat_stages_by_ident: Dictionary = {}
var ability_stat_modifiers_by_ident: Dictionary = {}
var player_party_moves_by_key: Dictionary = {}
var current_move_hover_rect := Rect2()
var current_party_hover_rect := Rect2()
const OPPONENT_RESPONSE_HOLD_SECONDS := 0.65
const DEBUG_BATTLE_HP_EVENTS := false
const DEBUG_BATTLE_MOVE_EVENTS := false
const DEBUG_SIDE_CONDITION_EFFECTS := false
const SHINY_ENTRANCE_EFFECT_KEY := "shiny_sparkle"
const INITIAL_TRANSFORM_REVEAL_SECONDS := 0.8
const STAT_STAGE_BADGE_BOOST_COLOR := Color(0.3882353, 0.83137256, 0.44313726, 1.0)
const STAT_STAGE_BADGE_DROP_COLOR := Color(0.9372549, 0.26666668, 0.26666668, 1.0)
const STAT_STAGE_BADGE_LINE_MODIFIER := "modifier"

#Active Pokemon
var active_player_pokemon: Pokemon
var active_enemy_pokemon: Pokemon

# Action Buttons
@onready var action_buttons = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/ActionChoices
@onready var moves_grid: MovesGrid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/MovesGrid
@onready var party_grid: PartyGrid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/PartyGrid
@onready var mega_evolution_button: TextureButton = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/MechanicsPanel/MarginContainer/MechanicsButtons/MegaEvolutionIcon
@onready var mechanic_buttons: Array[TextureButton] = [
	$HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/MechanicsPanel/MarginContainer/MechanicsButtons/MegaEvolutionIcon,
	$HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/MechanicsPanel/MarginContainer/MechanicsButtons/Terra,
	$HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/MechanicsPanel/MarginContainer/MechanicsButtons/ZMove,
]

# Battle Log
@onready var battle_log_panel: BattleLogPanel = $BattleLogPanel
@onready var battle_log_toggle_button: Button = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattleLogButton

# Battle Sprites
@onready var player_battle_platform: Control = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattlePlatform
@onready var enemy_battle_platform: Control = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattlePlatform2
@onready var enemy_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/EnemySpriteBox
@onready var player_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/PlayerSpriteBox
@onready var enemy_team_preview_layer = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/EnemyTeamPreviewLayer
@onready var player_team_preview_layer = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/PlayerTeamPreviewLayer
@onready var pokemon_hover_card: Control = $PokemonHoverCard
@onready var move_hover_card: Control = $MoveHoverCard
@onready var party_hover_card: Control = $PartyHoverCard

# Pokemon HUD
@onready var player_hud_panel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/PlayerHudPanel
@onready var enemy_hud_panel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/EnemyHudPanel

# Turn Nodes
@onready var battle_status_panel: BattleStatusPanel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattleStatusPanel
@onready var vs_player_1_label: Label = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/VSPanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Player1") as Label
@onready var vs_player_2_label: Label = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/VSPanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Player2") as Label
@onready var player_side_effects_panel: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/SideFieldEffectsPanel") as Control
@onready var enemy_side_effects_panel: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/SideFieldEffectsPanel2") as Control
@onready var weather_particles: GPUParticles2D = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/GPUParticles2D") as GPUParticles2D
@onready var weather_tint: ColorRect = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherTint") as ColorRect
@onready var terrain_tint: ColorRect = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/TerrainTint") as ColorRect
@onready var sun_rays: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/SunRays") as Control
@onready var sun_sparkles: GPUParticles2D = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/SunSparkles") as GPUParticles2D
@onready var sandstorm_particles: GPUParticles2D = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/SandstormParticles") as GPUParticles2D
@onready var sandstorm_swirls: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/SandstormSwirls") as Control
@onready var grassy_terrain_layer: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/GrassyTerrainLayer") as Control
@onready var misty_terrain_layer: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/MistyTerrainLayer") as Control
@onready var psychic_terrain_layer: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/PsychicTerrainLayer") as Control
@onready var trick_room_layer: Control = get_node_or_null("HBoxContainer/BattleFrame/MarginContainer/BattleArena/WeatherLayer/TrickRoomLayer") as Control

@onready var field_timers_panel: FieldTimersPanel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/FieldTimers
@onready var current_action_panel: CurrentActionPanel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/CurrentActionPanel
@onready var forfeit_confirm_dialog: Control = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/ForfeitConfirmDialog

# HTTP Request
@onready var battle_request: HTTPRequest = $BattleRequest
@onready var pokemon_info_request: HTTPRequest = $PokemonInfoRequest
@onready var pokemon_stats_request: HTTPRequest = $PokemonStatsRequest

## Verbindt de UI-signals en zet de battle UI in de beginstand.
func _ready() -> void:
	action_buttons.action_selected.connect(_on_action_selected)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	hover_state.setup(pokemon_info_request, pokemon_stats_request)
	pokemon_hover_service.debug_enabled = DEBUG_BATTLE_MOVE_EVENTS
	setup_flow.setup(event_text_formatter)
	_connect_pokemon_hover_signals()
	_connect_hud_team_hover_signals()
	_connect_move_hover_signals()
	_connect_party_hover_signals()
	_connect_forfeit_confirm_dialog_signals()
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
	event_presentation.debug_enabled = DEBUG_BATTLE_MOVE_EVENTS
	animation_router.setup(player_sprite_box, enemy_sprite_box, player_sprite_box.get_parent())
	event_renderer.setup(
		battle_log_panel,
		current_action_panel,
		animation_router,
		message_timing,
		self,
		Callable(self, "_set_active_hud_hp_from_event")
	)
	_setup_mechanic_buttons()
	_update_battle_log_toggle_button()

	# Show Moves, Party or Bag
	_reset_action_choices()
	_reset_battle_effect_tracking()
	_reset_battle_status_panel()
	weather_presentation.update_weather("")
	weather_presentation.update_terrain("")
	weather_presentation.update_trick_room(false)
	current_action_panel.clear_message()
	battle_log_panel.clear_log()
	event_renderer.reset_battle_log_player_gap()

	if PlayerSave.party.is_empty():
		return

func _setup_weather_presentation() -> void:
	weather_presentation.setup(
		weather_particles,
		weather_tint,
		sun_rays,
		sun_sparkles,
		sandstorm_particles,
		sandstorm_swirls,
		terrain_tint,
		grassy_terrain_layer,
		misty_terrain_layer,
		psychic_terrain_layer,
		trick_room_layer
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
	_update_active_sprites()

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

func _connect_pokemon_hover_signals() -> void:
	if not player_sprite_box.has_method("get_single_sprite_slot"):
		return
	if not enemy_sprite_box.has_method("get_single_sprite_slot"):
		return

	var player_sprite_slot: Control = player_sprite_box.get_single_sprite_slot()
	player_sprite_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var enemy_sprite_slot: Control = enemy_sprite_box.get_single_sprite_slot()
	enemy_sprite_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _connect_hud_team_hover_signals() -> void:
	if player_hud_panel.has_signal("team_pokemon_hovered"):
		player_hud_panel.team_pokemon_hovered.connect(_show_hud_pokemon_hover)
	if player_hud_panel.has_signal("team_pokemon_unhovered"):
		player_hud_panel.team_pokemon_unhovered.connect(_hide_hud_pokemon_hover)
	if enemy_hud_panel.has_signal("team_pokemon_hovered"):
		enemy_hud_panel.team_pokemon_hovered.connect(_show_hud_pokemon_hover)
	if enemy_hud_panel.has_signal("team_pokemon_unhovered"):
		enemy_hud_panel.team_pokemon_unhovered.connect(_hide_hud_pokemon_hover)

func _connect_move_hover_signals() -> void:
	if moves_grid.has_signal("move_hovered"):
		moves_grid.move_hovered.connect(_show_move_hover)
	if moves_grid.has_signal("move_unhovered"):
		moves_grid.move_unhovered.connect(_hide_move_hover)

func _connect_party_hover_signals() -> void:
	if party_grid.has_signal("pokemon_hovered"):
		party_grid.pokemon_hovered.connect(_show_party_hover)
	if party_grid.has_signal("pokemon_unhovered"):
		party_grid.pokemon_unhovered.connect(_hide_party_hover)

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
	var stat_stages := _get_active_stat_stages_for_party_hover(display_data)
	if not stat_stages.is_empty():
		hover_data["statStages"] = stat_stages

	var moves: Array = _get_party_hover_moves(display_data, hover_data)
	if not moves.is_empty():
		hover_data["moves"] = moves

	return hover_data

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
		if not move_data.has("maxpp") and move_data.has("pp"):
			var max_pp: int = _calculate_max_pp(int(move_data.get("pp", 0)))
			move_data["maxpp"] = max_pp
			move_data["pp"] = max_pp

		normalized_moves.append(move_data)

	return normalized_moves

func _calculate_max_pp(base_pp: int) -> int:
	if base_pp <= 1:
		return max(base_pp, 0)

	return int(floor(float(base_pp) * 1.6))

func _get_player_save_pokemon_for_hover(pokemon_data: Dictionary) -> Pokemon:
	var instance_id := str(pokemon_data.get("instanceId", pokemon_data.get("instance_id", "")))
	if instance_id != "":
		for pokemon in PlayerSave.party:
			if pokemon.instance_id == instance_id:
				return pokemon

	var display_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	var normalized_display_species := _normalize_species_for_compare(display_species)
	if normalized_display_species == "":
		return null

	for pokemon in PlayerSave.party:
		if _normalize_species_for_compare(pokemon.species) == normalized_display_species:
			return pokemon

	return null

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
	var request_token: int = hover_state.begin_hover_request()
	var hover_data: Dictionary = await pokemon_hover_service.get_hover_card_data(
		battle_state,
		pokemon_info_request,
		pokemon_stats_request,
		request_pokemon_data,
		public_confirmed_abilities_by_ident
	)
	if not hover_state.is_hover_request_current(request_token, hover_ident, hover_owner_player_id):
		return
	if not _hover_data_matches_pokemon_request(hover_data, request_pokemon_data):
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
	var display_species := battle_state.get_species_from_pokemon_data(request_pokemon_data)
	if display_species != "":
		display_data["species"] = display_species
		display_data["displaySpecies"] = display_species

	if pokemon_hover_card.has_method("show_for_pokemon"):
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

	var requested_species := str(hover_data.get("requested_species", ""))
	var current_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	if requested_species == "" or current_species == "":
		return true

	return _normalize_species_for_compare(requested_species) == _normalize_species_for_compare(current_species)

func _normalize_species_for_compare(species: String) -> String:
	return species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")

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
	for button in mechanic_buttons:
		button.disabled = true
		button.modulate = Color(0.45, 0.45, 0.45, 0.65)
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		button.tooltip_text = "Not implemented yet"
	if mega_evolution_button != null:
		mega_evolution_button.pressed.connect(_on_mega_evolution_pressed)
		mega_evolution_button.tooltip_text = "Mega Evolution"
	_update_mechanic_button_states()

func _on_mega_evolution_pressed() -> void:
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
	return (
		battle_actions_ready
		and not battle_input_locked
		and not battle_finished
		and not team_preview_lead_selection_active
		and not force_switch_flow.player_needs_force_switch("p1")
		and battle_state.can_active_pokemon_mega_evolve("p1")
	)

func _update_mechanic_button_states() -> void:
	if mega_evolution_button == null:
		return

	var can_use_mega := _can_toggle_mega_evolution()
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
		mega_evolution_button.modulate = Color(1.0, 0.82, 0.2, 1.0)
		mega_evolution_button.tooltip_text = "Mega Evolution ready"
		_start_mega_evolution_pulse()
	else:
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

func _unhandled_input(event: InputEvent) -> void:
	if _is_ui_typing():
		return

	if event.is_action_pressed("battle_run"):
		if not battle_actions_ready:
			_queue_battle_action("run")
			return

		_try_run()
		return

	if event.is_action_pressed("battle_move_1"):
		if not battle_actions_ready:
			_queue_battle_action("move", 1)
			return

		_try_select_move(1)
		return
	if event.is_action_pressed("battle_move_2"):
		if not battle_actions_ready:
			_queue_battle_action("move", 2)
			return

		_try_select_move(2)
		return
	if event.is_action_pressed("battle_move_3"):
		if not battle_actions_ready:
			_queue_battle_action("move", 3)
			return

		_try_select_move(3)
		return
	if event.is_action_pressed("battle_move_4"):
		if not battle_actions_ready:
			_queue_battle_action("move", 4)
			return

		_try_select_move(4)
		return

## Handelt de gekozen hoofdactie af.
func _on_action_selected(action: String) -> void:
	if not battle_actions_ready and not team_preview_lead_selection_active:
		if action == "run":
			_queue_battle_action("run")
		return

	if battle_input_locked:
		return

	if action == "fight":
		_show_moves()
	elif action == "bag":
		_open_bag()
	elif action == "party":
		_show_party()
	elif action == "run":
		_try_run()

## Klapt de battle log open of dicht.
func _on_battle_log_toggle_pressed() -> void:
	battle_log_panel.toggle_log()
	_update_battle_log_toggle_button()

## Zet de tekst van de battle log toggle op basis van de open/dicht state.
func _update_battle_log_toggle_button() -> void:
	if battle_log_panel.is_open():
		battle_log_toggle_button.text = ">"
	else:
		battle_log_toggle_button.text = "<"

## Verbergt alle action views en reset de geselecteerde action state.
func _reset_action_choices() -> void:
	current_action_view = ActionView.NONE
	moves_grid.visible = false
	party_grid.visible = false
	_hide_party_hover()
	_clear_mega_evolution_selection()
	_update_mechanic_button_states()

## Toont de move keuzes in het action panel.
func _show_moves() -> void:
	action_buttons.set_action_disabled("fight", false)
	action_buttons.set_action_disabled("bag", false)
	action_buttons.set_action_disabled("run", false)
	current_action_view = ActionView.MOVES
	moves_grid.visible = true
	party_grid.visible = false
	_hide_party_hover()
	action_buttons.set_selected_action("fight")
	_show_current_action_prompt()
	_update_mechanic_button_states()

func _show_current_action_prompt() -> void:
	var player_species: String = _get_active_display_species("p1")
	current_action_panel.set_message(event_text_formatter.format_action_prompt(player_species))

func _set_battle_input_locked(is_locked: bool) -> void:
	battle_input_locked = is_locked
	if action_buttons.has_method("set_all_actions_disabled"):
		action_buttons.set_all_actions_disabled(is_locked)
	if moves_grid.has_method("set_input_disabled"):
		moves_grid.set_input_disabled(is_locked)
	if party_grid.has_method("set_input_disabled"):
		party_grid.set_input_disabled(is_locked)
	_update_mechanic_button_states()

func _set_battle_actions_ready(is_ready: bool) -> void:
	battle_actions_ready = is_ready
	_update_mechanic_button_states()
	if battle_actions_ready:
		_process_queued_battle_action()

func _queue_battle_action(action_type: String, slot := 0) -> void:
	if team_preview_lead_selection_active or battle_finished:
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
	if not force_switch and force_switch_flow.is_player_trapped_outside_force_switch("p1"):
		current_action_panel.set_message("Cannot switch right now!")
		_show_moves()
		return

	_clear_mega_evolution_selection()
	action_buttons.set_action_disabled("fight", force_switch)
	action_buttons.set_action_disabled("bag", force_switch)
	action_buttons.set_action_disabled("run", force_switch)
	current_action_view = ActionView.PARTY
	_update_party_slots()
	moves_grid.visible = false
	party_grid.visible = true
	action_buttons.set_selected_action("party")
	_update_mechanic_button_states()

## Zet de UI in bag-modus.
func _open_bag() -> void:
	_clear_mega_evolution_selection()
	current_action_view = ActionView.BAG
	moves_grid.visible = false
	party_grid.visible = false
	_hide_party_hover()
	_update_mechanic_button_states()

## Probeert de battle te verlaten.
func _try_run() -> void:
	if not battle_actions_ready:
		return

	if team_preview_lead_selection_active:
		return

	if battle_finished or battle_input_locked or force_switch_flow.player_needs_force_switch("p1"):
		return

	if battle_type != BattleType.WILD:
		_clear_mega_evolution_selection()
		_show_forfeit_confirm_dialog()
		return

	_clear_mega_evolution_selection()
	battle_log_panel.add_message("Got away safely!")
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
	battle_log_panel.add_message("You forfeited the battle.")
	_finish_battle({"reason": "forfeit"})

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

## Vult de party slots met de huidige player party.
func _update_party_slots() -> void:
	party_grid.set_party(_get_display_team_data("p1"))

func _finish_battle(result: Dictionary) -> void:
	if battle_finished:
		return

	battle_finished = true
	pending_mega_species_by_ident.clear()
	_sync_player_save_from_battle_state()
	PlayerPartyStateService.save_current_battle_party_state_deferred()
	battle_ended.emit(result)

## Laadt een API-response in de battle state en geeft terug of dat gelukt is.
func _apply_api_response(response: Dictionary, apply_event_conditions: bool = true) -> bool:
	var success: bool = action_flow.apply_response(response, apply_event_conditions)
	if success:
		_apply_party_state_from_api_response(response)
		_remember_active_player_party_moves()
		_prewarm_current_battle_move_animations()

	return success

func _apply_party_state_from_api_response(response: Dictionary) -> void:
	if not response.has("party"):
		return

	var party_value: Variant = response.get("party")
	if party_value is Array:
		var party_data: Array = party_value as Array
		if not party_data.is_empty():
			PlayerSave.replace_party_from_state(party_data)

func _prewarm_current_battle_move_animations() -> void:
	var move_names: Array[String] = []
	_append_available_move_names(move_names, "p1")
	_append_available_move_names(move_names, "p2")
	_append_team_move_names(move_names, battle_state.get_player_team("p1"))
	_append_team_move_names(move_names, battle_state.get_player_team("p2"))
	_append_saved_party_move_names(move_names)

	animation_router.prewarm_move_animations(move_names)

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
		if str(event_data.get("type", "")) == "switch" and not effect_keys.has(SHINY_ENTRANCE_EFFECT_KEY):
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

## Werkt de player en opponent HUD panels bij vanuit de battle state.
func _update_hud_panels() -> void:
	_update_active_hud_panel("p1", player_hud_panel)
	_update_active_hud_panel("p2", enemy_hud_panel)

	player_hud_panel.set_team_data(_get_display_team_data("p1"))
	enemy_hud_panel.set_team_data(_get_display_team_data("p2"))

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
	)

## Reset de battle status UI naar een lege beginstand.
func _reset_battle_status_panel() -> void:
	battle_status_panel.reset_status()
	field_timers_panel.reset_timers()
	_update_side_condition_ui()

func _reset_battle_effect_tracking() -> void:
	public_confirmed_abilities_by_ident.clear()
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
		var ability: String = _get_public_confirmed_ability_from_event(event)
		if ability == "":
			continue

		var ident: String = _get_public_confirmed_ability_ident_from_event(event)
		var ident_key: String = _normalize_battle_ident(ident)
		if ident_key == "":
			continue

		public_confirmed_abilities_by_ident[ident_key] = ability

func _remember_battle_modifier_event(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"switch":
			_clear_stat_stages_for_ident(str(event.get("fromIdent", "")))
			_clear_stat_stages_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))
			_clear_ability_stat_modifier_for_ident(str(event.get("fromIdent", "")))
			_clear_ability_stat_modifier_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))
		"faint":
			_clear_stat_stages_for_ident(str(event.get("target", "")))
			_clear_ability_stat_modifier_for_ident(str(event.get("target", "")))
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
	var new_stage: int = mini(maxi(current_stage + int(event.get("amount", 0)), -6), 6)
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

	return badges

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

func _get_public_confirmed_ability_from_event(event: Dictionary) -> String:
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

## Werkt turn en field timer status bij vanuit de battle state.
func _update_battle_status_panels() -> void:
	battle_status_panel.set_turn(battle_state.get_turn())
	battle_status_panel.hide_timer()
	var field_effects := battle_state.get_field_effects()
	field_timers_panel.set_effects(field_effects, battle_state.get_turn())
	_update_side_condition_ui()
	weather_presentation.update_weather(_get_active_weather_effect_id(field_effects))
	weather_presentation.update_terrain(_get_active_terrain_effect_id(field_effects))
	weather_presentation.update_trick_room(_is_trick_room_active(field_effects))

func _update_side_condition_ui() -> void:
	var player_side_effects: Array = _get_side_condition_effects("p1")
	var enemy_side_effects: Array = _get_side_condition_effects("p2")
	side_condition_presentation.update(player_side_effects, enemy_side_effects, battle_state.get_turn())

func _get_side_condition_effects(side_id: String) -> Array:
	var side_effects: Array = []
	for effect_value in battle_state.get_field_effects():
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
			return str(effect_data.get("effectId", ""))

	return ""

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

func _update_battle_platform_hazards() -> void:
	_update_side_condition_ui()

## Initialiseert een wild battle vanuit een al gemaakte API battle response.
func setup_wild_battle_from_response(player_pokemon: Pokemon, enemy_pokemon: Pokemon, api_response: Dictionary) -> void:
	_prepare_battle_setup(BattleType.WILD, player_pokemon, enemy_pokemon)

	player_sprite_box.set_single_pokemon(player_pokemon, "back")
	enemy_sprite_box.set_single_pokemon(enemy_pokemon, "front")

	if not _apply_initial_battle_response(api_response):
		return

	var player_species := _get_original_active_player_species(player_pokemon.species)
	var opponent_species := _get_active_display_species("p2")

	_add_battle_log_messages(setup_flow.get_wild_battle_start_messages(player_species, opponent_species))
	_show_original_player_lead_before_initial_events(player_species)
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

	var player_species := _get_original_active_player_species(player_pokemon.species)
	var opponent_species := _get_active_display_species("p2")
	_add_battle_log_messages(setup_flow.get_trainer_battle_start_messages(
		player_species,
		opponent_species,
		trainer_data,
		_get_player_display_name("p2")
	))
	_show_original_player_lead_before_initial_events(player_species)
	await _render_initial_battle_events(lead_response)
	_show_battle_controls_after_initial_events()
	_set_battle_actions_ready(true)

func _prepare_battle_setup(type: BattleType, player_pokemon: Pokemon, enemy_pokemon: Pokemon) -> void:
	battle_type = type
	_set_battle_actions_ready(false)
	queued_battle_action.clear()
	active_player_pokemon = player_pokemon
	active_enemy_pokemon = enemy_pokemon
	display_data_presenter.set_battle_context(type, active_enemy_pokemon)
	_reset_battle_effect_tracking()
	pending_mega_species_by_ident.clear()
	animation_router.prewarm_effect_animations([SHINY_ENTRANCE_EFFECT_KEY])
	player_hud_panel.clear_player_name()
	enemy_hud_panel.clear_player_name()

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
	player_hud_panel.set_team_data(_get_display_team_data("p1"))
	enemy_hud_panel.set_team_data(_get_display_team_data("p2"))
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
		player_pokemon.shiny
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
	enemy_sprite_box.set_single_pokemon_species(species, "front", is_shiny)
	enemy_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)

func _render_initial_battle_events(api_response: Dictionary) -> void:
	event_renderer.add_turn_header(battle_state.get_turn())
	var start_events := _get_wild_battle_start_events(api_response.get("events", []))
	if _show_original_transform_targets_before_initial_events(start_events):
		await get_tree().process_frame
		await get_tree().create_timer(INITIAL_TRANSFORM_REVEAL_SECONDS).timeout
	else:
		await get_tree().process_frame
	await _play_initial_shiny_entrance_effects()
	await _render_battle_events(start_events, false)

func _show_battle_controls_after_initial_events() -> void:
	_update_battle_presentation()
	_show_moves()
	_show_current_action_prompt()

func _show_original_player_lead_before_initial_events(species: String) -> void:
	if species == "":
		return

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon("p1")
	var level: int = battle_state.get_active_pokemon_level("p1")
	var hp: int = battle_state.get_active_pokemon_current_hp("p1")
	var max_hp: int = max(battle_state.get_active_pokemon_max_hp("p1"), 1)
	var status: String = battle_state.get_active_pokemon_status("p1")
	var gender: String = battle_state.get_active_pokemon_gender("p1")
	var is_shiny := _get_saved_pokemon_shiny_for_active_data(active_pokemon)

	player_sprite_box.set_single_pokemon_species(species, "back", is_shiny)
	player_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)

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
		player_sprite_box.set_single_pokemon_species(species, "back", is_shiny)
		player_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)
	elif player_id == "p2":
		enemy_sprite_box.set_single_pokemon_species(species, "front", is_shiny)
		enemy_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)

func _get_original_active_player_species(fallback_species: String = "") -> String:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon("p1")
	var saved_pokemon := _get_saved_pokemon_for_active_data(active_pokemon)
	if saved_pokemon != null:
		return saved_pokemon.species

	var ident := str(active_pokemon.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return fallback_species

func _get_saved_pokemon_shiny_for_active_data(active_pokemon: Dictionary) -> bool:
	var saved_pokemon := _get_saved_pokemon_for_active_data(active_pokemon)
	if saved_pokemon == null:
		return false

	return saved_pokemon.shiny

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
	if not (battle_options_value is Dictionary):
		return false

	var battle_options: Dictionary = battle_options_value as Dictionary
	return bool(battle_options.get("teamPreview", false))

func _run_default_trainer_lead_selection() -> Dictionary:
	_set_battle_input_locked(true)
	var player_lead_response := await _submit_lead("p1", 1)
	if not bool(player_lead_response.get("success", false)):
		var error_message := str(player_lead_response.get("error", "Cannot choose player lead!"))
		current_action_panel.set_message(error_message)
		battle_log_panel.add_message(error_message)
		_set_battle_input_locked(false)
		return {}

	var npc_lead_response := await _submit_npc_lead()
	if not bool(npc_lead_response.get("success", false)):
		var error_message := str(npc_lead_response.get("error", "The trainer could not choose a lead!"))
		current_action_panel.set_message(error_message)
		battle_log_panel.add_message(error_message)
		_set_battle_input_locked(false)
		return {}

	_set_battle_input_locked(false)
	return npc_lead_response

func _run_trainer_team_preview_lead_selection() -> Dictionary:
	team_preview_lead_selection_active = true
	queued_battle_action.clear()
	_show_team_preview_layers()
	current_action_panel.set_message("Choose your Lead")
	current_action_view = ActionView.PARTY
	moves_grid.visible = false
	party_grid.set_party(_get_lead_selection_team_data("p1"))
	party_grid.visible = true
	action_buttons.set_action_disabled("fight", true)
	action_buttons.set_action_disabled("bag", true)
	action_buttons.set_action_disabled("run", true)
	action_buttons.set_selected_action("party")

	while team_preview_lead_selection_active:
		var selected_slot: int = int(await party_grid.party_selected)
		if not _can_choose_lead_slot(selected_slot):
			current_action_panel.set_message("Choose another Pokemon!")
			continue

		_set_battle_input_locked(true)
		var lead_response := await _submit_lead("p1", selected_slot)
		if not bool(lead_response.get("success", false)):
			var error_message := str(lead_response.get("error", "Cannot choose that lead!"))
			current_action_panel.set_message(error_message)
			battle_log_panel.add_message(error_message)
			_set_battle_input_locked(false)
			continue

		var npc_lead_response := await _submit_npc_lead()
		if not bool(npc_lead_response.get("success", false)):
			var error_message := str(npc_lead_response.get("error", "The trainer could not choose a lead!"))
			current_action_panel.set_message(error_message)
			battle_log_panel.add_message(error_message)
			_set_battle_input_locked(false)
			continue

		team_preview_lead_selection_active = false
		_hide_team_preview_layers()
		party_grid.visible = false
		_set_battle_input_locked(false)
		return npc_lead_response

	return {}

func _show_team_preview_layers() -> void:
	player_sprite_box.visible = false
	enemy_sprite_box.visible = false

	if player_team_preview_layer.has_method("show_team"):
		player_team_preview_layer.call("show_team", _get_display_team_data("p1"), "back")
	if enemy_team_preview_layer.has_method("show_team"):
		enemy_team_preview_layer.call("show_team", _get_display_team_data("p2"), "front")


func _hide_team_preview_layers() -> void:
	if player_team_preview_layer.has_method("clear"):
		player_team_preview_layer.call("clear")
	if enemy_team_preview_layer.has_method("clear"):
		enemy_team_preview_layer.call("clear")

	player_team_preview_layer.visible = false
	enemy_team_preview_layer.visible = false
	player_sprite_box.visible = true
	enemy_sprite_box.visible = true

func _get_lead_selection_team_data(player_id: String) -> Array:
	var lead_team: Array = []
	for pokemon_value in _get_display_team_data(player_id):
		if pokemon_value is Dictionary:
			var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate(true)
			pokemon_data["active"] = false
			lead_team.append(pokemon_data)
		else:
			lead_team.append(pokemon_value)

	return lead_team

func _add_battle_log_messages(messages: Array[String]) -> void:
	for message in messages:
		if message == "":
			continue

		battle_log_panel.add_message(message)




## Stuurt de gekozen player move door en laat de backend de NPC-keuze verwerken.
func _on_moves_grid_move_selected(slot: int) -> void:
	if battle_input_locked:
		return

	var use_mega := mega_evolution_selected
	var pending_player_choice_events: Array = _build_pending_player_mega_events(use_mega)
	_hide_move_hover()
	_set_battle_input_locked(true)
	moves_grid.visible = false
	_clear_mega_evolution_selection()
	var player_response: Dictionary = await _submit_player_choice("move", slot, use_mega)

	if not player_response.get("success", false):
		_clear_pending_mega_species_for_events(pending_player_choice_events)
		_show_moves()
		_set_battle_input_locked(false)
		return

	pending_player_choice_events = _get_pending_player_choice_events(player_response, pending_player_choice_events)
	if not await _submit_npc_choice_and_render({}, pending_player_choice_events):
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

	_set_battle_input_locked(false)
	_show_moves()

func _render_battle_events(events: Array, render_turn_headers := true) -> void:
	var ordered_events: Array = _order_form_change_events_before_moves(events)
	_prewarm_battle_event_animations(ordered_events)
	event_presentation.reset_recent_context()

	for event in ordered_events:
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		_remember_battle_modifier_event(event_data)

		var event_type: String = str(event_data.get("type", ""))
		if event_type == "mega":
			_fill_mega_event_species(event_data)
			battle_state.apply_event_conditions([event_data])
			_update_active_pokemon_presentation_for_ident(str(event_data.get("target", "")))
			_clear_pending_mega_species_for_event(event_data)

		var presentation: Dictionary = event_presentation.build(event_data)
		var turn := int(presentation.get("turn", 0))
		if turn > 0:
			if render_turn_headers:
				event_renderer.add_turn_header(turn)
			continue

		await event_renderer.render_event(event_data, presentation)
		if event_type == "damage" or event_type == "heal" or event_type == "faint":
			battle_state.apply_event_conditions([event_data])
		if event_type == "switch":
			battle_state.apply_event_conditions([event_data])
			_update_hud_panels()
			_update_active_sprites()
			await _play_shiny_entrance_if_needed(event_data)
		if event_type == "transform":
			battle_state.apply_event_conditions([event_data])
			_update_hud_panels()
			_update_active_sprites()

	_update_hud_panels()
	_update_party_slots()
	_update_vs_panel_names()
	_sync_player_save_from_battle_state()

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

	var target_ident := battle_state.get_active_pokemon_ident("p1")
	var mega_species := battle_state.resolve_active_mega_species("p1")
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
	var pending_events: Array = _get_pending_mega_events_from_response(response.get("events", []))
	if pending_events.is_empty():
		return fallback_events

	for event_value: Variant in pending_events:
		if event_value is Dictionary:
			var event_data: Dictionary = event_value as Dictionary
			_fill_mega_event_species(event_data)
			_remember_pending_mega_species(event_data)

	return pending_events

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

func _filter_already_rendered_events(events_value: Variant, rendered_event_keys: Dictionary) -> Array:
	var filtered_events: Array = []
	if not (events_value is Array):
		return filtered_events

	var events: Array = events_value as Array
	for event_value in events:
		if event_value is Dictionary:
			var event_data: Dictionary = event_value as Dictionary
			var event_key := _get_battle_event_key(event_data)
			if event_key != "" and rendered_event_keys.has(event_key):
				continue

		filtered_events.append(event_value)

	return filtered_events

func _get_battle_event_key(event_data: Dictionary) -> String:
	if str(event_data.get("type", "")) == "mega":
		return "mega|%s" % str(event_data.get("target", ""))

	return "%s|%s|%s|%s|%s" % [
		str(event_data.get("type", "")),
		str(event_data.get("target", "")),
		str(event_data.get("actor", "")),
		str(event_data.get("species", "")),
		str(event_data.get("to", "")),
	]

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
		if event_type != "mega":
			continue

		var target_ident: String = str(event_data.get("target", ""))
		if target_ident == actor_ident:
			return index
		if actor_player_id != "" and _get_player_id_from_ident(target_ident) == actor_player_id:
			return index

	return -1

func _get_wild_battle_start_events(events: Array) -> Array:
	var start_events: Array = []

	for event in events:
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		match str(event_data.get("type", "")):
			"fieldEffect", "pokemonEffect", "ability", "statChange", "transform", "mega":
				start_events.append(event_data)

	return start_events

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
	var species: String = _get_active_display_species(player_id)
	var level: int = battle_state.get_active_pokemon_level(player_id)
	var status: String = _get_status_from_event_or_state(event, player_id, use_previous_hp)
	var gender: String = battle_state.get_active_pokemon_gender(player_id)
	var is_shiny: bool = _get_active_pokemon_is_shiny(player_id)

	match player_id:
		"p1":
			player_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)
		"p2":
			enemy_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender, is_shiny)

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
	var player_team: Array = rewind_helper.get_rewound_team_data_for_events("p1", _get_display_team_data("p1"), events)
	if not player_team.is_empty():
		player_hud_panel.set_team_data(player_team)
		party_grid.set_party(player_team)

	var enemy_team: Array = rewind_helper.get_rewound_team_data_for_events("p2", _get_display_team_data("p2"), events)
	if not enemy_team.is_empty():
		enemy_hud_panel.set_team_data(enemy_team)

func _debug_battle_hp(message: String) -> void:
	if DEBUG_BATTLE_HP_EVENTS:
		print("[battle-hp] " + message)

func _debug_battle_move(message: String) -> void:
	if DEBUG_BATTLE_MOVE_EVENTS:
		print("[battle-move] " + message)

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
	if team_preview_lead_selection_active:
		return

	if battle_input_locked:
		return

	if not _can_switch_to_slot(slot):
		return

	_set_battle_input_locked(true)
	var was_force_switch := force_switch_flow.player_needs_force_switch("p1")
	party_grid.visible = false
	_hide_party_hover()

	var player_response: Dictionary = await _submit_player_choice("switch", slot)

	if not player_response.get("success", false):
		var error_message := str(player_response.get("error", "Cannot switch right now!"))
		current_action_panel.set_message(error_message)
		battle_log_panel.add_message(error_message)
		if was_force_switch:
			_show_party(true)
		else:
			_show_moves()
		_set_battle_input_locked(false)
		return

	_update_battle_presentation()

	if was_force_switch:
		var player_events: Array = player_response.get("events", [])
		_rewind_active_hud_hp_for_events(player_events)
		_rewind_party_slots_for_events(player_events)
		await _render_battle_events(player_events)

		if await _finish_if_battle_ended():
			return

		_show_moves()
		_set_battle_input_locked(false)
		return

	if not await _submit_npc_choice_and_render():
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

	_set_battle_input_locked(false)
	_show_moves()

func _show_force_switch_if_needed() -> bool:
	if not force_switch_flow.should_show_player_force_switch():
		return false

	current_action_panel.set_message("Choose a Pokemon!")
	_show_party(true)
	return true

func _finish_if_battle_ended() -> bool:
	if not battle_state.is_battle_ended():
		return false

	await get_tree().create_timer(0.25).timeout
	_finish_battle({
		"reason": "win",
		"winner": battle_state.get_winner()
	})
	return true

func _submit_player_choice(choice_type: String, slot: int, mega := false) -> Dictionary:
	return await action_flow.submit_player_choice(choice_type, slot, mega)

func _submit_lead(player_id: String, slot: int) -> Dictionary:
	var response: Dictionary = await BattleApiClient.choose_lead(
		battle_request,
		battle_state.battle_id,
		player_id,
		slot
	)
	if not bool(response.get("success", false)):
		return response

	if not _apply_api_response(response, false):
		return response

	return response

func _submit_npc_lead() -> Dictionary:
	var response: Dictionary = await BattleApiClient.send_npc_lead(
		battle_request,
		battle_state.battle_id,
		"p2"
	)
	if not bool(response.get("success", false)):
		return response

	if not _apply_api_response(response, false):
		return response

	return response

func _auto_force_switch_opponent_if_needed() -> bool:
	if not force_switch_flow.opponent_needs_auto_force_switch():
		return false

	return await _submit_npc_choice_and_render()

func _submit_npc_choice_and_render(
	rendered_event_keys: Dictionary = {},
	pending_player_choice_events: Array = []
) -> bool:
	var opponent_response: Dictionary = await action_flow.submit_npc_choice("p2")

	if not bool(opponent_response.get("success", false)):
		return false

	await _render_opponent_response(opponent_response, rendered_event_keys, pending_player_choice_events)
	await _hold_opponent_response_message()
	return true

func _render_opponent_response(
	opponent_response: Dictionary,
	rendered_event_keys: Dictionary = {},
	pending_player_choice_events: Array = []
) -> void:
	defer_force_switch_active_hide = true
	_update_battle_presentation()
	defer_force_switch_active_hide = false
	var filtered_events: Array = _filter_already_rendered_events(opponent_response.get("events", []), rendered_event_keys)
	var opponent_events: Array = _merge_pending_player_choice_events(pending_player_choice_events, filtered_events)
	_rewind_active_hud_hp_for_events(opponent_events)
	_rewind_party_slots_for_events(opponent_events)
	await _render_battle_events(opponent_events)
	_update_active_sprites()

func _hold_opponent_response_message() -> void:
	await get_tree().create_timer(OPPONENT_RESPONSE_HOLD_SECONDS).timeout

func _can_switch_to_slot(slot: int) -> bool:
	if force_switch_flow.is_player_trapped_outside_force_switch("p1"):
		current_action_panel.set_message("Cannot switch right now!")
		return false

	return force_switch_flow.can_switch_to_slot(slot, "p1")

func _can_choose_lead_slot(slot: int) -> bool:
	var team := battle_state.get_player_team("p1")
	if slot < 1 or slot > team.size():
		return false

	var pokemon_value: Variant = team[slot - 1]
	if not (pokemon_value is Dictionary):
		return false

	var pokemon_data: Dictionary = pokemon_value as Dictionary
	if bool(pokemon_data.get("fainted", false)):
		return false

	var condition := str(pokemon_data.get("condition", "")).strip_edges().to_lower()
	return condition != "0 fnt" and not condition.ends_with(" fnt")

func _update_active_sprites() -> void:
	_update_active_sprite_box("p1", player_sprite_box, "back")
	_update_active_sprite_box("p2", enemy_sprite_box, "front")
	_update_stat_stage_panels()

func _update_active_sprite_box(player_id: String, sprite_box: Node, side: String) -> void:
	if _should_hide_active_pokemon_for_force_switch(player_id):
		if sprite_box.has_method("clear_pokemon"):
			sprite_box.call("clear_pokemon")
		return

	sprite_box.set_single_pokemon_species(
		_get_active_display_species(player_id),
		side,
		_get_active_pokemon_is_shiny(player_id)
	)

func _should_hide_active_pokemon_for_force_switch(player_id: String) -> bool:
	return force_switch_flow.should_hide_active_pokemon(player_id, defer_force_switch_active_hide)

func _update_battle_presentation() -> void:
	_update_battle_status_panels()
	_update_hud_panels()
	_update_active_sprites()
	_update_move_slots()
	_update_party_slots()
	_update_vs_panel_names()
	_update_mechanic_button_states()

func _update_vs_panel_names() -> void:
	if vs_player_1_label != null:
		vs_player_1_label.text = _get_vs_player_name("p1")
	if vs_player_2_label != null:
		vs_player_2_label.text = _get_vs_player_name("p2")

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
	return display_data_presenter.get_active_display_species(player_id)

func _get_active_pokemon_is_shiny(player_id: String) -> bool:
	return display_data_presenter.get_active_pokemon_is_shiny(player_id)

func _get_display_team_data(player_id: String) -> Array:
	return display_data_presenter.get_display_team_data(player_id)

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
