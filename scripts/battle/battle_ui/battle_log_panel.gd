extends Panel

class_name BattleLogPanel

@onready var log_text: RichTextLabel = $MarginContainer/VBoxContainer/BattleLogText

const COLOR_TEXT := "#e6eefb"
const COLOR_MUTED := "#a9bad4"
const COLOR_TURN := "#62d7ff"
const COLOR_FIELD := "#8fc5ff"
const COLOR_DETAIL := "#b8c9e3"
const COLOR_WARNING := "#ffd080"
const COLOR_DIVIDER := "#2468b5"
const COLOR_MOVE := "#86dcff"
const COLOR_DAMAGE := "#ff929f"
const COLOR_HEAL := "#8ee6a5"
const COLOR_EFFECT := "#c5b3ff"
const COLOR_STATUS := "#f2c879"
const COLOR_FAINT := "#ff7f91"
const COLOR_RESULT := "#ffe08a"

var log_buffer := ""

func _ready() -> void:
	log_text.bbcode_enabled = true
	log_text.scroll_following = true

func clear_log() -> void:
	log_buffer = ""
	_sync_log_text()
	
func add_message(message: String, kind := "") -> void:
	_append_spacing()
	log_buffer += _format_message(message, kind)
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

func _format_message(message: String, kind := "") -> String:
	var lines := PackedStringArray()
	for raw_line in message.split("\n"):
		var line := str(raw_line).strip_edges()
		if line == "":
			continue

		lines.append(_format_line(line, kind))

	return "\n".join(lines)

func _format_line(line: String, kind := "") -> String:
	var escaped := _escape_bbcode(line)
	var lower := line.to_lower()
	var explicit_color := _get_kind_color(kind)
	if explicit_color != "":
		return "[color=%s]%s[/color]" % [explicit_color, escaped]

	if line.begins_with("(") and line.ends_with(")"):
		if _is_damage_line(lower):
			return "[color=%s]%s[/color]" % [COLOR_DAMAGE, escaped]
		if _is_heal_line(lower):
			return "[color=%s]%s[/color]" % [COLOR_HEAL, escaped]

		return "[color=%s]%s[/color]" % [COLOR_DETAIL, escaped]

	if line.begins_with("- ") or line.begins_with("  - "):
		var detail_line := line
		while detail_line.begins_with("-") or detail_line.begins_with(" "):
			detail_line = detail_line.substr(1).strip_edges()

		var detail: String = _escape_bbcode(detail_line)
		var detail_lower: String = detail_line.to_lower()
		if _is_damage_line(detail_lower):
			return "[color=%s]- %s[/color]" % [COLOR_DAMAGE, detail]
		if _is_heal_line(detail_lower):
			return "[color=%s]- %s[/color]" % [COLOR_HEAL, detail]

		return "[color=%s]- %s[/color]" % [COLOR_DETAIL, detail]

	if _is_heal_line(lower):
		return "[color=%s]%s[/color]" % [COLOR_HEAL, escaped]

	if _is_field_line(lower):
		return "[color=%s]%s[/color]" % [COLOR_FIELD, escaped]

	if lower.contains("failed") or lower.contains("couldn't move"):
		return "[color=%s]%s[/color]" % [COLOR_WARNING, escaped]

	if lower.contains("used "):
		return "[color=%s]%s[/color]" % [COLOR_MOVE, escaped]

	if lower.contains("come back") or lower.begins_with("go!") or lower.contains(" sent out "):
		return "[color=%s]%s[/color]" % [COLOR_MUTED, escaped]

	return "[color=%s]%s[/color]" % [COLOR_TEXT, escaped]

func _get_kind_color(kind: String) -> String:
	match kind:
		"move":
			return COLOR_MOVE
		"switch":
			return COLOR_MUTED
		"damage":
			return COLOR_DAMAGE
		"heal":
			return COLOR_HEAL
		"field":
			return COLOR_FIELD
		"effect":
			return COLOR_EFFECT
		"status":
			return COLOR_STATUS
		"warning":
			return COLOR_WARNING
		"faint":
			return COLOR_FAINT
		"result":
			return COLOR_RESULT
		"detail":
			return COLOR_DETAIL
	return ""

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
