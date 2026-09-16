extends Button
class_name CoopPartyHud

const BACKGROUND := Color("#0b1a2bea")
const BORDER := Color("#315070")
const ACCENT := Color("#60d3ff")
const TEXT := Color("#f4f0de")
const MUTED := Color("#aeb8c5")

var _names: Array[Label] = []
var _portraits: Array[TrainerHeadPortrait] = []
var _fallbacks: Array[Label] = []


func _ready() -> void:
	visible = false
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", _style(BORDER))
	add_theme_stylebox_override("hover", _style(ACCENT))
	add_theme_stylebox_override("pressed", _style(ACCENT))
	add_theme_stylebox_override("focus", _style(ACCENT))
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
	var members := HBoxContainer.new()
	members.mouse_filter = Control.MOUSE_FILTER_IGNORE
	members.add_theme_constant_override("separation", 6)
	column.add_child(members)
	for index in 2:
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_constant_override("separation", 2)
		members.add_child(slot)
		var name := Label.new()
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.add_theme_color_override("font_color", TEXT if index == 0 else MUTED)
		name.add_theme_font_size_override("font_size", 11)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name)
		_names.append(name)
		var frame := CenterContainer.new()
		frame.custom_minimum_size.y = 44
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


func set_members(party: Dictionary, own_id: int) -> void:
	var ids: Array = party.get("memberIds", []) if party.get("memberIds") is Array else []
	visible = ids.size() == 2
	if not visible or _names.size() != 2:
		return
	var own_member: Variant = ids[0]
	var partner_member: Variant = ids[1]
	if int(ids[1]) == own_id:
		own_member = ids[1]
		partner_member = ids[0]
	var names: Dictionary = party.get("memberUsernames", {}) if party.get("memberUsernames") is Dictionary else {}
	var appearances: Dictionary = party.get("memberAppearances", {}) if party.get("memberAppearances") is Dictionary else {}
	for index in 2:
		var member_id := str(own_member if index == 0 else partner_member)
		var name := str(names.get(member_id, "Trainer"))
		_names[index].text = name
		_names[index].tooltip_text = name
		var appearance: Dictionary = appearances.get(member_id, {}) if appearances.get(member_id) is Dictionary else {}
		if appearance != _portraits[index].appearance_state:
			_portraits[index].set_appearance_state(appearance)
		_portraits[index].visible = not str(appearance.get("body", "")).is_empty()
		_fallbacks[index].visible = not _portraits[index].visible
	tooltip_text = "Adventure Party: %s and %s" % [_names[0].text, _names[1].text]


func _style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
