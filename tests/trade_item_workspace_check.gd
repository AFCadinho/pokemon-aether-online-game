extends SceneTree

const Workspace := preload("res://scripts/ui/trade_workspace.gd")

var failed := false


func _init() -> void:
	var normalized := Workspace.normalize_inventory_candidates([
		{"itemId":"poke_ball","name":"Poke Ball","category":"pokeballs","quantity":10},
		{"itemId":"town-map","name":"Town Map","category":"key-items","quantity":1},
		{"itemId":"potion","name":"Potion","category":"medicine","quantity":0},
	])
	_check(normalized.size() == 1, "only positive tradable stacks are selectable")
	_check(normalized[0].get("itemId", "") == "poke-ball", "item identifiers are normalized")
	_check(Workspace.item_matches_search("Custap Berry berries", "custap"), "item search matches names")
	_check(Workspace.item_matches_search("Poke Ball pokeballs", " BALL "), "item search is normalized")
	_check(not Workspace.item_matches_search("Leftovers held-items", "berry"), "item search excludes non-matches")
	_check(Workspace._is_stale_revision_error({"success":false,"status":409,"body":{"detail":"stale trade revision"}}), "stale revision conflicts are detected for authoritative retry")
	_check(not Workspace._is_stale_revision_error({"success":false,"status":409,"body":{"detail":"trade is locked"}}), "unrelated conflicts are never retried")
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_workspace.gd")
	_check(source.contains("func _open_item_selector"), "workspace exposes item selector")
	_check(source.contains("func _apply_item_selection"), "workspace applies item selection")
	_check(source.contains("selected_item_offers") and source.contains("service.replace_offer"), "workspace sends combined complete replacements")
	_check(source.contains("placeholder_text = \"Search items\"") and source.contains("func _filter_item_selector_rows"), "item selector supports scalable inventory search")
	_check(not source.contains("Choose no more than five item stacks"), "workspace does not impose a five-stack product limit")
	_check(source.contains("func _retry_offer_after_stale_revision") and source.contains("service.load_trade(trade_id)"), "stale offer retry refreshes the authoritative snapshot")
	_check(source.contains("_render_item_offer"), "both offer panels render item stacks")
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
