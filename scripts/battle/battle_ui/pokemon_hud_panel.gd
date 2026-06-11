extends PanelContainer

signal team_pokemon_hovered(pokemon_data: Dictionary)
signal team_pokemon_unhovered

@onready var active_info_rows: Array[Node] = [
	$MarginContainer/VBoxContainer/PokemonInfoHud,
	$MarginContainer/VBoxContainer/PokemonInfoHud2,
]
@onready var player_name_label: Label = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer2/PlayerNameLabel") as Label

@onready var team_panel: HBoxContainer = $MarginContainer/VBoxContainer/HBoxContainer2/PlayerTeamPanel
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
	_connect_team_slot_hover_signals()
	clear_team_slots()
	_set_active_info_row_visible(1, false)

func _connect_team_slot_hover_signals() -> void:
	for slot_value in team_slots:
		var slot: Node = slot_value as Node
		if slot.has_signal("pokemon_hovered"):
			slot.pokemon_hovered.connect(_on_team_slot_pokemon_hovered)
		if slot.has_signal("pokemon_unhovered"):
			slot.pokemon_unhovered.connect(_on_team_slot_pokemon_unhovered)

func set_pokemon_data(species: String, level: int, current_hp: int, max_hp: int, status: String = "", gender: String = "") -> void:
	_set_active_info_row_data(0, species, level, current_hp, max_hp, status, gender)

func clear_active_pokemon_data() -> void:
	_set_active_info_row_visible(0, false)

func _set_active_info_row_data(
	row_index: int,
	species: String,
	level: int,
	current_hp: int,
	max_hp: int,
	status: String = "",
	gender: String = ""
) -> void:
	if row_index < 0 or row_index >= active_info_rows.size():
		return

	var row: Node = active_info_rows[row_index]
	_set_active_info_row_visible(row_index, true)

	var name_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/NameContainer/NameLabel") as Label
	if name_label != null:
		name_label.text = species

	var level_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/HBoxContainer/LevelLabel") as Label
	if level_label != null:
		level_label.text = "Lv. " + str(level)

	var hp_bar: ProgressBar = row.get_node_or_null("MarginContainer/VBoxContainer/HPRow/HpBar") as ProgressBar
	var visible_hp_percent := _to_visible_hp_percent(current_hp, max_hp)
	if hp_bar != null:
		hp_bar.max_value = 100
		hp_bar.value = visible_hp_percent

	_set_gender(row, gender)
	_set_status(row, status)

func _set_active_info_row_visible(row_index: int, is_visible: bool) -> void:
	if row_index < 0 or row_index >= active_info_rows.size():
		return

	var row: Node = active_info_rows[row_index]
	if row is CanvasItem:
		var canvas_item: CanvasItem = row as CanvasItem
		canvas_item.visible = is_visible

func _set_gender(row: Node, gender: String) -> void:
	var gender_icon: TextureRect = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/NameContainer/GenderIcon") as TextureRect
	if gender_icon == null:
		return

	var gender_text: String = gender.strip_edges().to_upper()
	gender_icon.visible = GENDER_COLORS.has(gender_text)
	if not gender_icon.visible:
		gender_icon.tooltip_text = ""
		return

	var gender_color: Color = GENDER_COLORS.get(gender_text, Color.WHITE)
	gender_icon.modulate = gender_color
	gender_icon.tooltip_text = "Male" if gender_text == "M" else "Female"

func _set_status(row: Node, status: String) -> void:
	var status_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/HBoxContainer/StatusLabel") as Label
	if status_label == null:
		return

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
	if player_name_label == null:
		return

	player_name_label.text = ""
	player_name_label.visible = false
	
func set_player_name(player_name: String) -> void:
	if player_name_label == null:
		return

	player_name_label.text = player_name
	player_name_label.visible = false

func _on_team_slot_pokemon_hovered(pokemon_data: Dictionary) -> void:
	team_pokemon_hovered.emit(pokemon_data)

func _on_team_slot_pokemon_unhovered() -> void:
	team_pokemon_unhovered.emit()
