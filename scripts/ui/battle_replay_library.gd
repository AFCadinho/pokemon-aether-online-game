extends Control

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
var previous: Button
var next: Button
var offset := 0
var busy := false
var return_scroll := 0
var team_strip_factory: Callable
var refresh_pending := false

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
	shell.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c30")
	style.border_color = Color("547297")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	shell.add_theme_stylebox_override("panel", style)
	add_child(shell)
	resized.connect(_position_shell)
	shell.minimum_size_changed.connect(func(): _position_shell.call_deferred())
	_position_shell.call_deferred()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	shell.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = _t("title")
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_button(header, _t("close"), func(): hide(); closed.emit())
	var intro := Label.new()
	intro.text = _t("intro")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(intro)
	var filters := HFlowContainer.new()
	layout.add_child(filters)
	search = LineEdit.new()
	search.placeholder_text = _t("search")
	search.max_length = 80
	search.custom_minimum_size.x = 220
	search.text_submitted.connect(func(_text: String): _filter())
	filters.add_child(search)
	outcome = OptionButton.new()
	for key: String in ["all_results", "win", "loss", "draw"]:
		outcome.add_item(_t(key))
	outcome.item_selected.connect(func(_i: int): _filter())
	filters.add_child(outcome)
	difficulty = OptionButton.new()
	for label: String in [_t("all_difficulties"), "Scholar", "Grandmaster Intermediate", "Grandmaster Hard", "Grandmaster Elite", "Grandmaster Nightmare"]:
		difficulty.add_item(label)
	difficulty.item_selected.connect(func(_i: int): _filter())
	filters.add_child(difficulty)
	favorites = CheckButton.new()
	favorites.text = _t("favorites")
	favorites.toggled.connect(func(_value: bool): _filter())
	filters.add_child(favorites)
	_button(filters, _t("refresh"), _filter)
	usage = Label.new()
	usage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(usage)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
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
	previous = _button(pager, _t("previous_page"), func(): offset = maxi(0, offset - 20); refresh())
	next = _button(pager, _t("next_page"), func(): offset += 20; refresh())

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open_library() -> void:
	show()
	refresh()

func _filter() -> void:
	if busy:
		refresh_pending = true
		return
	offset = 0
	refresh()

func refresh() -> void:
	if busy:
		return
	busy = true
	status.text = _t("loading")
	previous.disabled = true
	next.disabled = true
	var modes := ["", "ai4", "intermediate", "active", "elite", "nightmare"]
	var results := ["", "win", "loss", "draw"]
	var path := "/game/replays?offset=%d&limit=20&search=%s&outcome=%s&difficulty=%s&favorites=%s" % [
		offset, search.text.uri_encode(), results[outcome.selected], modes[difficulty.selected], "true" if favorites.button_pressed else "false"]
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
	status.text = _t("empty") if rows.is_empty() else _t("count", {"count": response.get("total", 0)})
	usage.text = _t("usage", {"used": snappedf(float(response.get("storedBytes", 0)) / 1000000.0, 0.01),
		"max": int(response.get("maxBytes", 0)) / 1000000, "favorites": response.get("favoriteCount", 0)})
	previous.disabled = offset == 0
	next.disabled = offset + rows.size() >= int(response.get("total", 0))

func _card(row: Dictionary) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182840")
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	var layout := VBoxContainer.new()
	card.add_child(layout)
	var title := Label.new()
	title.text = str(row.get("title", ""))
	if title.text.is_empty():
		title.text = "AI Sparring · %s" % str(row.get("opponentDisplayName", ""))
	title.add_theme_font_size_override("font_size", 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title)
	var detail := Label.new()
	detail.text = "%s · %s · %s · %s" % [str(row.get("opponentDisplayName", "")), str(row.get("createdAt", "")).replace("T", " ").left(16),
		_t(str(row.get("result", "unknown"))), _t("turns", {"count": row.get("turns", 0)})]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(detail)
	if team_strip_factory.is_valid():
		var teams := HFlowContainer.new()
		teams.add_child(team_strip_factory.call(row.get("playerRoster", [])))
		var versus := Label.new()
		versus.text = "VS"
		teams.add_child(versus)
		teams.add_child(team_strip_factory.call(row.get("opponentRoster", [])))
		layout.add_child(teams)
	var state := str(row.get("status", "failed"))
	var expiry := Label.new()
	expiry.text = _t("status_" + state)
	if state == "available":
		expiry.text = _t("pinned") if row.get("favorite", false) else _t("expires", {"date": str(row.get("expiresAt", "")).left(10)})
	layout.add_child(expiry)
	var actions := HFlowContainer.new()
	layout.add_child(actions)
	var battle_id := str(row.get("battleId", ""))
	_button(actions, _t("watch"), func(): watch(battle_id)).disabled = state != "available"
	var pinned := bool(row.get("favorite", false))
	_button(actions, _t("unpin") if pinned else _t("pin"), func(): _edit(battle_id, {"favorite": not pinned})).disabled = state != "available"
	_button(actions, _t("rename"), func(): _rename(row)).disabled = state != "available"
	_button(actions, _t("delete"), func(): _confirm_remove(battle_id))
	return card

func _position_shell() -> void:
	if shell == null:
		return
	shell.size = Vector2(minf(1280, size.x - 48), minf(900, size.y - 80))
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

func restore_library() -> void:
	show()
	scroll.set_deferred("scroll_vertical", return_scroll)
	status.text = ""

func _rename(row: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = _t("rename")
	var input := LineEdit.new()
	input.text = str(row.get("title", ""))
	input.max_length = 80
	input.custom_minimum_size = Vector2(360, 40)
	dialog.add_child(input)
	add_child(dialog)
	dialog.confirmed.connect(func(): _edit(str(row.get("battleId", "")), {"title": input.text}); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(400, 140))
	input.grab_focus()

func _confirm_remove(battle_id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = _t("delete")
	dialog.dialog_text = _t("delete_confirm")
	add_child(dialog)
	dialog.confirmed.connect(func(): _remove(battle_id); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(440, 160))

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
	else:
		var base: String = await GatewayApiConfig.get_base_url()
		var error := request.request(base + path, GatewayApiConfig.get_json_headers(), HTTPClient.METHOD_PATCH, JSON.stringify(body))
		response = await BattleApiClient._read_json_response(request) if error == OK else {"success": false}
	request.queue_free()
	return response
