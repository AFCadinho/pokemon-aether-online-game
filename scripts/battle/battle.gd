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

#Battle State
var battle_state := BattleState.new()
var known_field_effect_keys := {}
var field_effect_started_turns := {}
var active_side_condition_effects: Dictionary = {
	"p1": {},
	"p2": {},
}
var previous_side_condition_effects_before_response: Dictionary = {
	"p1": {},
	"p2": {},
}
var pending_field_start_events: Array[Dictionary] = []
var last_battle_log_player_id := ""
var active_residual_pokemon_effects := {}
var public_confirmed_abilities_by_ident := {}
var current_sprite_hover_player_id := ""
var pokemon_hover_request_token := 0
var is_hud_slot_hover_active := false
var current_hover_pokemon_ident := ""
var pokemon_stats_cache: Dictionary = {}
var current_move_hover_rect := Rect2()
var sun_weather_time := 0.0
var sandstorm_weather_time := 0.0
var grassy_terrain_time := 0.0
var trick_room_time := 0.0
var active_terrain_effect := ""

const MOVE_EVENT_HOLD_SECONDS := 0.35
const DAMAGE_EVENT_HOLD_SECONDS := 0.25
const STAT_CHANGE_EVENT_HOLD_SECONDS := 0.85
const BATTLE_MESSAGE_HOLD_SECONDS := 0.35
const DEBUG_BATTLE_HP_EVENTS := true
const DEBUG_BATTLE_MOVE_EVENTS := true
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
	_disable_unimplemented_mechanics()
	_update_battle_log_toggle_button()

	# Show Moves, Party or Bag
	_reset_action_choices()
	_reset_battle_effect_tracking()
	_reset_battle_status_panel()
	_update_weather_particles("")
	_update_terrain_effects("")
	_update_trick_room_effect(false)
	current_action_panel.clear_message()
	battle_log_panel.clear_log()
	last_battle_log_player_id = ""
	active_residual_pokemon_effects.clear()

	if PlayerSave.party.is_empty():
		return

func _process(delta: float) -> void:
	if not is_hud_slot_hover_active:
		_update_sprite_hover()
	if pokemon_hover_card.visible:
		_position_pokemon_hover_card()
	if move_hover_card.visible:
		_position_move_hover_card()
	if sun_rays != null and sun_rays.visible:
		_animate_sun_weather(delta)
	if sandstorm_swirls != null and sandstorm_swirls.visible:
		_animate_sandstorm_weather(delta)
	if terrain_tint != null and terrain_tint.visible:
		_animate_terrain_effects(delta)
	if trick_room_layer != null and trick_room_layer.visible:
		_animate_trick_room_effect(delta)

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
	await _show_pokemon_hover(pokemon_data, _get_player_id_from_pokemon_data(pokemon_data))

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
	var pokemon_info: Dictionary = await _fetch_hover_pokemon_info(pokemon_data)
	if request_token != pokemon_hover_request_token:
		return
	var pokemon_stats: Dictionary = await _fetch_hover_pokemon_stats(pokemon_data)
	if request_token != pokemon_hover_request_token:
		return
	if is_hud_slot_hover_active and current_hover_pokemon_ident != hover_ident:
		return
	if not is_hud_slot_hover_active and current_sprite_hover_player_id != hover_owner_player_id:
		return

	var confirmed_moves: Array = _get_confirmed_info_moves(pokemon_info)
	var confirmed_item: String = _get_optional_known_info_string(pokemon_info, "confirmedItem")
	var confirmed_ability: String = _get_confirmed_ability_for_hover(pokemon_info, pokemon_data)
	var stat_changes: Dictionary = _get_confirmed_info_stat_changes(pokemon_info)
	var speed_data: Dictionary = _get_hover_speed_data(pokemon_stats)
	_debug_battle_move("pokemon-info parsed player=%s moves=%s item=%s ability=%s statChanges=%s speed=%s info=%s" % [
		hover_owner_player_id,
		JSON.stringify(confirmed_moves),
		confirmed_item,
		confirmed_ability,
		JSON.stringify(stat_changes),
		JSON.stringify(speed_data),
		JSON.stringify(pokemon_info),
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

func _fetch_hover_pokemon_info(pokemon_data: Dictionary) -> Dictionary:
	var battle_id: String = battle_state.battle_id
	var ident: String = str(pokemon_data.get("ident", ""))
	if battle_id == "" or ident == "":
		_debug_battle_move("pokemon-info skipped battle_id=%s ident=%s pokemon=%s" % [
			battle_id,
			ident,
			JSON.stringify(pokemon_data),
		])
		return {}

	var viewer_id: String = _get_hover_known_info_viewer_id(ident)
	if viewer_id == "":
		return {}

	_debug_battle_move("pokemon-info request viewerId=%s ident=%s battleId=%s" % [viewer_id, ident, battle_id])
	var response: Dictionary = await BattleApiClient.get_pokemon_info(
		pokemon_info_request,
		battle_id,
		viewer_id,
		ident
	)
	_debug_battle_move("pokemon-info response=%s" % JSON.stringify(response))
	if not bool(response.get("success", false)):
		return {}

	var pokemon_value: Variant = response.get("pokemon", {})
	if pokemon_value is Dictionary:
		return pokemon_value

	return {}

func _fetch_hover_pokemon_stats(pokemon_data: Dictionary) -> Dictionary:
	var species: String = battle_state.get_species_from_pokemon_data(pokemon_data)
	var level: int = _get_level_from_pokemon_data(pokemon_data)
	if species == "" or level <= 0:
		return {}

	var cache_key: String = "%s|%s" % [species.to_lower(), level]
	var cached_value: Variant = pokemon_stats_cache.get(cache_key, {})
	if cached_value is Dictionary and not cached_value.is_empty():
		return cached_value as Dictionary

	_debug_battle_move("pokemon-stats request species=%s level=%s" % [species, str(level)])
	var response: Dictionary = await PokemonDataApiClient.get_pokemon_stats(
		pokemon_stats_request,
		species,
		level
	)
	_debug_battle_move("pokemon-stats response=%s" % JSON.stringify(response))
	if not bool(response.get("success", false)):
		return {}

	var pokemon_value: Variant = response.get("pokemon", {})
	if pokemon_value is Dictionary:
		var pokemon_stats: Dictionary = pokemon_value as Dictionary
		pokemon_stats_cache[cache_key] = pokemon_stats
		return pokemon_stats

	return {}

func _get_level_from_pokemon_data(pokemon_data: Dictionary) -> int:
	var level_value: Variant = pokemon_data.get("level", null)
	if level_value != null:
		return int(level_value)

	var details: String = str(pokemon_data.get("details", ""))
	for part in details.split(","):
		var trimmed: String = str(part).strip_edges()
		if trimmed.begins_with("L"):
			return int(trimmed.substr(1))

	return 100

func _get_player_id_from_pokemon_data(pokemon_data: Dictionary) -> String:
	var ident: String = str(pokemon_data.get("ident", ""))
	return _get_player_id_from_ident(ident)

func _get_hover_known_info_viewer_id(ident: String) -> String:
	match _get_player_id_from_ident(ident):
		"p1":
			return "p2"
		"p2":
			return "p1"

	return ""

func _get_confirmed_ability_for_hover(pokemon_info: Dictionary, pokemon_data: Dictionary) -> String:
	var confirmed_ability: String = _get_optional_known_info_string(pokemon_info, "confirmedAbility")
	if confirmed_ability != "":
		return confirmed_ability

	var ident_key: String = _normalize_battle_ident(str(pokemon_data.get("ident", "")))
	if ident_key == "":
		return ""

	return str(public_confirmed_abilities_by_ident.get(ident_key, ""))

func _get_confirmed_info_moves(pokemon_info: Dictionary) -> Array:
	var moves_value: Variant = pokemon_info.get("confirmedMoves", pokemon_info.get("confirmed_moves", []))
	if moves_value is Array:
		return moves_value

	return []

func _get_confirmed_info_stat_changes(pokemon_info: Dictionary) -> Dictionary:
	var stat_changes_value: Variant = pokemon_info.get("statChanges", pokemon_info.get("stat_changes", {}))
	if stat_changes_value is Dictionary:
		return stat_changes_value

	return {}

func _get_hover_speed_data(pokemon_stats: Dictionary) -> Dictionary:
	var speed_value: Variant = pokemon_stats.get("speed", {})
	if speed_value is Dictionary:
		return speed_value as Dictionary

	return {}

func _get_optional_known_info_string(pokemon_info: Dictionary, key: String) -> String:
	var snake_key: String = _to_snake_case_key(key)
	var value: Variant = pokemon_info.get(key, pokemon_info.get(snake_key, ""))
	if value == null:
		return ""

	return str(value)

func _to_snake_case_key(key: String) -> String:
	var result: String = ""
	for index in range(key.length()):
		var character: String = key.substr(index, 1)
		if index > 0 and character == character.to_upper() and character != character.to_lower():
			result += "_"
		result += character.to_lower()

	return result

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
	if player_species == "":
		player_species = "Pokemon"

	current_action_panel.set_message("What will %s do?" % player_species)

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

	var previous_field_effect_keys: Dictionary = known_field_effect_keys.duplicate()
	_fill_missing_previous_event_conditions(response)
	_remember_public_confirmed_abilities_from_response(response)
	_remember_field_effect_start_turns_from_response(response)
	battle_state.load_from_api_response(response)
	_remember_side_condition_effects_from_field_snapshot()
	_remember_side_condition_effects_from_response(response)
	_queue_missing_field_start_events(previous_field_effect_keys)
	_remember_current_field_effects()
	return true

func _sync_player_save_from_battle_state() -> void:
	var player_team := battle_state.get_player_team("p1")
	if player_team.is_empty():
		return

	PlayerSave.apply_battle_team_state(player_team)

## Werkt de player en opponent HUD panels bij vanuit de battle state.
func _update_hud_panels() -> void:
	player_hud_panel.set_pokemon_data(
		_get_active_display_species("p1"),
		battle_state.get_active_pokemon_level("p1"),
		battle_state.get_active_pokemon_current_hp("p1"),
		battle_state.get_active_pokemon_max_hp("p1"),
		battle_state.get_active_pokemon_status("p1"),
		battle_state.get_active_pokemon_gender("p1"),
	)

	enemy_hud_panel.set_pokemon_data(
		_get_active_display_species("p2"),
		battle_state.get_active_pokemon_level("p2"),
		battle_state.get_active_pokemon_current_hp("p2"),
		battle_state.get_active_pokemon_max_hp("p2"),
		battle_state.get_active_pokemon_status("p2"),
		battle_state.get_active_pokemon_gender("p2"),
	)

	player_hud_panel.set_team_data(_get_display_team_data("p1"))
	enemy_hud_panel.set_team_data(battle_state.get_player_team("p2"))

## Reset de battle status UI naar een lege beginstand.
func _reset_battle_status_panel() -> void:
	battle_status_panel.reset_status()
	field_timers_panel.reset_timers()
	_update_side_condition_ui()

func _reset_battle_effect_tracking() -> void:
	known_field_effect_keys.clear()
	field_effect_started_turns.clear()
	pending_field_start_events.clear()
	public_confirmed_abilities_by_ident.clear()
	active_side_condition_effects = {
		"p1": {},
		"p2": {},
	}
	previous_side_condition_effects_before_response = {
		"p1": {},
		"p2": {},
	}

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
	if not cleaned.to_lower().begins_with("ability:"):
		return ""

	return cleaned.split(":", false, 1)[1].strip_edges()

## Werkt turn en field timer status bij vanuit de battle state.
func _update_battle_status_panels() -> void:
	battle_status_panel.set_turn(battle_state.get_turn())
	battle_status_panel.hide_timer()
	field_timers_panel.set_effects(_get_field_effects_with_started_turns(), battle_state.get_turn())
	_update_side_condition_ui()
	_update_weather_particles(_get_active_weather_effect())
	_update_terrain_effects(_get_active_terrain_effect())
	_update_trick_room_effect(_is_trick_room_active())

func _get_active_weather_effect() -> String:
	for effect_value in battle_state.get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var normalized_effect: String = _get_normalized_field_effect_key(str(effect_data.get("effect", "")))
		if str(effect_data.get("effectType", "")) != "weather" and not _is_weather_effect_key(normalized_effect):
			continue

		return normalized_effect

	return ""

func _is_weather_effect_key(effect_key: String) -> bool:
	return effect_key in ["RainDance", "SunnyDay", "Sandstorm", "Hail", "Snow"]

func _get_active_terrain_effect() -> String:
	for effect_value in battle_state.get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var normalized_effect: String = _get_normalized_field_effect_key(str(effect_data.get("effect", "")))
		var is_terrain_group: bool = str(effect_data.get("effectGroup", "")) == "terrain"
		if not is_terrain_group and not _is_terrain_effect_key(normalized_effect):
			continue

		return normalized_effect

	return ""

func _is_terrain_effect_key(effect_key: String) -> bool:
	return effect_key in ["GrassyTerrain", "ElectricTerrain", "MistyTerrain", "PsychicTerrain"]

func _is_trick_room_active() -> bool:
	for effect_value in battle_state.get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		var normalized_effect: String = _get_normalized_field_effect_key(str(effect_data.get("effect", "")))
		if normalized_effect == "TrickRoom":
			return true

	return false

func _update_weather_particles(weather_effect: String) -> void:
	_update_weather_tint(weather_effect)

	var should_emit_rain := weather_effect == "RainDance"
	if weather_particles != null:
		weather_particles.visible = should_emit_rain
		weather_particles.emitting = should_emit_rain

	var should_show_sun := weather_effect == "SunnyDay"
	if sun_rays != null:
		sun_rays.visible = should_show_sun
		if not should_show_sun:
			sun_rays.position = Vector2.ZERO
			sun_rays.modulate = Color.WHITE
			sun_weather_time = 0.0
	if sun_sparkles != null:
		sun_sparkles.visible = should_show_sun
		sun_sparkles.emitting = should_show_sun

	var should_emit_sandstorm := weather_effect == "Sandstorm"
	if sandstorm_particles != null:
		sandstorm_particles.visible = should_emit_sandstorm
		sandstorm_particles.emitting = should_emit_sandstorm
	if sandstorm_swirls != null:
		sandstorm_swirls.visible = should_emit_sandstorm
		_set_child_particles_emitting(sandstorm_swirls, should_emit_sandstorm)
		if not should_emit_sandstorm:
			sandstorm_swirls.position = Vector2.ZERO
			sandstorm_swirls.modulate = Color.WHITE
			sandstorm_weather_time = 0.0

func _update_weather_tint(weather_effect: String) -> void:
	if weather_tint == null:
		return

	var tint_color := Color.TRANSPARENT
	var should_show_tint := true
	match weather_effect:
		"RainDance":
			tint_color = Color(0.24, 0.46, 0.9, 0.12)
		"SunnyDay":
			tint_color = Color(1.0, 0.76, 0.18, 0.1)
		"Sandstorm":
			tint_color = Color(0.68, 0.47, 0.22, 0.14)
		"Hail", "Snow":
			tint_color = Color(0.72, 0.88, 1.0, 0.1)
		_:
			should_show_tint = false

	weather_tint.visible = should_show_tint
	if should_show_tint:
		weather_tint.color = tint_color

func _update_terrain_effects(terrain_effect: String) -> void:
	var should_show_grassy_terrain := terrain_effect == "GrassyTerrain"
	var should_show_misty_terrain := terrain_effect == "MistyTerrain"
	var should_show_psychic_terrain := terrain_effect == "PsychicTerrain"
	var should_show_terrain := should_show_grassy_terrain or should_show_misty_terrain or should_show_psychic_terrain
	active_terrain_effect = terrain_effect
	if terrain_tint != null:
		terrain_tint.visible = should_show_terrain
		if should_show_terrain:
			terrain_tint.color = _get_terrain_tint_color(terrain_effect, 0.025)
		else:
			terrain_tint.color = Color(0.22, 0.84, 0.16, 0.025)
			grassy_terrain_time = 0.0

	if grassy_terrain_layer != null:
		grassy_terrain_layer.visible = should_show_grassy_terrain
		_set_child_particles_emitting(grassy_terrain_layer, should_show_grassy_terrain)
	if misty_terrain_layer != null:
		misty_terrain_layer.visible = should_show_misty_terrain
		_set_child_particles_emitting(misty_terrain_layer, should_show_misty_terrain)
	if psychic_terrain_layer != null:
		psychic_terrain_layer.visible = should_show_psychic_terrain
		_set_child_particles_emitting(psychic_terrain_layer, should_show_psychic_terrain)

func _update_trick_room_effect(is_active: bool) -> void:
	if trick_room_layer == null:
		return

	trick_room_layer.visible = is_active
	if not is_active:
		trick_room_layer.position = Vector2.ZERO
		trick_room_layer.modulate = Color.WHITE
		trick_room_time = 0.0

func _get_terrain_tint_color(terrain_effect: String, alpha: float) -> Color:
	match terrain_effect:
		"GrassyTerrain":
			return Color(0.24, 0.88, 0.18, alpha)
		"MistyTerrain":
			return Color(0.9, 0.48, 0.95, alpha)
		"PsychicTerrain":
			return Color(0.72, 0.28, 1.0, alpha)

	return Color.TRANSPARENT

func _animate_sun_weather(delta: float) -> void:
	sun_weather_time += delta
	var drift_x := sin(sun_weather_time * 0.45) * 14.0
	var drift_y := sin(sun_weather_time * 0.32) * 5.0
	var alpha := 0.78 + (sin(sun_weather_time * 0.8) * 0.18)

	sun_rays.position = Vector2(drift_x, drift_y)
	sun_rays.modulate = Color(1.0, 1.0, 1.0, alpha)

func _animate_sandstorm_weather(delta: float) -> void:
	sandstorm_weather_time += delta
	var drift_x: float = sin(sandstorm_weather_time * 0.72) * 9.0
	var drift_y: float = sin(sandstorm_weather_time * 0.48) * 4.0
	var alpha: float = 0.82 + (sin(sandstorm_weather_time * 1.05) * 0.16)

	sandstorm_swirls.position = Vector2(drift_x, drift_y)
	sandstorm_swirls.modulate = Color(1.0, 1.0, 1.0, alpha)

func _animate_terrain_effects(delta: float) -> void:
	grassy_terrain_time += delta
	var alpha: float = 0.022 + (sin(grassy_terrain_time * 0.9) * 0.008)
	terrain_tint.color = _get_terrain_tint_color(active_terrain_effect, alpha)

func _animate_trick_room_effect(delta: float) -> void:
	trick_room_time += delta
	var drift_x: float = sin(trick_room_time * 0.55) * 4.0
	var drift_y: float = sin(trick_room_time * 0.72) * 3.0
	var alpha: float = 0.72 + (sin(trick_room_time * 1.25) * 0.18)

	trick_room_layer.position = Vector2(drift_x, drift_y)
	trick_room_layer.modulate = Color(1.0, 1.0, 1.0, alpha)

func _set_child_particles_emitting(container: Node, emitting: bool) -> void:
	for child: Node in container.get_children():
		if child is GPUParticles2D:
			var particle_node: GPUParticles2D = child as GPUParticles2D
			particle_node.emitting = emitting

func _update_side_condition_ui() -> void:
	var player_side_effects: Array = _get_active_side_condition_effects("p1")
	var enemy_side_effects: Array = _get_active_side_condition_effects("p2")
	_set_battle_platform_side_effects(player_battle_platform, player_side_effects)
	_set_battle_platform_side_effects(enemy_battle_platform, enemy_side_effects)
	_set_side_effects_panel_data(player_side_effects_panel, player_side_effects)
	_set_side_effects_panel_data(enemy_side_effects_panel, enemy_side_effects)

func _update_battle_platform_hazards() -> void:
	_update_side_condition_ui()

func _set_side_effects_panel_data(panel: Control, side_effects: Array) -> void:
	if panel == null:
		return

	if panel.has_method("set_side_effects"):
		panel.call("set_side_effects", side_effects, battle_state.get_turn())
	else:
		panel.visible = not side_effects.is_empty()

func _set_battle_platform_side_effects(platform: Control, side_effects: Array) -> void:
	if platform == null:
		return

	if platform.has_method("set_side_effects"):
		platform.call("set_side_effects", side_effects)
		return

	_set_platform_hazard_image_visible(platform, "StickyWebsImage", false)
	_set_platform_hazard_image_visible(platform, "StealthRockImage", false)
	_set_platform_hazard_image_visible(platform, "SpikesImage", false)
	_set_platform_hazard_image_visible(platform, "ToxicSpikesImage", false)

	for effect_value in side_effects:
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		match _get_side_condition_effect_key(effect_data):
			"stickyweb", "stickywebs":
				_set_platform_hazard_image_visible(platform, "StickyWebsImage", true)
			"stealthrock":
				_set_platform_hazard_image_visible(platform, "StealthRockImage", true)
			"spikes":
				_set_platform_hazard_image_visible(platform, "SpikesImage", true)
			"toxicspikes":
				_set_platform_hazard_image_visible(platform, "ToxicSpikesImage", true)

func _set_platform_hazard_image_visible(platform: Control, node_name: String, is_visible: bool) -> void:
	var image_node: CanvasItem = platform.get_node_or_null(node_name) as CanvasItem
	if image_node != null:
		image_node.visible = is_visible

func _remember_side_condition_effects_from_response(response: Dictionary) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) != "fieldEffect":
			continue
		if not _is_side_condition_effect(event):
			continue

		var side_id: String = _get_side_condition_side_id(event)
		if not active_side_condition_effects.has(side_id):
			continue

		var effect_key: String = _get_side_condition_effect_key(event)
		if effect_key == "":
			continue

		var side_effects: Dictionary = active_side_condition_effects[side_id] as Dictionary
		var previous_side_effects_value: Variant = previous_side_condition_effects_before_response.get(side_id, {})
		var previous_side_effects: Dictionary = {}
		if previous_side_effects_value is Dictionary:
			previous_side_effects = previous_side_effects_value as Dictionary

		var state: String = str(event.get("state", ""))
		if state == "end":
			_debug_side_condition("event end side=%s key=%s event=%s" % [
				side_id,
				effect_key,
				JSON.stringify(event),
			])
			side_effects.erase(effect_key)
		else:
			var current_layers_before_event: int = _get_side_condition_layer_count_from_value(side_effects.get(effect_key, {}))
			side_effects[effect_key] = _get_side_condition_effect_with_layers(
				event,
				previous_side_effects.get(effect_key, {}),
				side_effects.get(effect_key, {}),
				effect_key,
				state
			)
			_debug_side_condition("event set side=%s key=%s state=%s previous=%s current=%s incoming=%s stored=%s event=%s" % [
				side_id,
				effect_key,
				state,
				_get_side_condition_layer_count_from_value(previous_side_effects.get(effect_key, {})),
				current_layers_before_event,
				_get_side_condition_layer_count(event),
				_get_side_condition_layer_count_from_value(side_effects.get(effect_key, {})),
				JSON.stringify(event),
			])

func _remember_side_condition_effects_from_field_snapshot() -> void:
	var previous_side_condition_effects: Dictionary = {}
	for side_id in active_side_condition_effects.keys():
		var previous_side_effects_value: Variant = active_side_condition_effects.get(side_id, {})
		if previous_side_effects_value is Dictionary:
			previous_side_condition_effects[side_id] = (previous_side_effects_value as Dictionary).duplicate()
		else:
			previous_side_condition_effects[side_id] = {}

		active_side_condition_effects[side_id] = {}

	previous_side_condition_effects_before_response = previous_side_condition_effects.duplicate(true)

	for effect_value in battle_state.get_field_effects():
		if not (effect_value is Dictionary):
			continue

		var effect_data: Dictionary = effect_value as Dictionary
		if not _is_side_condition_effect(effect_data):
			continue

		var side_id: String = _get_side_condition_side_id(effect_data)
		if not active_side_condition_effects.has(side_id):
			continue

		var effect_key: String = _get_side_condition_effect_key(effect_data)
		if effect_key == "":
			continue

		var side_effects: Dictionary = active_side_condition_effects[side_id] as Dictionary
		var previous_side_effects: Dictionary = previous_side_condition_effects.get(side_id, {}) as Dictionary
		side_effects[effect_key] = _get_side_condition_effect_with_preserved_layers(effect_data, previous_side_effects.get(effect_key, {}), effect_key)
		_debug_side_condition("snapshot set side=%s key=%s previous=%s incoming=%s stored=%s effect=%s" % [
			side_id,
			effect_key,
			_get_side_condition_layer_count_from_value(previous_side_effects.get(effect_key, {})),
			_get_side_condition_layer_count(effect_data),
			_get_side_condition_layer_count_from_value(side_effects.get(effect_key, {})),
			JSON.stringify(effect_data),
		])

func _get_active_side_condition_effects(side_id: String) -> Array:
	var side_effects_value: Variant = active_side_condition_effects.get(side_id, {})
	if not (side_effects_value is Dictionary):
		return []

	var side_effects: Dictionary = side_effects_value as Dictionary
	var effects_with_started_turns: Array = []
	for effect_value in side_effects.values():
		if not (effect_value is Dictionary):
			effects_with_started_turns.append(effect_value)
			continue

		var effect_data: Dictionary = (effect_value as Dictionary).duplicate()
		var effect_key: String = _get_field_effect_key(effect_data)
		if field_effect_started_turns.has(effect_key):
			effect_data["startedTurn"] = int(field_effect_started_turns.get(effect_key, effect_data.get("startedTurn", 0)))

		effects_with_started_turns.append(effect_data)

	return effects_with_started_turns

func _is_side_condition_effect(effect_data: Dictionary) -> bool:
	var effect_type: String = str(effect_data.get("effectType", ""))
	if effect_type == "sideCondition":
		return true

	if str(effect_data.get("scope", "")) == "side":
		return true

	return _is_entry_hazard_effect(effect_data)

func _get_side_condition_side_id(effect_data: Dictionary) -> String:
	var side_id: String = str(effect_data.get("side", ""))
	if side_id == "p1" or side_id == "p2":
		return side_id

	var source_ident: String = str(effect_data.get("sourceTarget", effect_data.get("sourcePokemon", effect_data.get("actor", ""))))
	var source_player_id: String = _get_player_id_from_ident(source_ident)
	if source_player_id == "p1":
		return "p2"
	if source_player_id == "p2":
		return "p1"

	var target_ident: String = str(effect_data.get("target", ""))
	return _get_player_id_from_ident(target_ident)

func _is_entry_hazard_effect(effect_data: Dictionary) -> bool:
	match _get_side_condition_effect_key(effect_data):
		"stealthrock", "spikes", "toxicspikes", "stickyweb", "stickywebs":
			return true

	return false

func _get_side_condition_effect_with_layers(effect_data: Dictionary, previous_effect_value: Variant, current_effect_value: Variant, effect_key: String, state: String) -> Dictionary:
	var next_effect: Dictionary = _get_merged_side_condition_effect_data(effect_data, current_effect_value, false)
	if not _is_layered_side_condition_key(effect_key):
		return next_effect

	var max_layers: int = _get_side_condition_max_layers(effect_key)
	var previous_layers: int = _get_side_condition_layer_count_from_value(previous_effect_value)
	var current_layers: int = _get_side_condition_layer_count_from_value(current_effect_value)
	var incoming_layers: int = _get_side_condition_layer_count(effect_data)
	if state == "start":
		if incoming_layers > previous_layers:
			next_effect["layers"] = clamp(incoming_layers, 1, max_layers)
		else:
			next_effect["layers"] = clamp(previous_layers + 1, 1, max_layers)
		return next_effect

	if current_layers > 0:
		next_effect["layers"] = clamp(current_layers, 1, max_layers)
	elif incoming_layers > 0:
		next_effect["layers"] = clamp(incoming_layers, 1, max_layers)
	elif previous_layers > 0:
		next_effect["layers"] = clamp(previous_layers, 1, max_layers)
	else:
		next_effect["layers"] = 1

	return next_effect

func _get_side_condition_effect_with_preserved_layers(effect_data: Dictionary, previous_effect_value: Variant, effect_key: String) -> Dictionary:
	var next_effect: Dictionary = _get_merged_side_condition_effect_data(effect_data, previous_effect_value, true)
	if not _is_layered_side_condition_key(effect_key):
		return next_effect

	var incoming_layers: int = _get_side_condition_layer_count(effect_data)
	var previous_layers: int = _get_side_condition_layer_count_from_value(previous_effect_value)
	if previous_layers > 0:
		next_effect["layers"] = clamp(previous_layers, 1, _get_side_condition_max_layers(effect_key))
	elif incoming_layers > 0:
		next_effect["layers"] = clamp(incoming_layers, 1, _get_side_condition_max_layers(effect_key))

	return next_effect

func _get_merged_side_condition_effect_data(effect_data: Dictionary, previous_effect_value: Variant, preserve_layer_counts: bool = true) -> Dictionary:
	var next_effect: Dictionary = effect_data.duplicate()
	if not (previous_effect_value is Dictionary):
		return next_effect

	var previous_effect: Dictionary = previous_effect_value as Dictionary
	if preserve_layer_counts:
		for key in ["layers", "layer", "count"]:
			if not next_effect.has(key) and previous_effect.has(key):
				next_effect[key] = previous_effect.get(key)

	for key in [
		"startedTurn",
		"minDuration",
		"maxDuration",
		"duration",
		"minRemainingTurns",
		"maxRemainingTurns",
		"remainingTurns",
		"turns",
	]:
		if not next_effect.has(key) and previous_effect.has(key):
			next_effect[key] = previous_effect.get(key)

	return next_effect

func _has_side_condition_layer_count(effect_data: Dictionary) -> bool:
	for key in ["layers", "layer", "count"]:
		if effect_data.has(key) and int(effect_data.get(key, 0)) > 0:
			return true

	return false

func _is_layered_side_condition_key(effect_key: String) -> bool:
	match effect_key:
		"spikes", "toxicspikes":
			return true

	return false

func _get_side_condition_max_layers(effect_key: String) -> int:
	match effect_key:
		"spikes":
			return 3
		"toxicspikes":
			return 2

	return 1

func _get_side_condition_layer_count_from_value(effect_value: Variant) -> int:
	if not (effect_value is Dictionary):
		return 0

	return _get_side_condition_layer_count(effect_value as Dictionary)

func _get_side_condition_layer_count(effect_data: Dictionary) -> int:
	for key in ["layers", "layer", "count"]:
		if effect_data.has(key):
			return int(effect_data.get(key, 0))

	return 0

func _get_side_condition_effect_key(effect_data: Dictionary) -> String:
	var effect: String = str(effect_data.get("effect", ""))
	if effect == "":
		return ""

	if effect.contains(": "):
		effect = effect.split(": ")[1]

	return effect.to_lower().replace(" ", "").replace("_", "").replace("-", "")

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

	current_action_panel.set_message("What will %s do?" % player_species)
	battle_log_panel.add_message("A wild %s has appeared!" % opponent_species)
	battle_log_panel.add_message("Go! %s!" % player_species)
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

	current_action_panel.set_message("What will %s do?" % player_species)
	battle_log_panel.add_message("%s wants to battle!" % trainer_name)
	battle_log_panel.add_message("%s sent out %s!" % [trainer_name, opponent_species])
	battle_log_panel.add_message("Go! %s!" % player_species)
	battle_log_panel.add_turn_header(battle_state.get_turn())
	last_battle_log_player_id = ""
	await _render_battle_events(_get_wild_battle_start_events(api_response.get("events", [])), false)
	_show_current_action_prompt()




## Stuurt de gekozen player move door en laat de backend de NPC-keuze verwerken.
func _on_moves_grid_move_selected(slot: int) -> void:
	if battle_input_locked:
		return

	_hide_move_hover()
	_set_battle_input_locked(true)
	moves_grid.visible = false
	var player_response: Dictionary = await BattleApiClient.send_choice(
		battle_request,
		battle_state.battle_id,
		"p1",
		"move",
		slot
	)

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

	if battle_state.is_battle_ended():
		await get_tree().create_timer(0.25).timeout
		_finish_battle({
			"reason": "win",
			"winner": battle_state.get_winner()
		})
		return

	if await _auto_force_switch_opponent_if_needed():
		if battle_state.is_battle_ended():
			await get_tree().create_timer(0.25).timeout
			_finish_battle({
				"reason": "win",
				"winner": battle_state.get_winner()
			})
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
				pre_log_message = _format_move_source_message(event_data, actor)
				if pre_log_message != "":
					battle_message = pre_log_message
					attack_actor_ident = ""
				else:
					log_message = "%s used %s!" % [actor, move_name]
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
					if from_name != "":
						log_message = "%s, come back!\nGo! %s!" % [from_name, to_name]
						battle_message = "Go! %s!" % to_name
					else:
						log_message = "Go! %s!" % to_name
						battle_message = log_message
				else:
					var trainer_name := _get_player_display_name(player_id)

					if from_name != "":
						log_message = "%s withdrew %s!\n%s sent out %s!"  % [
							trainer_name,
							from_name,
							trainer_name,
							to_name
						]
					else:
						log_message = "%s sent out %s!" % [trainer_name, to_name]
					battle_message = "%s sent out %s!" % [trainer_name, to_name]
				add_blank_after = true

			"faint":
				recent_ability_event = false
				recent_move_event = false
				faint_target_ident = str(event_data.get("target", ""))
				var target := _format_battle_actor(faint_target_ident)
				log_message = "%s fainted!" % target
				battle_message = ""
				add_blank_after = true

			"win":
				recent_ability_event = false
				recent_move_event = false
				var winner := str(event_data.get("winner", ""))
				log_message = "%s won!" % winner
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
				log_message = _format_field_effect_event(event_data)
				add_blank_after = log_message != ""
				recent_field_effect_source = str(event_data.get("effect", ""))
				_remove_pending_field_start_event(event_data)

			"pokemonEffect":
				recent_ability_event = false
				recent_move_event = false
				_track_pokemon_effect_event(event_data)
				log_message = _format_pokemon_effect_event(event_data)
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
				log_message = _format_ability_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""
				if _is_ability_boost_event(event_data):
					ability_boost_target_ident = str(event_data.get("target", event_data.get("actor", "")))
				recent_ability_event = log_message != ""

			"statChange":
				recent_move_event = false
				stat_change_target_ident = str(event_data.get("target", ""))
				stat_change_amount = int(event_data.get("amount", 0))
				var is_ability_detail := recent_ability_event or _is_stat_change_from_ability(event_data)
				log_message = _format_stat_change_event(event_data, is_ability_detail)
				battle_message = _format_stat_change_battle_message(event_data)
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
				log_message = _format_status_event(event_data)
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
				log_message = _format_fail_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""

			"cant":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				log_message = _format_cant_event(event_data)
				battle_message = log_message
				add_blank_after = log_message != ""

			"miss":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				log_message = _format_miss_event(event_data)
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
					JSON.stringify(_get_event_hp_snapshot(event_data, true)),
					JSON.stringify(_get_event_hp_snapshot(event_data, false)),
					str(_event_has_hp_loss(event_data)),
					str(_get_event_visible_hp_change(event_data)),
					JSON.stringify(event_data),
				])
				var target := _format_battle_actor(damage_target_ident)
				var has_hp_loss: bool = _event_has_hp_loss(event_data)
				var has_sub_percent_hp_loss: bool = _event_has_sub_percent_hp_loss(event_data)
				var source_message := _format_indirect_damage_message(
					event_data,
					target,
					recent_field_effect_source,
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
				elif has_hp_loss:
					var percent: int = max(1, _get_event_visible_hp_change(event_data))
					log_message = "(%s lost %s%% of its health!)" % [target, percent]
				elif has_sub_percent_hp_loss:
					log_message = "(%s lost less than 1%% of its health!)" % target
				else:
					log_message = ""
					damage_target_ident = ""

				add_blank_after = log_message != ""
				recent_field_effect_source = ""
				recent_move_event = false

			"heal":
				recent_ability_event = false
				recent_move_event = false
				heal_target_ident = str(event_data.get("target", ""))
				_fill_missing_leftovers_heal_snapshot(event_data, heal_target_ident)
				var target := _format_battle_actor(heal_target_ident)
				var previous_hp := int(event_data.get("previousHp", 0))
				var hp := int(event_data.get("hp", 0))
				log_message = _format_heal_event(event_data, target, previous_hp, hp)
				battle_message = _format_heal_battle_message(event_data, target, previous_hp, hp)

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

		var has_timed_animation: bool = (
			attack_actor_ident != ""
			or damage_target_ident != ""
			or heal_target_ident != ""
			or stat_change_target_ident != ""
			or ability_boost_target_ident != ""
			or faint_target_ident != ""
		)
		if battle_message != "" and not has_timed_animation:
			await get_tree().create_timer(BATTLE_MESSAGE_HOLD_SECONDS).timeout

		if attack_actor_ident != "":
			await _play_attack_tween_for_actor(attack_actor_ident)
			await get_tree().create_timer(MOVE_EVENT_HOLD_SECONDS).timeout
		if damage_target_ident != "":
			_set_active_hud_hp_from_event(damage_target_ident, event_data, true)
			await _play_damage_tween_for_target(damage_target_ident)
			_set_active_hud_hp_from_event(damage_target_ident, event_data, false)
			await get_tree().create_timer(DAMAGE_EVENT_HOLD_SECONDS).timeout
		if heal_target_ident != "":
			_set_active_hud_hp_from_event(heal_target_ident, event_data, true)
			await _play_heal_tween_for_target(heal_target_ident)
			_set_active_hud_hp_from_event(heal_target_ident, event_data, false)
		if stat_change_target_ident != "":
			await _play_stat_change_tween_for_target(stat_change_target_ident, stat_change_amount)
			await get_tree().create_timer(STAT_CHANGE_EVENT_HOLD_SECONDS).timeout
		if ability_boost_target_ident != "":
			await _play_stat_change_tween_for_target(ability_boost_target_ident, 1)
			await get_tree().create_timer(STAT_CHANGE_EVENT_HOLD_SECONDS).timeout
		if faint_target_ident != "":
			await _play_faint_tween_for_target(faint_target_ident)

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

func _fill_missing_previous_event_conditions(response: Dictionary) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	var current_conditions_by_ident: Dictionary = {}
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident: String = str(event.get("target", ""))
		if target_ident == "":
			continue

		if str(event.get("previousCondition", "")) != "":
			var known_condition: String = _get_condition_from_event_data(event)
			if known_condition != "" and not _is_percentage_only_condition_event(event, false):
				current_conditions_by_ident[target_ident] = known_condition
			continue

		var previous_condition: String = str(current_conditions_by_ident.get(target_ident, ""))
		if previous_condition == "":
			previous_condition = _get_battle_condition_for_ident(target_ident)
		if previous_condition == "":
			_debug_battle_move("could not fill previousCondition target=%s event=%s" % [
				target_ident,
				JSON.stringify(event),
			])
			continue

		event["previousCondition"] = previous_condition
		var previous_snapshot: Dictionary = _parse_condition_hp_snapshot(previous_condition)
		if not previous_snapshot.is_empty():
			event["previousHp"] = int(previous_snapshot.get("hp", 0))
			if not event.has("maxHp"):
				event["maxHp"] = int(previous_snapshot.get("max_hp", 1))
		var current_condition: String = _get_condition_from_event_data(event)
		if current_condition != "" and not _is_percentage_only_condition_event(event, false):
			current_conditions_by_ident[target_ident] = current_condition
		_debug_battle_move("filled previousCondition target=%s previousCondition=%s event=%s" % [
			target_ident,
			previous_condition,
			JSON.stringify(event),
		])

func _get_condition_from_event_data(event: Dictionary) -> String:
	var condition: String = str(event.get("condition", ""))
	if condition != "":
		return condition

	if str(event.get("type", "")) == "faint":
		return "0 fnt"

	if event.has("hp") and event.has("maxHp"):
		var hp: int = int(event.get("hp", 0))
		var max_hp: int = max(int(event.get("maxHp", 1)), 1)
		if hp <= 0:
			return "0 fnt"

		return "%s/%s" % [hp, max_hp]

	return ""

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

func _play_attack_tween_for_actor(actor_ident: String) -> void:
	match _get_player_id_from_ident(actor_ident):
		"p1":
			await player_sprite_box.play_attack_tween(Vector2(28, -6))
		"p2":
			await enemy_sprite_box.play_attack_tween(Vector2(-28, 6))

func _play_damage_tween_for_target(target_ident: String) -> void:
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_damage_tween()
		"p2":
			await enemy_sprite_box.play_damage_tween()

func _play_heal_tween_for_target(target_ident: String) -> void:
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_heal_tween()
		"p2":
			await enemy_sprite_box.play_heal_tween()

func _play_faint_tween_for_target(target_ident: String) -> void:
	match _get_player_id_from_ident(target_ident):
		"p1":
			await player_sprite_box.play_faint_tween()
		"p2":
			await enemy_sprite_box.play_faint_tween()

func _play_stat_change_tween_for_target(target_ident: String, amount: int) -> void:
	if amount == 0:
		return

	match _get_player_id_from_ident(target_ident):
		"p1":
			if amount > 0:
				await player_sprite_box.play_stat_raise_tween()
			else:
				await player_sprite_box.play_stat_drop_tween()
		"p2":
			if amount > 0:
				await enemy_sprite_box.play_stat_raise_tween()
			else:
				await enemy_sprite_box.play_stat_drop_tween()

func _set_active_hud_hp_from_event(target_ident: String, event: Dictionary, use_previous_hp: bool) -> void:
	var player_id := _get_player_id_from_ident(target_ident)
	if player_id == "":
		return

	var hp_data: Dictionary = _get_event_hp_snapshot(event, use_previous_hp)
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
	var player_team: Array = _get_rewound_display_team_data_for_events("p1", events)
	if not player_team.is_empty():
		player_hud_panel.set_team_data(player_team)
		party_grid.set_party(player_team)

	var enemy_team: Array = _get_rewound_display_team_data_for_events("p2", events)
	if not enemy_team.is_empty():
		enemy_hud_panel.set_team_data(enemy_team)

func _get_rewound_display_team_data_for_events(player_id: String, events: Array) -> Array:
	var previous_conditions_by_name: Dictionary = _get_previous_conditions_by_pokemon_name_for_events(player_id, events)
	var team: Array = _get_display_team_data(player_id)
	if previous_conditions_by_name.is_empty():
		return team

	var rewound_team: Array = []
	for pokemon_value in team:
		if not (pokemon_value is Dictionary):
			rewound_team.append(pokemon_value)
			continue

		var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate()
		var pokemon_name: String = _get_ident_pokemon_name(str(pokemon_data.get("ident", "")))
		if previous_conditions_by_name.has(pokemon_name):
			pokemon_data["condition"] = str(previous_conditions_by_name.get(pokemon_name, pokemon_data.get("condition", "")))

		rewound_team.append(pokemon_data)

	return rewound_team

func _get_previous_conditions_by_pokemon_name_for_events(player_id: String, events: Array) -> Dictionary:
	var previous_conditions_by_name: Dictionary = {}
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident: String = str(event.get("target", ""))
		if _get_player_id_from_ident(target_ident) != player_id:
			continue

		var pokemon_name: String = _get_ident_pokemon_name(target_ident)
		var previous_condition: String = str(event.get("previousCondition", ""))
		if pokemon_name == "" or previous_condition == "" or previous_conditions_by_name.has(pokemon_name):
			continue

		previous_conditions_by_name[pokemon_name] = previous_condition

	return previous_conditions_by_name

func _get_event_hp_snapshot(event: Dictionary, use_previous_hp: bool) -> Dictionary:
	var hp_key: String = "previousHp" if use_previous_hp else "hp"
	if event.has(hp_key) and event.has("maxHp"):
		return {
			"hp": int(event.get(hp_key, 0)),
			"max_hp": max(int(event.get("maxHp", 1)), 1),
		}

	var condition_key: String = "previousCondition" if use_previous_hp else "condition"
	return _parse_condition_hp_snapshot(str(event.get(condition_key, "")))

func _is_percentage_only_condition_event(event: Dictionary, use_previous_hp: bool) -> bool:
	var hp_key: String = "previousHp" if use_previous_hp else "hp"
	if event.has(hp_key):
		return false

	var condition_key: String = "previousCondition" if use_previous_hp else "condition"
	var condition_snapshot: Dictionary = _parse_condition_hp_snapshot(str(event.get(condition_key, "")))
	if condition_snapshot.is_empty():
		return false

	var condition_max_hp: int = int(condition_snapshot.get("max_hp", 0))
	var event_max_hp: int = int(event.get("maxHp", 0))
	return condition_max_hp == 100 and event_max_hp > 100

func _fill_missing_leftovers_heal_snapshot(event: Dictionary, target_ident: String) -> void:
	if target_ident == "":
		return

	var source_key: String = _normalize_event_source(str(event.get("source", ""))).to_lower().replace(" ", "")
	_debug_battle_hp("Checking heal snapshot target=%s source=%s source_key=%s event=%s" % [
		target_ident,
		str(event.get("source", "")),
		source_key,
		JSON.stringify(event),
	])
	if source_key != "leftovers":
		return

	var final_snapshot: Dictionary = _get_event_hp_snapshot(event, false)
	var previous_snapshot: Dictionary = _get_event_hp_snapshot(event, true)
	if not final_snapshot.is_empty() and not previous_snapshot.is_empty():
		var final_hp: int = int(final_snapshot.get("hp", 0))
		var previous_event_hp: int = int(previous_snapshot.get("hp", 0))
		if final_hp > previous_event_hp:
			_debug_battle_hp("Leftovers heal already has valid final snapshot target=%s event=%s" % [
				target_ident,
				JSON.stringify(event),
			])
			return

		_debug_battle_hp("Leftovers final snapshot has no healing; using fallback target=%s previous_hp=%s final_hp=%s event=%s" % [
			target_ident,
			str(previous_event_hp),
			str(final_hp),
			JSON.stringify(event),
		])

	_debug_battle_hp("Leftovers previous snapshot from event target=%s snapshot=%s" % [
		target_ident,
		JSON.stringify(previous_snapshot),
	])
	if previous_snapshot.is_empty():
		previous_snapshot = _get_battle_hp_snapshot_for_ident(target_ident)
		_debug_battle_hp("Leftovers previous snapshot from battle_state target=%s snapshot=%s" % [
			target_ident,
			JSON.stringify(previous_snapshot),
		])
	if previous_snapshot.is_empty():
		_debug_battle_hp("Leftovers fallback failed: no previous snapshot target=%s event=%s" % [
			target_ident,
			JSON.stringify(event),
		])
		return

	var previous_hp: int = int(previous_snapshot.get("hp", 0))
	var max_hp: int = max(int(previous_snapshot.get("max_hp", 1)), 1)
	if previous_hp <= 0 or previous_hp >= max_hp:
		_debug_battle_hp("Leftovers fallback skipped: previous_hp=%s max_hp=%s target=%s" % [
			str(previous_hp),
			str(max_hp),
			target_ident,
		])
		return

	var heal_amount: int = max(1, int(floor(float(max_hp) / 16.0)))
	var hp: int = min(previous_hp + heal_amount, max_hp)
	event["previousHp"] = previous_hp
	event["hp"] = hp
	event["maxHp"] = max_hp
	event["previousCondition"] = "%s/%s" % [previous_hp, max_hp]
	event["condition"] = "%s/%s" % [hp, max_hp]
	battle_state.apply_event_conditions([event])
	_debug_battle_hp("Leftovers fallback applied target=%s previous_hp=%s hp=%s max_hp=%s heal_amount=%s event=%s" % [
		target_ident,
		str(previous_hp),
		str(hp),
		str(max_hp),
		str(heal_amount),
		JSON.stringify(event),
	])

func _get_battle_hp_snapshot_for_ident(target_ident: String) -> Dictionary:
	var condition: String = _get_battle_condition_for_ident(target_ident)
	if condition == "":
		return {}

	return _parse_condition_hp_snapshot(condition)

func _get_battle_condition_for_ident(target_ident: String) -> String:
	var player_id: String = _get_player_id_from_ident(target_ident)
	if player_id == "":
		return ""

	var target_name: String = _get_ident_pokemon_name(target_ident)
	if target_name == "":
		return ""

	for pokemon_value in battle_state.get_player_team(player_id):
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _get_ident_pokemon_name(str(pokemon_data.get("ident", ""))) != target_name:
			continue

		return str(pokemon_data.get("condition", ""))

	return ""

func _get_ident_pokemon_name(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges().to_lower()

func _debug_battle_hp(message: String) -> void:
	if DEBUG_BATTLE_HP_EVENTS:
		print("[battle-hp] " + message)

func _debug_battle_move(message: String) -> void:
	if DEBUG_BATTLE_MOVE_EVENTS:
		print("[battle-move] " + message)

func _debug_side_condition(message: String) -> void:
	if DEBUG_SIDE_CONDITION_EFFECTS:
		print("[side-effects] " + message)

func _parse_condition_hp_snapshot(condition: String) -> Dictionary:
	if not condition.contains("/"):
		if condition.ends_with(" fnt") or condition == "0 fnt":
			return {
				"hp": 0,
				"max_hp": 1,
			}

		return {}

	var parts: PackedStringArray = condition.split("/")
	if parts.size() < 2:
		return {}

	var hp: int = int(parts[0])
	var max_hp_text: String = str(parts[1]).split(" ")[0]
	var max_hp: int = max(int(max_hp_text), 1)
	return {
		"hp": hp,
		"max_hp": max_hp,
	}


## Zet echte HP om naar het zichtbare Showdown-percentage.
func _to_visible_hp_percent(hp: int, max_hp: int) -> int:
	if max_hp <= 0:
		return 0

	if hp <= 0:
		return 0

	var clamped_hp: int = clamp(hp, 0, max_hp)
	return clamp(ceili((float(clamped_hp) / float(max_hp)) * 100.0), 0, 100)

## Berekent het zichtbare HP-percentageverschil tussen twee HP-waarden.
func _get_visible_hp_change(previous_hp: int, hp: int, max_hp: int) -> int:
	var previous_percent := _to_visible_hp_percent(previous_hp, max_hp)
	var current_percent := _to_visible_hp_percent(hp, max_hp)
	return abs(previous_percent - current_percent)

func _get_event_visible_hp_change(event: Dictionary) -> int:
	var previous_condition := str(event.get("previousCondition", ""))
	var condition := str(event.get("condition", ""))
	var previous_percent: int = _get_condition_visible_hp_percent(previous_condition)
	var current_percent: int = _get_condition_visible_hp_percent(condition)

	if previous_percent >= 0 and current_percent >= 0:
		return abs(previous_percent - current_percent)

	var previous_hp: int = int(event.get("previousHp", 0))
	var hp: int = int(event.get("hp", 0))
	var max_hp: int = int(event.get("maxHp", 0))
	if max_hp > 0:
		return _get_visible_hp_change(previous_hp, hp, max_hp)

	return 0

func _event_has_hp_loss(event: Dictionary) -> bool:
	if _is_percentage_only_condition_event(event, false):
		return false

	var previous_snapshot: Dictionary = _get_event_hp_snapshot(event, true)
	var snapshot: Dictionary = _get_event_hp_snapshot(event, false)
	if not previous_snapshot.is_empty() and not snapshot.is_empty():
		return int(previous_snapshot.get("hp", 0)) > int(snapshot.get("hp", 0))

	return false

func _event_has_sub_percent_hp_loss(event: Dictionary) -> bool:
	var amount: int = int(event.get("amount", 0))
	var max_hp: int = int(event.get("maxHp", 0))
	if amount <= 0 or max_hp <= 0:
		return false

	return _to_visible_hp_percent(amount, max_hp) <= 1

func _get_condition_visible_hp_percent(condition: String) -> int:
	if condition.contains("fnt"):
		return 0

	if not condition.contains("/"):
		return -1

	var current_hp := int(condition.split("/")[0])
	var right := str(condition.split("/")[1])
	var max_hp := int(right.split(" ")[0])
	return _to_visible_hp_percent(current_hp, max_hp)

func _format_battle_actor(actor: String, include_side_prefix := true) -> String:
	var player_id := _get_player_id_from_ident(actor)
	var actor_name := actor
	if actor_name.contains(": "):
		actor_name = actor_name.split(": ")[1]

	if include_side_prefix and player_id == "p2" and actor_name != "":
		return "The opposing %s" % actor_name

	return actor_name

func _queue_missing_field_start_events(previous_field_effect_keys: Dictionary) -> void:
	for effect_data in battle_state.get_field_effects():
		if not (effect_data is Dictionary):
			continue

		var effect_dict: Dictionary = effect_data as Dictionary
		var effect_key: String = _get_field_effect_key(effect_dict)
		if effect_key == "" or previous_field_effect_keys.has(effect_key):
			continue

		var start_event: Dictionary = effect_dict.duplicate()
		start_event["type"] = "fieldEffect"
		start_event["state"] = "start"
		var started_turn: int = max(battle_state.get_turn() - 1, 1)
		start_event["startedTurn"] = started_turn
		field_effect_started_turns[effect_key] = started_turn
		pending_field_start_events.append(start_event)

func _remember_current_field_effects() -> void:
	known_field_effect_keys.clear()
	var active_field_effect_keys: Dictionary = {}

	for effect_data in battle_state.get_field_effects():
		if not (effect_data is Dictionary):
			continue

		var effect_dict: Dictionary = effect_data as Dictionary
		var effect_key: String = _get_field_effect_key(effect_dict)
		if effect_key != "":
			known_field_effect_keys[effect_key] = true
			active_field_effect_keys[effect_key] = true

	for effect_key in field_effect_started_turns.keys():
		if not active_field_effect_keys.has(effect_key):
			field_effect_started_turns.erase(effect_key)

func _remember_field_effect_start_turns_from_response(response: Dictionary) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	var event_turn: int = _get_initial_event_turn(response, events)
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type == "turn":
			event_turn = max(int(event.get("turn", event_turn)), 1)
			continue

		if event_type != "fieldEffect":
			continue

		var event_key: String = _get_field_effect_key(event)
		if event_key == "":
			continue

		var state: String = str(event.get("state", ""))
		if state == "start":
			field_effect_started_turns[event_key] = max(event_turn, 1)
		elif state == "end":
			field_effect_started_turns.erase(event_key)

func _get_initial_event_turn(response: Dictionary, events: Array) -> int:
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		if str(event.get("type", "")) == "turn":
			return max(int(event.get("turn", 1)) - 1, 1)

	var state_value: Variant = response.get("state", {})
	if state_value is Dictionary:
		var state: Dictionary = state_value as Dictionary
		return max(int(state.get("turn", 1)) - 1, 1)

	return max(battle_state.get_turn(), 1)

func _get_field_effects_with_started_turns() -> Array:
	var effects_with_started_turns: Array = []
	for effect_value in battle_state.get_field_effects():
		if not (effect_value is Dictionary):
			effects_with_started_turns.append(effect_value)
			continue

		var effect_data: Dictionary = (effect_value as Dictionary).duplicate()
		var effect_key: String = _get_field_effect_key(effect_data)
		if field_effect_started_turns.has(effect_key):
			effect_data["startedTurn"] = int(field_effect_started_turns.get(effect_key, effect_data.get("startedTurn", 0)))

		effects_with_started_turns.append(effect_data)

	return effects_with_started_turns

func _remove_pending_field_start_event(event: Dictionary) -> void:
	if str(event.get("state", "")) != "start":
		return

	var event_key: String = _get_field_effect_key(event)
	if event_key == "":
		return

	for idx in range(pending_field_start_events.size() - 1, -1, -1):
		if _get_field_effect_key(pending_field_start_events[idx]) == event_key:
			pending_field_start_events.remove_at(idx)

func _render_pending_field_start_events() -> void:
	for event in pending_field_start_events:
		var log_message: String = _format_field_effect_event(event)
		if log_message == "":
			continue

		_add_battle_log_player_gap(event)
		battle_log_panel.add_message(log_message)

	pending_field_start_events.clear()

func _get_field_effect_key(effect_data: Dictionary) -> String:
	var effect := _get_normalized_field_effect_key(str(effect_data.get("effect", "")))
	if effect == "":
		return ""

	var key_parts := PackedStringArray([
		str(effect_data.get("side", "")),
		effect,
	])
	return "|".join(key_parts)

func _get_normalized_field_effect_key(effect: String) -> String:
	var cleaned: String = _normalize_event_source(effect)
	cleaned = cleaned.replace(" ", "")

	match cleaned:
		"Rain", "RainDance":
			return "RainDance"
		"Sun", "SunnyDay":
			return "SunnyDay"
		"GrassyTerrain":
			return "GrassyTerrain"
		"ElectricTerrain":
			return "ElectricTerrain"
		"MistyTerrain":
			return "MistyTerrain"
		"PsychicTerrain":
			return "PsychicTerrain"
		"TrickRoom":
			return "TrickRoom"

	return cleaned

func _format_ability_event(event: Dictionary) -> String:
	var actor := _format_ability_event_actor(event)
	var ability := _format_ability_name(_get_first_event_text_value(event, [
		"ability",
		"abilityName",
		"sourceName",
		"source",
	]))
	if ability == "":
		return ""

	if _is_ability_boost_event(event):
		var stat: String = _format_stat_name(str(event.get("stat", "")))
		if actor == "":
			return "%s boosted %s!" % [ability, stat]

		return "%s's %s boosted its %s!" % [actor, ability, stat]

	if actor == "":
		return "%s activated!" % ability

	return "%s's %s activated!" % [actor, ability]

func _is_ability_boost_event(event: Dictionary) -> bool:
	var effect: String = str(event.get("effect", "")).to_lower()
	var stat: String = _format_stat_name(str(event.get("stat", "")))
	return effect == "boost" and stat != ""

func _format_ability_event_actor(event: Dictionary) -> String:
	var actor := _format_battle_actor(_get_first_event_text_value(event, [
		"target",
		"actor",
		"pokemon",
		"sourcePokemon",
		"sourceTarget",
	]))
	return actor

func _format_ability_name(ability: String) -> String:
	var cleaned := _normalize_event_source(ability)
	if cleaned == "":
		return ""

	return _format_compact_effect_name(cleaned)

func _format_pokemon_effect_event(event: Dictionary) -> String:
	var target := _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var raw_effect := str(event.get("effect", ""))
	var effect := _format_pokemon_effect_name(raw_effect)
	if target == "" or effect == "":
		return ""

	var state := str(event.get("state", "")).to_lower()
	if state == "activate" and _is_reflection_effect(raw_effect, effect):
		return "%s's %s reflected the move!" % [target, effect]
	var ability_stat_message := _format_ability_stat_pokemon_effect(target, raw_effect)
	if ability_stat_message != "":
		return ability_stat_message
	if _is_ability_like_pokemon_effect(raw_effect, effect):
		match state:
			"start", "activate":
				return "%s's %s activated!" % [target, effect]
			"end":
				return "%s's %s ended." % [target, effect]

	if effect.to_lower() == "confusion":
		match state:
			"start":
				return "%s became confused!" % target
			"activate":
				return "%s is confused!" % target
			"end":
				return "%s snapped out of confusion!" % target

	if _is_trapping_pokemon_effect(effect):
		match state:
			"start", "activate":
				return "%s is trapped by %s!" % [target, effect]
			"end":
				return "%s was freed from %s!" % [target, effect]

	match state:
		"start":
			return "%s became affected by %s!" % [target, effect]
		"activate":
			return "%s is affected by %s!" % [target, effect]
		"end":
			return "%s is no longer affected by %s." % [target, effect]

	return "%s's %s changed." % [target, effect]

func _format_move_source_message(event: Dictionary, actor: String) -> String:
	var raw_source := str(event.get("source", ""))
	if raw_source == "" or actor == "":
		return ""

	var source_name := _format_pokemon_effect_name(raw_source)
	if source_name == "":
		return ""

	if _is_reflection_effect(raw_source, source_name):
		return "%s's %s reflected the move!" % [actor, source_name]

	return ""

func _is_reflection_effect(raw_effect: String, effect: String) -> bool:
	var source_kind := ""
	var cleaned_raw := raw_effect.strip_edges()
	if cleaned_raw.begins_with("[from] "):
		cleaned_raw = cleaned_raw.substr("[from] ".length()).strip_edges()
	if cleaned_raw.contains(": "):
		source_kind = str(cleaned_raw.split(": ")[0]).strip_edges().to_lower()

	var effect_key := effect.to_lower().replace(" ", "")
	return (
		(source_kind == "ability" and effect_key == "magicbounce")
		or (source_kind == "move" and effect_key == "magiccoat")
	)

func _format_pokemon_effect_name(effect: String) -> String:
	var cleaned := _normalize_event_source(effect)
	if cleaned == "":
		return ""

	return _format_compact_effect_name(cleaned)

func _is_ability_like_pokemon_effect(raw_effect: String, effect: String) -> bool:
	var cleaned_raw: String = raw_effect.strip_edges()
	if cleaned_raw.begins_with("[from] "):
		cleaned_raw = cleaned_raw.substr("[from] ".length()).strip_edges()

	if cleaned_raw.to_lower().begins_with("ability:"):
		return true

	match effect.to_lower().replace(" ", ""):
		"protosynthesis", "quarkdrive":
			return true

	return false

func _format_ability_stat_pokemon_effect(target: String, raw_effect: String) -> String:
	var effect_key: String = _normalize_event_source(raw_effect).to_lower().replace(" ", "")
	var ability_name: String = ""
	var stat_key: String = ""

	for ability_key in ["protosynthesis", "quarkdrive"]:
		if effect_key.begins_with(ability_key) and effect_key.length() > ability_key.length():
			ability_name = _format_compact_effect_name(ability_key)
			stat_key = effect_key.substr(ability_key.length())
			break

	if ability_name == "" or stat_key == "":
		return ""

	var stat_name: String = _format_stat_name(stat_key)
	if stat_name == "":
		return "%s's %s activated!" % [target, ability_name]

	return "%s's %s was boosted by %s!" % [target, stat_name, ability_name]

func _is_trapping_pokemon_effect(effect: String) -> bool:
	match effect.to_lower().replace(" ", ""):
		"bind", "clamp", "firespin", "infestation", "magmastorm", "sandtomb", "snaptrap", "whirlpool", "wrap":
			return true

	return false

func _track_pokemon_effect_event(event: Dictionary) -> void:
	var target_key := _get_pokemon_effect_target_key(event)
	var effect := _format_pokemon_effect_name(str(event.get("effect", "")))
	if target_key == "" or not _is_trapping_pokemon_effect(effect):
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

func _format_stat_change_event(event: Dictionary, as_detail := false) -> String:
	var target := _format_battle_actor(_get_first_event_text_value(event, [
		"target",
		"pokemon",
		"actor",
	]))
	var stat := _format_stat_name(_get_first_event_text_value(event, [
		"stat",
		"statName",
	]))
	var amount: int = _get_stat_change_amount(event)
	if target == "" or stat == "" or amount == 0:
		return ""

	var action: String = _format_stat_change_action(amount)
	if action == "":
		return ""

	var message := "%s's %s %s!" % [target, stat, action]
	if as_detail:
		return "- %s" % message

	return message

func _format_stat_change_battle_message(event: Dictionary) -> String:
	var target := _format_battle_actor(_get_first_event_text_value(event, [
		"target",
		"pokemon",
		"actor",
	]))
	var stat := _format_stat_name(_get_first_event_text_value(event, [
		"stat",
		"statName",
	]))
	var amount := _get_stat_change_amount(event)
	if target == "" or stat == "" or amount == 0:
		return ""

	var action := _format_stat_change_action(amount)
	if action == "":
		return ""

	var source: String = _format_stat_change_source(event)
	if source != "":
		return "%s's %s %s because of %s!" % [target, stat, action, source]

	return "%s's %s %s!" % [target, stat, action]

func _format_stat_change_source(event: Dictionary) -> String:
	var source := _normalize_event_source(str(event.get("source", "")))
	if source == "":
		return ""

	return _format_compact_effect_name(source)

func _is_stat_change_from_ability(event: Dictionary) -> bool:
	var source := str(event.get("source", "")).strip_edges()
	if source.begins_with("[from] "):
		source = source.substr("[from] ".length()).strip_edges()

	return source.to_lower().begins_with("ability:")

func _get_stat_change_amount(event: Dictionary) -> int:
	for key in ["amount", "change", "stages", "stageChange"]:
		if event.has(key):
			return int(event.get(key, 0))

	var direction := str(event.get("direction", event.get("kind", ""))).to_lower()
	var amount := int(event.get("stage", event.get("value", 1)))
	if direction == "down" or direction == "fall" or direction == "fell" or direction == "unboost":
		return -abs(amount)
	if direction == "up" or direction == "rise" or direction == "rose" or direction == "boost":
		return abs(amount)

	return 0

func _format_stat_change_action(amount: int) -> String:
	match amount:
		1:
			return "rose"
		2:
			return "rose sharply"
		3, 4, 5, 6:
			return "rose drastically"
		-1:
			return "fell"
		-2:
			return "harshly fell"
		-3, -4, -5, -6:
			return "severely fell"

	return ""

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

func _format_fail_event(event: Dictionary) -> String:
	var ability_message: String = _format_fail_ability_source_event(event)
	if ability_message != "":
		return ability_message

	var reason := _format_event_reason(str(event.get("reason", event.get("source", ""))))
	if reason != "":
		return "But it failed! (%s)" % reason

	return "But it failed!"

func _format_fail_ability_source_event(event: Dictionary) -> String:
	var source: String = str(event.get("source", ""))
	if not source.to_lower().begins_with("ability:"):
		return ""

	var target: String = _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var ability: String = _format_ability_name(source)
	if target == "" or ability == "":
		return ""

	return "%s's %s activated!" % [target, ability]

func _format_status_event(event: Dictionary) -> String:
	var target: String = _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var status: String = _format_status_name(_get_first_event_text_value(event, [
		"status",
		"statusName",
		"condition",
	]))
	if target == "" or status == "":
		return ""

	var state: String = str(event.get("state", "start")).to_lower()
	match state:
		"end", "cure", "cured":
			return "%s was cured of %s!" % [target, status]

	match status.to_lower():
		"poison":
			return "%s was poisoned!" % target
		"toxic poison":
			return "%s was badly poisoned!" % target
		"burn":
			return "%s was burned!" % target
		"paralysis":
			return "%s was paralyzed!" % target
		"sleep":
			return "%s fell asleep!" % target
		"freeze":
			return "%s was frozen!" % target

	return "%s became affected by %s!" % [target, status]

func _format_status_name(status: String) -> String:
	var cleaned: String = _normalize_event_source(status).to_lower().replace(" ", "")
	match cleaned:
		"psn", "poison", "poisoned":
			return "poison"
		"tox", "toxic", "badlypoisoned":
			return "toxic poison"
		"brn", "burn", "burned":
			return "burn"
		"par", "paralysis", "paralyzed":
			return "paralysis"
		"slp", "sleep", "asleep":
			return "sleep"
		"frz", "freeze", "frozen":
			return "freeze"

	if cleaned == "":
		return ""

	return _format_compact_effect_name(cleaned)

func _format_cant_event(event: Dictionary) -> String:
	var actor := _format_battle_actor(str(event.get("actor", event.get("target", ""))))
	var reason := _format_event_reason(str(event.get("reason", event.get("source", ""))))
	if actor != "" and reason != "":
		return "%s couldn't move because of %s!" % [actor, reason]
	if actor != "":
		return "%s couldn't move!" % actor
	if reason != "":
		return "It couldn't move because of %s!" % reason

	return "It couldn't move!"

func _format_miss_event(event: Dictionary) -> String:
	var actor: String = _format_battle_actor(str(event.get("actor", "")))
	var target: String = _format_battle_actor(str(event.get("target", "")))
	if target != "":
		return "%s avoided the attack!" % target
	if actor != "":
		return "%s's attack missed!" % actor

	return "The attack missed!"

func _format_event_reason(reason: String) -> String:
	var cleaned := _normalize_event_source(reason)
	if cleaned == "":
		return ""

	match cleaned.to_lower().replace(" ", ""):
		"slp", "sleep":
			return "sleep"
		"frz", "freeze":
			return "freeze"
		"par", "paralysis":
			return "paralysis"
		"flinch":
			return "flinching"
		"recharge":
			return "recharging"
		"trapped":
			return "being trapped"

	return cleaned

func _format_heal_event(event: Dictionary, target: String, previous_hp: int, hp: int) -> String:
	var source := _normalize_event_source(str(event.get("source", "")))
	var source_key := source.to_lower().replace(" ", "")

	if source_key == "leftovers":
		return "%s restored HP using its Leftovers!" % target
	if source != "" and source_key != "drain":
		return "%s restored HP with %s!" % [target, _format_compact_effect_name(source)]

	if hp > previous_hp:
		var percent: int = max(1, _get_event_visible_hp_change(event))
		return "(%s restored %s%% of its health!)" % [target, percent]

	return "  - %s restored HP!" % target

func _format_heal_battle_message(event: Dictionary, target: String, previous_hp: int, hp: int) -> String:
	var source := _normalize_event_source(str(event.get("source", "")))
	var source_key := source.to_lower().replace(" ", "")

	if source_key == "leftovers":
		return "%s restored HP using its Leftovers!" % target
	if source != "" and source_key != "drain":
		return "%s restored HP with %s!" % [target, _format_compact_effect_name(source)]
	if hp > previous_hp:
		return "%s restored HP!" % target

	return ""

func _format_indirect_damage_message(
	event: Dictionary,
	target: String,
	fallback_source: String = "",
	allow_active_effect_fallback := true
	) -> String:
	var source := _normalize_event_source(str(event.get("source", "")))
	if source == "":
		source = _normalize_event_source(fallback_source)

	if source == "":
		if allow_active_effect_fallback:
			var active_effect := _get_active_residual_pokemon_effect(str(event.get("target", "")))
			if active_effect != "":
				return "%s is hurt by %s!" % [target, active_effect]
		return ""

	match source.to_lower().replace(" ", ""):
		"sandstorm":
			return "%s is buffeted by the sandstorm!" % target
		"hail":
			return "%s is buffeted by the hail!" % target
		"bind", "clamp", "firespin", "infestation", "magmastorm", "sandtomb", "snaptrap", "whirlpool", "wrap":
			return "%s is hurt by %s!" % [target, _format_compact_effect_name(source)]
		"stealthrock":
			return "Pointed stones dug into %s!" % target
		"spikes":
			return "%s was hurt by spikes!" % target
		"toxicspikes":
			return "%s was hurt by poison spikes!" % target
		"leechseed":
			return "%s's health is sapped by Leech Seed!" % target
		"brn", "burn":
			return "%s was hurt by its burn!" % target
		"psn", "poison":
			return "%s was hurt by poison!" % target
		"tox", "toxic":
			return "%s was hurt by poison!" % target
		"curse":
			return "%s is afflicted by the curse!" % target

	if allow_active_effect_fallback:
		var fallback_active_effect := _get_active_residual_pokemon_effect(str(event.get("target", "")))
		if fallback_active_effect != "":
			return "%s is hurt by %s!" % [target, fallback_active_effect]

	return ""

func _normalize_event_source(source: String) -> String:
	var cleaned := source.strip_edges()
	if cleaned.begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()

	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.strip_edges()

func _format_field_effect_event(event: Dictionary) -> String:
	var effect_name := _format_field_effect_name(str(event.get("effect", "")))
	if effect_name == "":
		return ""

	var state := str(event.get("state", ""))
	match state:
		"start":
			var source_message := _format_field_effect_start_source_message(event, effect_name)
			if source_message != "":
				return source_message

			return "%s became active!" % effect_name
		"upkeep":
			return "%s continues." % effect_name
		"end":
			return "%s ended." % effect_name

	return "%s changed." % effect_name

func _format_field_effect_start_source_message(event: Dictionary, effect_name: String) -> String:
	var source_name := _get_field_effect_source_name(event)
	if source_name == "":
		return ""

	var actor := _format_field_effect_source_actor(event)
	var source_kind := _get_field_effect_source_kind(event)
	if source_kind == "ability":
		return _format_ability_field_effect_message(actor, source_name, effect_name)

	if actor != "" and source_name != effect_name:
		return "%s's %s activated %s!" % [actor, source_name, effect_name]

	return ""

func _get_field_effect_source_name(event: Dictionary) -> String:
	var source_name := str(event.get("sourceName", ""))
	if source_name != "":
		return _normalize_event_source(source_name)

	return _normalize_event_source(str(event.get("source", "")))

func _get_field_effect_source_kind(event: Dictionary) -> String:
	var source := str(event.get("source", "")).strip_edges()
	if source.begins_with("[from] "):
		source = source.substr("[from] ".length()).strip_edges()

	if source.contains(": "):
		return str(source.split(": ")[0]).strip_edges().to_lower()

	return ""

func _format_field_effect_source_actor(event: Dictionary) -> String:
	var source_actor := str(event.get("sourcePokemon", ""))
	if source_actor == "":
		source_actor = str(event.get("sourceTarget", ""))
	if source_actor == "":
		source_actor = str(event.get("actor", ""))

	return _format_battle_actor(source_actor)

func _format_ability_field_effect_message(actor: String, ability: String, effect_name: String) -> String:
	var action := _get_field_effect_start_action(effect_name)
	if action == "":
		action = "activated %s" % effect_name

	return _format_ability_weather_message(actor, ability, action)

func _get_field_effect_start_action(effect_name: String) -> String:
	match effect_name.to_lower().replace(" ", ""):
		"sun":
			return "intensified the sun"
		"rain":
			return "made it rain"
		"sandstorm":
			return "whipped up a sandstorm"
		"hail":
			return "summoned hail"
		"snow":
			return "summoned snow"

	return ""

func _format_ability_weather_message(actor: String, ability: String, action: String) -> String:
	if actor == "":
		return "%s %s!" % [ability, action]

	return "%s's %s %s!" % [actor, ability, action]

func _format_field_effect_name(effect: String) -> String:
	var cleaned := effect
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	match cleaned:
		"RainDance":
			return "Rain"
		"SunnyDay":
			return "Sun"
		"Sandstorm":
			return "Sandstorm"
		"Hail":
			return "Hail"
		"Snow":
			return "Snow"

	cleaned = cleaned.replace("Dance", " Dance")
	cleaned = cleaned.replace("Room", " Room")
	cleaned = cleaned.replace("Terrain", " Terrain")
	cleaned = cleaned.replace("Rock", " Rock")
	cleaned = cleaned.replace("Web", " Web")
	cleaned = cleaned.replace("Spikes", " Spikes")

	return cleaned.strip_edges()

func _on_party_grid_party_selected(slot: int) -> void:
	if battle_input_locked:
		return

	if not _can_switch_to_slot(slot):
		return

	_set_battle_input_locked(true)
	var was_force_switch := battle_state.needs_force_switch("p1")
	party_grid.visible = false

	var player_response: Dictionary = await BattleApiClient.send_choice(
		battle_request,
		battle_state.battle_id,
		"p1",
		"switch",
		slot
	)

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

		if battle_state.is_battle_ended():
			await get_tree().create_timer(0.25).timeout
			_finish_battle({
				"reason": "win",
				"winner": battle_state.get_winner()
			})
			return

		_show_moves()
		_set_battle_input_locked(false)
		return

	if not await _submit_npc_choice_and_render():
		_set_battle_input_locked(false)
		return

	if battle_state.is_battle_ended():
		await get_tree().create_timer(0.25).timeout
		_finish_battle({
			"reason": "win",
			"winner": battle_state.get_winner()
		})
		return

	if await _auto_force_switch_opponent_if_needed():
		if battle_state.is_battle_ended():
			await get_tree().create_timer(0.25).timeout
			_finish_battle({
				"reason": "win",
				"winner": battle_state.get_winner()
			})
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

func _auto_force_switch_opponent_if_needed() -> bool:
	if battle_state.is_battle_ended() or not battle_state.needs_force_switch("p2"):
		return false

	return await _submit_npc_choice_and_render()

func _submit_npc_choice_and_render() -> bool:
	var opponent_name: String = _get_vs_player_name("p2")
	if opponent_name == "":
		opponent_name = "Opponent"
	current_action_panel.set_message("%s is choosing..." % opponent_name)

	var opponent_response: Dictionary = await BattleApiClient.send_npc_choice(
		battle_request,
		battle_state.battle_id,
		"p2"
	)

	if not bool(opponent_response.get("success", false)):
		print("NPC choice failed: ", opponent_response)
		return false

	if not _apply_api_response(opponent_response):
		return false

	_update_battle_presentation()
	var opponent_events: Array = opponent_response.get("events", [])
	_rewind_active_hud_hp_for_events(opponent_events)
	_rewind_party_slots_for_events(opponent_events)
	await _render_battle_events(opponent_events)
	return true

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
	var player_species := _get_active_display_species("p1")
	var opponent_species := _get_active_display_species("p2")

	player_sprite_box.set_single_pokemon_species(player_species, "back", _get_active_pokemon_is_shiny("p1"))
	enemy_sprite_box.set_single_pokemon_species(opponent_species, "front", _get_active_pokemon_is_shiny("p2"))

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
