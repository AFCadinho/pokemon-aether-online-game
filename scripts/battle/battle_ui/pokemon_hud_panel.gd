extends PanelContainer

@onready var active_info_rows: Array[Node] = [
	$MarginContainer/VBoxContainer/PokemonInfoHud,
	$MarginContainer/VBoxContainer/PokemonInfoHud2,
]

var experience_bar_enabled := false

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
const POKEMON_GENDER_DISPLAY := preload("res://scripts/ui/pokemon_gender_display.gd")
const MALE_GENDER_ICON: Texture2D = preload("res://assets/gender/male.png")
const FEMALE_GENDER_ICON: Texture2D = preload("res://assets/gender/female.png")

var status_icon_texture_cache: Dictionary = {}
var localization_manager: Node

func _ready() -> void:
	localization_manager = get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null and not localization_manager.locale_changed.is_connected(_on_locale_changed):
		localization_manager.locale_changed.connect(_on_locale_changed)
	for row_index in range(active_info_rows.size()):
		_clear_active_info_row_data(row_index)
		_set_active_info_row_visible(row_index, false)

func set_pokemon_data(
	species: String,
	level: int,
	current_hp: int,
	max_hp: int,
	status: String = "",
	gender: String = "",
	is_shiny: bool = false,
	experience_data: Dictionary = {},
	display_name: String = ""
) -> void:
	_set_active_info_row_data(0, species, level, current_hp, max_hp, status, gender, is_shiny, experience_data, display_name)

func set_experience_bar_enabled(enabled: bool) -> void:
	experience_bar_enabled = enabled
	for row_index in range(active_info_rows.size()):
		_update_experience_bar(active_info_rows[row_index], {})

func clear_active_pokemon_data() -> void:
	_clear_active_info_row_data(0)
	_set_active_info_row_visible(0, false)

func set_owned_icon_visible(is_owned: bool) -> void:
	for row: Node in active_info_rows:
		var owned_icon := row.get_node_or_null(
			"MarginContainer/VBoxContainer/TopRow/NameContainer/OwnedIcon"
		) as TextureRect
		if owned_icon != null:
			owned_icon.visible = is_owned


func _clear_active_info_row_data(row_index: int) -> void:
	if row_index < 0 or row_index >= active_info_rows.size():
		return

	var row: Node = active_info_rows[row_index]
	row.remove_meta("battle_hud_data")
	var name_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/NameContainer/NameLabel") as Label
	if name_label != null:
		name_label.text = ""

	var owned_icon := row.get_node_or_null(
		"MarginContainer/VBoxContainer/TopRow/NameContainer/OwnedIcon"
	) as TextureRect
	if owned_icon != null:
		owned_icon.visible = false

	_set_shiny_badge(row, false)
	_set_gender(row, "")
	_set_status(row, "")

	var level_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/HBoxContainer/LevelLabel") as Label
	if level_label != null:
		level_label.text = _t("battle.hud.level_unknown")

	var hp_bar: ProgressBar = row.get_node_or_null("MarginContainer/VBoxContainer/HPRow/HpBar") as ProgressBar
	if hp_bar != null:
		hp_bar.max_value = 100
		hp_bar.value = 100
	_update_experience_bar(row, {})

func _set_active_info_row_data(
	row_index: int,
	species: String,
	level: int,
	current_hp: int,
	max_hp: int,
	status: String = "",
	gender: String = "",
	is_shiny: bool = false,
	experience_data: Dictionary = {},
	display_name: String = ""
) -> void:
	if row_index < 0 or row_index >= active_info_rows.size():
		return

	var row: Node = active_info_rows[row_index]
	row.set_meta("battle_hud_data", {
		"species": species,
		"level": level,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"status": status,
		"gender": gender,
		"is_shiny": is_shiny,
		"experience_data": experience_data.duplicate(true),
		"display_name": display_name,
	})
	_set_active_info_row_visible(row_index, true)

	var name_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/NameContainer/NameLabel") as Label
	if name_label != null:
		name_label.text = display_name if display_name.strip_edges() != "" else species

	_set_shiny_badge(row, is_shiny)
	var level_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/HBoxContainer/LevelLabel") as Label
	if level_label != null:
		level_label.text = _t("battle.hud.level", {"level": level})

	var hp_bar: ProgressBar = row.get_node_or_null("MarginContainer/VBoxContainer/HPRow/HpBar") as ProgressBar
	var visible_hp_percent := _to_visible_hp_percent(current_hp, max_hp)
	if hp_bar != null:
		hp_bar.max_value = 100
		hp_bar.value = visible_hp_percent
	_update_experience_bar(row, experience_data)

	_set_gender(row, gender)
	_set_status(row, status)

func _update_experience_bar(row: Node, experience_data: Dictionary) -> void:
	var exp_row := row.get_node_or_null("MarginContainer/VBoxContainer/ExpRow") as Control
	var exp_bar: ProgressBar = row.get_node_or_null("MarginContainer/VBoxContainer/ExpRow/ExpBar") as ProgressBar
	if exp_bar == null:
		return

	if not experience_bar_enabled or experience_data.is_empty():
		if exp_row != null:
			exp_row.visible = false
		exp_bar.value = 0
		return

	var current_exp: int = int(experience_data.get("experience", 0))
	var current_level_exp: int = int(experience_data.get("currentLevelExp", experience_data.get("current_level_exp", 0)))
	var next_level_exp: int = int(experience_data.get("nextLevelExp", experience_data.get("next_level_exp", 0)))
	if next_level_exp <= current_level_exp:
		if exp_row != null:
			exp_row.visible = false
		exp_bar.value = 0
		return

	var earned_level_exp: int = clamp(current_exp - current_level_exp, 0, next_level_exp - current_level_exp)
	exp_bar.max_value = next_level_exp - current_level_exp
	exp_bar.value = earned_level_exp
	if exp_row != null:
		exp_row.visible = true

func _set_shiny_badge(row: Node, is_shiny: bool) -> void:
	var shiny_badge: TextureRect = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/NameContainer/ShinyBadge") as TextureRect
	if shiny_badge == null:
		return

	shiny_badge.visible = is_shiny

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

	var presentation: Dictionary = POKEMON_GENDER_DISPLAY.presentation(gender)
	gender_icon.visible = bool(presentation.get("visible", false))
	if not gender_icon.visible:
		gender_icon.texture = null
		gender_icon.modulate = Color.WHITE
		gender_icon.tooltip_text = ""
		return

	var symbol := str(presentation.get("symbol", ""))
	# PokemonGenderDisplay normalizes every accepted male value to "M". Keep
	# the original gender artwork rather than deriving a replacement tint.
	gender_icon.texture = MALE_GENDER_ICON if symbol == "M" else FEMALE_GENDER_ICON
	# The gender artwork already contains its intended blue or pink color.
	gender_icon.modulate = Color.WHITE
	gender_icon.tooltip_text = _t(str(presentation.get("localization_key", "")))

func _set_status(row: Node, status: String) -> void:
	var status_icon: TextureRect = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/HBoxContainer/StatusIcon") as TextureRect
	if status_icon == null:
		var legacy_status_label: Label = row.get_node_or_null("MarginContainer/VBoxContainer/TopRow/HBoxContainer/StatusLabel") as Label
		if legacy_status_label != null:
			legacy_status_label.text = ""
			legacy_status_label.visible = false
		return

	var status_key: String = _normalize_status_key(status)
	var status_texture: Texture2D = _get_status_icon_texture(status_key)
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
			return _t("pokemon.status.poisoned")
		"tox":
			return _t("pokemon.status.badly_poisoned")
		"brn":
			return _t("pokemon.status.burned")
		"par":
			return _t("pokemon.status.paralyzed")
		"slp":
			return _t("pokemon.status.asleep")
		"frz":
			return _t("pokemon.status.frozen")

	return ""


func _on_locale_changed(_locale: String) -> void:
	for row_index in range(active_info_rows.size()):
		var row := active_info_rows[row_index]
		var data_value: Variant = row.get_meta("battle_hud_data", {})
		if not data_value is Dictionary or (data_value as Dictionary).is_empty():
			continue
		var data := data_value as Dictionary
		_set_active_info_row_data(
			row_index,
			str(data.get("species", "")),
			int(data.get("level", 0)),
			int(data.get("current_hp", 0)),
			int(data.get("max_hp", 0)),
			str(data.get("status", "")),
			str(data.get("gender", "")),
			bool(data.get("is_shiny", false)),
			data.get("experience_data", {}) as Dictionary,
			str(data.get("display_name", ""))
		)

func _to_visible_hp_percent(current_hp: int, max_hp: int) -> int:
	if max_hp <= 0:
		return 0
		
	if current_hp <= 0:
		return 0
		
	return ceili((float(current_hp) / float(max_hp)) * 100.0)


func _t(key: String, replacements: Dictionary = {}) -> String:
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
