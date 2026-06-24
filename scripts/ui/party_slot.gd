extends PanelContainer

signal drag_started(slot_index: int)
signal drag_released(slot_index: int, global_position: Vector2)
signal clicked(slot_index: int)

const SLOT_BG := Color("#111e31f4")
const SLOT_BORDER := Color("#628bb8")
const SLOT_HOVER_BG := Color("#122136f6")
const SLOT_HOVER_BORDER := Color("#9ab6d4")
const SHINY_SLOT_BG := Color("#121d2df4")
const SHINY_SLOT_BORDER := Color("#8f7847")
const SHINY_SLOT_HOVER_BG := Color("#142033f6")
const SHINY_SLOT_HOVER_BORDER := Color("#b09a66")
const SLOT_SHADOW := Color(0.16, 0.24, 0.34, 0.0)
const SLOT_HOVER_SHADOW := Color(0.52, 0.68, 0.86, 0.12)
const SHINY_SLOT_SHADOW := Color(0.58, 0.46, 0.24, 0.05)
const SHINY_SLOT_HOVER_SHADOW := Color(0.62, 0.50, 0.28, 0.08)

@onready var pokemon_sprite: TextureRect = $MarginContainer/HBoxContainer/PokemonSprite
@onready var shiny_badge: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ShinyBadge
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/NameLabel
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/HPBar
@onready var click_button: Button = $ClickButton
@onready var seperator: Control = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Seperator
@onready var level_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

var slot_index := -1
var press_global_position := Vector2.ZERO
var is_hovered := false
var current_is_shiny := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hp_bar.custom_minimum_size.x = 160.0
	if not click_button.gui_input.is_connected(_on_click_button_gui_input):
		click_button.gui_input.connect(_on_click_button_gui_input)
	if not click_button.mouse_entered.is_connected(_on_click_button_mouse_entered):
		click_button.mouse_entered.connect(_on_click_button_mouse_entered)
	if not click_button.mouse_exited.is_connected(_on_click_button_mouse_exited):
		click_button.mouse_exited.connect(_on_click_button_mouse_exited)
	_apply_slot_style()
	
func set_pokemon(pokemon: Pokemon) -> void:
	visible = true
	current_is_shiny = pokemon.shiny
	name_label.text = pokemon.species
	name_label.tooltip_text = pokemon.species
	shiny_badge.visible = pokemon.shiny
	level_label.text = "Lv. " + str(pokemon.level)
	hp_bar.max_value = max(pokemon.max_hp, 1)
	hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	
	pokemon_sprite.texture = PokemonAssets.load_party_icon(pokemon.species, pokemon.shiny)
	click_button.disabled = false
	_apply_slot_style()
	
func set_empty() -> void:
	visible = false
	current_is_shiny = false
	is_hovered = false
	name_label.text = ""
	name_label.tooltip_text = ""
	shiny_badge.visible = false
	pokemon_sprite.texture = null
	hp_bar.value = 0.0
	click_button.disabled = true
	_apply_slot_style()

func _on_click_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		press_global_position = mouse_event.global_position
		drag_started.emit(slot_index)
	else:
		if press_global_position.distance_to(mouse_event.global_position) <= 6.0:
			clicked.emit(slot_index)
		drag_released.emit(slot_index, mouse_event.global_position)

func _on_click_button_mouse_entered() -> void:
	is_hovered = true
	_apply_slot_style()

func _on_click_button_mouse_exited() -> void:
	is_hovered = false
	_apply_slot_style()

func _apply_slot_style() -> void:
	var background: Color = SLOT_BG
	var border: Color = SLOT_BORDER
	var shadow: Color = SLOT_SHADOW
	var border_width := 1
	if current_is_shiny:
		background = SHINY_SLOT_BG
		border = SHINY_SLOT_BORDER
		shadow = SHINY_SLOT_SHADOW
		border_width = 2
	if is_hovered:
		background = SHINY_SLOT_HOVER_BG if current_is_shiny else SLOT_HOVER_BG
		border = SHINY_SLOT_HOVER_BORDER if current_is_shiny else SLOT_HOVER_BORDER
		shadow = SHINY_SLOT_HOVER_SHADOW if current_is_shiny else SLOT_HOVER_SHADOW
		border_width = 2

	add_theme_stylebox_override("panel", _make_slot_style(background, border, shadow, border_width))

func _make_slot_style(background: Color, border: Color, shadow: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = shadow
	style.shadow_size = 8 if shadow.a > 0.0 else 0
	style.shadow_offset = Vector2(0, 2)
	return style
	
