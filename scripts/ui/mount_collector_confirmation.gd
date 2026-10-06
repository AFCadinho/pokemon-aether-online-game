extends "res://scripts/ui/mount_collector_grid.gd"

const VOUCHER_ICON := preload("res://assets/ui/store_voucher.svg")
const MUTED := Color("#afbdca")
const GOLD := Color("#e3bd68")

var confirmation_body: VBoxContainer
var confirmation_scroll: ScrollContainer
var confirmation_panel: PanelContainer
var confirm_button: Button
var back_button: Button


func confirm_mount(offer: Dictionary, credit: int, keep_one: bool) -> String:
	layer = 105
	_build_confirmation(offer, credit, keep_one)
	return await topic_selected


func _build_confirmation(offer: Dictionary, credit: int, keep_one: bool) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var root := Control.new()
	root.name = "MountCollectorConfirmation"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#02060bd1")
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	confirmation_panel = PanelContainer.new()
	confirmation_panel.name = "ConfirmationPanel"
	confirmation_panel.custom_minimum_size.x = minf(640, viewport_size.x - 32)
	confirmation_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(confirmation_panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	confirmation_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var title := _label(_t("confirmation_title"), 22, Color("#f4f0de"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title)
	confirmation_scroll = ScrollContainer.new()
	confirmation_scroll.name = "ConfirmationScroll"
	confirmation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	confirmation_scroll.custom_minimum_size.y = minf(420, maxf(64, viewport_size.y - 160))
	layout.add_child(confirmation_scroll)
	confirmation_body = VBoxContainer.new()
	confirmation_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirmation_body.add_theme_constant_override("separation", 12)
	confirmation_scroll.add_child(confirmation_body)
	var exchange: BoxContainer = HBoxContainer.new() if confirmation_panel.custom_minimum_size.x >= 400 else VBoxContainer.new()
	exchange.name = "ExchangePreview"
	exchange.add_theme_constant_override("separation", 10)
	confirmation_body.add_child(exchange)
	var bound := bool(offer.get("accountBound", false))
	exchange.add_child(_mount_summary(str(offer.get("shinyMountId", "")), bound, false, credit, false))
	var arrow := _label("→" if exchange is HBoxContainer else "↓", 24, GOLD)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exchange.add_child(arrow)
	exchange.add_child(_mount_summary(str(offer.get("normalMountId", "")), bound, true, credit, bool(offer.get("normalAlreadyOwned", false))))
	var owned := int(offer.get("shinyOwnedQuantity", offer.get("quantity", 0)))
	if keep_one:
		layout.add_child(_notice("ProtectedShinyNotice", _t("protected_title"), _t("protected_body"), Color("#83d8b0")))
	elif owned <= 1:
		var mount_name := Mounts.get_mount_display_name(str(offer.get("normalMountId", "")))
		layout.add_child(_notice("LastShinyWarning", _t("last_title"), _t("last_body", {"mount": mount_name}), Color("#ffa17c")))
	var tracker := _label(_t("tracker_unchanged"), 11, MUTED)
	tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_body.add_child(tracker)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)
	back_button = _action_button(_t("back"), "")
	back_button.name = "BackButton"
	back_button.custom_minimum_size.y = 40
	actions.add_child(back_button)
	confirm_button = _action_button(_t("trade"), "confirm")
	confirm_button.name = "ConfirmButton"
	confirm_button.custom_minimum_size.y = 40
	confirm_button.add_theme_stylebox_override("normal", _button_style(Color("#665128"), GOLD, true))
	confirm_button.add_theme_stylebox_override("hover", _button_style(Color("#806539"), Color("#f9d98f"), true))
	actions.add_child(confirm_button)
	confirmation_panel.resized.connect(_fit_confirmation_height)
	_fit_confirmation_height.call_deferred()
	back_button.grab_focus.call_deferred()


func _mount_summary(mount_id: String, bound: bool, reward: bool, credit: int, duplicate: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "RewardCard" if reward else "SourceCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent := Color("#83d8b0") if reward else Color("#bc9bdf")
	card.add_theme_stylebox_override("panel", _button_style(Color("#0b1a2b"), Color("#315070"), true))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	card.add_child(content)
	var heading := _label(_t("you_receive" if reward else "you_give"), 15, accent)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var image := TextureRect.new()
	image.name = "NormalPreview" if reward else "ShinyPreview"
	image.custom_minimum_size.y = 64
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.texture = _preview_texture(mount_id)
	content.add_child(image)
	var mount_name := _label("1 × " + Mounts.get_mount_display_name(mount_id), 15, Color("#e8eef4"))
	mount_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mount_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(mount_name)
	var binding_label := _label(_t("bound" if bound else "tradeable"), 12, GOLD if bound else Color("#83d8b0"))
	binding_label.name = "RewardBinding" if reward else "SourceBinding"
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(binding_label)
	if reward:
		var voucher := HBoxContainer.new()
		voucher.alignment = BoxContainer.ALIGNMENT_CENTER
		voucher.add_theme_constant_override("separation", 6)
		content.add_child(voucher)
		var voucher_icon := TextureRect.new()
		voucher_icon.custom_minimum_size = Vector2(22, 22)
		voucher_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		voucher_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		voucher_icon.texture = VOUCHER_ICON
		voucher.add_child(voucher_icon)
		var amount := _label("+%s" % credit, 20, GOLD)
		amount.name = "VoucherCredit"
		voucher.add_child(amount)
		var currency := _label(_t("voucher_credit"), 12, GOLD)
		currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(currency)
		var binding_note := _label(_t("voucher_binding"), 11, MUTED)
		binding_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		binding_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(binding_note)
		if duplicate:
			var duplicate_note := _label(_t("normal_owned"), 11, MUTED)
			duplicate_note.name = "NormalAlreadyOwned"
			duplicate_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			duplicate_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(duplicate_note)
	else:
		var removal := _label(_t("source_removed"), 12, Color("#ffa17c"))
		removal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		removal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(removal)
	return card


func _notice(node_name: String, title_text: String, body_text: String, color: Color) -> PanelContainer:
	var notice := PanelContainer.new()
	notice.name = node_name
	notice.add_theme_stylebox_override("panel", _button_style(Color("#17212b"), color, true))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	notice.add_child(content)
	var title := _label(title_text, 14, color)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var body := _label(body_text, 12, Color("#e8eef4"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(body)
	return notice


func _fit_confirmation_height() -> void:
	if not is_inside_tree():
		return
	var other_height := confirmation_panel.get_combined_minimum_size().y - confirmation_scroll.custom_minimum_size.y
	var available := maxf(48, get_viewport().get_visible_rect().size.y - other_height - 32)
	var height := minf(confirmation_body.get_combined_minimum_size().y, available)
	if absf(confirmation_scroll.custom_minimum_size.y - height) >= 1:
		confirmation_scroll.custom_minimum_size.y = height
