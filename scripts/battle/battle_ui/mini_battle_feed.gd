extends PanelContainer

class_name MiniBattleFeed

const MAX_LINES := 24
const COLOR_TEXT := Color("#f3ead6")
const COLOR_OLDER := Color("#b9c1c8")
const COLOR_TURN := Color("#e0bf68")
const COLOR_FIELD := Color("#9fd0ee")
const COLOR_WARNING := Color("#e6b779")
const COLOR_DAMAGE := Color("#e78b8b")
const COLOR_HEAL := Color("#93d99b")
const FILTERED_MESSAGE_KEYS: Array[String] = [
	"battle.prompt.waiting_opponent",
	"battle.prompt.waiting_other_player",
	"battle.prompt.choose_lead",
	"battle.prompt.choose_another_pokemon",
	"battle.prompt.choose_pokemon",
	"battle.error.cannot_switch",
	"battle.error.bag_unavailable",
]

@onready var scroll_container: ScrollContainer = $MarginContainer/ScrollContainer
@onready var lines_container: VBoxContainer = $MarginContainer/ScrollContainer/Lines

var line_entries: Array[Dictionary] = []
var feed_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_refresh_lines()

func clear() -> void:
	line_entries.clear()
	_refresh_lines()

func set_feed_enabled(enabled: bool) -> void:
	feed_enabled = enabled
	_refresh_lines()

func add_turn_header(turn: int) -> void:
	if turn <= 0:
		return

	_add_line(_t("battle.status.turn", {"turn": turn}), "turn")

func add_message(message: String, kind := "") -> void:
	for raw_line: String in message.split("\n"):
		var line: String = raw_line.strip_edges()
		if not _should_show_message(line):
			continue

		_add_line(line, kind)

func _add_line(line: String, kind: String) -> void:
	if line == "":
		return

	if not line_entries.is_empty() and str(line_entries.back().get("text", "")) == line:
		return

	line_entries.append({
		"text": line,
		"kind": kind,
	})
	while line_entries.size() > MAX_LINES:
		line_entries.pop_front()
	_refresh_lines()
	_scroll_to_bottom.call_deferred()

func _refresh_lines() -> void:
	if lines_container == null:
		return

	for child: Node in lines_container.get_children():
		child.queue_free()

	visible = feed_enabled and not line_entries.is_empty()
	for index in range(line_entries.size()):
		var entry: Dictionary = line_entries[index]
		var label: Label = Label.new()
		label.text = str(entry.get("text", ""))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.max_lines_visible = 2
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", _get_line_color(entry, index))
		lines_container.add_child(label)

func _scroll_to_bottom() -> void:
	if scroll_container == null:
		return

	var vertical_scroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
	if vertical_scroll_bar != null:
		scroll_container.scroll_vertical = int(vertical_scroll_bar.max_value)

func _get_line_color(entry: Dictionary, index: int) -> Color:
	var text: String = str(entry.get("text", ""))
	var kind: String = str(entry.get("kind", ""))
	if kind == "turn":
		return COLOR_TURN

	var lower: String = text.to_lower()
	if _is_damage_line(lower):
		return COLOR_DAMAGE
	if _is_heal_line(lower):
		return COLOR_HEAL
	if _is_field_line(lower):
		return COLOR_FIELD
	if lower.contains("failed") or lower.contains("couldn't move"):
		return COLOR_WARNING

	var newest_index: int = line_entries.size() - 1
	if index < newest_index:
		return COLOR_OLDER
	return COLOR_TEXT

func _should_show_message(line: String) -> bool:
	if line == "":
		return false
	if line.begins_with("──"):
		return false

	var lower: String = line.to_lower()
	for key: String in FILTERED_MESSAGE_KEYS:
		var prefix := _t(key).to_lower()
		if lower.begins_with(prefix):
			return false

	return true

func _is_damage_line(lower: String) -> bool:
	return (
		lower.contains("lost ")
		or lower.contains("took damage")
		or lower.contains("hurt")
		or lower.contains("less than 1%")
	)

func _is_heal_line(lower: String) -> bool:
	return (
		lower.contains("restored")
		or lower.contains("recovered")
		or lower.contains("healed")
	)

func _is_field_line(lower: String) -> bool:
	return (
		lower.contains("sandstorm")
		or _contains_word(lower, "rain")
		or _contains_word(lower, "sun")
		or _contains_word(lower, "hail")
		or _contains_word(lower, "snow")
		or lower.contains("terrain")
		or lower.contains("trick room")
		or lower.contains("stealth rock")
		or lower.contains("spikes")
		or lower.contains("buffeted")
		or lower.contains("pointed stones")
	)

func _contains_word(value: String, word: String) -> bool:
	var normalized: String = value
	for character: String in [".", ",", "!", "?", ":", ";", "(", ")", "-", "_"]:
		normalized = normalized.replace(character, " ")

	return (" " + normalized + " ").contains(" " + word + " ")


func _t(key: String, replacements: Dictionary = {}) -> String:
	var localization_manager := get_tree().root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
