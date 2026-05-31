extends Control

signal flee_requested

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

# Called when the node enters the scene tree for the first time.
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_action_selected(action: String) -> void:
	if action == "fight":
		_show_moves()
	elif action == "bag":
		_open_bag()
	elif action == "party":
		_show_party()
	elif action == "run":
		_try_run()
	
func _on_battle_log_toggle_pressed() -> void:
	battle_log_panel.toggle_log()
	_update_battle_log_toggle_button()
	
func _update_battle_log_toggle_button() -> void:
	if battle_log_panel.is_open():
		battle_log_toggle_button.text = ">"
	else:
		battle_log_toggle_button.text = "<"
	
func _reset_action_choices() -> void:
	current_action_view = ActionView.NONE
	moves_grid.visible = false
	party_grid.visible = false
	
func _show_moves() -> void:
	current_action_view = ActionView.MOVES
	moves_grid.visible = true
	party_grid.visible = false
	action_buttons.set_selected_action("fight")

	
func _show_party() -> void:
	current_action_view = ActionView.PARTY
	moves_grid.visible = false
	party_grid.visible = true
	action_buttons.set_selected_action("party")
	
func _open_bag() -> void:
	current_action_view = ActionView.BAG
	moves_grid.visible = false
	party_grid.visible = false
	
func _try_run() -> void:
	battle_log_panel.add_message("Got away safely!")
	flee_requested.emit()

func _update_move_slots() -> void:
	if active_player_pokemon == null:
		return
	
	moves_grid.set_moves(battle_state.get_available_moves())

func _update_party_slots() -> void:
	party_grid.set_party(PlayerSave.party)

func _apply_api_response(response: Dictionary) -> bool:	
	if not response.get("success", false):
		print("Battle API failed: ", response)
		return false
		
	battle_state.load_from_api_response(response)
	return true
	
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

func _reset_battle_status_panel() -> void:
	battle_status_panel.reset_status()
	field_timers_panel.reset_timers()
	
func _update_battle_status_panels() -> void:
	battle_status_panel.set_turn(battle_state.get_turn())
	battle_status_panel.hide_timer()
	field_timers_panel.reset_timers()
	
func setup_wild_battle_from_response(player_pokemon: Pokemon, enemy_pokemon: Pokemon, api_response: Dictionary) -> void:
	battle_type = BattleType.WILD
	active_player_pokemon = player_pokemon
	
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

	
