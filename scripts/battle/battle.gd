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
var defer_force_switch_active_hide := false

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
var current_move_hover_rect := Rect2()
const OPPONENT_RESPONSE_HOLD_SECONDS := 0.65
const DEBUG_BATTLE_HP_EVENTS := false
const DEBUG_BATTLE_MOVE_EVENTS := false
const DEBUG_SIDE_CONDITION_EFFECTS := false

#Active Pokemon
var active_player_pokemon: Pokemon
var active_enemy_pokemon: Pokemon

# Action Buttons
@onready var action_buttons = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/ActionChoices
@onready var moves_grid: MovesGrid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/MovesGrid
@onready var party_grid: PartyGrid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/PartyGrid
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
@onready var pokemon_hover_card: Control = $PokemonHoverCard
@onready var move_hover_card: Control = $MoveHoverCard

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

# HTTP Request
@onready var battle_request: HTTPRequest = $BattleRequest
@onready var pokemon_info_request: HTTPRequest = $PokemonInfoRequest
@onready var pokemon_stats_request: HTTPRequest = $PokemonStatsRequest

## Verbindt de UI-signals en zet de battle UI in de beginstand.
func _ready() -> void:
	action_buttons.action_selected.connect(_on_action_selected)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	hover_state.setup(pokemon_info_request, pokemon_stats_request)
	setup_flow.setup(event_text_formatter)
	_connect_pokemon_hover_signals()
	_connect_hud_team_hover_signals()
	_connect_move_hover_signals()
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
	animation_router.setup(player_sprite_box, enemy_sprite_box)
	event_renderer.setup(
		battle_log_panel,
		current_action_panel,
		animation_router,
		message_timing,
		self,
		Callable(self, "_set_active_hud_hp_from_event")
	)
	_disable_unimplemented_mechanics()
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

func _process(delta: float) -> void:
	if hover_state.should_poll_sprite_hover():
		_update_sprite_hover()
	if pokemon_hover_card.visible:
		_position_pokemon_hover_card()
	if move_hover_card.visible:
		_position_move_hover_card()
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

func _disable_unimplemented_mechanics() -> void:
	for button in mechanic_buttons:
		button.disabled = true
		button.modulate = Color(0.45, 0.45, 0.45, 0.65)
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		button.tooltip_text = "Not implemented yet"

func _unhandled_input(event: InputEvent) -> void:
	if _is_ui_typing():
		return

	if event.is_action_pressed("battle_run"):
		_try_run()
		return

	if event.is_action_pressed("battle_move_1"):
		_try_select_move(1)
		return
	if event.is_action_pressed("battle_move_2"):
		_try_select_move(2)
		return
	if event.is_action_pressed("battle_move_3"):
		_try_select_move(3)
		return
	if event.is_action_pressed("battle_move_4"):
		_try_select_move(4)
		return

## Handelt de gekozen hoofdactie af.
func _on_action_selected(action: String) -> void:
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

## Toont de move keuzes in het action panel.
func _show_moves() -> void:
	action_buttons.set_action_disabled("fight", false)
	action_buttons.set_action_disabled("bag", false)
	action_buttons.set_action_disabled("run", false)
	current_action_view = ActionView.MOVES
	moves_grid.visible = true
	party_grid.visible = false
	action_buttons.set_selected_action("fight")
	_show_current_action_prompt()

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


## Toont de party keuzes in het action panel.
func _show_party(force_switch := false) -> void:
	if not force_switch and force_switch_flow.is_player_trapped_outside_force_switch("p1"):
		current_action_panel.set_message("Cannot switch right now!")
		_show_moves()
		return

	action_buttons.set_action_disabled("fight", force_switch)
	action_buttons.set_action_disabled("bag", force_switch)
	action_buttons.set_action_disabled("run", force_switch)
	current_action_view = ActionView.PARTY
	moves_grid.visible = false
	party_grid.visible = true
	action_buttons.set_selected_action("party")

## Zet de UI in bag-modus.
func _open_bag() -> void:
	current_action_view = ActionView.BAG
	moves_grid.visible = false
	party_grid.visible = false

## Probeert de battle te verlaten.
func _try_run() -> void:
	if battle_finished or battle_input_locked or force_switch_flow.player_needs_force_switch("p1"):
		return

	battle_log_panel.add_message("Got away safely!")
	_finish_battle({"reason": "flee"})

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
	PlayerSave.apply_battle_team_state(battle_state.get_player_team("p1"))
	battle_ended.emit(result)

## Laadt een API-response in de battle state en geeft terug of dat gelukt is.
func _apply_api_response(response: Dictionary) -> bool:
	return action_flow.apply_response(response)

func _sync_player_save_from_battle_state() -> void:
	var player_team := battle_state.get_player_team("p1")
	if player_team.is_empty():
		return

	PlayerSave.apply_battle_team_state(player_team)

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
		)
		return

	hud_panel.set_pokemon_data(
		_get_active_display_species(player_id),
		battle_state.get_active_pokemon_level(player_id),
		battle_state.get_active_pokemon_current_hp(player_id),
		battle_state.get_active_pokemon_max_hp(player_id),
		battle_state.get_active_pokemon_status(player_id),
		battle_state.get_active_pokemon_gender(player_id),
	)

## Reset de battle status UI naar een lege beginstand.
func _reset_battle_status_panel() -> void:
	battle_status_panel.reset_status()
	field_timers_panel.reset_timers()
	_update_side_condition_ui()

func _reset_battle_effect_tracking() -> void:
	public_confirmed_abilities_by_ident.clear()
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

	var player_species := _get_active_display_species("p1")
	var opponent_species := _get_active_display_species("p2")

	_add_battle_log_messages(setup_flow.get_wild_battle_start_messages(player_species, opponent_species))
	await _render_initial_battle_events(api_response)

func setup_trainer_battle_from_response(player_pokemon: Pokemon, trainer_data: Dictionary, api_response: Dictionary) -> void:
	_prepare_battle_setup(BattleType.TRAINER, player_pokemon, null)
	display_data_presenter.set_trainer_team(api_response.get("trainerTeam", []))

	if not _apply_initial_battle_response(api_response):
		return

	var player_species := _get_active_display_species("p1")
	var opponent_species := _get_active_display_species("p2")
	_add_battle_log_messages(setup_flow.get_trainer_battle_start_messages(
		player_species,
		opponent_species,
		trainer_data,
		_get_player_display_name("p2")
	))
	await _render_initial_battle_events(api_response)

func _prepare_battle_setup(type: BattleType, player_pokemon: Pokemon, enemy_pokemon: Pokemon) -> void:
	battle_type = type
	active_player_pokemon = player_pokemon
	active_enemy_pokemon = enemy_pokemon
	display_data_presenter.set_battle_context(type, active_enemy_pokemon)
	_reset_battle_effect_tracking()
	player_hud_panel.clear_player_name()
	enemy_hud_panel.clear_player_name()

func _apply_initial_battle_response(api_response: Dictionary) -> bool:
	if not _apply_api_response(api_response):
		return false

	_update_battle_presentation()
	_show_moves()
	_show_current_action_prompt()
	return true

func _render_initial_battle_events(api_response: Dictionary) -> void:
	event_renderer.add_turn_header(battle_state.get_turn())
	await _render_battle_events(_get_wild_battle_start_events(api_response.get("events", [])), false)
	_show_current_action_prompt()

func _add_battle_log_messages(messages: Array[String]) -> void:
	for message in messages:
		if message == "":
			continue

		battle_log_panel.add_message(message)




## Stuurt de gekozen player move door en laat de backend de NPC-keuze verwerken.
func _on_moves_grid_move_selected(slot: int) -> void:
	if battle_input_locked:
		return

	_hide_move_hover()
	_set_battle_input_locked(true)
	moves_grid.visible = false
	var player_response: Dictionary = await _submit_player_choice("move", slot)

	if not player_response.get("success", false):
		_show_moves()
		_set_battle_input_locked(false)
		return

	if not await _submit_npc_choice_and_render():
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
	event_presentation.reset_recent_context()

	for event in events:
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		var presentation: Dictionary = event_presentation.build(event_data)
		var turn := int(presentation.get("turn", 0))
		if turn > 0:
			if render_turn_headers:
				event_renderer.add_turn_header(turn)
			continue

		await event_renderer.render_event(event_data, presentation)

	_update_hud_panels()
	_update_party_slots()
	_update_vs_panel_names()
	_sync_player_save_from_battle_state()

func _get_wild_battle_start_events(events: Array) -> Array:
	var start_events: Array = []

	for event in events:
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		match str(event_data.get("type", "")):
			"fieldEffect", "pokemonEffect", "ability", "statChange":
				start_events.append(event_data)

	return start_events

func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"

	if ident.begins_with("p2"):
		return "p2"

	return ""

func _set_active_hud_hp_from_event(target_ident: String, event: Dictionary, use_previous_hp: bool) -> void:
	var player_id := _get_player_id_from_ident(target_ident)
	if player_id == "":
		return

	var hp_data: Dictionary = hp_event_helper.get_event_hp_snapshot(event, use_previous_hp)
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

	match player_id:
		"p1":
			player_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender)
		"p2":
			enemy_hud_panel.set_pokemon_data(species, level, hp, max_hp, status, gender)

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
	if battle_input_locked:
		return

	if not _can_switch_to_slot(slot):
		return

	_set_battle_input_locked(true)
	var was_force_switch := force_switch_flow.player_needs_force_switch("p1")
	party_grid.visible = false

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

func _submit_player_choice(choice_type: String, slot: int) -> Dictionary:
	return await action_flow.submit_player_choice(choice_type, slot)

func _auto_force_switch_opponent_if_needed() -> bool:
	if not force_switch_flow.opponent_needs_auto_force_switch():
		return false

	return await _submit_npc_choice_and_render()

func _submit_npc_choice_and_render() -> bool:
	var opponent_response: Dictionary = await action_flow.submit_npc_choice("p2")

	if not bool(opponent_response.get("success", false)):
		return false

	await _render_opponent_response(opponent_response)
	await _hold_opponent_response_message()
	return true

func _render_opponent_response(opponent_response: Dictionary) -> void:
	defer_force_switch_active_hide = true
	_update_battle_presentation()
	defer_force_switch_active_hide = false
	var opponent_events: Array = opponent_response.get("events", [])
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

func _update_active_sprites() -> void:
	_update_active_sprite_box("p1", player_sprite_box, "back")
	_update_active_sprite_box("p2", enemy_sprite_box, "front")

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
