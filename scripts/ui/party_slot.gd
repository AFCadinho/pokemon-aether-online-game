extends PanelContainer

signal drag_started(slot_index: int)
signal drag_released(slot_index: int, global_position: Vector2)
signal clicked(slot_index: int)
signal held_item_dropped(slot_index: int, item: Dictionary)
signal context_requested(slot_index: int, global_position: Vector2)

const HeldItemDropTarget := preload("res://scripts/ui/held_item_drop_target_button.gd")

const SLOT_BG := Color("#081522eb")
const SLOT_BORDER := Color("#2d4b66b3")
const SLOT_HOVER_BG := Color("#112a44f2")
const SLOT_HOVER_BORDER := Color("#69b9e8")
const SLOT_PRESSED_BG := Color("#0e2740f5")
const SLOT_PRESSED_BORDER := Color("#8ed7ff")
const SLOT_DROP_BG := Color("#102c3df8")
const SLOT_DROP_BORDER := Color("#63e6d0")
const SHINY_SLOT_BG := Color("#0b1927f2")
const SHINY_SLOT_BORDER := Color("#4d7890cc")
const SHINY_SLOT_HOVER_BG := Color("#132b3ef5")
const SHINY_SLOT_HOVER_BORDER := Color("#78d8f6")
const SLOT_SHADOW := Color(0.0, 0.0, 0.0, 0.18)
const SLOT_HOVER_SHADOW := Color(0.36, 0.7, 0.95, 0.18)
const SLOT_PRESSED_SHADOW := Color(0.42, 0.78, 1.0, 0.28)
const SLOT_DROP_SHADOW := Color(0.34, 0.94, 0.78, 0.3)
const SHINY_SLOT_SHADOW := Color(0.32, 0.82, 1.0, 0.16)
const SHINY_SLOT_HOVER_SHADOW := Color(0.32, 0.82, 1.0, 0.28)
const SLOT_BORDER_WIDTH := 1
const SLOT_SHADOW_SIZE := 3
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
@onready var lead_accent: Panel = $ClickButton/LeadAccent
@onready var shiny_accent: Panel = $ClickButton/ShinyAccent
@onready var seperator: Control = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/Seperator
@onready var level_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/HBoxContainer/LevelLabel

var slot_index: int = -1
var press_global_position: Vector2 = Vector2.ZERO
var is_hovered: bool = false
var is_pressed: bool = false
var is_dragging: bool = false
var is_drop_target: bool = false
var is_lead: bool = false
var current_is_shiny: bool = false
var current_level: int = 0
var current_held_item_id: String = ""
var current_status_key: String = ""
var current_species_id: String = ""
var current_species_source_name: String = ""
var current_nickname: String = ""
var held_item_marker: Control
var status_icon_texture_cache: Dictionary = {}
var held_item_drop_enabled := false

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
	if click_button.has_signal("held_item_dropped") and not click_button.is_connected("held_item_dropped", _on_click_button_held_item_dropped):
		click_button.connect("held_item_dropped", _on_click_button_held_item_dropped)
	if click_button.has_signal("drop_highlight_changed") and not click_button.is_connected("drop_highlight_changed", _on_click_button_drop_highlight_changed):
		click_button.connect("drop_highlight_changed", _on_click_button_drop_highlight_changed)
	click_button.set("held_item_drop_enabled", held_item_drop_enabled)
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	_setup_held_item_marker()
	_refresh_localized_text()
	_refresh_lead_accent()
	_apply_slot_style()
	
func set_pokemon(pokemon: Pokemon) -> void:
	visible = true
	_refresh_lead_accent()
	current_is_shiny = pokemon.shiny
	current_level = pokemon.level
	current_species_id = pokemon.species
	current_species_source_name = pokemon.species
	current_nickname = pokemon.nickname.strip_edges()
	_set_held_item_drop_enabled(pokemon.owned_pokemon_id > 0)
	_refresh_species_name()
	shiny_badge.visible = pokemon.shiny
	_refresh_level_label()
	hp_bar.max_value = max(pokemon.max_hp, 1)
	hp_bar.value = clamp(pokemon.current_hp, 0, pokemon.max_hp)
	_update_health_bar_style()
	_update_experience_bar(pokemon)
	
	pokemon_sprite.texture = PokemonAssets.load_party_icon(pokemon.species, pokemon.shiny)
	_set_held_item_marker(pokemon.item)
	_set_status_icon(pokemon.status)
	click_button.disabled = false
	_apply_slot_style()

func set_pokemon_data(pokemon_data: Dictionary) -> void:
	visible = true
	_refresh_lead_accent()
	var species := str(pokemon_data.get("displaySpecies", pokemon_data.get("species", ""))).strip_edges()
	current_species_id = str(pokemon_data.get(
		"speciesId",
		pokemon_data.get("species_id", pokemon_data.get("species", species))
	))
	current_species_source_name = species
	current_nickname = str(pokemon_data.get("nickname", "")).strip_edges()
	_set_held_item_drop_enabled(false)
	var is_shiny := bool(pokemon_data.get("shiny", false))
	var level := int(pokemon_data.get("level", 0))
	var max_hp: int = maxi(int(pokemon_data.get("maxHp", pokemon_data.get("max_hp", 1))), 1)
	var current_hp: int = int(pokemon_data.get("hp", pokemon_data.get("currentHp", pokemon_data.get("current_hp", max_hp))))
	current_is_shiny = is_shiny
	current_level = level
	_refresh_species_name()
	shiny_badge.visible = is_shiny
	_refresh_level_label()
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(current_hp, 0, max_hp)
	_update_health_bar_style()
	exp_bar.value = 0.0
	exp_bar.visible = false
	pokemon_sprite.texture = PokemonAssets.load_party_icon(species, is_shiny)
	_set_held_item_marker(str(pokemon_data.get("item", pokemon_data.get("heldItemId", ""))))
	_set_status_icon(str(pokemon_data.get("status", "")))
	click_button.disabled = false
	_apply_slot_style()
	
func set_empty() -> void:
	visible = false
	current_is_shiny = false
	current_level = 0
	current_species_id = ""
	current_species_source_name = ""
	current_nickname = ""
	_set_held_item_drop_enabled(false)
	is_hovered = false
	is_pressed = false
	is_dragging = false
	is_drop_target = false
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
	_refresh_lead_accent()
	_apply_slot_style()

func set_lead(value: bool) -> void:
	is_lead = value
	_refresh_lead_accent()

func set_dragging(value: bool) -> void:
	is_dragging = value
	if not value:
		is_pressed = false
	_apply_slot_style()

func set_drop_target(value: bool) -> void:
	if is_drop_target == value:
		return
	is_drop_target = value
	_apply_slot_style()


func _set_held_item_drop_enabled(value: bool) -> void:
	held_item_drop_enabled = value
	if click_button != null:
		click_button.set("held_item_drop_enabled", value)


func _on_click_button_held_item_dropped(item: Dictionary) -> void:
	if held_item_drop_enabled:
		held_item_dropped.emit(slot_index, item.duplicate(true))


func _on_click_button_drop_highlight_changed(highlighted: bool) -> void:
	set_drop_target(highlighted and held_item_drop_enabled)


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var accepted := held_item_drop_enabled and HeldItemDropTarget.can_accept_drag_data(data)
	set_drop_target(accepted)
	return accepted


func _drop_data(_position: Vector2, data: Variant) -> void:
	var item: Dictionary = HeldItemDropTarget.item_from_drag_data(data)
	if not held_item_drop_enabled or item.is_empty():
		return
	set_drop_target(false)
	held_item_dropped.emit(slot_index, item.duplicate(true))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or (
		what == NOTIFICATION_MOUSE_EXIT
		and get_viewport() != null
		and get_viewport().gui_is_dragging()
	):
		set_drop_target(false)

func _refresh_lead_accent() -> void:
	if lead_accent != null:
		lead_accent.visible = is_lead and visible

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
	current_held_item_id = normalized_item_id
	held_item_marker.visible = normalized_item_id != ""
	held_item_marker.tooltip_text = (
		LocalizationManager.text("ui.party.holding_item", {
			"item": normalized_item_id.replace("-", " ").capitalize(),
		})
		if normalized_item_id != ""
		else ""
	)

func _set_status_icon(status: String) -> void:
	if status_icon == null:
		return

	var status_key := _normalize_status_key(status)
	current_status_key = status_key
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
	var key := str({
		"psn": "pokemon.status.poisoned",
		"tox": "pokemon.status.badly_poisoned",
		"brn": "pokemon.status.burned",
		"par": "pokemon.status.paralyzed",
		"slp": "pokemon.status.asleep",
		"frz": "pokemon.status.frozen",
	}.get(status_key, ""))
	return LocalizationManager.text(key) if key != "" else ""

func _on_locale_changed(_locale: String) -> void:
	_refresh_localized_text()

func _refresh_localized_text() -> void:
	if shiny_badge != null:
		shiny_badge.tooltip_text = LocalizationManager.text("ui.party.shiny")
	_refresh_level_label()
	if held_item_marker != null:
		_set_held_item_marker(current_held_item_id)
	if status_icon != null:
		status_icon.tooltip_text = _get_status_tooltip(current_status_key) if status_icon.visible else ""
	_refresh_species_name()


func _refresh_species_name() -> void:
	if name_label == null or current_species_id.strip_edges().is_empty():
		return
	var species_name := current_species_source_name
	var content_localization := get_node_or_null("/root/ContentLocalization")
	if content_localization != null and content_localization.has_method("display_name"):
		species_name = str(content_localization.call(
			"display_name",
			"species",
			current_species_id,
			current_species_source_name
		))
	var display_name := current_nickname if current_nickname != "" else species_name
	name_label.text = display_name
	name_label.tooltip_text = (
		"%s (%s)" % [current_nickname, species_name]
		if current_nickname != "" and current_nickname.to_lower() != species_name.to_lower()
		else display_name
	)

func _refresh_level_label() -> void:
	if level_label == null:
		return
	level_label.text = LocalizationManager.text("ui.party.level", {"level": current_level}) if current_level > 0 else ""

func _on_click_button_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		context_requested.emit(slot_index, mouse_event.global_position)
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		is_pressed = true
		_apply_slot_style()
		press_global_position = mouse_event.global_position
		drag_started.emit(slot_index)
	else:
		is_pressed = false
		_apply_slot_style()
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
	if shiny_accent != null:
		shiny_accent.visible = current_is_shiny and visible
	var background: Color = SLOT_BG
	var border: Color = SLOT_BORDER
	var shadow: Color = SLOT_SHADOW
	var border_width: int = SLOT_BORDER_WIDTH
	var shadow_size: int = SLOT_SHADOW_SIZE
	if current_is_shiny:
		background = SHINY_SLOT_BG
		border = SHINY_SLOT_BORDER
		shadow = SHINY_SLOT_SHADOW
		shadow_size = 4
	if is_hovered:
		background = SHINY_SLOT_HOVER_BG if current_is_shiny else SLOT_HOVER_BG
		border = SHINY_SLOT_HOVER_BORDER if current_is_shiny else SLOT_HOVER_BORDER
		shadow = SHINY_SLOT_HOVER_SHADOW if current_is_shiny else SLOT_HOVER_SHADOW
		shadow_size = 6 if current_is_shiny else 5
	if is_pressed or is_dragging:
		background = SLOT_PRESSED_BG
		border = SHINY_SLOT_HOVER_BORDER if current_is_shiny else SLOT_PRESSED_BORDER
		shadow = SHINY_SLOT_HOVER_SHADOW if current_is_shiny else SLOT_PRESSED_SHADOW
		shadow_size = 6
	if is_drop_target:
		background = SLOT_DROP_BG
		border = SLOT_DROP_BORDER
		shadow = SLOT_DROP_SHADOW
		border_width = 2
		shadow_size = 7

	add_theme_stylebox_override("panel", _make_slot_style(background, border, shadow, border_width, shadow_size))

func _update_health_bar_style() -> void:
	var ratio := hp_bar.value / maxf(hp_bar.max_value, 1.0)
	var fill_color := Color("#58dc78")
	if ratio <= 0.2:
		fill_color = Color("#ef5c67")
	elif ratio <= 0.5:
		fill_color = Color("#efc34f")
	hp_bar.add_theme_stylebox_override("fill", _make_bar_style(fill_color, 5))

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
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = shadow
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 1)
	return style

func _make_bar_style(color: Color, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	return style
	
