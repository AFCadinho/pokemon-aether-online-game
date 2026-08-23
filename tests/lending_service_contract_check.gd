extends SceneTree

const ServiceScript := preload("res://scripts/services/lending_service.gd")
const WorkspaceScript := preload("res://scripts/ui/lending_workspace.gd")
const InvitationScript := preload("res://scripts/ui/loan_invitation_dialog.gd")
const ReturnsDialogScript := preload("res://scripts/ui/loan_returns_dialog.gd")
const BorrowedPokemonDialogScript := preload("res://scripts/ui/borrowed_pokemon_dialog.gd")
const PokemonFactoryScript := preload("res://scripts/data/pokemon_factory.gd")

var failed := false


func _init() -> void:
	var service := ServiceScript.new()
	var capabilities := service.normalize_capabilities({"enabled": true, "maxBorrowedPokemon": 6, "maxBorrowedItems": 6, "maxLentPokemon": 30, "maxLentItems": 30, "maxPendingOffers": 5})
	_check(bool(capabilities.get("enabled", false)), "enabled capability")
	_check(int(capabilities.get("maxBorrowedPokemon", 0)) == 6, "borrower Pokemon cap")
	_check(int(capabilities.get("maxLentItems", 0)) == 30, "lender item cap")
	_check(bool(capabilities.get("requiresSameMap", false)), "nearby same-map requirement")
	var source := FileAccess.get_file_as_string("res://scripts/services/lending_service.gd")
	for contract in ["func create_loan", "func accept_loan", "func decline_loan", "func cancel_loan", "func request_return", "func return_assets", "func attach_item", "func detach_item", "func load_notifications", "func acknowledge_notification", "func load_return_inbox", "func acknowledge_return"]:
		_check(source.contains(contract), contract)
	var workspace_source := FileAccess.get_file_as_string("res://scripts/ui/lending_workspace.gd")
	_check(workspace_source.contains("loan_asset_mode") and workspace_source.contains("_request_asset_mode") and workspace_source.contains("_render_item_offer_assets"), "loan composer separates Pokemon and item offer modes")
	_check(source.contains("A loan offer must contain only Pokemon or only items."), "loan client rejects mixed asset offers")
	var inventory_source := FileAccess.get_file_as_string("res://scripts/services/inventory_service.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(inventory_source.contains("cached_borrowed_inventory_items") and inventory_source.contains("borrowedItems"), "inventory service keeps borrowed assets separate from owned items")
	_check(overlay_source.contains("ui.bag.loan_marker") and overlay_source.contains("_bag_item_key") and overlay_source.contains("loanAssetId"), "Bag identifies and labels borrowed item copies")
	var party_slot_source := FileAccess.get_file_as_string("res://scripts/ui/party_slot.gd")
	_check(party_slot_source.contains("_setup_loan_marker") and party_slot_source.contains("returnRequestedAt") and party_slot_source.contains("loan_requested.emit"), "Party cards mark borrowed Pokemon and open Player Loans")
	_check(overlay_source.contains("_add_pc_loan_marker") and overlay_source.contains("_pc_borrowed_pokemon_entries") and overlay_source.contains("BORROWED_POKEMON_DIALOG_SCRIPT") and overlay_source.contains("_on_pc_loan_marker_gui_input"), "PC cards mark and list borrowed Pokemon")
	var borrowed_dialog := BorrowedPokemonDialogScript.new()
	_check(borrowed_dialog.has_signal("locate_requested") and borrowed_dialog.has_signal("loans_requested"), "borrowed Pokemon list supports location and loan management")
	borrowed_dialog.free()
	var borrowed_pokemon := PokemonFactoryScript.create_pokemon_from_backend_payload({"species": "Pikachu", "level": 20, "borrowed": true, "loan": {"lenderUsername": "misty", "status": "active"}})
	_check(borrowed_pokemon != null and borrowed_pokemon.borrowed and str(borrowed_pokemon.loan.get("lenderUsername", "")) == "misty", "borrowed Pokemon retain loan metadata in runtime cards")
	_check(workspace_source.contains("_open_attach_menu") and workspace_source.contains("_detach_loan_item"), "borrowed item attach and detach controls")
	_check(workspace_source.contains("_poll_incoming_offers") and workspace_source.contains("load_loans(\"borrowed\")"), "incoming loan offers are polled for the borrower")
	var invitation_source := FileAccess.get_file_as_string("res://scripts/ui/loan_invitation_dialog.gd")
	_check(invitation_source.contains("accept_loan") and invitation_source.contains("decline_loan"), "incoming offer has direct accept and decline actions")
	_check(invitation_source.contains("open_trade_pokemon_summary"), "incoming Pokemon can open a read-only summary")
	_check(invitation_source.contains("_refresh_after_acceptance") and invitation_source.contains("refresh_party") and invitation_source.contains("load_inventory"), "accepted loans refresh visible player state")
	_check(workspace_source.contains("_apply_checkbox_style") and workspace_source.contains("_checkbox_icon"), "loan asset selection remains clearly visible")
	_check(workspace_source.contains("_toggle_pokemon_selection") and workspace_source.contains("party_candidates.size() - 1") and workspace_source.contains("ui.lending.error.party_required"), "lender must retain one party Pokemon")
	_check(workspace_source.contains("ui.lending.pokemon_not_lendable") and workspace_source.contains("box.disabled = not is_lendable"), "non-lendable Pokemon are visibly marked and disabled in Party and Box results")
	_check(workspace_source.contains("_set_workspace_mode(false)") and workspace_source.contains("loans_panel.visible = not is_composing"), "Socials Loans opens as a management-only overview")
	_check(workspace_source.contains("loan_overview_view := \"borrowed\"") and workspace_source.contains("Currently borrowing") == false, "loan overview defaults to the borrowed API view without hardcoded display text")
	_check(workspace_source.contains("_render_loan_type_tabs") and workspace_source.contains("_loans_for_asset_type"), "loan overview separates Pokemon and item tabs")
	_check(workspace_source.contains("create_loan(target_username") and not workspace_source.contains("create_loan(target_input"), "nearby target is fixed by player interaction")
	_check(workspace_source.contains("_loan_asset_row") and workspace_source.contains("_status_badge") and workspace_source.contains("_loan_timing_text"), "loan cards expose assets, status, and timing details")
	_check(workspace_source.contains("loan_overview_view != \"history\"") and workspace_source.contains("[\"returned\", \"declined\", \"cancelled\", \"expired\"]"), "terminal loans stay in History")
	_check(workspace_source.contains("_return_loan_asset") and workspace_source.contains("return_assets(loan_id, [asset_id])"), "borrowed assets return individually")
	_check(workspace_source.contains("_request_loan_asset_return") and workspace_source.contains("request_return(loan_id, asset_id)") and not workspace_source.contains("_loan_action.bind(\"request-return\""), "lenders request individual assets without a contract-wide recall")
	_check(workspace_source.contains("_poll_loan_notifications") and workspace_source.contains("acknowledge_notification"), "durable loan notifications become system messages and are acknowledged")
	_check(workspace_source.contains("custody_changed") and workspace_source.contains("ui.lending.notification.accepted") and workspace_source.contains("await _refresh_after_asset_return()"), "loan custody notifications refresh Party, PC, and Bag state")
	_check(not workspace_source.contains("service.return_assets(loan_id)"), "loan cards never return every asset implicitly")
	var workspace := WorkspaceScript.new()
	_check(not workspace._pokemon_candidate_is_lendable({"pokemon": {"tradable": false}}), "non-tradable Pokemon are identified before offer selection")
	_check(workspace._pokemon_candidate_is_lendable({"pokemon": {"tradable": true}}), "tradable Pokemon remain selectable for lending")
	var locked_candidate_row := workspace._pokemon_candidate_row({"pokemonId": 25, "name": "Starter", "speciesId": "pikachu", "level": 5, "pokemon": {"speciesId": "pikachu", "tradable": false}}, 25)
	var locked_checkboxes := _checkboxes(locked_candidate_row)
	_check(locked_checkboxes.size() == 1 and locked_checkboxes[0].disabled, "non-lendable Pokemon render with a disabled selector")
	_check(_has_label_fragment(locked_candidate_row, "ui.lending.pokemon_not_lendable"), "non-lendable Pokemon render a visible reason")
	locked_candidate_row.free()
	workspace.loans = [
		{"loanId": "pokemon-loan", "assets": [{"assetType": "pokemon"}]},
		{"loanId": "item-loan", "assets": [{"assetType": "item"}, {"assetType": "item"}]},
	]
	_check(workspace._loans_for_asset_type("pokemon").size() == 1 and workspace._loans_for_asset_type("items").size() == 1, "asset tabs keep each single-type loan in its matching overview")
	_check(workspace._format_loan_time("2026-08-23T16:45:12+00:00") == "2026-08-23 16:45 UTC", "loan timestamps are player readable")
	var countdown_now := int(Time.get_unix_time_from_datetime_string("2026-08-23T20:00:00"))
	_check(workspace._seconds_until_loan_deadline("2026-08-23T20:30:00+00:00", countdown_now) == 1800, "loan deadline countdown parses backend UTC timestamps")
	_check(workspace._loan_remaining_text("2026-08-23T20:30:00+00:00", countdown_now) == "ui.lending.remaining.minutes", "the final loan hour switches to minute precision")
	_check(workspace._loan_remaining_text("2026-08-23T21:00:00+00:00", countdown_now) == "", "a full hour remaining keeps the normal deadline display")
	_check(workspace._seconds_until_loan_deadline("2026-08-23T19:30:00+00:00", countdown_now) == -1800, "past loan deadlines retain their overdue duration")
	_check(workspace._loan_remaining_text("2026-08-23T19:30:00+00:00", countdown_now) == "ui.lending.remaining.overdue_minutes", "past loan deadlines are labelled overdue instead of due now")
	_check(workspace_source.contains("_setup_deadline_refresh") and workspace_source.contains("_refresh_loan_deadline_labels"), "visible loan minute countdowns refresh while the window stays open")
	_check(workspace._status_color("pending") == Color("#d8b767") and workspace._status_color("expired").a == 1.0, "loan status colors remain distinct")
	_check(workspace_source.contains("_loan_terms_text") and workspace_source.contains("ui.lending.card.item_terms"), "item loan terms omit the irrelevant Pokemon count")
	_check(workspace_source.contains("_loan_contents_title") and workspace_source.contains("ui.lending.card.item_contents"), "item loan cards label their contents and count")
	_check(workspace_source.contains("ui.lending.card.item_copy_meta") and workspace_source.contains("_open_item_details"), "each item copy has a clear identity and read-only detail action")
	_check(workspace_source.contains("panel.tooltip_text = description") and workspace_source.contains("icon.tooltip_text = description"), "item loan rows expose item descriptions")
	var first_item_row := workspace._loan_asset_row({"assetId": "item-1", "assetType": "item", "status": "active", "itemId": "leftovers", "heldPokemonId": null, "snapshot": {"id": "leftovers", "name": "Leftovers"}}, false, "active", "item-loan", 1, 2)
	var second_item_row := workspace._loan_asset_row({"assetId": "item-2", "assetType": "item", "status": "active", "itemId": "choice-band", "heldPokemonId": null, "snapshot": {"id": "choice-band", "name": "Choice Band"}}, false, "active", "item-loan", 2, 2)
	_check(first_item_row != null and second_item_row != null, "null held-Pokemon ids still render every item copy as its own row")
	_check("ui.lending.request_return_asset" in _button_texts(first_item_row) and "ui.lending.request_return_asset" in _button_texts(second_item_row), "each rendered item copy keeps its own request-return action")
	_check(workspace._optional_string(null) == "", "nullable return timestamps do not become false return requests")
	first_item_row.free()
	second_item_row.free()
	var party := workspace._party_candidates([{"id": 7, "pokemon": {"species": "Pikachu", "level": 22, "item": "light-ball"}}])
	_check(party.size() == 1 and int(party[0].get("pokemonId", 0)) == 7, "party candidate normalization")
	_check(str(party[0].get("heldItemId", "")) == "light-ball", "held item remains an explicit selectable asset")
	var items := workspace._item_candidates([{"itemId": "leftovers", "name": "Leftovers", "quantity": 2, "category": "held-items", "isHoldable": true, "tradable": true}, {"itemId": "oran-berry", "quantity": 3, "category": "berries", "isHoldable": true, "tradable": true}, {"itemId": "potion", "quantity": 1, "category": "medicine", "isHoldable": false, "tradable": true}, {"itemId": "secret-key", "quantity": 1, "category": "key-items", "isHoldable": false, "tradable": false}])
	_check(items.size() == 1 and str(items[0].get("itemId", "")) == "leftovers", "key items excluded from client candidates")
	_check(workspace_source.contains("_selected_item_copy_count") and workspace_source.contains("\"quantity\": int(selected_items.get"), "multiple item copies remain separate loan assets")
	var box_candidates := workspace._box_candidates([{"boxIndex": 2, "slots": [{"slotIndex": 4, "pokemon": {"id": 9, "pokemon": {"species": "Abra", "level": 8}}}]}])
	_check(box_candidates.size() == 1 and int(box_candidates[0].get("pokemonId", 0)) == 9 and str(box_candidates[0].get("sourceType", "")) == "box", "PC Box Pokemon are selectable loan candidates")
	workspace.box_candidates = box_candidates
	workspace.pokemon_source_mode = 1
	workspace.pokemon_search_query = "abra"
	_check(workspace._visible_pokemon_candidates().size() == 1, "loan Box search finds Pokemon across PC Boxes")
	workspace.pokemon_search_query = "missingno"
	_check(workspace._visible_pokemon_candidates().is_empty(), "loan Box search filters unmatched Pokemon")
	workspace.pokemon_boxes = workspace._pokemon_boxes([{"boxIndex": 2, "slots": []}])
	_check(workspace.pokemon_boxes.size() == 1 and int(workspace.pokemon_boxes[0].get("boxIndex", -1)) == 2, "untyped Box API arrays normalize before typed assignment")
	workspace.party_candidates = [{"pokemonId": 1, "heldItemId": "leftovers", "name": "Pikachu"}]
	workspace.box_candidates = [{"pokemonId": 2, "heldItemId": "choice-band", "name": "Machamp"}]
	_check(workspace._held_item_candidates().size() == 2, "item-only offers include eligible items held by Party and Box Pokemon")
	_check(source.contains("duration_seconds not in [3600, 10800, 21600, 43200, 86400, 172800, 259200]"), "loan service accepts one-to-72-hour windows")
	_check(workspace_source.contains("[3600, 10800, 21600, 43200, 86400, 172800, 259200]") and workspace_source.contains("172800: return _t(\"ui.lending.duration.forty_eight_hours\")") and workspace_source.contains("259200: return _t(\"ui.lending.duration.seventy_two_hours\")"), "loan duration selector includes 48 and 72 hours")
	_check(workspace_source.contains("select.get_popup()") and workspace_source.contains("_dropdown_popup_style"), "loan dropdown popups use the Aether theme")
	_check(workspace_source.contains("AetherConfirmationDialogScene.instantiate()"), "loan confirmations use the Aether dialog")
	var option := OptionButton.new()
	workspace._apply_option_style(option)
	_check(option.get_popup().has_theme_stylebox_override("panel") and option.get_popup().has_theme_stylebox_override("hover"), "loan dropdown popup theme is applied at runtime")
	option.free()
	var confirmation_source := FileAccess.get_file_as_string("res://scripts/ui/aether_confirmation_dialog.gd")
	var confirmation_scene := FileAccess.get_file_as_string("res://scenes/interface/aether_confirmation_dialog.tscn")
	_check(confirmation_source.contains("func add_custom_control") and confirmation_scene.contains("name=\"CustomContent\""), "Aether confirmation supports a styled loan selector")
	var returns_source := FileAccess.get_file_as_string("res://scripts/ui/loan_returns_dialog.gd")
	_check(returns_source.contains("locate_requested") and returns_source.contains("acknowledge_return"), "PC loan return inbox locates and acknowledges returned Pokemon")
	workspace.free()
	service.free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)


func _button_texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Button:
		result.append((node as Button).text)
	for child: Node in node.get_children():
		result.append_array(_button_texts(child))
	return result


func _checkboxes(node: Node) -> Array[CheckBox]:
	var result: Array[CheckBox] = []
	if node is CheckBox:
		result.append(node as CheckBox)
	for child: Node in node.get_children():
		result.append_array(_checkboxes(child))
	return result


func _label_texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	for child: Node in node.get_children():
		result.append_array(_label_texts(child))
	return result


func _has_label_fragment(node: Node, fragment: String) -> bool:
	for label_text: String in _label_texts(node):
		if fragment in label_text:
			return true
	return false
