extends PanelContainer

@onready var pokemon_sprite : TextureRect = $MarginContainer/HBoxContainer/PokemonSprite
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/HPBar
@onready var click_button: Button = $ClickButton
@onready var seperator: ColorRect = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Seperator
@onready var level_label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_pokemon(pokemon: Pokemon) -> void:
	visible = true
	name_label.text = pokemon.species
	level_label.text = "Lv. " + str(pokemon.level)
	hp_bar.max_value = max(pokemon.max_hp, 1)
	hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	
	pokemon_sprite.texture = _load_pokemon_sprite(pokemon.species)
	click_button.disabled = false
	
	
func _load_pokemon_sprite(species: String) -> Texture2D:
	var home_path := "res://assets/sprites/pokemon/pokemon_home/%s.png" % species
	
	if ResourceLoader.exists(home_path):
		return load(home_path)
		
	var fallback_path := "res://assets/sprites/pokemon/front/%s/frame_000.png" % species.to_lower()
	
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path)
		
	return null
	
func set_empty() -> void:
	visible = false
	name_label.text = ""
	pokemon_sprite.texture = null
	hp_bar.value = 0.0
	click_button.disabled = true
	
