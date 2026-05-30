extends Button

@onready var pokemon_icon: TextureRect = $MarginContainer/HBoxContainer/PokemonIcon
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/BottomRowContainer/HPBar
@onready var status_icon: TextureRect = $MarginContainer/HBoxContainer/VBoxContainer/BottomRowContainer/StatusIcon

func _ready() -> void:
	_ignore_child_mouse_input(self)

func _ignore_child_mouse_input(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		_ignore_child_mouse_input(child)

func set_pokemon(pokemon: Pokemon) -> void:
	visible = true
	disabled = false
	
	name_label.text = pokemon.species
	hp_bar.max_value = max(pokemon.max_hp, 1)
	hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	pokemon_icon.texture = _load_pokemon_icon(pokemon.species)
	status_icon.visible = false

func set_empty() -> void:
	visible = true
	disabled = true
	
	name_label.text = ""
	hp_bar.value = 0
	pokemon_icon.texture = null
	status_icon.visible = false
	
func _load_pokemon_icon(species: String) -> Texture2D:
	var icon_path := "res://assets/sprites/pokemon/pokemon_home/%s.png" % species
	
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
		
	return null
	
