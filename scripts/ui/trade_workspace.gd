extends Window

class_name TradeWorkspaceNode

const MAX_OFFER_SIZE := 5

var trade: Dictionary = {}
var candidates: Array[Dictionary] = []
var selected_ids: Array[int] = []
var local_offer_box: PanelContainer
var opponent_offer_box: PanelContainer
var local_offer_slots: Array[Control] = []
var opponent_offer_slots: Array[Control] = []
var local_ready_indicator: Label
var opponent_ready_indicator: Label
var status_label: Label
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
var party_drag_preview: TextureRect


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
	local_offer_box = _offer_section(columns, "Your Offer", local_offer_slots)
	opponent_offer_box = _offer_section(columns, "Other Player's Offer", opponent_offer_slots)
	var actions := HBoxContainer.new()
	editable_root.add_child(actions)
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


func _offer_section(parent: Control, label_text: String, slots: Array[Control]) -> PanelContainer:
	var section := VBoxContainer.new()
	section.custom_minimum_size = Vector2(340, 250)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var header := HBoxContainer.new()
	section.add_child(header)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var ready_indicator := Label.new()
	ready_indicator.text = "READY"
	ready_indicator.visible = false
	ready_indicator.add_theme_color_override("font_color", Color("#63df8b"))
	ready_indicator.add_theme_font_size_override("font_size", 14)
	header.add_child(ready_indicator)
	if label_text == "Your Offer":
		local_ready_indicator = ready_indicator
	else:
		opponent_ready_indicator = ready_indicator
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#111925f2")
	panel_style.border_color = Color("#526b87")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)
	section.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = MAX_OFFER_SIZE
	grid.add_theme_constant_override("h_separation", 8)
	margin.add_child(grid)
	for index in range(MAX_OFFER_SIZE):
		var slot := _create_offer_slot()
		slots.append(slot)
		grid.add_child(slot)
	return panel


func _create_offer_slot() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(58, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#09111c")
	style.border_color = Color("#36506d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)
	return slot


func _on_trade_changed(value: Dictionary) -> void:
	var status := str(value.get("status", ""))
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


func _replace_offer(pokemon_ids: Array[int]) -> void:
	if mutation_in_flight or pokemon_ids.is_empty() or _local_participant_ready() or str(trade.get("status", "")) == "locked" or _connection_state_unresolved():
		return
	mutation_in_flight = true
	_render_offers()
	var service := get_node_or_null("/root/TradeService")
	var result: Dictionary
	if service == null:
		result = {"success":false, "error":"Trade service unavailable."}
	else:
		result = await service.replace_offer(str(trade.get("tradeId", "")), int(trade.get("revision", 0)), pokemon_ids)
	mutation_in_flight = false
	if not bool(result.get("success", false)):
		_show_error(_friendly_error(result))
		_render_offers()
		return
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
	selected_ids.clear()
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if offer_value is Dictionary and int(offer_value.get("userId", 0)) == user_id:
			for pokemon_value: Variant in offer_value.get("pokemon", []):
				if pokemon_value is Dictionary:
					selected_ids.append(int(pokemon_value.get("pokemonId", 0)))


func _render_offers() -> void:
	_clear_offer_slots(local_offer_slots)
	_clear_offer_slots(opponent_offer_slots)
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if not offer_value is Dictionary:
			continue
		var is_local := int(offer_value.get("userId", 0)) == user_id
		var target := local_offer_slots if is_local else opponent_offer_slots
		var pokemon_values: Array = offer_value.get("pokemon", []) if offer_value.get("pokemon", []) is Array else []
		for index in range(mini(pokemon_values.size(), MAX_OFFER_SIZE)):
			if pokemon_values[index] is Dictionary:
				_render_offer_slot(target[index], pokemon_values[index], is_local, index)


func _clear_offer_slots(slots: Array[Control]) -> void:
	for slot in slots:
		_clear(slot)


func _render_offer_slot(slot: Control, pokemon: Dictionary, is_local: bool, position: int) -> void:
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon_button := Button.new()
	icon_button.custom_minimum_size = Vector2(52, 48)
	icon_button.icon = PokemonAssets.load_party_icon(_pokemon_species(pokemon), bool(pokemon.get("shiny", false)))
	icon_button.expand_icon = true
	icon_button.tooltip_text = "%s\nOpen Pokemon summary" % _pokemon_label(pokemon)
	icon_button.pressed.connect(_open_offer_summary.bind(pokemon, is_local))
	content.add_child(icon_button)
	var name_label := Label.new()
	name_label.text = _pokemon_label(pokemon)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 52
	content.add_child(name_label)
	if is_local and selected_ids.size() > 1 and not _local_participant_ready() and not mutation_in_flight:
		var remove_button := Button.new()
		remove_button.text = "X"
		remove_button.tooltip_text = "Remove from offer"
		remove_button.focus_mode = Control.FOCUS_NONE
		remove_button.pressed.connect(_remove_offer_position.bind(position))
		content.add_child(remove_button)
	slot.add_child(content)


func _open_offer_summary(pokemon: Dictionary, is_local: bool) -> void:
	var payload := pokemon.duplicate(true)
	if is_local:
		var candidate := _candidate_by_id(int(pokemon.get("pokemonId", 0)))
		if not candidate.is_empty():
			payload = candidate.get("pokemon", {}).duplicate(true)
	payload = normalize_summary_payload(payload)
	var overlay := get_tree().get_first_node_in_group("ui_overlay")
	if overlay != null and overlay.has_method("open_trade_pokemon_summary"):
		overlay.call("open_trade_pokemon_summary", payload)


func hide_for_pokemon_summary() -> void:
	hide()


func restore_after_pokemon_summary() -> void:
	if str(trade.get("status", "")) in ["active", "locked"]:
		popup_centered()


func _remove_offer_position(position: int) -> void:
	if selected_ids.size() <= 1 or position < 0 or position >= selected_ids.size():
		return
	var replacement := selected_ids.duplicate()
	replacement.remove_at(position)
	_replace_offer(replacement)


func try_offer_party_drop(global_position: Vector2, party_slot: int) -> bool:
	var workspace_position := _main_to_workspace_position(global_position)
	if not visible or local_offer_box == null or not local_offer_box.get_global_rect().has_point(workspace_position):
		return false
	if party_slot < 0 or party_slot >= 6 or mutation_in_flight or _local_participant_ready() or _connection_state_unresolved() or str(trade.get("status", "")) != "active":
		return true
	var candidate := _candidate_by_party_slot(party_slot)
	if candidate.is_empty():
		_show_error("That party Pokemon is unavailable. Refresh your party.")
		return true
	var pokemon_id := int(candidate.get("pokemonId", 0))
	var target_position := _offer_slot_at_position(workspace_position)
	var replacement := build_drop_replacement(selected_ids, pokemon_id, target_position, _offer_limit())
	if replacement == selected_ids:
		if pokemon_id not in selected_ids and selected_ids.size() >= _offer_limit():
			_show_error("The other player does not have enough free party slots.")
		return true
	_replace_offer(replacement)
	return true


func begin_party_offer_drag(pokemon_payload: Dictionary) -> bool:
	if not visible or str(trade.get("status", "")) != "active":
		return false
	end_party_offer_drag()
	party_drag_preview = TextureRect.new()
	party_drag_preview.custom_minimum_size = Vector2(58, 58)
	party_drag_preview.size = Vector2(58, 58)
	party_drag_preview.texture = PokemonAssets.load_party_icon(_pokemon_species(pokemon_payload), bool(pokemon_payload.get("shiny", false)))
	party_drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	party_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	party_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	party_drag_preview.z_index = 1000
	add_child(party_drag_preview)
	update_party_offer_drag(DisplayServer.mouse_get_position())
	return true


func update_party_offer_drag(global_position: Vector2) -> void:
	if party_drag_preview == null:
		return
	party_drag_preview.position = _main_to_workspace_position(global_position) - party_drag_preview.size * 0.5


func end_party_offer_drag() -> void:
	if party_drag_preview != null:
		party_drag_preview.queue_free()
	party_drag_preview = null


func _main_to_workspace_position(global_position: Vector2) -> Vector2:
	if get_viewport() == get_tree().root:
		return global_position
	return global_position - Vector2(position)


static func build_drop_replacement(current_ids: Array[int], pokemon_id: int, target_position: int, limit: int) -> Array[int]:
	var result := current_ids.duplicate()
	if pokemon_id <= 0 or pokemon_id in result:
		return result
	if target_position >= 0 and target_position < result.size():
		result[target_position] = pokemon_id
	elif result.size() < clampi(limit, 0, MAX_OFFER_SIZE):
		result.append(pokemon_id)
	return result


func _offer_slot_at_position(global_position: Vector2) -> int:
	for index in range(local_offer_slots.size()):
		if local_offer_slots[index].get_global_rect().has_point(global_position):
			return index
	return -1


func _candidate_by_party_slot(party_slot: int) -> Dictionary:
	for candidate in candidates:
		if int(candidate.get("location", {}).get("partySlot", -1)) == party_slot:
			return candidate
	return {}


func _candidate_by_id(pokemon_id: int) -> Dictionary:
	for candidate in candidates:
		if int(candidate.get("pokemonId", 0)) == pokemon_id:
			return candidate
	return {}


static func normalize_summary_payload(value: Dictionary) -> Dictionary:
	var payload := value.duplicate(true)
	if str(payload.get("species", "")).strip_edges() == "":
		payload["species"] = str(payload.get("speciesId", payload.get("speciesName", "")))
	if not payload.has("ownedPokemonId") and payload.has("pokemonId"):
		payload["ownedPokemonId"] = int(payload.get("pokemonId", 0))
	return payload


func _render_mode() -> void:
	var locked := str(trade.get("status", "")) == "locked"
	editable_root.visible = not locked
	review_root.visible = locked
	if locked:
		_render_locked_review()
		return
	var local_ready := _local_participant_ready()
	local_ready_indicator.visible = local_ready
	opponent_ready_indicator.visible = _opponent_participant_ready()
	var blocked := _connection_state_unresolved()
	ready_button.visible = not local_ready
	ready_button.disabled = mutation_in_flight or not _local_offer_nonempty() or blocked
	edit_button.visible = local_ready
	edit_button.disabled = mutation_in_flight or blocked
	if local_ready:
		status_label.text = "Your offer is ready and cannot be edited."
	elif _opponent_receive_capacity() <= 0:
		status_label.text = "The other player needs a free party slot before you can offer a Pokemon."
	elif not _local_offer_nonempty():
		status_label.text = "Offer at least one Pokemon before becoming Ready."
	else:
		status_label.text = ""


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


func _opponent_participant_ready() -> bool:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) != user_id:
			return bool(participant_value.get("ready", false))
	return false


func _local_participant_confirmed() -> bool:
	var user_id := _current_user_id()
	for participant_value: Variant in trade.get("participants", []):
		if participant_value is Dictionary and int(participant_value.get("userId", 0)) == user_id:
			return bool(participant_value.get("confirmed", false))
	return false


func _local_offer_nonempty() -> bool:
	var user_id := _current_user_id()
	for offer_value: Variant in trade.get("offers", []):
		if offer_value is Dictionary and int(offer_value.get("userId", 0)) == user_id:
			return offer_value.get("pokemon", []) is Array and not offer_value.get("pokemon", []).is_empty()
	return false


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
		"trade_offer_required": return "Offer at least one Pokemon before becoming Ready."
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


func _pokemon_species(value: Dictionary) -> String:
	return str(value.get("speciesId", value.get("species", value.get("speciesName", ""))))


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
