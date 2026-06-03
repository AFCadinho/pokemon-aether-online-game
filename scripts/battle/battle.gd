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

#Battle State
var battle_state := BattleState.new()

#Active Pokemon
var active_player_pokemon: Pokemon

# Action Buttons
@onready var action_buttons = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/ActionChoices
@onready var moves_grid: MovesGrid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/MovesGrid
@onready var party_grid: PartyGrid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/PartyGrid

# Battle Log
@onready var battle_log_panel: BattleLogPanel = $BattleLogPanel
@onready var battle_log_toggle_button: Button = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattleLogButton

# Battle Sprites
@onready var enemy_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/EnemySpriteBox
@onready var player_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/PlayerSpriteBox

# Pokemon HUD
@onready var player_hud_panel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/PlayerHudPanel
@onready var enemy_hud_panel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/EnemyHudPanel

# Turn Nodes
@onready var battle_status_panel: BattleStatusPanel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattleStatusPanel

@onready var field_timers_panel: FieldTimersPanel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/FieldTimers
@onready var current_action_panel: CurrentActionPanel = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/CurrentActionPanel

# HTTP Request
@onready var battle_request: HTTPRequest = $BattleRequest

## Verbindt de UI-signals en zet de battle UI in de beginstand.
func _ready() -> void:
	action_buttons.action_selected.connect(_on_action_selected)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	_update_battle_log_toggle_button()

	# Show Moves, Party or Bag
	_reset_action_choices()
	_reset_battle_status_panel()
	current_action_panel.clear_message()
	battle_log_panel.clear_log()

	if PlayerSave.party.is_empty():
		return

## Doet momenteel niets per frame.
func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
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
	if battle_finished or battle_state.needs_force_switch("p1"):
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
	party_grid.set_party(battle_state.get_player_team("p1"))

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

	battle_state.load_from_api_response(response)
	return true

## Werkt de player en opponent HUD panels bij vanuit de battle state.
func _update_hud_panels() -> void:
	player_hud_panel.set_pokemon_data(
		battle_state.get_active_pokemon_species("p1"),
		battle_state.get_active_pokemon_level("p1"),
		battle_state.get_active_pokemon_current_hp("p1"),
		battle_state.get_active_pokemon_max_hp("p1"),
	)

	enemy_hud_panel.set_pokemon_data(
		battle_state.get_active_pokemon_species("p2"),
		battle_state.get_active_pokemon_level("p2"),
		battle_state.get_active_pokemon_current_hp("p2"),
		battle_state.get_active_pokemon_max_hp("p2"),
	)

	player_hud_panel.set_team_data(battle_state.get_player_team("p1"))
	enemy_hud_panel.set_team_data(battle_state.get_player_team("p2"))

## Reset de battle status UI naar een lege beginstand.
func _reset_battle_status_panel() -> void:
	battle_status_panel.reset_status()
	field_timers_panel.reset_timers()

## Werkt turn en field timer status bij vanuit de battle state.
func _update_battle_status_panels() -> void:
	battle_status_panel.set_turn(battle_state.get_turn())
	battle_status_panel.hide_timer()
	field_timers_panel.reset_timers()

## Initialiseert een wild battle vanuit een al gemaakte API battle response.
func setup_wild_battle_from_response(player_pokemon: Pokemon, enemy_pokemon: Pokemon, api_response: Dictionary) -> void:
	battle_type = BattleType.WILD
	active_player_pokemon = player_pokemon

	player_hud_panel.clear_player_name()
	enemy_hud_panel.clear_player_name()

	player_sprite_box.set_single_pokemon(player_pokemon, "back")
	enemy_sprite_box.set_single_pokemon(enemy_pokemon, "front")

	if not _apply_api_response(api_response):
		return

	_update_battle_status_panels()
	_update_hud_panels()
	_update_move_slots()
	_update_party_slots()
	_show_moves()

	var player_species := battle_state.get_active_pokemon_species("p1")
	var opponent_species := battle_state.get_active_pokemon_species("p2")

	current_action_panel.set_message("What will %s do?" % player_species)
	battle_log_panel.add_message("A wild %s has appeared!" % opponent_species)
	battle_log_panel.add_turn_header(battle_state.get_turn())




## Stuurt de gekozen player move door en kiest daarna automatisch een opponent move.
func _on_moves_grid_move_selected(slot: int) -> void:
	var player_response: Dictionary = await BattleApiClient.send_choice(
		battle_request,
		battle_state.battle_id,
		"p1",
		"move",
		slot
	)

	if not player_response.get("success", false):
		print("Player choice failed: ", player_response)

	battle_state.load_from_api_response(player_response)

	var opponent_moves: Array = battle_state.get_available_moves("p2")
	if opponent_moves.is_empty():
		print("No opponent moves available")
		return

	var opponent_slot := randi_range(1, opponent_moves.size())

	var opponent_response: Dictionary = await BattleApiClient.send_choice(
		battle_request,
		battle_state.battle_id,
		"p2",
		"move",
		opponent_slot
	)

	if not _apply_api_response(opponent_response):
		return

	_update_battle_status_panels()
	_update_hud_panels()
	_update_move_slots()
	_update_party_slots()
	_render_battle_events(opponent_response.get("events", []))

	if battle_state.is_battle_ended():
		await get_tree().create_timer(0.25).timeout
		_finish_battle({
			"reason": "win",
			"winner": battle_state.get_winner()
		})
		return

	if _show_force_switch_if_needed():
		return

func _render_battle_events(events: Array) -> void:
	for event in events:
		var event_type := str(event.get("type", ""))
		var log_message := ""
		var battle_message := ""
		var add_blank_after := false

		match event_type:
			"move":
				var actor := _format_battle_actor(str(event.get("actor", "")))
				var move_name := str(event.get("move", ""))
				log_message = "%s used %s!" % [actor, move_name]
				battle_message = log_message

			"switch":
				var player_id := str(event.get("playerId", ""))
				var from_name := str(event.get("from", ""))
				var to_name := str(event.get("to", ""))

				if to_name == "":
					to_name = _format_battle_actor(str(event.get("toIdent", "")))
				if to_name == "":
					to_name = _format_battle_actor(str(event.get("pokemon", "")))
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
				var target := _format_battle_actor(str(event.get("target", "")))
				log_message = "%s fainted!" % target
				battle_message = ""
				add_blank_after = true

			"win":
				var winner := str(event.get("winner", ""))
				log_message = "%s won!" % winner
				battle_message = log_message
				add_blank_after = true

			"turn":
				var turn := int(event.get("turn", 0))
				if turn > 0:
					battle_log_panel.add_turn_header(turn)

			"damage":
				var target := _format_battle_actor(str(event.get("target", "")))
				var previous_hp := int(event.get("previousHp", 0))
				var hp := int(event.get("hp", 0))
				var max_hp := int(event.get("maxHp", 0))

				if previous_hp > hp and max_hp > 0:
					var percent: int = max(1, _get_visible_hp_change(previous_hp, hp, max_hp))
					log_message = "  - %s lost %s%% HP" % [target, percent]

				else:
					log_message = "  - %s took damage!" % target

				add_blank_after = true

			"heal":
				var target := _format_battle_actor(str(event.get("target", "")))
				var previous_hp := int(event.get("previousHp", 0))
				var hp := int(event.get("hp", 0))
				var max_hp := int(event.get("maxHp", 0))


				if hp > previous_hp and max_hp > 0:
					var percent: int = max(1, _get_visible_hp_change(previous_hp, hp, max_hp))
					log_message = "  - %s restored %s%% HP!" % [target, percent]

				else:
					log_message = "  - %s restored HP!" % target

				add_blank_after = true
			_:
				pass

		if log_message != "":
			battle_log_panel.add_message(log_message)

		if add_blank_after:
			battle_log_panel.add_blank_line()

		if battle_message != "":
			current_action_panel.set_message(battle_message)


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

func _format_battle_actor(actor: String) -> String:
	if actor.contains(": "):
		return actor.split(": ")[1]

	return actor

func _on_party_grid_party_selected(slot: int) -> void:
	if not _can_switch_to_slot(slot):
		return

	var was_force_switch := battle_state.needs_force_switch("p1")

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
		return

	if not _apply_api_response(player_response):
		return

	if was_force_switch:
		_update_battle_status_panels()
		_update_hud_panels()
		_update_active_sprites()
		_update_move_slots()
		_update_party_slots()
		_render_battle_events(player_response.get("events", []))

		if battle_state.is_battle_ended():
			await get_tree().create_timer(0.25).timeout
			_finish_battle({
				"reason": "win",
				"winner": battle_state.get_winner()
			})
			return

		_show_moves()
		return

	var opponent_moves: Array = battle_state.get_available_moves("p2")
	if opponent_moves.is_empty():
		print("No opponent moves available")
		return

	var opponent_slot := randi_range(1, opponent_moves.size())

	var opponent_response: Dictionary = await BattleApiClient.send_choice(
		battle_request,
		battle_state.battle_id,
		"p2",
		"move",
		opponent_slot
	)

	if not _apply_api_response(opponent_response):
		return

	_update_battle_status_panels()
	_update_hud_panels()
	_update_active_sprites()
	_update_move_slots()
	_update_party_slots()
	_render_battle_events(opponent_response.get("events", []))

	if battle_state.is_battle_ended():
		await get_tree().create_timer(0.25).timeout
		_finish_battle({
			"reason": "win",
			"winner": battle_state.get_winner()
		})
		return

	if _show_force_switch_if_needed():
		return

	_show_moves()

func _show_force_switch_if_needed() -> bool:
	if not battle_state.needs_force_switch("p1") or battle_state.is_battle_ended():
		return false

	current_action_panel.set_message("Choose a Pokemon!")
	_show_party(true)
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
	var player_species := battle_state.get_active_pokemon_species("p1")
	var opponent_species := battle_state.get_active_pokemon_species("p2")

	player_sprite_box.set_single_pokemon_species(player_species, "back")
	enemy_sprite_box.set_single_pokemon_species(opponent_species, "front")

func _get_player_display_name(player_id: String) -> String:
	var player_data: Dictionary = battle_state.players.get(player_id, {})
	var player_name := str(player_data.get("name", ""))

	if player_name != "":
		return player_name
	if player_id == "p1":
		return "Player"

	return "Opponent"

func _try_select_move(slot: int) -> void:
	if battle_finished:
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
