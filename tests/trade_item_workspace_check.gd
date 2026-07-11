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
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_workspace.gd")
	_check(source.contains("func _open_item_selector"), "workspace exposes item selector")
	_check(source.contains("func _apply_item_selection"), "workspace applies item selection")
	_check(source.contains("selected_item_offers") and source.contains("service.replace_offer"), "workspace sends combined complete replacements")
	_check(source.contains("replacement.size() > MAX_OFFER_SIZE"), "workspace limits item stacks to five")
	_check(source.contains("_render_item_offer"), "both offer panels render item stacks")
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
