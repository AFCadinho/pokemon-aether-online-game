extends Panel

@onready var name_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/NameLabel
@onready var level_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/HBoxContainer/LevelLabel
@onready var hp_bar: ProgressBar = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/HPRow/HpBar
@onready var gender_icon: TextureRect = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/NameContainer/GenderIcon
@onready var status_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/MarginContainer/VBoxContainer/TopRow/HBoxContainer/StatusLabel
@onready var player_name_label: Label = $PokemonInfo/VBoxContainer/HBoxContainer/Panel/HBoxContainer/PlayerNameLabel

@onready var team_panel: HBoxContainer = $PokemonInfo/VBoxContainer/HBoxContainer/Panel/HBoxContainer/PlayerTeamPanel
@onready var team_slots: Array = team_panel.get_children()

const STATUS_COLORS := {
	"PSN": Color("#b45cff"),
	"TOX": Color("#7d3cff"),
	"BRN": Color("#ff7a2f"),
	"PAR": Color("#ffd84a"),
	"SLP": Color("#64a8ff"),
	"FRZ": Color("#7de8ff"),
}

const GENDER_COLORS := {
	"M": Color("#64a8ff"),
	"F": Color("#ff78c8"),
}

func _ready() -> void:
	clear_team_slots()

func set_pokemon_data(species: String, level: int, current_hp: int, max_hp: int, status: String = "", gender: String = "") -> void:
	name_label.text = species
	level_label.text = "Lv. " + str(level)
	
	var visible_hp_percent := _to_visible_hp_percent(current_hp, max_hp)
	hp_bar.max_value = 100
	hp_bar.value = visible_hp_percent
	
	_set_gender(gender)
	_set_status(status)

func _set_gender(gender: String) -> void:
	var gender_text: String = gender.strip_edges().to_upper()
	gender_icon.visible = GENDER_COLORS.has(gender_text)
	if not gender_icon.visible:
		gender_icon.tooltip_text = ""
		return

	var gender_color: Color = GENDER_COLORS.get(gender_text, Color.WHITE)
	gender_icon.modulate = gender_color
	gender_icon.tooltip_text = "Male" if gender_text == "M" else "Female"

func _set_status(status: String) -> void:
	var status_text: String = _format_status_text(status)
	status_label.text = status_text
	status_label.visible = status_text != ""
	var status_color: Color = STATUS_COLORS.get(status_text, Color.WHITE)
	status_label.modulate = status_color

func _format_status_text(status: String) -> String:
	match status.strip_edges().to_lower():
		"psn", "poison":
			return "PSN"
		"tox", "toxic":
			return "TOX"
		"brn", "burn":
			return "BRN"
		"par", "paralysis":
			return "PAR"
		"slp", "sleep":
			return "SLP"
		"frz", "freeze":
			return "FRZ"

	return ""

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
