extends Control

signal flee_requested

@onready var run_button: Button = $HBoxContainer/ActionSidePanel/MarginContainer/VBoxContainer/ActionChoices/MarginContainer/CenterContainer/GridContainer/RunButton
@onready var battle_log_text: RichTextLabel = $BattleLogPanel/MarginContainer/VBoxContainer/ScrollContainer/BattleLogText

@onready var battle_log_panel: Panel = $BattleLogPanel
@onready var battle_log_toggle_button: Button = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/BattleLogButton

@onready var enemy_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/EnemySpriteBox
@onready var player_sprite_box = $HBoxContainer/BattleFrame/MarginContainer/BattleArena/PlayerSpriteBox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	run_button.pressed.connect(_on_run_button_pressed)
	battle_log_toggle_button.pressed.connect(_on_battle_log_toggle_pressed)
	_update_battle_log_toggle_button()
	
	var test_player := Pokemon.new("Koraidon", 5)
	var test_enemy := Pokemon.new("Groudon", 100)

	setup_single_battle(test_player, test_enemy)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _on_run_button_pressed() -> void:
	battle_log_text.text += "\nGot away safely!"
	flee_requested.emit()
	
func _on_battle_log_toggle_pressed() -> void:
	battle_log_panel.visible = not battle_log_panel.visible
	_update_battle_log_toggle_button()
	
func _update_battle_log_toggle_button() -> void:
	if battle_log_panel.visible:
		battle_log_toggle_button.text = ">"
	else:
		battle_log_toggle_button.text = "<"

func setup_single_battle(player_pokemon: Pokemon, enemy_pokemon: Pokemon) -> void:
	player_sprite_box.set_single_pokemon(player_pokemon, "back")
	enemy_sprite_box.set_single_pokemon(enemy_pokemon, "front")
