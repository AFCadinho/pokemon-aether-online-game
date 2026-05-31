extends Panel

@onready var name_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/NameLabel
@onready var level_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/LevelLabel
@onready var hp_bar: ProgressBar = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HPRow/HpBar
@onready var gender_icon: TextureRect = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/GenderIcon
@onready var status_icon: TextureRect = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/StatusIcon

@onready var team_panel: HBoxContainer = $PokemonInfo/VBoxContainer/HBoxContainer/Panel/HBoxContainer/PlayerTeamPanel
@onready var team_slots: Array = team_panel.get_children()

func _ready() -> void:
	clear_team_slots()

func set_pokemon_data(species: String, level: int, current_hp: int, max_hp: int) -> void:
	name_label.text = species
	level_label.text = "Lv. " + str(level)
	
	hp_bar.max_value = max(max_hp, 1)
	hp_bar.value = clamp(current_hp, 0, hp_bar.max_value)
	
	gender_icon.visible = false
	status_icon.visible = false
 
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
