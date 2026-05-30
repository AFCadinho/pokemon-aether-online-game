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
	var types := PokemonFactory.get_species_types(pokemon.species)
	if not types.is_empty():
		var primary_type := str(types[0])
		_set_color(TypeColors.get_slot_background(primary_type), TypeColors.get_slot_border(primary_type))

	
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
	
	remove_theme_stylebox_override("normal")
	remove_theme_stylebox_override("hover")
	remove_theme_stylebox_override("pressed")
	remove_theme_stylebox_override("disabled")

	
func _load_pokemon_icon(species: String) -> Texture2D:
	var icon_path := "res://assets/sprites/pokemon/pokemon_home/%s.png" % species
	
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
		
	return null
	
func _set_color(background: Color, border: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(0.08)
	
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = background.darkened(0.08)
	
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", normal)
	
	

	
	
