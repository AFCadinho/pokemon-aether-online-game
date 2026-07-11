extends Window

class_name TradeWorkspaceNode

const MAX_OFFER_SIZE := 5

var trade: Dictionary = {}
var candidates: Array[Dictionary] = []
var selected_ids: Array[int] = []
var candidate_list: VBoxContainer
var local_offer_list: VBoxContainer
var opponent_offer_list: VBoxContainer
var status_label: Label
var submit_button: Button
var ready_button: Button
var edit_button: Button
var editable_root: VBoxContainer
var review_root: VBoxContainer
var review_give_list: VBoxContainer
var review_receive_list: VBoxContainer
var review_trust_label: Label
var review_edit_button: Button
var confirm_button: Button
var confirmation_label: Label
var mutation_in_flight := false
var offer_draft_dirty := false


func _ready() -> void:
	hide()
	title = "Pokemon Trade"
	min_size = Vector2i(760, 520)
	_build_ui()
	close_requested.connect(_on_close_requested)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.active_trade_changed.connect(_on_trade_changed)
		if not realtime.active_trade_snapshot.is_empty():
			_on_trade_changed(realtime.active_trade_snapshot)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	var heading := Label.new()
	heading.text = "Pokemon Trade"
	heading.add_theme_font_size_override("font_size", 22)
	root.add_child(heading)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)
	editable_root = VBoxContainer.new()
	editable_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(editable_root)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editable_root.add_child(columns)
	candidate_list = _section(columns, "Your Pokemon")
	local_offer_list = _section(columns, "Your Offer")
	opponent_offer_list = _section(columns, "Other Player's Offer")
	var actions := HBoxContainer.new()
	editable_root.add_child(actions)
	submit_button = Button.new()
	submit_button.text = "Replace Offer"
	submit_button.pressed.connect(_submit_offer)
	actions.add_child(submit_button)
	ready_button = Button.new()
	ready_button.text = "Ready"
	ready_button.pressed.connect(_set_ready.bind(true))
	actions.add_child(ready_button)
	edit_button = Button.new()
	edit_button.text = "Edit Offer"
	edit_button.pressed.connect(_set_ready.bind(false))
	actions.add_child(edit_button)
	review_root = VBoxContainer.new()
	review_root.visible = false
	review_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(review_root)
	review_trust_label = Label.new()
	review_root.add_child(review_trust_label)
	var review_columns := HBoxContainer.new()
	review_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_root.add_child(review_columns)
	review_give_list = _section(review_columns, "You give")
	review_receive_list = _section(review_columns, "You receive")
	review_edit_button = Button.new()
	review_edit_button.text = "Edit Offer"
	review_edit_button.pressed.connect(_set_ready.bind(false))
	review_root.add_child(review_edit_button)
	confirmation_label = Label.new()
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	review_root.add_child(confirmation_label)
	confirm_button = Button.new()
	confirm_button.text = "Confirm Trade"
	confirm_button.pressed.connect(_confirm_trade)
	review_root.add_child(confirm_button)
func _process(_delta: float) -> void:
	if visible and str(trade.get("status", "")) in ["active", "locked"]:
		_render_connection_status()


func _section(parent: Control, label_text: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(235, 0)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	section.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _on_trade_changed(value: Dictionary) -> void:
	var status := str(value.get("status", ""))
	var previous_trade_id := str(trade.get("tradeId", ""))
	var refresh_candidates := status == "active" and _trade_snapshot_changed(value)
	if status == "cancelled":
		trade = value.duplicate(true)
		editable_root.visible = false
		review_root.visible = false
		if str(trade.get("cancellationReason", "")) == "reconnect_timeout":
			status_label.text = "Trade cancelled because reconnect time expired."
			popup_centered()
		else:
			hide()
		return
	if status == "completed":
		trade = value.duplicate(true)
		editable_root.visible = false
		review_root.visible = false
		status_label.text = "Trade completed. Your party was refreshed."
		popup_centered()
		refresh_after_completion.call_deferred()
		return
	if status not in ["active", "locked"]:
		if visible:
			hide()
		return
	trade = value.duplicate(true)
	if _should_sync_selected_from_offer(previous_trade_id, status):
		_sync_selected_from_offer()
	_render_offers()
	_render_mode()
	popup_centered()
	if refresh_candidates:
		refresh_available_pokemon.call_deferred()


func refresh_available_pokemon() -> void:
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service == null:
		_show_error("Your party is unavailable.")
		return
	var party_result: Dictionary = await party_service.load_party()
	if not bool(party_result.get("success", false)):
		_show_error("Could not refresh your party.")
		return
	candidates = collect_candidates(party_result.get("party", []))
	_render_candidates()


func _trade_snapshot_changed(value: Dictionary) -> bool:
	return str(trade.get("tradeId", "")) != str(value.get("tradeId", "")) \
		or int(trade.get("revision", 0)) != int(value.get("revision", 0)) \
		or int(trade.get("lastEventSeq", 0)) != int(value.get("lastEventSeq", 0))


static func collect_candidates(party_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	if party_value is Array:
		for index in range(party_value.size()):
			_add_candidate(result, seen, party_value[index], {"type":"party", "partySlot":index})
	result.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("pokemonId", 0)) < int(b.get("pokemonId", 0)))
	return result


static func _add_candidate(result: Array[Dictionary], seen: Dictionary, value: Variant, location: Dictionary) -> void:
	if not value is Dictionary:
		return
	var payload: Dictionary = value.get("pokemon", value)
	var pokemon_id := int(value.get("id", value.get("pokemonId", payload.get("ownedPokemonId", payload.get("pokemonId", 0)))))
	if pokemon_id <= 0 or seen.has(pokemon_id):
		return
	seen[pokemon_id] = true
	result.append({"pokemonId":pokemon_id, "pokemon":payload.duplicate(true), "location":location.duplicate(true)})


func _render_candidates() -> void:
	_clear(candidate_list)
	for candidate: Dictionary in candidates:
		var pokemon_id := int(candidate.get("pokemonId", 0))
		var check := CheckButton.new()
		check.text = _pokemon_label(candidate.get("pokemon", {}))
		check.button_pressed = pokemon_id in selected_ids
		check.disabled = _any_participant_ready() or str(trade.get("status", "")) == "locked" or _connection_state_unresolved() or (pokemon_id not in selected_ids and selected_ids.size() >= _offer_limit())
		check.toggled.connect(_toggle_candidate.bind(pokemon_id))
		candidate_list.add_child(check)


func _toggle_candidate(enabled: bool, pokemon_id: int) -> void:
	if enabled:
		if pokemon_id not in selected_ids and selected_ids.size() < _offer_limit():
			selected_ids.append(pokemon_id)
	else:
		selected_ids.erase(pokemon_id)
	offer_draft_dirty = true
	_render_candidates()
	_refresh_submit_button()
	if not selected_ids.is_empty():
		status_label.text = "%d Pokemon selected. Press Send Offer to share it with the other player." % selected_ids.size()


func _submit_offer() -> void:
	if mutation_in_flight or selected_ids.is_empty() or _any_participant_ready() or str(trade.get("status", "")) == "locked" or _connection_state_unresolved():
		return
	mutation_in_flight = true
	submit_button.disabled = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false, "error":"Trade service unavailable."}
	else:
		result = await service.replace_offer(str(trade.get("tradeId", "")), int(trade.get("revision", 0)), selected_ids)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result))
		_refresh_submit_button()
		return
	offer_draft_dirty = false
	_refresh_submit_button()
	trade = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(trade)
	await refresh_available_pokemon()


func _set_ready(ready: bool) -> void:
	if mutation_in_flight or _connection_state_unresolved():
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false, "error":"Trade service unavailable."}
	else:
		result = await service.set_readiness(str(trade.get("tradeId", "")), int(trade.get("revision", 0)), ready)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result))
		return
	trade = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(trade)
	_render_mode()


func _sync_selected_from_offer() -> void:
	offer_draft_dirty = false
	selected_ids.clear()
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if offer_value is Dictionary and int(offer_value.get("userId", 0)) == user_id:
			for pokemon_value: Variant in offer_value.get("pokemon", []):
				if pokemon_value is Dictionary:
					selected_ids.append(int(pokemon_value.get("pokemonId", 0)))
	_refresh_submit_button()


func _refresh_submit_button() -> void:
	if submit_button == null:
		return
	submit_button.text = "Send Offer (%d)" % selected_ids.size() if not selected_ids.is_empty() else "Replace Offer"
	submit_button.disabled = mutation_in_flight or selected_ids.is_empty() or selected_ids.size() > _offer_limit()


func _should_sync_selected_from_offer(previous_trade_id: String, next_status: String) -> bool:
	return not offer_draft_dirty or previous_trade_id != str(trade.get("tradeId", "")) or next_status == "locked"


func _render_offers() -> void:
	_clear(local_offer_list)
	_clear(opponent_offer_list)
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if not offer_value is Dictionary:
			continue
		var target := local_offer_list if int(offer_value.get("userId", 0)) == user_id else opponent_offer_list
		for pokemon_value: Variant in offer_value.get("pokemon", []):
			var label := Label.new()
			label.text = _pokemon_label(pokemon_value if pokemon_value is Dictionary else {})
			target.add_child(label)


func _render_mode() -> void:
	var locked := str(trade.get("status", "")) == "locked"
	editable_root.visible = not locked
	review_root.visible = locked
	if locked:
		_render_locked_review()
		return
	var local_ready := _local_participant_ready()
	var any_ready := _any_participant_ready()
	var blocked := _connection_state_unresolved()
	ready_button.visible = not local_ready
	ready_button.disabled = mutation_in_flight or not _both_offers_nonempty() or blocked
	edit_button.visible = any_ready
	edit_button.disabled = mutation_in_flight or blocked
	_refresh_submit_button()
	submit_button.disabled = submit_button.disabled or any_ready or blocked
	if any_ready:
		status_label.text = "Offer editing is paused until readiness is cleared."
	elif _opponent_receive_capacity() <= 0:
		status_label.text = "The other player needs a free party slot before you can offer a Pokemon."
	elif not _both_offers_nonempty():
		status_label.text = "Both players must send at least one Pokemon before Ready is available."
	else:
		status_label.text = ""
	_render_candidates()


func _render_locked_review() -> void:
	_clear(review_give_list)
	_clear(review_receive_list)
	var review: Dictionary = trade.get("lockedReview", {}) if trade.get("lockedReview", {}) is Dictionary else {}
	var snapshot: Dictionary = review.get("snapshot", {}) if review.get("snapshot", {}) is Dictionary else {}
	var user_id := _current_user_id()
	for participant_value: Variant in snapshot.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			_add_review_pokemon(review_give_list, participant_value.get("gives", []))
			_add_review_pokemon(review_receive_list, participant_value.get("receives", []))
	review_trust_label.text = "Locked revision %d  Review %s" % [int(review.get("lockedRevision", 0)), str(review.get("snapshotHash", "")).left(12)]
	review_edit_button.disabled = mutation_in_flight
	var local_confirmed := _local_participant_confirmed()
	confirm_button.visible = not local_confirmed
	confirm_button.disabled = mutation_in_flight or _connection_state_unresolved()
	confirmation_label.text = "Confirmed. Waiting for the other player." if local_confirmed else "Review the exact exchange before confirming."
	if _connection_state_unresolved():
		review_edit_button.disabled = true


func _confirm_trade() -> void:
	if mutation_in_flight or _connection_state_unresolved() or str(trade.get("status", "")) != "locked":
		return
	var review: Dictionary = trade.get("lockedReview", {}) if trade.get("lockedReview", {}) is Dictionary else {}
	mutation_in_flight = true
	confirm_button.disabled = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false,"error":"Trade service unavailable."}
	else:
		result = await service.confirm_trade(str(trade.get("tradeId", "")),int(trade.get("revision",0)),int(review.get("lockedRevision",0)),str(review.get("snapshotHash","")))
	mutation_in_flight = false
	if not bool(result.get("success",false)):
		_show_error(_friendly_error(result))
		confirm_button.disabled = false
		return
	var snapshot: Dictionary = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(snapshot)
	else:
		_on_trade_changed(snapshot)


func refresh_after_completion() -> void:
	var party_service := get_node_or_null("/root/PlayerPartyStateService")
	if party_service != null:
		await party_service.load_party()


func _leave_trade() -> void:
	if mutation_in_flight:
		return
	mutation_in_flight = true
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false,"error":"Trade service unavailable."}
	else:
		result = await service.leave_trade(str(trade.get("tradeId", "")), int(trade.get("revision", 0)))
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result))
		return
	var snapshot: Dictionary = result.get("trade", {}).duplicate(true)
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	if realtime != null:
		realtime.apply_snapshot(snapshot)
	else:
		_on_trade_changed(snapshot)


func _on_close_requested() -> void:
	if str(trade.get("status", "")) in ["active", "locked"]:
		_leave_trade()
		return
	hide()


func _render_connection_status() -> void:
	var disconnected := _disconnected_opponent()
	if disconnected.is_empty():
		return
	var deadline := str(disconnected.get("reconnectDeadlineAt", ""))
	var remaining := reconnect_seconds_remaining(deadline, Time.get_unix_time_from_system())
	status_label.text = "Other player disconnected. Waiting %d seconds for reconnect." % remaining


static func reconnect_seconds_remaining(deadline: String, now_unix: float) -> int:
	if deadline.strip_edges() == "":
		return 0
	return maxi(int(ceil(Time.get_unix_time_from_datetime_string(deadline) - now_unix)), 0)


func _disconnected_opponent() -> Dictionary:
	var user_id := _current_user_id()
	for value: Variant in trade.get("participants", []):
		if value is Dictionary and int(value.get("userId", 0)) != user_id and str(value.get("connectionState", "connected")) == "disconnected":
			return value
	return {}


func _connection_state_unresolved() -> bool:
	if not _disconnected_opponent().is_empty():
		return true
	var realtime := get_node_or_null("/root/TradeRealtimeService")
	return realtime != null and realtime.active_trade_id == str(trade.get("tradeId", "")) and realtime.recovery_in_progress


func _add_review_pokemon(target: VBoxContainer, values: Variant) -> void:
	if not values is Array:
		return
	for value: Variant in values:
		var label := Label.new()
		label.text = _pokemon_label(value if value is Dictionary else {})
		target.add_child(label)


func _local_participant_ready() -> bool:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			return bool(participant_value.get("ready", false))
	return false


func _any_participant_ready() -> bool:
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and bool(participant_value.get("ready", false)):
			return true
	return false


func _local_participant_confirmed() -> bool:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			return bool(participant_value.get("confirmed", false))
	return false


func _both_offers_nonempty() -> bool:
	var nonempty := 0
	for offer_value: Variant in trade.get("offers", []):
		if offer_value is Dictionary and offer_value.get("pokemon", []) is Array and not offer_value.get("pokemon", []).is_empty():
			nonempty += 1
	return nonempty == 2


func _friendly_error(result: Dictionary) -> String:
	var body: Dictionary = result.get("body", {}) if result.get("body", {}) is Dictionary else {}
	var detail: Variant = body.get("detail", {})
	var code := str(detail.get("code", "")) if detail is Dictionary else ""
	match code:
		"pokemon_reserved_for_trade": return "That Pokemon is already reserved for a trade."
		"pokemon_holding_item": return "Remove the held item before offering that Pokemon."
		"pokemon_not_tradable": return "That Pokemon cannot be traded."
		"pokemon_not_owned_or_held": return "That Pokemon is no longer held by your account."
		"pokemon_location_stale": return "That Pokemon moved. Refresh your party."
		"trade_offer_party_only": return "Only Pokemon currently in your party can be offered."
		"trade_party_capacity_exceeded": return "The other player does not have enough free party slots."
		"trade_party_space_required": return "A free party slot is required to receive a Pokemon."
		"trade_review_mismatch": return "The locked review changed. Refresh before confirming."
		"trade_review_not_locked": return "This trade is no longer locked for review."
		"trade_settlement_invalidated": return "The trade changed and could not be completed. Refresh the authoritative trade state."
		"trade_settlement_retryable": return "The trade was not committed. Refresh and try again."
	return str(result.get("error", "The offer could not be updated. Refresh and try again."))


func _show_error(message: String) -> void:
	status_label.text = message


func _pokemon_label(value: Variant) -> String:
	var pokemon: Dictionary = value if value is Dictionary else {}
	var nickname := str(pokemon.get("nickname", "")).strip_edges()
	var species_name := str(pokemon.get("speciesName", "")).strip_edges()
	var species_id := str(pokemon.get("speciesId", "")).strip_edges()
	var name := nickname if nickname != "" and nickname != "<null>" else species_name
	if name == "" or name == "<null>":
		name = species_id if species_id != "" else "Pokemon"
	return "%s  Lv. %d" % [name, maxi(int(pokemon.get("level", 1)), 1)]


func _current_user_id() -> int:
	var auth := get_node_or_null("/root/AuthService")
	return int(auth.current_user.get("id", 0)) if auth != null else 0


func _opponent_receive_capacity() -> int:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) != user_id:
			return clampi(6 - int(participant_value.get("partyCount", 0)), 0, MAX_OFFER_SIZE)
	return MAX_OFFER_SIZE


func _offer_limit() -> int:
	return mini(MAX_OFFER_SIZE, _opponent_receive_capacity())


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
