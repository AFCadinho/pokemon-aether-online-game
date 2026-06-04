extends Panel

class_name BattleLogPanel

@onready var log_text: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/BattleLogText

const COLOR_TEXT := "#f1ede6"
const COLOR_MUTED := "#c7bda8"
const COLOR_TURN := "#ffd875"
const COLOR_FIELD := "#9fd7ff"
const COLOR_DETAIL := "#d8d0bf"
const COLOR_WARNING := "#ffcf8a"
const COLOR_DIVIDER := "#8f7544"
const COLOR_MOVE := "#fff4c2"

var log_buffer := ""

func _ready() -> void:
	log_text.bbcode_enabled = true
	log_text.scroll_following = true

func clear_log() -> void:
	log_buffer = ""
	_sync_log_text()
	
func add_message(message: String) -> void:
	_append_spacing()
	log_buffer += _format_message(message)
	_sync_log_text()
	_scroll_to_bottom.call_deferred()
		
func toggle_log() -> void:
	visible = not visible
	
func is_open() -> bool:
	return visible

func add_turn_header(turn: int) -> void:
	if log_buffer != "":
		log_buffer += "\n"

	log_buffer += "[color=%s]────────────[/color]\n[color=%s][b]Turn %s[/b][/color]" % [COLOR_DIVIDER, COLOR_TURN, turn]
	_sync_log_text()
	_scroll_to_bottom.call_deferred()

func add_gap() -> void:
	if log_buffer == "":
		return

	if log_buffer.ends_with("\n\n"):
		return

	if not log_buffer.ends_with("\n"):
		log_buffer += "\n"

	log_buffer += "\n"
	_sync_log_text()
	_scroll_to_bottom.call_deferred()
	
func add_blank_line() -> void:
	pass

func _append_spacing() -> void:
	if log_buffer == "":
		return

	if log_buffer.ends_with("\n\n"):
		return

	log_buffer += "\n"

func _sync_log_text() -> void:
	log_text.text = log_buffer

func _format_message(message: String) -> String:
	var lines := PackedStringArray()
	for raw_line in message.split("\n"):
		var line := str(raw_line).strip_edges()
		if line == "":
			continue

		lines.append(_format_line(line))

	return "\n".join(lines)

func _format_line(line: String) -> String:
	var escaped := _escape_bbcode(line)
	var lower := line.to_lower()

	if line.begins_with("(") and line.ends_with(")"):
		return "   [color=%s]%s[/color]" % [COLOR_DETAIL, escaped]

	if line.begins_with("- ") or line.begins_with("  - "):
		var detail_line := line
		while detail_line.begins_with("-") or detail_line.begins_with(" "):
			detail_line = detail_line.substr(1).strip_edges()

		var detail := _escape_bbcode(detail_line)
		return "   [color=%s]- %s[/color]" % [COLOR_DETAIL, detail]

	if _is_field_line(lower):
		return "[color=%s]%s[/color]" % [COLOR_FIELD, escaped]

	if lower.contains("failed") or lower.contains("couldn't move"):
		return "[color=%s]%s[/color]" % [COLOR_WARNING, escaped]

	if lower.contains("used "):
		return "[color=%s]%s[/color]" % [COLOR_MOVE, escaped]

	if lower.contains("come back") or lower.begins_with("go!") or lower.contains(" sent out "):
		return "[color=%s]%s[/color]" % [COLOR_MUTED, escaped]

	return "[color=%s]%s[/color]" % [COLOR_TEXT, escaped]

func _is_field_line(lower: String) -> bool:
	return (
		lower.contains("sandstorm")
		or _contains_word(lower, "rain")
		or _contains_word(lower, "sun")
		or _contains_word(lower, "hail")
		or _contains_word(lower, "snow")
		or lower.contains("stealth rock")
		or lower.contains("spikes")
		or lower.contains("leech seed")
		or lower.contains("buffeted")
		or lower.contains("pointed stones")
	)

func _contains_word(value: String, word: String) -> bool:
	var normalized := value
	for character in [".", ",", "!", "?", ":", ";", "(", ")", "-", "_"]:
		normalized = normalized.replace(character, " ")

	return (" " + normalized + " ").contains(" " + word + " ")

func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")

func _scroll_to_bottom() -> void:
	log_text.scroll_to_line(log_text.get_line_count())
