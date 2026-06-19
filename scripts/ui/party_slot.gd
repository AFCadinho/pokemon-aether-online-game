extends PanelContainer

signal drag_started(slot_index: int)
signal drag_released(slot_index: int, global_position: Vector2)

@onready var pokemon_sprite: TextureRect = $MarginContainer/HBoxContainer/PokemonSprite
@onready var shiny_badge: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ShinyBadge
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/HPBar
@onready var click_button: Button = $ClickButton
@onready var seperator: Control = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Seperator
@onready var level_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

var slot_index := -1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hp_bar.custom_minimum_size.x = 160.0
	if not click_button.gui_input.is_connected(_on_click_button_gui_input):
		click_button.gui_input.connect(_on_click_button_gui_input)
	
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

func _on_click_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		drag_started.emit(slot_index)
	else:
		drag_released.emit(slot_index, mouse_event.global_position)
	
