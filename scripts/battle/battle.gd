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
@onready var moves_grid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/MovesGrid
@onready var party_grid = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/PanelContainer/VBoxContainer/PartyGrid

# Battle Log
@onready var battle_log_text: RichTextLabel = $BattleLogPanel/MarginContainer/VBoxContainer/ScrollContainer/BattleLogText
@onready var battle_log_panel: Panel = $BattleLogPanel
@onready var battle_log_toggle_button: Button = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattleLogButton

# Battle Sprites
@onready var enemy_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/EnemySpriteBox
@onready var player_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/PlayerSpriteBox

# HTTP Request
@onready var battle_request: HTTPRequest = $BattleRequest

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	action_buttons.action_selected.connect(_on_action_selected)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	_update_battle_log_toggle_button()
	
	# Show Moves, Party or Bag
	_reset_action_choices()
	
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
	battle_log_panel.visible = not battle_log_panel.visible
	_update_battle_log_toggle_button()
	
func _update_battle_log_toggle_button() -> void:
	if battle_log_panel.visible:
		battle_log_toggle_button.text = ">"
	else:
		battle_log_toggle_button.text = "<"

func setup_single_battle(player_pokemon: Pokemon, enemy_pokemon: Pokemon, type: BattleType=BattleType.WILD) -> void:
	battle_type = type
	active_player_pokemon = player_pokemon
	
	player_sprite_box.set_single_pokemon(player_pokemon, "back")
	enemy_sprite_box.set_single_pokemon(enemy_pokemon, "front")
	
	_update_move_slots()
	_update_party_slots()
	
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
	battle_log_text.text += "\nGot away safely!"
	flee_requested.emit()
	
func _show_initial_action_view() -> void:
	if battle_type == BattleType.WILD:
		_show_moves()
	elif battle_type == BattleType.TRAINER:
		_show_party()
	else:
		_reset_action_choices()

func _update_move_slots() -> void:
	if active_player_pokemon == null:
		return
	
	var moves := battle_state.get_available_moves()
	var slots := moves_grid.get_children()
	
	for idx in range(slots.size()):
		var slot = slots[idx]
		
		if idx < moves.size():
			slot.set_move_data(moves[idx])
		else:
			slot.set_empty()

func _update_party_slots() -> void:
	var slots := party_grid.get_children()
	for idx in range(slots.size()):
		var slot = slots[idx]
		if idx < PlayerSave.party.size():
			slot.set_pokemon(PlayerSave.party[idx])
		else:
			slot.set_empty()

func start_battle(player1: Dictionary, player2: Dictionary) -> void:		
	if battle_type == BattleType.WILD:
		await _start_wild_battle(player1, player2)
		return
		
	var response = await BattleApiClient.create_battle(battle_request, player1, player2)
	if not _apply_api_response(response):
		return

func _start_wild_battle(player1: Dictionary, player2: Dictionary) -> void:
	var response = await BattleApiClient.create_wild_battle(battle_request, player1, player2)
	if not _apply_api_response(response):
		return
		
	_update_move_slots()
	_show_moves()

func _apply_api_response(response: Dictionary) -> bool:
	if not response.get("success", false):
		print("Battle API failed: ", response)
		return false
		
	battle_state.load_from_api_response(response)
	print("Battle updated: ", battle_state.battle_id)
	print("Team preview: ", battle_state.is_team_preview("p1"))
	return true
