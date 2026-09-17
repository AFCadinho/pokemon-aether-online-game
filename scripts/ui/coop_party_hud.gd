extends Button
class_name CoopPartyHud

const BACKGROUND := Color("#0b1a2b70")
const HOVER_BACKGROUND := Color("#0b1a2ba8")
const BORDER := Color("#31507099")
const ACCENT := Color("#60d3ff")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")
const ONLINE := Color("#65e99a")
const OFFLINE := Color("#ff6d7c")

var _names: Array[Label] = []
var _portraits: Array[TrainerHeadPortrait] = []
var _fallbacks: Array[Label] = []
var _presence: Array[Label] = []
var _badges: Array[Label] = []


func _ready() -> void:
	visible = false
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", _style(BORDER))
	add_theme_stylebox_override("hover", _style(ACCENT, HOVER_BACKGROUND))
	add_theme_stylebox_override("pressed", _style(ACCENT, HOVER_BACKGROUND))
	add_theme_stylebox_override("focus", _style(ACCENT, HOVER_BACKGROUND))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	margin.add_child(column)
	var title := Label.new()
	title.text = "PARTY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 11)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var members := VBoxContainer.new()
	members.mouse_filter = Control.MOUSE_FILTER_IGNORE
	members.add_theme_constant_override("separation", 4)
	column.add_child(members)
	for index in 2:
		var slot := HBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_constant_override("separation", 8)
		members.add_child(slot)
		var frame := CenterContainer.new()
		frame.custom_minimum_size = Vector2(42, 42)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(frame)
		var portrait := TrainerHeadPortrait.new()
		portrait.custom_minimum_size = Vector2(42, 42)
		frame.add_child(portrait)
		_portraits.append(portrait)
		var fallback := Label.new()
		fallback.text = "?"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_color_override("font_color", MUTED)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fallback)
		_fallbacks.append(fallback)
		var presence := Label.new()
		presence.text = "●"
		presence.tooltip_text = "Online"
		presence.add_theme_font_size_override("font_size", 13)
		presence.add_theme_color_override("font_color", ONLINE)
		presence.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(presence)
		_presence.append(presence)
		var badge := Label.new()
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", ACCENT)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)
		_badges.append(badge)
		var name := Label.new()
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.add_theme_color_override("font_color", TEXT if index == 0 else MUTED)
		name.add_theme_font_size_override("font_size", 12)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name)
		_names.append(name)


func set_members(party: Dictionary, own_id: int) -> void:
	var ids: Array = party.get("memberIds", []) if party.get("memberIds") is Array else []
	visible = ids.size() == 2
	if not visible or _names.size() != 2:
		return
	var leader_id := int(party.get("leaderId", 0))
	if leader_id not in [int(ids[0]), int(ids[1])]:
		leader_id = int(ids[0])
	var partner_id := int(ids[1]) if int(ids[0]) == leader_id else int(ids[0])
	var names: Dictionary = party.get("memberUsernames", {}) if party.get("memberUsernames") is Dictionary else {}
	var appearances: Dictionary = party.get("memberAppearances", {}) if party.get("memberAppearances") is Dictionary else {}
	var online: Dictionary = party.get("memberOnline", {}) if party.get("memberOnline") is Dictionary else {}
	# During an active shared battle the runtime heartbeat is authoritative: it
	# proves the partner is actively polling the same battle even if the general
	# overworld presence lookup is briefly stale.
	var coop_partner_connected := not CoopService.activity.is_empty() and bool(CoopService.activity.get("partnerConnected", false))
	for index in 2:
		var member_id := str(leader_id if index == 0 else partner_id)
		var name := str(names.get(member_id, "")).strip_edges()
		if name.is_empty():
			name = "Trainer #%s" % member_id
		_names[index].text = name
		_names[index].tooltip_text = name
		_badges[index].text = "LEADER · #1" if index == 0 else "#2"
		_badges[index].add_theme_color_override("font_color", ACCENT if index == 0 else MUTED)
		var appearance: Dictionary = appearances.get(member_id, {}) if appearances.get(member_id) is Dictionary else {}
		if appearance != _portraits[index].appearance_state:
			_portraits[index].set_appearance_state(appearance)
		_portraits[index].visible = not str(appearance.get("body", "")).is_empty()
		_fallbacks[index].visible = not _portraits[index].visible
		_fallbacks[index].text = name.substr(0, 1).to_upper()
		var is_online := true if int(member_id) == own_id else (bool(online.get(member_id, false)) or coop_partner_connected)
		_presence[index].add_theme_color_override("font_color", ONLINE if is_online else OFFLINE)
		_presence[index].tooltip_text = "Online" if is_online else "Offline"
	tooltip_text = "Adventure Party: %s and %s" % [_names[0].text, _names[1].text]


func _style(border: Color, background := BACKGROUND) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
