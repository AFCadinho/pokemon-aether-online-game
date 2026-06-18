extends PanelContainer

@onready var pokemon_sprite: TextureRect = $MarginContainer/HBoxContainer/PokemonSprite
@onready var shiny_badge: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ShinyBadge
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/HPBar
@onready var click_button: Button = $ClickButton
@onready var seperator: Control = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Seperator
@onready var level_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hp_bar.custom_minimum_size.x = 160.0
	
func set_pokemon(pokemon: Pokemon) -> void:
	visible = true
	name_label.text = pokemon.species
	name_label.tooltip_text = pokemon.species
	shiny_badge.visible = pokemon.shiny
	level_label.text = "Lv. " + str(pokemon.level)
	hp_bar.max_value = max(pokemon.max_hp, 1)
	hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	
	pokemon_sprite.texture = PokemonAssets.load_party_icon(pokemon.species, pokemon.shiny)
	click_button.disabled = false
	
func set_empty() -> void:
	visible = false
	name_label.text = ""
	name_label.tooltip_text = ""
	shiny_badge.visible = false
	pokemon_sprite.texture = null
	hp_bar.value = 0.0
	click_button.disabled = true
	
