extends RefCounted

# Player consumables have no Pokémon target and can use the same dispatch from
# the Bag, its context menu, drag-and-drop and the hotbar.
const OVERWORLD_CONSUMABLE_ACTIONS := ["recharge_repel"]
const REPEL_ITEM_STEPS := {"repel": 100, "super-repel": 200, "max-repel": 250}


static func overworld_consumable_action(item: Dictionary) -> String:
	var action := str(item.get("useAction", "")).strip_edges().to_lower()
	if action in OVERWORLD_CONSUMABLE_ACTIONS:
		return action
	# Older inventory projections omit the field; only these exact catalog IDs
	# are safe to recognize locally. The server still validates every use.
	var item_id := str(item.get("id", item.get("itemId", ""))).strip_edges().to_lower()
	return "recharge_repel" if action.is_empty() and REPEL_ITEM_STEPS.has(item_id) else ""


static func is_overworld_consumable(item: Dictionary) -> bool:
	return not overworld_consumable_action(item).is_empty()
