extends PanelContainer

signal drag_started(slot_index: int)
signal drag_released(slot_index: int, global_position: Vector2)
signal clicked(slot_index: int)

const SLOT_BG := Color("#111e31f4")
const SLOT_BORDER := Color("#628bb8")
const SLOT_HOVER_BG := Color("#17345af8")
const SLOT_HOVER_BORDER := Color("#c5e0ff")
const SHINY_SLOT_BG := Color("#121d2df4")
const SHINY_SLOT_BORDER := Color("#8f7847")
const SHINY_SLOT_HOVER_BG := Color("#2b2740f8")
const SHINY_SLOT_HOVER_BORDER := Color("#f0ca72")
const SLOT_SHADOW := Color(0.16, 0.24, 0.34, 0.0)
const SLOT_HOVER_SHADOW := Color(0.58, 0.78, 1.0, 0.24)
const SHINY_SLOT_SHADOW := Color(0.58, 0.46, 0.24, 0.05)
const SHINY_SLOT_HOVER_SHADOW := Color(0.95, 0.72, 0.32, 0.18)
const SLOT_BORDER_WIDTH := 1
const SHINY_SLOT_BORDER_WIDTH := 2
const SLOT_SHADOW_SIZE := 0
const SHINY_SLOT_SHADOW_SIZE := 8
const STATUS_ICON_SHEET: Texture2D = preload("res://assets/battles/status/icon_statuses.png")
const STATUS_ICON_WIDTH := 44
const STATUS_ICON_HEIGHT := 16
const STATUS_ICON_ROWS := {
	"slp": 0,
	"psn": 1,
	"brn": 2,
	"par": 3,
	"frz": 4,
	"tox": 7,
}

@onready var pokemon_sprite: TextureRect = $MarginContainer/HBoxContainer/PokemonSprite
@onready var shiny_badge: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/ShinyBadge
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/NameLabel
@onready var status_icon: TextureRect = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/StatusIcon
@onready var hp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/HPBar
@onready var exp_bar: ProgressBar = $MarginContainer/HBoxContainer/VBoxContainer/ExpBar
@onready var click_button: Button = $ClickButton
@onready var seperator: Control = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Seperator
@onready var level_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

var slot_index: int = -1
var press_global_position: Vector2 = Vector2.ZERO
var is_hovered: bool = false
var current_is_shiny: bool = false
var held_item_marker: Control
var status_icon_texture_cache: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hp_bar.custom_minimum_size.x = 160.0
	exp_bar.custom_minimum_size.x = 160.0
	if not click_button.gui_input.is_connected(_on_click_button_gui_input):
		click_button.gui_input.connect(_on_click_button_gui_input)
	if not click_button.mouse_entered.is_connected(_on_click_button_mouse_entered):
		click_button.mouse_entered.connect(_on_click_button_mouse_entered)
	if not click_button.mouse_exited.is_connected(_on_click_button_mouse_exited):
		click_button.mouse_exited.connect(_on_click_button_mouse_exited)
	_setup_held_item_marker()
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
	_update_experience_bar(pokemon)
	
	pokemon_sprite.texture = PokemonAssets.load_party_icon(pokemon.species, pokemon.shiny)
	_set_held_item_marker(pokemon.item)
	_set_status_icon(pokemon.status)
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
	_set_held_item_marker("")
	_set_status_icon("")
	hp_bar.value = 0.0
	exp_bar.value = 0.0
	exp_bar.visible = false
	click_button.disabled = true
	_apply_slot_style()

func _setup_held_item_marker() -> void:
	if held_item_marker != null:
		return
	held_item_marker = Control.new()
	held_item_marker.name = "HeldItemMarker"
	held_item_marker.visible = false
	held_item_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held_item_marker.custom_minimum_size = Vector2(10, 14)
	held_item_marker.anchor_left = 1.0
	held_item_marker.anchor_right = 1.0
	held_item_marker.anchor_top = 0.0
	held_item_marker.anchor_bottom = 0.0
	held_item_marker.offset_left = -10.0
	held_item_marker.offset_top = 0.0
	held_item_marker.offset_right = 0.0
	held_item_marker.offset_bottom = 14.0
	pokemon_sprite.add_child(held_item_marker)

	var item_chip: PanelContainer = _create_held_item_chip(Color("#f5c33b"), Color("#2a1700"))
	item_chip.position = Vector2(1, 1)
	held_item_marker.add_child(item_chip)

	var red_stripe: PanelContainer = PanelContainer.new()
	red_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red_stripe.custom_minimum_size = Vector2(6, 2)
	red_stripe.size = Vector2(6, 2)
	red_stripe.position = Vector2(2, 7)
	var stripe_style: StyleBoxFlat = StyleBoxFlat.new()
	stripe_style.bg_color = Color("#c93324")
	stripe_style.border_color = Color("#6f140d")
	stripe_style.border_width_bottom = 1
	red_stripe.add_theme_stylebox_override("panel", stripe_style)
	held_item_marker.add_child(red_stripe)


func _create_held_item_chip(fill_color: Color, border_color: Color) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(8, 12)
	chip.size = Vector2(8, 12)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.corner_radius_bottom_left = 1
	chip.add_theme_stylebox_override("panel", style)
	return chip


func _set_held_item_marker(item_id: String) -> void:
	if held_item_marker == null:
		return
	var normalized_item_id: String = item_id.strip_edges()
	held_item_marker.visible = normalized_item_id != ""
	held_item_marker.tooltip_text = "Holding %s" % normalized_item_id if normalized_item_id != "" else ""

func _set_status_icon(status: String) -> void:
	if status_icon == null:
		return

	var status_key := _normalize_status_key(status)
	var status_texture := _get_status_icon_texture(status_key)
	status_icon.texture = status_texture
	status_icon.visible = status_texture != null
	status_icon.tooltip_text = _get_status_tooltip(status_key) if status_icon.visible else ""

func _normalize_status_key(status: String) -> String:
	match status.strip_edges().to_lower():
		"psn", "poison", "poisoned":
			return "psn"
		"tox", "toxic", "badly_poisoned", "badlypoisoned":
			return "tox"
		"brn", "burn", "burned":
			return "brn"
		"par", "paralysis", "paralyzed":
			return "par"
		"slp", "sleep", "sleeping", "asleep":
			return "slp"
		"frz", "freeze", "frozen":
			return "frz"

	return ""

func _get_status_icon_texture(status_key: String) -> Texture2D:
	if status_key == "" or not STATUS_ICON_ROWS.has(status_key):
		return null
	if status_icon_texture_cache.has(status_key):
		return status_icon_texture_cache[status_key] as Texture2D

	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = STATUS_ICON_SHEET
	atlas_texture.region = Rect2(
		0,
		int(STATUS_ICON_ROWS[status_key]) * STATUS_ICON_HEIGHT,
		STATUS_ICON_WIDTH,
		STATUS_ICON_HEIGHT
	)
	status_icon_texture_cache[status_key] = atlas_texture
	return atlas_texture

func _get_status_tooltip(status_key: String) -> String:
	match status_key:
		"psn":
			return "Poisoned"
		"tox":
			return "Badly poisoned"
		"brn":
			return "Burned"
		"par":
			return "Paralyzed"
		"slp":
			return "Asleep"
		"frz":
			return "Frozen"

	return ""

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
	var border_width: int = SLOT_BORDER_WIDTH
	var shadow_size: int = SLOT_SHADOW_SIZE
	if current_is_shiny:
		background = SHINY_SLOT_BG
		border = SHINY_SLOT_BORDER
		shadow = SHINY_SLOT_SHADOW
		border_width = SHINY_SLOT_BORDER_WIDTH
		shadow_size = SHINY_SLOT_SHADOW_SIZE
	if is_hovered:
		background = SHINY_SLOT_HOVER_BG if current_is_shiny else SLOT_HOVER_BG
		border = SHINY_SLOT_HOVER_BORDER if current_is_shiny else SLOT_HOVER_BORDER
		shadow = SHINY_SLOT_HOVER_SHADOW if current_is_shiny else SLOT_HOVER_SHADOW

	add_theme_stylebox_override("panel", _make_slot_style(background, border, shadow, border_width, shadow_size))

func _update_experience_bar(pokemon: Pokemon) -> void:
	var current_level_exp: int = pokemon.current_level_exp
	var next_level_exp: int = pokemon.next_level_exp
	if next_level_exp <= current_level_exp:
		exp_bar.value = 0.0
		exp_bar.visible = false
		return

	var level_exp_range: int = next_level_exp - current_level_exp
	var earned_level_exp: int = clampi(pokemon.experience - current_level_exp, 0, level_exp_range)
	exp_bar.max_value = level_exp_range
	exp_bar.value = earned_level_exp
	exp_bar.visible = true

func _make_slot_style(
	background: Color,
	border: Color,
	shadow: Color,
	border_width: int,
	shadow_size: int
) -> StyleBoxFlat:
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
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 2)
	return style
	
