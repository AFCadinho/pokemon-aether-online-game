extends SceneTree

const ServiceScript := preload("res://scripts/services/lending_service.gd")
const WorkspaceScript := preload("res://scripts/ui/lending_workspace.gd")

var failed := false


func _init() -> void:
	var service := ServiceScript.new()
	var capabilities := service.normalize_capabilities({"enabled": true, "maxBorrowedPokemon": 6, "maxBorrowedItems": 6, "maxLentPokemon": 30, "maxLentItems": 30, "maxPendingOffers": 5})
	_check(bool(capabilities.get("enabled", false)), "enabled capability")
	_check(int(capabilities.get("maxBorrowedPokemon", 0)) == 6, "borrower Pokemon cap")
	_check(int(capabilities.get("maxLentItems", 0)) == 30, "lender item cap")
	var source := FileAccess.get_file_as_string("res://scripts/services/lending_service.gd")
	for contract in ["func create_loan", "func accept_loan", "func decline_loan", "func cancel_loan", "func request_return", "func return_assets", "func attach_item", "func detach_item"]:
		_check(source.contains(contract), contract)
	var workspace_source := FileAccess.get_file_as_string("res://scripts/ui/lending_workspace.gd")
	_check(workspace_source.contains("_open_attach_menu") and workspace_source.contains("_detach_loan_item"), "borrowed item attach and detach controls")
	var workspace := WorkspaceScript.new()
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
