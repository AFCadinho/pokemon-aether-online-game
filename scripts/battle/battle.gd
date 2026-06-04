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
var known_field_effect_keys := {}
var pending_field_start_events: Array[Dictionary] = []
var last_battle_log_player_id := ""
var active_residual_pokemon_effects := {}

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
	last_battle_log_player_id = ""
	active_residual_pokemon_effects.clear()

	if PlayerSave.party.is_empty():
		return

## Doet momenteel niets per frame.
func _process(_delta: float) -> void:
	pass

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
	battle_state.load_from_api_response(response)
	_queue_missing_field_start_events(previous_field_effect_keys)
	_remember_current_field_effects()
	_sync_player_save_from_battle_state()
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
	)

	enemy_hud_panel.set_pokemon_data(
		_get_active_display_species("p2"),
		battle_state.get_active_pokemon_level("p2"),
		battle_state.get_active_pokemon_current_hp("p2"),
		battle_state.get_active_pokemon_max_hp("p2"),
	)

	player_hud_panel.set_team_data(_get_display_team_data("p1"))
	enemy_hud_panel.set_team_data(battle_state.get_player_team("p2"))

## Reset de battle status UI naar een lege beginstand.
func _reset_battle_status_panel() -> void:
	battle_status_panel.reset_status()
	field_timers_panel.reset_timers()

## Werkt turn en field timer status bij vanuit de battle state.
func _update_battle_status_panels() -> void:
	battle_status_panel.set_turn(battle_state.get_turn())
	battle_status_panel.hide_timer()
	field_timers_panel.set_effects(battle_state.get_field_effects(), battle_state.get_turn())

## Initialiseert een wild battle vanuit een al gemaakte API battle response.
func setup_wild_battle_from_response(player_pokemon: Pokemon, enemy_pokemon: Pokemon, api_response: Dictionary) -> void:
	battle_type = BattleType.WILD
	active_player_pokemon = player_pokemon
	active_residual_pokemon_effects.clear()

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
	_show_moves()

	var player_species := _get_active_display_species("p1")
	var opponent_species := _get_active_display_species("p2")

	current_action_panel.set_message("What will %s do?" % player_species)
	battle_log_panel.add_message("A wild %s has appeared!" % opponent_species)
	battle_log_panel.add_turn_header(battle_state.get_turn())
	last_battle_log_player_id = ""
	_render_battle_events(_get_wild_battle_start_events(api_response.get("events", [])), false)




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
		return

	if not _apply_api_response(player_response):
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

func _render_battle_events(events: Array, render_turn_headers := true) -> void:
	var recent_field_effect_source := ""
	var recent_ability_event := false
	var recent_move_event := false

	for event in events:
		if not (event is Dictionary):
			continue

		var event_data: Dictionary = event as Dictionary
		var event_type := str(event_data.get("type", ""))
		var log_message := ""
		var battle_message := ""
		var add_blank_after := false
		var suppress_player_gap := false

		match event_type:
			"move":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = true
				var actor := _format_battle_actor(str(event_data.get("actor", "")))
				var move_name := str(event_data.get("move", ""))
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
					to_name = _format_battle_actor(str(event_data.get("toIdent", "")))
				if to_name == "":
					to_name = _format_battle_actor(str(event_data.get("pokemon", "")))
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
				var target := _format_battle_actor(str(event_data.get("target", "")))
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
				log_message = _format_ability_event(event_data)
				add_blank_after = log_message != ""
				recent_ability_event = log_message != ""

			"statChange":
				recent_move_event = false
				var is_ability_detail := recent_ability_event or _is_stat_change_from_ability(event_data)
				log_message = _format_stat_change_event(event_data, is_ability_detail)
				add_blank_after = log_message != ""
				suppress_player_gap = is_ability_detail

			"fail":
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
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

			"turn":
				var turn := int(event_data.get("turn", 0))
				if render_turn_headers and turn > 0:
					battle_log_panel.add_turn_header(turn)
					last_battle_log_player_id = ""
					recent_ability_event = false
					recent_move_event = false

			"damage":
				recent_ability_event = false
				var target := _format_battle_actor(str(event_data.get("target", "")))
				var previous_hp := int(event_data.get("previousHp", 0))
				var hp := int(event_data.get("hp", 0))
				var source_message := _format_indirect_damage_message(
					event_data,
					target,
					recent_field_effect_source,
					not recent_move_event
				)

				if source_message != "":
					log_message = source_message
				elif previous_hp > hp:
					var percent: int = max(1, _get_event_visible_hp_change(event_data))
					log_message = "(%s lost %s%% of its health!)" % [target, percent]
				else:
					log_message = "  - %s took damage!" % target

				add_blank_after = true
				recent_field_effect_source = ""
				recent_move_event = false

			"heal":
				recent_ability_event = false
				recent_move_event = false
				var target := _format_battle_actor(str(event_data.get("target", "")))
				var previous_hp := int(event_data.get("previousHp", 0))
				var hp := int(event_data.get("hp", 0))

				if hp > previous_hp:
					var percent: int = max(1, _get_event_visible_hp_change(event_data))
					log_message = "(%s restored %s%% of its health!)" % [target, percent]

				else:
					log_message = "  - %s restored HP!" % target

				add_blank_after = true
				recent_field_effect_source = ""
			_:
				recent_ability_event = false
				recent_move_event = false
				pass

		if log_message != "":
			if not suppress_player_gap:
				_add_battle_log_player_gap(event_data)
			battle_log_panel.add_message(log_message)

		if add_blank_after:
			battle_log_panel.add_blank_line()

		if battle_message != "":
			current_action_panel.set_message(battle_message)

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
		"move", "cant", "fail":
			return _get_player_id_from_ident(str(event.get("actor", "")))
		"ability":
			return _get_ability_event_player_id(event)
		"statChange":
			return _get_stat_change_event_player_id(event)
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

	var previous_hp := int(event.get("previousHp", 0))
	var hp := int(event.get("hp", 0))
	var max_hp := int(event.get("maxHp", 0))
	if max_hp > 0:
		return _get_visible_hp_change(previous_hp, hp, max_hp)

	return 0

func _get_condition_visible_hp_percent(condition: String) -> int:
	if condition.contains("fnt"):
		return 0

	if not condition.contains("/"):
		return -1

	var current_hp := int(condition.split("/")[0])
	var right := str(condition.split("/")[1])
	var max_hp := int(right.split(" ")[0])
	return _to_visible_hp_percent(current_hp, max_hp)

func _format_battle_actor(actor: String) -> String:
	if actor.contains(": "):
		return actor.split(": ")[1]

	return actor

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
		pending_field_start_events.append(start_event)

func _remember_current_field_effects() -> void:
	known_field_effect_keys.clear()

	for effect_data in battle_state.get_field_effects():
		if not (effect_data is Dictionary):
			continue

		var effect_dict: Dictionary = effect_data as Dictionary
		var effect_key: String = _get_field_effect_key(effect_dict)
		if effect_key != "":
			known_field_effect_keys[effect_key] = true

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
	var effect := str(effect_data.get("effect", ""))
	if effect == "":
		return ""

	var key_parts := PackedStringArray([
		str(effect_data.get("side", "")),
		effect,
	])
	return "|".join(key_parts)

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

	if actor == "":
		return "%s activated!" % ability

	return "%s's %s activated!" % [actor, ability]

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
	var effect := _format_pokemon_effect_name(str(event.get("effect", "")))
	if target == "" or effect == "":
		return ""

	var state := str(event.get("state", "")).to_lower()
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

func _format_pokemon_effect_name(effect: String) -> String:
	var cleaned := _normalize_event_source(effect)
	if cleaned == "":
		return ""

	return _format_compact_effect_name(cleaned)

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
	var amount := _get_stat_change_amount(event)
	if target == "" or stat == "" or amount == 0:
		return ""

	var action := _format_stat_change_action(amount)
	if action == "":
		return ""

	var message := "%s's %s %s!" % [target, stat, action]
	if as_detail:
		return "- %s" % message

	return message

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
	var reason := _format_event_reason(str(event.get("reason", event.get("source", ""))))
	if reason != "":
		return "But it failed! (%s)" % reason

	return "But it failed!"

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

	_update_battle_presentation()

	if was_force_switch:
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

	_update_battle_presentation()
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
	var player_species := _get_active_display_species("p1")
	var opponent_species := _get_active_display_species("p2")

	player_sprite_box.set_single_pokemon_species(player_species, "back")
	enemy_sprite_box.set_single_pokemon_species(opponent_species, "front")

func _update_battle_presentation() -> void:
	_update_battle_status_panels()
	_update_hud_panels()
	_update_active_sprites()
	_update_move_slots()
	_update_party_slots()

func _get_active_display_species(player_id: String) -> String:
	if player_id == "p1":
		var active_pokemon := battle_state.get_active_player_pokemon(player_id)
		var instance_id := str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", "")))
		var saved_pokemon := _get_player_save_pokemon_by_instance_id(instance_id)
		if saved_pokemon != null and _saved_species_matches_battle_data(saved_pokemon, active_pokemon):
			return saved_pokemon.species

	return battle_state.get_active_pokemon_species(player_id)

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

func _is_ui_typing() -> bool:
	var focused_control := get_viewport().gui_get_focus_owner()
	return focused_control is LineEdit or focused_control is TextEdit
