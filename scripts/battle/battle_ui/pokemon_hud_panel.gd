extends Panel

@onready var name_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/NameLabel
@onready var level_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/LevelLabel
@onready var hp_bar: ProgressBar = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HPRow/HpBar
@onready var gender_icon: TextureRect = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/GenderIcon
@onready var status_icon: TextureRect = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/StatusIcon
@onready var player_name_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/Panel/HBoxContainer/PlayerNameLabel

@onready var team_panel: HBoxContainer = $PokemonInfo/VBoxContainer/HBoxContainer/Panel/HBoxContainer/PlayerTeamPanel
@onready var team_slots: Array = team_panel.get_children()

func _ready() -> void:
	clear_team_slots()

func set_pokemon_data(species: String, level: int, current_hp: int, max_hp: int) -> void:
	name_label.text = species
	level_label.text = "Lv. " + str(level)
	
	var visible_hp_percent := _to_visible_hp_percent(current_hp, max_hp)
	hp_bar.max_value = 100
	hp_bar.value = visible_hp_percent
	
	gender_icon.visible = false
	status_icon.visible = false

func _to_visible_hp_percent(current_hp: int, max_hp: int) -> int:
	if max_hp <= 0:
		return 0
		
	if current_hp <= 0:
		return 0
		
	return ceili((float(current_hp) / float(max_hp)) * 100.0)
 
func set_team_data(team: Array) -> void:
	clear_team_slots()
	
	for idx in range(min(team.size(), team_slots.size())):
		var slot: Node = team_slots[idx]
		if slot.has_method("set_pokemon_data"):
			slot.set_pokemon_data(team[idx])

func clear_team_slots() -> void:
	for slot: Node in team_slots:
		if slot.has_method("set_empty"):
			slot.set_empty()
		else:
			slot.visible = false
			
func clear_player_name() -> void:
	player_name_label.text = ""
	player_name_label.visible = true
	
func set_player_name(player_name: String) -> void:
	player_name_label.text = player_name
	player_name_label.visible = player_name != ""
