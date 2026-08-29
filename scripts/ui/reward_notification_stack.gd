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


func _create_card(
	reward_key: String,
	title: String,
	icon_texture: Texture2D,
	amount: int,
	amount_prefix: String,
	amount_suffix: String,
	detail: String
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
	card.add_theme_stylebox_override("panel", _card_style())

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

	var title_label := Label.new()
	title_label.name = "RewardTitle"
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", TEXT_COLOR)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_label)

	var detail_label := Label.new()
	detail_label.name = "RewardDetail"
	detail_label.text = _amount_text(amount, amount_prefix, amount_suffix) if amount > 0 else detail
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 15)
	detail_label.add_theme_color_override("font_color", DETAIL_COLOR)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(detail_label)
	card.set_meta("detail_label", detail_label)
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
	move_child(card, 0)
	card.modulate = Color.WHITE
	var pulse := card.create_tween()
	pulse.tween_property(card, "modulate", Color("#fff0b8"), 0.08)
	pulse.tween_property(card, "modulate", Color.WHITE, 0.16)
	_schedule_expiry(card)


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


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BORDER_COLOR
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_right = 9
	style.corner_radius_bottom_left = 9
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
