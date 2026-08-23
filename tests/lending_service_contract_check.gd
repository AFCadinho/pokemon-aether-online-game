extends SceneTree

const ServiceScript := preload("res://scripts/services/lending_service.gd")
const WorkspaceScript := preload("res://scripts/ui/lending_workspace.gd")
const InvitationScript := preload("res://scripts/ui/loan_invitation_dialog.gd")

var failed := false


func _init() -> void:
	var service := ServiceScript.new()
	var capabilities := service.normalize_capabilities({"enabled": true, "maxBorrowedPokemon": 6, "maxBorrowedItems": 6, "maxLentPokemon": 30, "maxLentItems": 30, "maxPendingOffers": 5})
	_check(bool(capabilities.get("enabled", false)), "enabled capability")
	_check(int(capabilities.get("maxBorrowedPokemon", 0)) == 6, "borrower Pokemon cap")
	_check(int(capabilities.get("maxLentItems", 0)) == 30, "lender item cap")
	_check(bool(capabilities.get("requiresSameMap", false)), "nearby same-map requirement")
	var source := FileAccess.get_file_as_string("res://scripts/services/lending_service.gd")
	for contract in ["func create_loan", "func accept_loan", "func decline_loan", "func cancel_loan", "func request_return", "func return_assets", "func attach_item", "func detach_item", "func load_notifications", "func acknowledge_notification"]:
		_check(source.contains(contract), contract)
	var workspace_source := FileAccess.get_file_as_string("res://scripts/ui/lending_workspace.gd")
	_check(workspace_source.contains("_open_attach_menu") and workspace_source.contains("_detach_loan_item"), "borrowed item attach and detach controls")
	_check(workspace_source.contains("_poll_incoming_offers") and workspace_source.contains("load_loans(\"borrowed\")"), "incoming loan offers are polled for the borrower")
	var invitation_source := FileAccess.get_file_as_string("res://scripts/ui/loan_invitation_dialog.gd")
	_check(invitation_source.contains("accept_loan") and invitation_source.contains("decline_loan"), "incoming offer has direct accept and decline actions")
	_check(invitation_source.contains("open_trade_pokemon_summary"), "incoming Pokemon can open a read-only summary")
	_check(invitation_source.contains("_refresh_after_acceptance") and invitation_source.contains("refresh_party") and invitation_source.contains("load_inventory"), "accepted loans refresh visible player state")
	_check(workspace_source.contains("_apply_checkbox_style") and workspace_source.contains("_checkbox_icon"), "loan asset selection remains clearly visible")
	_check(workspace_source.contains("_toggle_pokemon_selection") and workspace_source.contains("party_candidates.size() - 1") and workspace_source.contains("ui.lending.error.party_required"), "lender must retain one party Pokemon")
	_check(workspace_source.contains("_set_workspace_mode(false)") and workspace_source.contains("loans_panel.visible = not is_composing"), "Socials Loans opens as a management-only overview")
	_check(workspace_source.contains("create_loan(target_username") and not workspace_source.contains("create_loan(target_input"), "nearby target is fixed by player interaction")
	_check(workspace_source.contains("_loan_asset_row") and workspace_source.contains("_status_badge") and workspace_source.contains("_loan_timing_text"), "loan cards expose assets, status, and timing details")
	_check(workspace_source.contains("selected_view < 3") and workspace_source.contains("[\"returned\", \"declined\", \"cancelled\", \"expired\"]"), "terminal loans stay in History")
	_check(workspace_source.contains("_return_loan_asset") and workspace_source.contains("return_assets(loan_id, [asset_id])"), "borrowed assets return individually")
	_check(workspace_source.contains("_poll_loan_notifications") and workspace_source.contains("acknowledge_notification"), "durable loan notifications become system messages and are acknowledged")
	_check(workspace_source.contains("custody_changed") and workspace_source.contains("ui.lending.notification.accepted") and workspace_source.contains("await _refresh_after_asset_return()"), "loan custody notifications refresh Party, PC, and Bag state")
	_check(not workspace_source.contains("service.return_assets(loan_id)"), "loan cards never return every asset implicitly")
	var workspace := WorkspaceScript.new()
	_check(workspace._format_loan_time("2026-08-23T16:45:12+00:00") == "2026-08-23 16:45 UTC", "loan timestamps are player readable")
	_check(workspace._status_color("pending") == Color("#d8b767") and workspace._status_color("expired").a == 1.0, "loan status colors remain distinct")
	var party := workspace._party_candidates([{"id": 7, "pokemon": {"species": "Pikachu", "level": 22, "item": "light-ball"}}])
	_check(party.size() == 1 and int(party[0].get("pokemonId", 0)) == 7, "party candidate normalization")
	_check(str(party[0].get("heldItemId", "")) == "light-ball", "held item remains an explicit selectable asset")
	var items := workspace._item_candidates([{"itemId": "leftovers", "name": "Leftovers", "quantity": 2, "category": "held-items"}, {"itemId": "secret-key", "quantity": 1, "category": "key-items"}])
	_check(items.size() == 1 and str(items[0].get("itemId", "")) == "leftovers", "key items excluded from client candidates")
	workspace.free()
	service.free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
