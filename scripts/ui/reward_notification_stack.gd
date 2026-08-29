extends VBoxContainer

class_name RewardNotificationStack

const CARD_WIDTH := 288.0
const CARD_HEIGHT := 58.0
const ICON_SIZE := 38.0
const DEFAULT_DISPLAY_SECONDS := 4.0
const DEFAULT_MAX_VISIBLE := 4
const TEXT_COLOR := Color("#f4f0de")
const DETAIL_COLOR := Color("#ffd45a")
const SURFACE_COLOR := Color("#081522f2")
const BORDER_COLOR := Color("#d8b767cc")
const SUBTITLE_COLOR := Color("#aeb8c5")

@export_range(0.1, 30.0, 0.1) var display_seconds := DEFAULT_DISPLAY_SECONDS
@export_range(1, 10, 1) var max_visible := DEFAULT_MAX_VISIBLE
@export var auto_expire := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)


func show_reward(
	reward_key: String,
	title: String,
	icon_texture: Texture2D = null,
	amount: int = 0,
	amount_prefix: String = "",
	amount_suffix: String = "",
	detail: String = ""
) -> void:
	var normalized_key := reward_key.strip_edges().to_lower()
	var clean_title := title.strip_edges()
	if normalized_key == "" or clean_title == "":
		return

	var existing_card := _find_card(normalized_key)
	if existing_card != null and amount > 0:
		_merge_card(existing_card, amount, amount_prefix, amount_suffix)
		return

	var card := _create_card(
		normalized_key,
		clean_title,
		icon_texture,
		maxi(amount, 0),
		amount_prefix,
		amount_suffix,
		detail
	)
	add_child(card)
	move_child(card, 0)
	_trim_oldest_cards()
	_animate_card_in.call_deferred(card)
	_schedule_expiry(card)


func show_pokemon_event(
	reward_key: String,
	title: String,
	subtitle: String,
	icon_texture: Texture2D = null,
	detail: String = "",
	badge_text: String = "",
	accent_color: Color = BORDER_COLOR,
	trailing_icon: Texture2D = null,
	previous_level: int = 0,
	current_level: int = 0
) -> void:
	var normalized_key := reward_key.strip_edges().to_lower()
	var clean_title := title.strip_edges()
	if normalized_key == "" or clean_title == "":
		return

	var existing_card := _find_card(normalized_key)
	if existing_card != null and current_level > 0:
		_merge_level_card(existing_card, previous_level, current_level)
		return

	var level_detail := detail
	if current_level > 0:
		level_detail = _level_text(previous_level, current_level)
	var card := _create_card(
		normalized_key,
		clean_title,
		icon_texture,
		0,
		"",
		"",
		level_detail,
		subtitle.strip_edges(),
		badge_text.strip_edges(),
		accent_color,
		trailing_icon
	)
	if current_level > 0:
		card.set_meta("level_start", maxi(previous_level, 0))
		card.set_meta("level_end", current_level)
	add_child(card)
	move_child(card, 0)
	_trim_oldest_cards()
	_animate_card_in.call_deferred(card)
	_schedule_expiry(card)


func _create_card(
	reward_key: String,
	title: String,
	icon_texture: Texture2D,
	amount: int,
	amount_prefix: String,
	amount_suffix: String,
	detail: String,
	subtitle: String = "",
	badge_text: String = "",
	accent_color: Color = BORDER_COLOR,
	trailing_icon: Texture2D = null
) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "RewardCard"
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("reward_key", reward_key)
	card.set_meta("amount", amount)
	card.set_meta("amount_prefix", amount_prefix)
	card.set_meta("amount_suffix", amount_suffix)
	card.set_meta("revision", 1)
	card.add_theme_stylebox_override("panel", _card_style(accent_color))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.name = "RewardIcon"
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = icon_texture
	row.add_child(icon)

	var text_stack := VBoxContainer.new()
	text_stack.name = "RewardText"
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", -1)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_stack)

	var title_label := Label.new()
	title_label.name = "RewardTitle"
	title_label.text = title
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", TEXT_COLOR)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(title_label)

	if subtitle != "":
		var subtitle_label := Label.new()
		subtitle_label.name = "RewardSubtitle"
		subtitle_label.text = subtitle
		subtitle_label.clip_text = true
		subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		subtitle_label.add_theme_font_size_override("font_size", 11)
		subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
		subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_stack.add_child(subtitle_label)

	var detail_label := Label.new()
	detail_label.name = "RewardDetail"
	detail_label.text = _amount_text(amount, amount_prefix, amount_suffix) if amount > 0 else detail
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 15)
	detail_label.add_theme_color_override("font_color", DETAIL_COLOR)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(detail_label)
	card.set_meta("detail_label", detail_label)

	if badge_text != "":
		var badge := PanelContainer.new()
		badge.name = "RewardBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _badge_style(accent_color))
		var badge_label := Label.new()
		badge_label.name = "RewardBadgeLabel"
		badge_label.text = badge_text
		badge_label.add_theme_font_size_override("font_size", 10)
		badge_label.add_theme_color_override("font_color", TEXT_COLOR)
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(badge_label)
		row.add_child(badge)

	if trailing_icon != null:
		var trailing := TextureRect.new()
		trailing.name = "RewardTrailingIcon"
		trailing.custom_minimum_size = Vector2(24, 24)
		trailing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trailing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trailing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trailing.texture = trailing_icon
		row.add_child(trailing)
	return card


func _find_card(reward_key: String) -> PanelContainer:
	for child: Node in get_children():
		if child is PanelContainer and str(child.get_meta("reward_key", "")) == reward_key:
			return child as PanelContainer
	return null


func _merge_card(card: PanelContainer, amount: int, amount_prefix: String, amount_suffix: String) -> void:
	var total := maxi(int(card.get_meta("amount", 0)), 0) + amount
	card.set_meta("amount", total)
	card.set_meta("amount_prefix", amount_prefix)
	card.set_meta("amount_suffix", amount_suffix)
	card.set_meta("revision", int(card.get_meta("revision", 0)) + 1)
	var detail_label := card.get_meta("detail_label", null) as Label
	if detail_label != null:
		detail_label.text = _amount_text(total, amount_prefix, amount_suffix)
	_pulse_card(card)
	_schedule_expiry(card)


func _merge_level_card(card: PanelContainer, previous_level: int, current_level: int) -> void:
	var level_start := int(card.get_meta("level_start", 0))
	if level_start <= 0:
		level_start = maxi(previous_level, 0)
	var level_end := maxi(current_level, int(card.get_meta("level_end", 0)))
	card.set_meta("level_start", level_start)
	card.set_meta("level_end", level_end)
	card.set_meta("revision", int(card.get_meta("revision", 0)) + 1)
	var detail_label := card.get_meta("detail_label", null) as Label
	if detail_label != null:
		detail_label.text = _level_text(level_start, level_end)
	_pulse_card(card)
	_schedule_expiry(card)


func _pulse_card(card: PanelContainer) -> void:
	move_child(card, 0)
	card.modulate = Color.WHITE
	var pulse := card.create_tween()
	pulse.tween_property(card, "modulate", Color("#fff0b8"), 0.08)
	pulse.tween_property(card, "modulate", Color.WHITE, 0.16)


func _level_text(previous_level: int, current_level: int) -> String:
	if previous_level > 0 and current_level - previous_level > 1:
		return "Lv. %d → %d" % [previous_level, current_level]
	return "Lv. %d" % current_level


func _amount_text(amount: int, prefix: String, suffix: String) -> String:
	return "%s%s%s" % [prefix, _format_amount(amount), suffix]


func _format_amount(value: int) -> String:
	var value_text := str(maxi(value, 0))
	var formatted := ""
	var counter := 0
	for index in range(value_text.length() - 1, -1, -1):
		if counter > 0 and counter % 3 == 0:
			formatted = "," + formatted
		formatted = value_text.substr(index, 1) + formatted
		counter += 1
	return formatted


func _trim_oldest_cards() -> void:
	while get_child_count() > max_visible:
		var oldest := get_child(get_child_count() - 1)
		remove_child(oldest)
		oldest.queue_free()


func _animate_card_in(card: PanelContainer) -> void:
	if not is_instance_valid(card) or card.get_parent() != self:
		return
	card.modulate = Color(1, 1, 1, 0)
	var tween := card.create_tween()
	tween.tween_property(card, "modulate", Color.WHITE, 0.18)


func _schedule_expiry(card: PanelContainer) -> void:
	if not auto_expire:
		return
	var revision := int(card.get_meta("revision", 0))
	_expire_card(card, revision)


func _expire_card(card: PanelContainer, revision: int) -> void:
	await get_tree().create_timer(display_seconds).timeout
	if (
		not is_instance_valid(card)
		or card.get_parent() != self
		or int(card.get_meta("revision", -1)) != revision
	):
		return
	var tween := card.create_tween()
	tween.tween_property(card, "modulate", Color(1, 1, 1, 0), 0.22)
	await tween.finished
	if is_instance_valid(card):
		card.queue_free()


func _card_style(accent_color: Color = BORDER_COLOR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 9
	style.corner_radius_bottom_left = 9
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func _badge_style(accent_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent_color.darkened(0.55)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 6
	style.content_margin_top = 2
	style.content_margin_right = 6
	style.content_margin_bottom = 2
	return style
