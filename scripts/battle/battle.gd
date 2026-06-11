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
var event_text_formatter := preload("res://scripts/battle/battle_event_text_formatter.gd").new()
var weather_presentation := preload("res://scripts/battle/battle_weather_presentation.gd").new()
var side_condition_presentation := preload("res://scripts/battle/battle_side_condition_presentation.gd").new()
var side_condition_tracker := preload("res://scripts/battle/battle_side_condition_tracker.gd").new()
var field_effect_tracker := preload("res://scripts/battle/battle_field_effect_tracker.gd").new()
var hp_event_helper := preload("res://scripts/battle/battle_hp_event_helper.gd").new()
var event_condition_helper := preload("res://scripts/battle/battle_event_condition_helper.gd").new()
var rewind_helper := preload("res://scripts/battle/battle_rewind_helper.gd").new()
var animation_router := preload("res://scripts/battle/battle_animation_router.gd").new()
var last_battle_log_player_id := ""
var active_residual_pokemon_effects := {}
var public_confirmed_abilities_by_ident := {}
var current_sprite_hover_player_id := ""
var pokemon_hover_request_token := 0
var is_hud_slot_hover_active := false
var current_hover_pokemon_ident := ""
var current_move_hover_rect := Rect2()
const MOVE_EVENT_HOLD_SECONDS := 0.35
const DAMAGE_EVENT_HOLD_SECONDS := 0.25
const STAT_CHANGE_EVENT_HOLD_SECONDS := 0.85
const BATTLE_MESSAGE_HOLD_SECONDS := 0.35
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
	_connect_pokemon_hover_signals()
	_connect_hud_team_hover_signals()
	_connect_move_hover_signals()
	_setup_weather_presentation()
	_setup_side_condition_presentation()
	animation_router.setup(player_sprite_box, enemy_sprite_box)
	event_condition_helper.debug_enabled = DEBUG_BATTLE_HP_EVENTS
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
	last_battle_log_player_id = ""
	active_residual_pokemon_effects.clear()

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
	side_condition_tracker.debug_enabled = DEBUG_SIDE_CONDITION_EFFECTS
	side_condition_presentation.setup(
		player_battle_platform,
		enemy_battle_platform,
		player_side_effects_panel,
		enemy_side_effects_panel
	)

func _process(delta: float) -> void:
	if not is_hud_slot_hover_active:
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
	if hovered_player_id == current_sprite_hover_player_id:
		return

	current_sprite_hover_player_id = hovered_player_id
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

	await _show_pokemon_hover(pokemon_data, player_id)

func _show_hud_pokemon_hover(pokemon_data: Dictionary) -> void:
	is_hud_slot_hover_active = true
	current_sprite_hover_player_id = ""
	current_hover_pokemon_ident = str(pokemon_data.get("ident", ""))
	await _show_pokemon_hover(pokemon_data, _get_player_id_from_ident(current_hover_pokemon_ident))

func _hide_hud_pokemon_hover() -> void:
	is_hud_slot_hover_active = false
	current_hover_pokemon_ident = ""
	_hide_pokemon_hover()

func _show_pokemon_hover(pokemon_data: Dictionary, hover_owner_player_id: String) -> void:
	var hover_ident: String = str(pokemon_data.get("ident", ""))
	pokemon_hover_request_token += 1
	var request_token: int = pokemon_hover_request_token
	pokemon_info_request.cancel_request()
	pokemon_stats_request.cancel_request()
	var hover_data: Dictionary = await pokemon_hover_service.get_hover_card_data(
		battle_state,
		pokemon_info_request,
		pokemon_stats_request,
		pokemon_data,
		public_confirmed_abilities_by_ident
	)
	if request_token != pokemon_hover_request_token:
		return
	if is_hud_slot_hover_active and current_hover_pokemon_ident != hover_ident:
		return
	if not is_hud_slot_hover_active and current_sprite_hover_player_id != hover_owner_player_id:
		return

	var confirmed_moves: Array = hover_data.get("confirmed_moves", [])
	var confirmed_item: String = str(hover_data.get("confirmed_item", ""))
	var confirmed_ability: String = str(hover_data.get("confirmed_ability", ""))
	var stat_changes: Dictionary = hover_data.get("stat_changes", {})
	var speed_data: Dictionary = hover_data.get("speed_data", {})
	_debug_battle_move("pokemon-info parsed player=%s moves=%s item=%s ability=%s statChanges=%s speed=%s info=%s" % [
		hover_owner_player_id,
		JSON.stringify(confirmed_moves),
		confirmed_item,
		confirmed_ability,
		JSON.stringify(stat_changes),
		JSON.stringify(speed_data),
		JSON.stringify(hover_data.get("pokemon_info", {})),
	])
	if pokemon_hover_card.has_method("show_for_pokemon"):
		pokemon_hover_card.call("show_for_pokemon", pokemon_data, confirmed_moves, confirmed_item, confirmed_ability, stat_changes, speed_data)
	_position_pokemon_hover_card()

func _hide_pokemon_hover() -> void:
	current_sprite_hover_player_id = ""
	current_hover_pokemon_ident = ""
	pokemon_hover_request_token += 1
	pokemon_info_request.cancel_request()
	pokemon_stats_request.cancel_request()
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
	if not force_switch and battle_state.is_active_trapped("p1"):
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
	if battle_finished or battle_input_locked or battle_state.needs_force_switch("p1"):
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
	if not response.get("success", false):
		print("Battle API failed: ", response)
		return false

	var previous_field_effect_keys: Dictionary = field_effect_tracker.get_known_keys()
	event_condition_helper.fill_missing_previous_event_conditions(response, battle_state)
	_remember_public_confirmed_abilities_from_response(response)
	field_effect_tracker.remember_start_turns_from_response(response)
	battle_state.load_from_api_response(response)
	side_condition_tracker.remember_from_field_snapshot(battle_state.get_field_effects())
	side_condition_tracker.remember_from_response(response)
	field_effect_tracker.queue_missing_start_events(battle_state.get_field_effects(), previous_field_effect_keys, battle_state.get_turn())
	field_effect_tracker.remember_current(battle_state.get_field_effects())
	return true

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
	enemy_hud_panel.set_team_data(battle_state.get_player_team("p2"))

func _update_active_hud_panel(player_id: String, hud_panel: Node) -> void:
	if _should_hide_active_pokemon_for_force_switch(player_id):
		if hud_panel.has_method("clear_active_pokemon_data"):
			hud_panel.call("clear_active_pokemon_data")
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
	field_effect_tracker.reset()
	public_confirmed_abilities_by_ident.clear()
	side_condition_tracker.reset()

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
	field_timers_panel.set_effects(field_effect_tracker.get_effects_with_started_turns(battle_state.get_field_effects()), battle_state.get_turn())
	_update_side_condition_ui()
	weather_presentation.update_weather(field_effect_tracker.get_active_weather_effect(battle_state.get_field_effects()))
	weather_presentation.update_terrain(field_effect_tracker.get_active_terrain_effect(battle_state.get_field_effects()))
	weather_presentation.update_trick_room(field_effect_tracker.is_trick_room_active(battle_state.get_field_effects()))

func _update_side_condition_ui() -> void:
	var player_side_effects: Array = side_condition_tracker.get_active_effects("p1", field_effect_tracker.get_started_turns())
	var enemy_side_effects: Array = side_condition_tracker.get_active_effects("p2", field_effect_tracker.get_started_turns())
	side_condition_presentation.update(player_side_effects, enemy_side_effects, battle_state.get_turn())

func _update_battle_platform_hazards() -> void:
	_update_side_condition_ui()

## Initialiseert een wild battle vanuit een al gemaakte API battle response.
func setup_wild_battle_from_response(player_pokemon: Pokemon, enemy_pokemon: Pokemon, api_response: Dictionary) -> void:
	battle_type = BattleType.WILD
	active_player_pokemon = player_pokemon
	active_enemy_pokemon = enemy_pokemon
	active_residual_pokemon_effects.clear()
	_reset_battle_effect_tracking()

	player_hud_panel.clear_player_name()
	enemy_hud_panel.clear_player_name()

	player_sprite_box.set_single_pokemon(player_pokemon, "back")
	enemy_sprite_box.set_single_pokemon(enemy_pokemon, "front")

	if not _apply_api_response(api_response):
		return

	_update_battle_status_panels()
	_update_hud_panels()
	_update_active_sprites()
	_update_move_slots()
	_update_party_slots()
	_update_vs_panel_names()
	_show_moves()

	var player_species := _get_active_display_species("p1")
	var opponent_species := _get_active_display_species("p2")

	_show_current_action_prompt()
	_add_battle_log_messages(event_text_formatter.format_wild_battle_start_messages(player_species, opponent_species))
	battle_log_panel.add_turn_header(battle_state.get_turn())
	last_battle_log_player_id = ""
	await _render_battle_events(_get_wild_battle_start_events(api_response.get("events", [])), false)
	_show_current_action_prompt()

func setup_trainer_battle_from_response(player_pokemon: Pokemon, trainer_data: Dictionary, api_response: Dictionary) -> void:
	battle_type = BattleType.TRAINER
	active_player_pokemon = player_pokemon
	active_enemy_pokemon = null
	active_residual_pokemon_effects.clear()
	_reset_battle_effect_tracking()

	player_hud_panel.clear_player_name()
	enemy_hud_panel.clear_player_name()

	if not _apply_api_response(api_response):
		return

	_update_battle_status_panels()
	_update_hud_panels()
	_update_active_sprites()
	_update_move_slots()
	_update_party_slots()
	_update_vs_panel_names()
	_show_moves()

	var player_species := _get_active_display_species("p1")
	var opponent_species := _get_active_display_species("p2")
	var trainer_name := str(trainer_data.get("name", _get_player_display_name("p2")))
	if trainer_name == "":
		trainer_name = "Trainer"

	_show_current_action_prompt()
	_add_battle_log_messages(event_text_formatter.format_trainer_battle_start_messages(
		player_species,
		opponent_species,
		trainer_name
	))
	battle_log_panel.add_turn_header(battle_state.get_turn())
	last_battle_log_player_id = ""
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
		print("Player choice failed: ", player_response)
		_show_moves()
		_set_battle_input_locked(false)
		return

	if not _apply_api_response(player_response):
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
	var recent_field_effect_source := ""
	var recent_ability_event := false
	var recent_move_event := false

	for event in events:
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		var event_type := str(event_data.get("type", ""))
		var pre_log_message := ""
		var log_message := ""
		var battle_message := ""
		var add_blank_after := false
		var suppress_player_gap := false
		var attack_actor_ident := ""
		var damage_target_ident := ""
		var heal_target_ident := ""
		var faint_target_ident := ""
		var stat_change_target_ident := ""
		var stat_change_amount: int = 0
		var ability_boost_target_ident := ""

		match event_type:
			"move":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = true
				attack_actor_ident = str(event_data.get("actor", ""))
				_debug_battle_move("move event actor=%s move=%s target=%s source=%s event=%s" % [
					attack_actor_ident,
					str(event_data.get("move", "")),
					str(event_data.get("target", "")),
					str(event_data.get("source", "")),
					JSON.stringify(event_data),
				])
				var actor := _format_battle_actor(str(event_data.get("actor", "")))
				var move_name := str(event_data.get("move", ""))
				pre_log_message = event_text_formatter.format_move_source_message(event_data, actor)
				if pre_log_message != "":
					battle_message = pre_log_message
					attack_actor_ident = ""
				else:
					log_message = event_text_formatter.format_move_event(actor, move_name)
					battle_message = log_message

			"switch":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				var player_id := str(event_data.get("playerId", ""))
				var from_name := str(event_data.get("from", ""))
				var to_name := str(event_data.get("to", ""))

				if to_name == "":
					to_name = _format_battle_actor(str(event_data.get("toIdent", "")), false)
				if to_name == "":
					to_name = _format_battle_actor(str(event_data.get("pokemon", "")), false)
				if to_name == "":
					to_name = "Pokemon"
				if player_id == "p1":
					log_message = event_text_formatter.format_player_switch_log_message(from_name, to_name)
					battle_message = event_text_formatter.format_player_switch_battle_message(from_name, to_name)
				else:
					var trainer_name := _get_player_display_name(player_id)
					log_message = event_text_formatter.format_opponent_switch_log_message(trainer_name, from_name, to_name)
					battle_message = event_text_formatter.format_opponent_switch_battle_message(trainer_name, to_name)
				add_blank_after = true

			"faint":
				recent_ability_event = false
				recent_move_event = false
				faint_target_ident = str(event_data.get("target", ""))
				var target := _format_battle_actor(faint_target_ident)
				log_message = event_text_formatter.format_faint_event(target)
				battle_message = ""
				add_blank_after = true

			"win":
				recent_ability_event = false
				recent_move_event = false
				var winner := str(event_data.get("winner", ""))
				log_message = event_text_formatter.format_win_event(winner)
				battle_message = log_message
				add_blank_after = true

			"fieldEffect":
				recent_ability_event = false
				recent_move_event = false
				_debug_battle_move("fieldEffect event effect=%s state=%s source=%s sourceTarget=%s event=%s" % [
					str(event_data.get("effect", "")),
					str(event_data.get("state", "")),
					str(event_data.get("source", "")),
					str(event_data.get("sourceTarget", "")),
					JSON.stringify(event_data),
				])
				log_message = event_text_formatter.format_field_effect_event(event_data)
				add_blank_after = log_message != ""
				recent_field_effect_source = str(event_data.get("effect", ""))
				_remove_pending_field_start_event(event_data)

			"pokemonEffect":
				recent_ability_event = false
				recent_move_event = false
				_track_pokemon_effect_event(event_data)
				log_message = event_text_formatter.format_pokemon_effect_event(event_data)
				add_blank_after = log_message != ""

			"ability":
				recent_field_effect_source = ""
				recent_move_event = false
				_debug_battle_move("ability event target=%s ability=%s effect=%s stat=%s source=%s event=%s" % [
					str(event_data.get("target", event_data.get("actor", ""))),
					str(event_data.get("ability", "")),
					str(event_data.get("effect", "")),
					str(event_data.get("stat", "")),
					str(event_data.get("source", "")),
					JSON.stringify(event_data),
				])
				log_message = event_text_formatter.format_ability_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""
				if event_text_formatter.is_ability_boost_event(event_data):
					ability_boost_target_ident = str(event_data.get("target", event_data.get("actor", "")))
				recent_ability_event = log_message != ""

			"statChange":
				recent_move_event = false
				stat_change_target_ident = str(event_data.get("target", ""))
				stat_change_amount = int(event_data.get("amount", 0))
				var is_ability_detail := recent_ability_event or event_text_formatter.is_stat_change_from_ability(event_data)
				log_message = event_text_formatter.format_stat_change_event(event_data, is_ability_detail)
				battle_message = event_text_formatter.format_stat_change_battle_message(event_data)
				add_blank_after = log_message != ""
				suppress_player_gap = is_ability_detail

			"status":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				_debug_battle_move("status event target=%s status=%s source=%s event=%s" % [
					str(event_data.get("target", event_data.get("pokemon", ""))),
					_get_first_event_text_value(event_data, ["status", "statusName", "condition"]),
					str(event_data.get("source", "")),
					JSON.stringify(event_data),
				])
				log_message = event_text_formatter.format_status_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""

			"fail":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				_debug_battle_move("fail event target=%s reason=%s source=%s event=%s" % [
					str(event_data.get("target", event_data.get("pokemon", ""))),
					str(event_data.get("reason", "")),
					str(event_data.get("source", "")),
					JSON.stringify(event_data),
				])
				log_message = event_text_formatter.format_fail_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""

			"cant":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				log_message = event_text_formatter.format_cant_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""

			"miss":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				log_message = event_text_formatter.format_miss_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""

			"effectiveness":
				recent_ability_event = false
				log_message = event_text_formatter.format_effectiveness_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""

			"turn":
				var turn := int(event_data.get("turn", 0))
				if render_turn_headers and turn > 0:
					battle_log_panel.add_turn_header(turn)
					last_battle_log_player_id = ""
					recent_ability_event = false
					recent_move_event = false

			"damage":
				recent_ability_event = false
				damage_target_ident = str(event_data.get("target", ""))
				_debug_battle_move("damage event target=%s previous_snapshot=%s final_snapshot=%s has_hp_loss=%s visible_change=%s event=%s" % [
					damage_target_ident,
					JSON.stringify(hp_event_helper.get_event_hp_snapshot(event_data, true)),
					JSON.stringify(hp_event_helper.get_event_hp_snapshot(event_data, false)),
					str(hp_event_helper.event_has_hp_loss(event_data)),
					str(hp_event_helper.get_event_visible_hp_change(event_data)),
					JSON.stringify(event_data),
				])
				var target := _format_battle_actor(damage_target_ident)
				var has_hp_loss: bool = hp_event_helper.event_has_hp_loss(event_data)
				var has_sub_percent_hp_loss: bool = hp_event_helper.event_has_sub_percent_hp_loss(event_data)
				var active_effect := ""
				if not recent_move_event:
					active_effect = _get_active_residual_pokemon_effect(damage_target_ident)
				var source_message := event_text_formatter.format_indirect_damage_message(
					event_data,
					target,
					recent_field_effect_source,
					active_effect,
					not recent_move_event
				)
				_debug_battle_move("damage formatted target=%s source=%s fallback_source=%s recent_move=%s source_message=%s has_hp_loss=%s sub_percent=%s" % [
					damage_target_ident,
					str(event_data.get("source", "")),
					recent_field_effect_source,
					str(recent_move_event),
					source_message,
					str(has_hp_loss),
					str(has_sub_percent_hp_loss),
				])

				if source_message != "" and (has_hp_loss or has_sub_percent_hp_loss):
					log_message = source_message
				else:
					log_message = event_text_formatter.format_direct_damage_message(
						target,
						hp_event_helper.get_event_visible_hp_change(event_data),
						has_hp_loss,
						has_sub_percent_hp_loss
					)
					if log_message == "":
						damage_target_ident = ""

				add_blank_after = log_message != ""
				recent_field_effect_source = ""
				recent_move_event = false

			"heal":
				recent_ability_event = false
				recent_move_event = false
				heal_target_ident = str(event_data.get("target", ""))
				event_condition_helper.fill_missing_leftovers_heal_snapshot(event_data, heal_target_ident, battle_state)
				var target := _format_battle_actor(heal_target_ident)
				var previous_hp := int(event_data.get("previousHp", 0))
				var hp := int(event_data.get("hp", 0))
				log_message = event_text_formatter.format_heal_event(
					event_data,
					target,
					previous_hp,
					hp,
					hp_event_helper.get_event_visible_hp_change(event_data)
				)
				battle_message = event_text_formatter.format_heal_battle_message(event_data, target, previous_hp, hp)

				add_blank_after = true
				recent_field_effect_source = ""
			_:
				recent_ability_event = false
				recent_move_event = false
				pass

		if pre_log_message != "":
			if not suppress_player_gap:
				_add_battle_log_player_gap(event_data)
			battle_log_panel.add_message(pre_log_message)

		if log_message != "":
			if not suppress_player_gap:
				_add_battle_log_player_gap(event_data)
			battle_log_panel.add_message(log_message)

		if add_blank_after:
			battle_log_panel.add_blank_line()

		if battle_message != "":
			current_action_panel.set_message(battle_message)

		if attack_actor_ident != "":
			await animation_router.play_attack_tween_for_actor(attack_actor_ident)
			await get_tree().create_timer(MOVE_EVENT_HOLD_SECONDS).timeout
		if damage_target_ident != "":
			_set_active_hud_hp_from_event(damage_target_ident, event_data, true)
			await animation_router.play_damage_tween_for_target(damage_target_ident)
			_set_active_hud_hp_from_event(damage_target_ident, event_data, false)
			await get_tree().create_timer(DAMAGE_EVENT_HOLD_SECONDS).timeout
		if heal_target_ident != "":
			_set_active_hud_hp_from_event(heal_target_ident, event_data, true)
			await animation_router.play_heal_tween_for_target(heal_target_ident)
			_set_active_hud_hp_from_event(heal_target_ident, event_data, false)
		if stat_change_target_ident != "":
			await animation_router.play_stat_change_tween_for_target(stat_change_target_ident, stat_change_amount)
			await get_tree().create_timer(STAT_CHANGE_EVENT_HOLD_SECONDS).timeout
		if ability_boost_target_ident != "":
			await animation_router.play_stat_change_tween_for_target(ability_boost_target_ident, 1)
			await get_tree().create_timer(STAT_CHANGE_EVENT_HOLD_SECONDS).timeout
		if faint_target_ident != "":
			await animation_router.play_faint_tween_for_target(faint_target_ident)
		if battle_message != "":
			await get_tree().create_timer(BATTLE_MESSAGE_HOLD_SECONDS).timeout

	_update_hud_panels()
	_update_party_slots()
	_update_vs_panel_names()
	_sync_player_save_from_battle_state()
	_render_pending_field_start_events()

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

func _add_battle_log_player_gap(event: Dictionary) -> void:
	var player_id := _get_battle_log_event_player_id(event)
	if player_id == "":
		return

	if last_battle_log_player_id != "" and last_battle_log_player_id != player_id:
		battle_log_panel.add_gap()

	last_battle_log_player_id = player_id

func _get_battle_log_event_player_id(event: Dictionary) -> String:
	var event_type := str(event.get("type", ""))
	match event_type:
		"switch":
			return str(event.get("playerId", ""))
		"move", "cant", "fail", "miss":
			return _get_player_id_from_ident(str(event.get("actor", "")))
		"ability":
			return _get_ability_event_player_id(event)
		"statChange":
			return _get_stat_change_event_player_id(event)
		"status":
			return _get_player_id_from_ident(str(event.get("target", event.get("pokemon", ""))))
		"pokemonEffect":
			return _get_pokemon_effect_event_player_id(event)
		"fieldEffect":
			return _get_field_effect_event_player_id(event)

	return ""

func _get_field_effect_event_player_id(event: Dictionary) -> String:
	var player_id := _get_player_id_from_ident(str(event.get("sourcePokemon", "")))
	if player_id != "":
		return player_id

	player_id = _get_player_id_from_ident(str(event.get("sourceTarget", "")))
	if player_id != "":
		return player_id

	return _get_player_id_from_ident(str(event.get("actor", "")))

func _get_ability_event_player_id(event: Dictionary) -> String:
	for key in ["target", "actor", "pokemon", "sourcePokemon", "sourceTarget"]:
		var player_id := _get_player_id_from_ident(str(event.get(str(key), "")))
		if player_id != "":
			return player_id

	return ""

func _get_stat_change_event_player_id(event: Dictionary) -> String:
	for key in ["target", "pokemon", "actor", "sourceTarget"]:
		var player_id := _get_player_id_from_ident(str(event.get(str(key), "")))
		if player_id != "":
			return player_id

	return ""

func _get_pokemon_effect_event_player_id(event: Dictionary) -> String:
	for key in ["target", "pokemon", "actor"]:
		var player_id := _get_player_id_from_ident(str(event.get(str(key), "")))
		if player_id != "":
			return player_id

	return ""

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
	var condition_key: String = "previousCondition" if use_previous_hp else "condition"
	var event_status: String = _get_status_from_condition(str(event.get(condition_key, "")))
	if event_status != "":
		return event_status

	return battle_state.get_active_pokemon_status(player_id)

func _get_status_from_condition(condition: String) -> String:
	var parts: PackedStringArray = condition.split(" ")
	for part in parts:
		var status: String = str(part).strip_edges().to_lower()
		match status:
			"psn", "tox", "brn", "par", "slp", "frz":
				return status

	return ""

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

func _remove_pending_field_start_event(event: Dictionary) -> void:
	field_effect_tracker.remove_pending_start_event(event)

func _render_pending_field_start_events() -> void:
	for event in field_effect_tracker.consume_pending_start_events():
		var log_message: String = event_text_formatter.format_field_effect_event(event)
		if log_message == "":
			continue

		_add_battle_log_player_gap(event)
		battle_log_panel.add_message(log_message)

func _track_pokemon_effect_event(event: Dictionary) -> void:
	var target_key := _get_pokemon_effect_target_key(event)
	var effect := event_text_formatter.format_pokemon_effect_name(str(event.get("effect", "")))
	if target_key == "" or not event_text_formatter.is_trapping_pokemon_effect(effect):
		return

	match str(event.get("state", "")).to_lower():
		"start", "activate":
			active_residual_pokemon_effects[target_key] = effect
		"end":
			active_residual_pokemon_effects.erase(target_key)

func _get_pokemon_effect_target_key(event: Dictionary) -> String:
	return _normalize_battle_ident(str(event.get("target", event.get("pokemon", ""))))

func _get_active_residual_pokemon_effect(target_ident: String) -> String:
	var target_key := _normalize_battle_ident(target_ident)
	if target_key == "":
		return ""

	return str(active_residual_pokemon_effects.get(target_key, ""))

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
	var was_force_switch := battle_state.needs_force_switch("p1")
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

	if not _apply_api_response(player_response):
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
	if not battle_state.needs_force_switch("p1") or battle_state.is_battle_ended():
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
	return await BattleApiClient.send_choice(
		battle_request,
		battle_state.battle_id,
		"p1",
		choice_type,
		slot
	)

func _auto_force_switch_opponent_if_needed() -> bool:
	if battle_state.is_battle_ended() or not battle_state.needs_force_switch("p2"):
		return false

	return await _submit_npc_choice_and_render()

func _submit_npc_choice_and_render() -> bool:
	var opponent_response: Dictionary = await _submit_npc_choice()

	if not bool(opponent_response.get("success", false)):
		print("NPC choice failed: ", opponent_response)
		return false

	if not _apply_api_response(opponent_response):
		return false

	await _render_opponent_response(opponent_response)
	await _hold_opponent_response_message()
	return true

func _submit_npc_choice() -> Dictionary:
	return await BattleApiClient.send_npc_choice(
		battle_request,
		battle_state.battle_id,
		"p2"
	)

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
	if battle_state.is_active_trapped("p1") and not battle_state.needs_force_switch("p1"):
		current_action_panel.set_message("Cannot switch right now!")
		return false

	var team := battle_state.get_player_team("p1")
	var index := slot - 1
	if index < 0 or index >= team.size():
		return false

	var pokemon_data = team[index]
	if not (pokemon_data is Dictionary):
		return false

	if bool(pokemon_data.get("active", false)):
		return false

	return not str(pokemon_data.get("condition", "")).contains("fnt")

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
	if defer_force_switch_active_hide:
		return false

	if not _is_active_pokemon_fainted(player_id):
		return false

	return battle_state.needs_force_switch(player_id) or battle_state.is_battle_ended()

func _is_active_pokemon_fainted(player_id: String) -> bool:
	return str(battle_state.get_active_pokemon_condition(player_id)).contains("fnt")

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
	if player_id == "p1":
		var active_pokemon := battle_state.get_active_player_pokemon(player_id)
		var instance_id := str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", "")))
		var saved_pokemon := _get_player_save_pokemon_by_instance_id(instance_id)
		if saved_pokemon != null and _saved_species_matches_battle_data(saved_pokemon, active_pokemon):
			return saved_pokemon.species

	return battle_state.get_active_pokemon_species(player_id)

func _get_active_pokemon_is_shiny(player_id: String) -> bool:
	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id)
	var instance_id: String = str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", "")))
	var saved_pokemon: Pokemon = _get_player_save_pokemon_by_instance_id(instance_id)
	if saved_pokemon != null and _saved_species_matches_battle_data(saved_pokemon, active_pokemon):
		return saved_pokemon.shiny

	if _pokemon_data_has_shiny_value(active_pokemon):
		return _get_pokemon_data_shiny_value(active_pokemon)

	if player_id == "p2" and battle_type == BattleType.WILD and active_enemy_pokemon != null:
		if _saved_species_matches_battle_data(active_enemy_pokemon, active_pokemon):
			return active_enemy_pokemon.shiny

	return false

func _pokemon_data_has_shiny_value(pokemon_data: Dictionary) -> bool:
	return pokemon_data.has("shiny") or pokemon_data.has("isShiny") or pokemon_data.has("is_shiny")

func _get_pokemon_data_shiny_value(pokemon_data: Dictionary) -> bool:
	for key in ["shiny", "isShiny", "is_shiny"]:
		if not pokemon_data.has(key):
			continue

		var value: Variant = pokemon_data.get(key)
		if value is bool:
			return bool(value)

		var text_value: String = str(value).strip_edges().to_lower()
		match text_value:
			"true", "yes", "1", "y":
				return true
			"false", "no", "0", "n":
				return false

	return false

func _get_display_team_data(player_id: String) -> Array:
	var team := battle_state.get_player_team(player_id)
	if player_id != "p1":
		return team

	var display_team: Array = []
	for pokemon_data in team:
		if not (pokemon_data is Dictionary):
			display_team.append(pokemon_data)
			continue

		var display_data: Dictionary = (pokemon_data as Dictionary).duplicate()
		var instance_id := str(display_data.get("instanceId", display_data.get("instance_id", "")))
		var saved_pokemon := _get_player_save_pokemon_by_instance_id(instance_id)
		if saved_pokemon != null and _saved_species_matches_battle_data(saved_pokemon, display_data):
			display_data["displaySpecies"] = saved_pokemon.species
			display_data["shiny"] = saved_pokemon.shiny

		display_team.append(display_data)

	return display_team

func _get_player_save_pokemon_by_instance_id(instance_id: String) -> Pokemon:
	if instance_id == "":
		return null

	for pokemon in PlayerSave.party:
		if pokemon.instance_id == instance_id:
			return pokemon

	return null

func _saved_species_matches_battle_data(saved_pokemon: Pokemon, pokemon_data: Dictionary) -> bool:
	var battle_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	if battle_species == "":
		return true

	return _normalize_species_for_compare(saved_pokemon.species) == _normalize_species_for_compare(battle_species)

func _normalize_species_for_compare(species: String) -> String:
	return species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")

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
