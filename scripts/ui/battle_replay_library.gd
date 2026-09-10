extends Control

const TrainerHeadPortraitScript := preload("res://scripts/ui/trainer_head_portrait.gd")

signal closed
signal playback_requested(recording: Dictionary)
signal playback_failed(message: String)

var shell: PanelContainer
var list: VBoxContainer
var scroll: ScrollContainer
var status: Label
var usage: Label
var search: LineEdit
var outcome: OptionButton
var difficulty: OptionButton
var favorites: CheckButton
var share_code_input: LineEdit
var shared_code_modal: Control
var shared_code_feedback: Label
var previous: Button
var next: Button
var reset_filters_button: Button
var category_buttons: Dictionary = {}
var category := ""
var offset := 0
var busy := false
var return_scroll := 0
var team_strip_factory: Callable
var refresh_pending := false
var search_filter_revision := 0

const INK := Color("#eaf3ff")
const MUTED := Color("#91a7bf")
const ACCENT := Color("#55d5ff")
const ACCENT_DARK := Color("#123c58")
const SURFACE := Color("#101e32")
const SURFACE_RAISED := Color("#162b45")
const DANGER := Color("#d96570")
const AI_SCIENTIST_PORTRAIT := preload("res://assets/sprites/trainer_cards/showdown/scientist-gen7.png")
const AI_VETERAN_PORTRAIT := preload("res://assets/sprites/trainer_cards/showdown/veteran-gen7.png")
const REPLAY_CATEGORIES := [
	{"id": "", "label": "category_all"},
	{"id": "ai_sparring", "label": "category_ai_sparring"},
	{"id": "pvp", "label": "category_pvp"},
	{"id": "pve", "label": "category_pve"},
	{"id": "wild", "label": "category_wild"},
]

func _t(key: String, args: Dictionary = {}) -> String:
	return LocalizationManager.text("ui.replays." + key, args)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shell = PanelContainer.new()
	shell.add_theme_font_size_override("font_size", 18)
	shell.add_theme_stylebox_override("panel", _style(Color("#0c1829"), Color("#42739b"), 14, 1, 24, 24, 18, 18))
	add_child(shell)
	resized.connect(_position_shell)
	shell.minimum_size_changed.connect(func(): _position_shell.call_deferred())
	_position_shell.call_deferred()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	shell.add_child(layout)
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _style(Color("#11243a"), Color("#294e70"), 10, 1, 16, 16, 13, 13))
	layout.add_child(header_panel)
	var header := HBoxContainer.new()
	header_panel.add_child(header)
	var accent := ColorRect.new()
	accent.color = ACCENT
	accent.custom_minimum_size = Vector2(4, 42)
	header.add_child(accent)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title := Label.new()
	title.text = _t("title")
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", INK)
	heading.add_child(title)
	var intro := Label.new()
	intro.text = _t("intro")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", MUTED)
	heading.add_child(intro)
	_button(header, _t("watch_shared_title"), _open_shared_replay_dialog, "shared")
	_button(header, _t("close"), func(): hide(); closed.emit(), "quiet")
	var filter_panel := PanelContainer.new()
	filter_panel.add_theme_stylebox_override("panel", _style(Color("#0a1524"), Color("#1f405e"), 10, 1, 10, 10, 9, 9))
	layout.add_child(filter_panel)
	var filter_layout := VBoxContainer.new()
	filter_layout.add_theme_constant_override("separation", 5)
	filter_panel.add_child(filter_layout)
	var category_bar := HBoxContainer.new()
	category_bar.add_theme_constant_override("separation", 10)
	filter_layout.add_child(category_bar)
	var filter_caption := Label.new()
	filter_caption.text = "BROWSE REPLAYS"
	filter_caption.custom_minimum_size.x = 90
	filter_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	filter_caption.add_theme_font_size_override("font_size", 12)
	filter_caption.add_theme_color_override("font_color", ACCENT)
	category_bar.add_child(filter_caption)
	var categories := HFlowContainer.new()
	categories.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	categories.add_theme_constant_override("horizontal_separation", 6)
	categories.add_theme_constant_override("vertical_separation", 6)
	category_bar.add_child(categories)
	for entry: Dictionary in REPLAY_CATEGORIES:
		var category_id := str(entry["id"])
		var tab := _category_button(categories, _t(str(entry["label"])), category_id)
		category_buttons[category_id] = tab
	_refresh_category_tabs()
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("horizontal_separation", 8)
	filter_layout.add_child(filters)
	search = LineEdit.new()
	search.placeholder_text = _t("search")
	search.max_length = 80
	search.custom_minimum_size.x = 180
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(search)
	search.text_changed.connect(_schedule_search_filter)
	search.text_submitted.connect(_filter_from_search_submit)
	filters.add_child(search)
	outcome = OptionButton.new()
	for key: String in ["all_results", "win", "loss", "draw"]:
		outcome.add_item(_t(key))
	outcome.item_selected.connect(func(_i: int): _filter())
	_style_option(outcome)
	filters.add_child(outcome)
	difficulty = OptionButton.new()
	for label: String in [_t("all_difficulties"), "Scholar", "Grandmaster Intermediate", "Grandmaster Hard", "Grandmaster Elite", "Grandmaster Nightmare"]:
		difficulty.add_item(label)
	difficulty.item_selected.connect(func(_i: int): _filter())
	difficulty.custom_minimum_size.x = 210
	_style_option(difficulty)
	filters.add_child(difficulty)
	_refresh_category_tabs()
	favorites = CheckButton.new()
	favorites.text = _t("favorites")
	_style_favorites_toggle(favorites)
	favorites.toggled.connect(func(_value: bool): _filter())
	filters.add_child(favorites)
	reset_filters_button = _button(filters, _t("reset_filters"), _reset_filters, "quiet")
	reset_filters_button.custom_minimum_size.x = 112
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 12)
	layout.add_child(summary)
	usage = Label.new()
	usage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	usage.add_theme_font_size_override("font_size", 14)
	usage.add_theme_color_override("font_color", MUTED)
	summary.add_child(usage)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", MUTED)
	summary.add_child(status)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(pager)
	previous = _button(pager, _t("previous_page"), func(): offset = maxi(0, offset - 20); refresh(), "quiet")
	next = _button(pager, _t("next_page"), func(): offset += 20; refresh(), "quiet")

func _style(color: Color, border: Color, radius: int, width := 0, left := 10, right := 10, top := 7, bottom := 7) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	return box

func _button(parent: Node, text: String, callback: Callable, variant := "secondary") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	var base := Color("#1a314b")
	var hover := Color("#244969")
	var border := Color("#385c7b")
	var font := INK
	if variant == "primary":
		base = Color("#126b91")
		hover = Color("#198abd")
		border = ACCENT
	elif variant == "shared":
		base = Color("#0d5174")
		hover = Color("#137aaa")
		border = ACCENT
		button.custom_minimum_size = Vector2(154, 44)
		button.add_theme_font_size_override("font_size", 15)
	elif variant == "danger":
		base = Color("#542632")
		hover = Color("#763444")
		border = DANGER
	elif variant == "quiet":
		base = Color("#132237")
		hover = Color("#1b3853")
		border = Color("#284966")
		font = MUTED
	button.add_theme_stylebox_override("normal", _style(base, border, 7, 1))
	button.add_theme_stylebox_override("hover", _style(hover, border.lightened(0.18), 7, 1))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.16), border, 7, 1))
	button.add_theme_stylebox_override("disabled", _style(Color("#101d2d"), Color("#233a52"), 7, 1))
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#52657a"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _category_button(parent: Node, text: String, category_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(func():
		if category == category_id:
			return
		category = category_id
		_refresh_category_tabs()
		_filter())
	parent.add_child(button)
	return button

func _filter_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#7fa5bf"))
	return label

func _refresh_category_tabs() -> void:
	for category_id: String in category_buttons:
		var button := category_buttons[category_id] as Button
		var selected := category_id == category
		var base := Color("#126b91") if selected else Color("#0c1b2b")
		var hover := Color("#198abd") if selected else Color("#142f47")
		var border := ACCENT if selected else Color("#24445f")
		var width := 2 if selected else 1
		button.add_theme_stylebox_override("normal", _style(base, border, 7, width, 12, 12, 7, 7))
		button.add_theme_stylebox_override("hover", _style(hover, border.lightened(0.18), 7, width, 12, 12, 7, 7))
		button.add_theme_stylebox_override("pressed", _style(base.darkened(0.16), border, 7, width, 12, 12, 7, 7))
		button.add_theme_color_override("font_color", INK if selected else MUTED)
		button.add_theme_color_override("font_hover_color", INK)
	if difficulty != null:
		var ai_sparring_selected := category == "ai_sparring"
		difficulty.visible = ai_sparring_selected
		if not ai_sparring_selected:
			difficulty.select(0)

func _style_line_edit(control: LineEdit) -> void:
	control.add_theme_stylebox_override("normal", _style(Color("#08121f"), Color("#315574"), 7, 1, 12, 12, 8, 8))
	control.add_theme_stylebox_override("focus", _style(Color("#0c1a2a"), ACCENT, 7, 1, 12, 12, 8, 8))
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_placeholder_color", Color("#7e92a8"))

func _style_option(control: OptionButton) -> void:
	control.custom_minimum_size = Vector2(145, 38)
	control.focus_mode = Control.FOCUS_NONE
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.add_theme_constant_override("arrow_margin", 12)
	control.add_theme_icon_override("arrow", _dropdown_arrow_icon())
	control.add_theme_stylebox_override("normal", _style(Color("#13243a"), Color("#315574"), 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("hover", _style(Color("#1a3550"), ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("pressed", _style(Color("#0e2033"), ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("focus", _style(Color("#13243a"), ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.add_theme_color_override("font_pressed_color", INK)
	var popup := control.get_popup()
	popup.transparent_bg = true
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", INK)
	popup.add_theme_constant_override("item_start_padding", 12)
	popup.add_theme_constant_override("item_end_padding", 12)
	popup.add_theme_constant_override("v_separation", 4)
	popup.add_theme_stylebox_override("panel", _style(Color("#0b1727"), Color("#315574"), 8, 1, 8, 8, 7, 7))
	popup.add_theme_stylebox_override("hover", _style(Color("#1a4160"), ACCENT, 6, 1, 8, 8, 5, 5))
	popup.add_theme_icon_override("radio_checked", _filter_icon(true))
	popup.add_theme_icon_override("radio_unchecked", _filter_icon(false))

func _style_favorites_toggle(control: CheckButton) -> void:
	control.custom_minimum_size = Vector2(126, 38)
	control.focus_mode = Control.FOCUS_NONE
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_constant_override("h_separation", 7)
	control.add_theme_stylebox_override("normal", _style(Color("#13243a"), Color("#315574"), 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("hover", _style(Color("#1a3550"), ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("pressed", _style(Color("#0e2033"), ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("normal_pressed", _style(ACCENT_DARK, ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("hover_pressed", _style(Color("#155675"), ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_stylebox_override("pressed_pressed", _style(Color("#0f455f"), ACCENT, 7, 1, 10, 10, 8, 8))
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.add_theme_color_override("font_pressed_color", INK)
	control.add_theme_icon_override("unchecked", _filter_icon(false))
	control.add_theme_icon_override("unchecked_hover", _filter_icon(false, true))
	control.add_theme_icon_override("unchecked_pressed", _filter_icon(false, true))
	control.add_theme_icon_override("checked", _filter_icon(true))
	control.add_theme_icon_override("checked_hover", _filter_icon(true, true))
	control.add_theme_icon_override("checked_pressed", _filter_icon(true, true))

func _dropdown_arrow_icon() -> ImageTexture:
	var image := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color("#00000000"))
	for offset in range(4):
		image.set_pixel(2 + offset, 2 + offset, ACCENT)
		image.set_pixel(9 - offset, 2 + offset, ACCENT)
	return ImageTexture.create_from_image(image)

func _filter_icon(checked: bool, highlighted := false) -> ImageTexture:
	var size := 18
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var border := ACCENT if checked or highlighted else Color("#476b89")
	var fill := Color("#126b91") if checked else Color("#13243a")
	image.fill(Color("#00000000"))
	for y in range(2, size - 2):
		for x in range(2, size - 2):
			var is_border := x < 3 or x > size - 4 or y < 3 or y > size - 4
			image.set_pixel(x, y, border if is_border else fill)
	if checked:
		for offset in range(4):
			image.set_pixel(4 + offset, 8 + offset, INK)
			image.set_pixel(4 + offset, 9 + offset, INK)
		for offset in range(6):
			image.set_pixel(7 + offset, 11 - offset, INK)
			image.set_pixel(7 + offset, 12 - offset, INK)
	return ImageTexture.create_from_image(image)

func open_library() -> void:
	show()
	refresh()

func _filter() -> void:
	if busy:
		refresh_pending = true
		return
	offset = 0
	refresh()

func _schedule_search_filter(_text: String) -> void:
	search_filter_revision += 1
	var revision := search_filter_revision
	await get_tree().create_timer(0.25).timeout
	if revision != search_filter_revision or not is_inside_tree():
		return
	_filter()

func _filter_from_search_submit(_text: String) -> void:
	search_filter_revision += 1
	_filter()

func _reset_filters() -> void:
	search_filter_revision += 1
	search.text = ""
	search_filter_revision += 1
	outcome.select(0)
	difficulty.select(0)
	favorites.set_pressed_no_signal(false)
	_filter()

func refresh() -> void:
	if busy:
		return
	busy = true
	status.text = _t("loading")
	previous.disabled = true
	next.disabled = true
	var modes := ["", "ai4", "intermediate", "active", "elite", "nightmare"]
	var results := ["", "win", "loss", "draw"]
	var path := "/game/replays?offset=%d&limit=20&search=%s&outcome=%s&difficulty=%s&favorites=%s&kind=%s" % [
		offset, search.text.uri_encode(), results[outcome.selected], modes[difficulty.selected], "true" if favorites.button_pressed else "false", category.uri_encode()]
	var response := await _request("GET", path)
	busy = false
	if refresh_pending:
		refresh_pending = false
		_filter()
		return
	if not bool(response.get("success", false)):
		status.text = _t("load_failed")
		return
	if offset > 0 and offset >= int(response.get("total", 0)):
		offset = maxi(0, offset - 20)
		refresh()
		return
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var rows: Array = response.get("replays", [])
	for row: Dictionary in rows:
		list.add_child(_card(row))
	status.text = _t("empty") if rows.is_empty() else _t("count", {"count": int(response.get("total", 0))})
	usage.text = _t("usage", {"favorites": response.get("favoriteCount", 0)})
	previous.disabled = offset == 0
	next.disabled = offset + rows.size() >= int(response.get("total", 0))

func _card(row: Dictionary) -> Control:
	var card := PanelContainer.new()
	var result := str(row.get("result", "unknown"))
	var result_color := Color("#487f61") if result == "win" else Color("#8b4652") if result == "loss" else Color("#6b6683")
	card.add_theme_stylebox_override("panel", _style(SURFACE_RAISED, result_color, 10, 1, 12, 12, 10, 10))
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 18)
	card.add_child(card_row)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 5)
	card_row.add_child(layout)
	var battle_id := str(row.get("battleId", ""))
	var state := str(row.get("status", "failed"))
	var pinned := bool(row.get("favorite", false))
	var saved_title := str(row.get("title", "")).strip_edges()
	if not saved_title.is_empty():
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 4)
		layout.add_child(title_row)
		var title := Label.new()
		title.text = saved_title
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", INK)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_row.add_child(title)
		var rename_button := _card_icon_button(title_row, "✎", _t("rename"))
		rename_button.disabled = state != "available"
		rename_button.pressed.connect(func(): _rename(row))
		var favorite_button := _card_icon_button(title_row, "★" if pinned else "☆", _t("unpin") if pinned else _t("pin"), pinned)
		favorite_button.disabled = state != "available"
		favorite_button.pressed.connect(func(): _edit(battle_id, {"favorite": not pinned}))
	var matchup_row := HBoxContainer.new()
	matchup_row.add_theme_constant_override("separation", 8)
	layout.add_child(matchup_row)
	matchup_row.add_child(_player_identity(PlayerSave.player_name, PlayerSave.to_appearance_state()))
	var matchup_versus := Label.new()
	matchup_versus.text = "VS"
	matchup_versus.add_theme_font_size_override("font_size", 12)
	matchup_versus.add_theme_color_override("font_color", ACCENT)
	matchup_versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	matchup_row.add_child(matchup_versus)
	matchup_row.add_child(_opponent_identity(row))
	var detail := Label.new()
	var turns := int(round(float(row.get("turns", 0))))
	detail.text = "%s · %s · %s" % [_t("category_" + str(row.get("kind", "ai_sparring"))),
		str(row.get("createdAt", "")).replace("T", " ").left(16), _t("turn" if turns == 1 else "turns", {"count": turns})]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", MUTED)
	layout.add_child(detail)
	if team_strip_factory.is_valid():
		var teams := HFlowContainer.new()
		teams.add_child(team_strip_factory.call(row.get("playerRoster", [])))
		var versus := Label.new()
		versus.text = "VS"
		versus.add_theme_font_size_override("font_size", 12)
		versus.add_theme_color_override("font_color", ACCENT)
		teams.add_child(versus)
		teams.add_child(team_strip_factory.call(row.get("opponentRoster", [])))
		layout.add_child(teams)
	var expiry := Label.new()
	expiry.text = _t("status_" + state)
	if state == "available":
		expiry.text = _t("pinned") if row.get("favorite", false) else _t("expires", {"date": str(row.get("expiresAt", "")).left(10)})
	expiry.add_theme_font_size_override("font_size", 13)
	expiry.add_theme_color_override("font_color", Color("#f1d48b") if row.get("favorite", false) else MUTED)
	expiry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	expiry.custom_minimum_size.x = 150
	expiry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size.x = 252
	action_column.add_theme_constant_override("separation", 8)
	card_row.add_child(action_column)
	var action_heading := HBoxContainer.new()
	action_heading.add_theme_constant_override("separation", 8)
	action_column.add_child(action_heading)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_heading.add_child(action_spacer)
	var result_badge := Label.new()
	result_badge.text = _t(result)
	result_badge.add_theme_font_size_override("font_size", 12)
	result_badge.add_theme_color_override("font_color", Color("#ffffff"))
	result_badge.add_theme_stylebox_override("normal", _style(result_color, result_color, 6, 0, 8, 8, 4, 4))
	action_heading.add_child(result_badge)
	action_heading.add_child(expiry)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	action_column.add_child(actions)
	_button(actions, _t("watch"), func(): watch(battle_id), "primary").disabled = state != "available"
	if str(row.get("kind", "ai_sparring")) == "ai_sparring":
		_button(actions, _t("new_share_code") if row.get("shared", false) else _t("share"), func(): _share(battle_id), "quiet").disabled = state != "available"
	_button(actions, _t("delete"), func(): _confirm_remove(battle_id), "danger")
	return card

func _card_icon_button(parent: Node, glyph: String, tooltip: String, active := false) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(28, 28)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	var base := Color("#2e2616") if active else Color("#102035")
	var hover := Color("#5a4920") if active else Color("#1b3853")
	var border := Color("#d6ae47") if active else Color("#284966")
	button.add_theme_stylebox_override("normal", _style(base, border, 6, 1, 3, 3, 2, 2))
	button.add_theme_stylebox_override("hover", _style(hover, border.lightened(0.18), 6, 1, 3, 3, 2, 2))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.16), border, 6, 1, 3, 3, 2, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("#101d2d"), Color("#233a52"), 6, 1, 3, 3, 2, 2))
	button.add_theme_color_override("font_color", Color("#f1d48b") if active else MUTED)
	button.add_theme_color_override("font_hover_color", Color("#fff0b7") if active else INK)
	button.add_theme_color_override("font_disabled_color", Color("#52657a"))
	parent.add_child(button)
	return button

func _player_identity(name: String, appearance: Dictionary) -> Control:
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(38, 38)
	frame.add_theme_stylebox_override("panel", _style(Color("#0b1727"), ACCENT, 8, 1, 0, 0, 0, 0))
	identity.add_child(frame)
	var fallback := Label.new()
	fallback.text = name.left(1).to_upper() if not name.is_empty() else "?"
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_font_size_override("font_size", 16)
	fallback.add_theme_color_override("font_color", ACCENT)
	frame.add_child(fallback)
	if not appearance.is_empty():
		var portrait := TrainerHeadPortraitScript.new()
		portrait.custom_minimum_size = Vector2(34, 34)
		portrait.set_appearance_state(appearance)
		frame.add_child(portrait)
		fallback.visible = false
	var label := Label.new()
	label.text = name if not name.is_empty() else "Trainer"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", INK)
	identity.add_child(label)
	return identity

func _opponent_identity(row: Dictionary) -> Control:
	var name := str(row.get("opponentDisplayName", "")).strip_edges()
	var kind := str(row.get("kind", "ai_sparring"))
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(38, 38)
	frame.add_theme_stylebox_override("panel", _style(Color("#0b1727"), Color("#627a99"), 8, 1, 0, 0, 0, 0))
	identity.add_child(frame)
	if kind == "ai_sparring":
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.texture = AI_SCIENTIST_PORTRAIT if str(row.get("difficulty", "")) == "ai4" else AI_VETERAN_PORTRAIT
		frame.add_child(portrait)
	else:
		var fallback := Label.new()
		fallback.text = name.left(1).to_upper() if not name.is_empty() else "?"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.add_theme_font_size_override("font_size", 16)
		fallback.add_theme_color_override("font_color", MUTED)
		frame.add_child(fallback)
	var label := Label.new()
	label.text = name if not name.is_empty() else _t("category_" + kind)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", INK)
	identity.add_child(label)
	return identity

func _position_shell() -> void:
	if shell == null:
		return
	# The library is a focused management overlay, not a fullscreen page. A
	# narrower, shorter shell keeps cards readable and the game visible around it.
	shell.size = Vector2(minf(1040, size.x - 48), minf(760, size.y - 80))
	shell.position = (size - shell.size) / 2.0

func watch(battle_id: String) -> void:
	if busy:
		return
	busy = true
	status.text = _t("loading")
	var response := await _request("GET", "/game/replays/" + battle_id.uri_encode())
	busy = false
	if not bool(response.get("success", false)):
		status.text = _t("unavailable")
		playback_failed.emit(status.text)
		return
	return_scroll = scroll.scroll_vertical
	playback_requested.emit(response)

func _watch_shared() -> void:
	if busy:
		return
	var code := share_code_input.text.strip_edges()
	if code.is_empty():
		status.text = _t("shared_unavailable")
		if shared_code_feedback != null:
			shared_code_feedback.text = status.text
		return
	busy = true
	status.text = _t("loading")
	var response := await _request("GET", "/game/replays/shared/" + code.uri_encode())
	busy = false
	if not bool(response.get("success", false)):
		status.text = _t("shared_unavailable")
		if shared_code_feedback != null:
			shared_code_feedback.text = status.text
		playback_failed.emit(status.text)
		return
	if is_instance_valid(shared_code_modal):
		shared_code_modal.queue_free()
		shared_code_modal = null
	return_scroll = scroll.scroll_vertical
	playback_requested.emit(response)

func _open_shared_replay_dialog() -> void:
	if is_instance_valid(shared_code_modal):
		return
	var dialog := _create_replay_dialog(_t("watch_shared_title"), 500)
	var content: VBoxContainer = dialog["content"]
	shared_code_modal = dialog["modal"]
	share_code_input = LineEdit.new()
	share_code_input.placeholder_text = _t("share_code_placeholder")
	share_code_input.max_length = 32
	share_code_input.custom_minimum_size.y = 40
	_style_line_edit(share_code_input)
	content.add_child(share_code_input)
	shared_code_feedback = Label.new()
	shared_code_feedback.add_theme_font_size_override("font_size", 13)
	shared_code_feedback.add_theme_color_override("font_color", DANGER)
	content.add_child(shared_code_feedback)
	var actions := _dialog_actions(content)
	_button(actions, _t("cancel"), func(): shared_code_modal.queue_free(); shared_code_modal = null, "quiet")
	var watch_button := _button(actions, _t("watch_shared"), _watch_shared, "primary")
	share_code_input.text_submitted.connect(func(_text: String): watch_button.emit_signal("pressed"))
	share_code_input.call_deferred("grab_focus")

func _share(battle_id: String) -> void:
	if busy:
		return
	busy = true
	status.text = _t("creating_share_code")
	var response := await _request("POST", "/game/replays/" + battle_id.uri_encode() + "/share")
	busy = false
	if not bool(response.get("success", false)):
		status.text = _t("sharing_failed")
		return
	var code := str(response.get("shareCode", ""))
	var dialog := _create_replay_dialog(_t("share_title"), 520)
	var content: VBoxContainer = dialog["content"]
	var modal: Control = dialog["modal"]
	var hint := Label.new()
	hint.text = _t("share_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", MUTED)
	content.add_child(hint)
	var code_field := LineEdit.new()
	code_field.text = code
	code_field.editable = false
	code_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_field.add_theme_font_size_override("font_size", 18)
	_style_line_edit(code_field)
	content.add_child(code_field)
	var feedback := Label.new()
	feedback.add_theme_font_size_override("font_size", 13)
	feedback.add_theme_color_override("font_color", ACCENT)
	content.add_child(feedback)
	var actions := _dialog_actions(content)
	_button(actions, _t("stop_sharing"), func(): modal.queue_free(); _unshare(battle_id), "danger")
	_button(actions, _t("copy_code"), func(): DisplayServer.clipboard_set(code); feedback.text = _t("code_copied"), "primary")
	_button(actions, _t("close"), func(): modal.queue_free(), "quiet")
	refresh()

func _unshare(battle_id: String) -> void:
	if busy:
		return
	busy = true
	var response := await _request("DELETE", "/game/replays/" + battle_id.uri_encode() + "/share")
	busy = false
	if bool(response.get("success", false)):
		refresh()
	else:
		status.text = _t("sharing_failed")

func restore_library() -> void:
	show()
	scroll.set_deferred("scroll_vertical", return_scroll)
	status.text = ""

func _rename(row: Dictionary) -> void:
	var dialog := _create_replay_dialog(_t("rename"), 440)
	var content: VBoxContainer = dialog["content"]
	var modal: Control = dialog["modal"]
	var input := LineEdit.new()
	input.text = str(row.get("title", ""))
	input.max_length = 80
	input.custom_minimum_size.y = 40
	_style_line_edit(input)
	content.add_child(input)
	var actions := _dialog_actions(content)
	_button(actions, _t("cancel"), func(): modal.queue_free(), "quiet")
	var confirm := _button(actions, "OK", func(): _edit(str(row.get("battleId", "")), {"title": input.text}); modal.queue_free(), "primary")
	input.text_submitted.connect(func(_text: String): confirm.emit_signal("pressed"))
	input.call_deferred("grab_focus")

func _confirm_remove(battle_id: String) -> void:
	var dialog := _create_replay_dialog(_t("delete"), 480)
	var content: VBoxContainer = dialog["content"]
	var modal: Control = dialog["modal"]
	var message := Label.new()
	message.text = _t("delete_confirm")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 15)
	message.add_theme_color_override("font_color", INK)
	content.add_child(message)
	var actions := _dialog_actions(content)
	_button(actions, _t("cancel"), func(): modal.queue_free(), "quiet")
	_button(actions, "OK", func(): _remove(battle_id); modal.queue_free(), "danger")

func _create_replay_dialog(title: String, width: float) -> Dictionary:
	var modal := Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 20
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.06, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", _style(Color("#0d1c2e"), Color("#3a6e93"), 11, 1, 18, 18, 15, 15))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := Label.new()
	heading.text = title
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", INK)
	header.add_child(heading)
	var close := _button(header, "×", func(): modal.queue_free(), "quiet")
	close.custom_minimum_size = Vector2(34, 34)
	close.add_theme_font_size_override("font_size", 20)
	return {"modal": modal, "content": content}

func _dialog_actions(content: VBoxContainer) -> HBoxContainer:
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	return actions

func _remove(battle_id: String) -> void:
	if busy:
		return
	busy = true
	var response := await _request("DELETE", "/game/replays/" + battle_id.uri_encode())
	busy = false
	if bool(response.get("success", false)):
		refresh()
	else:
		status.text = _t("edit_failed")

func _edit(battle_id: String, body: Dictionary) -> void:
	if busy:
		return
	busy = true
	var response := await _request("PATCH", "/game/replays/" + battle_id.uri_encode(), body)
	busy = false
	if bool(response.get("success", false)):
		refresh()
	else:
		status.text = _t("edit_failed")

func _request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 20.0
	request.body_size_limit = 18000000
	add_child(request)
	var response: Dictionary
	if method == "GET":
		response = await BattleApiClient.send_get_request(request, path)
	elif method == "DELETE":
		response = await BattleApiClient.send_delete_request(request, path)
	elif method == "POST":
		response = await BattleApiClient.send_post_request(request, path, body)
	else:
		var base: String = await GatewayApiConfig.get_base_url()
		var error := request.request(base + path, GatewayApiConfig.get_json_headers(), HTTPClient.METHOD_PATCH, JSON.stringify(body))
		response = await BattleApiClient._read_json_response(request) if error == OK else {"success": false}
	request.queue_free()
	return response
