extends RefCounted

# Player consumables have no Pokémon target and can use the same dispatch from
# the Bag, its context menu, drag-and-drop and the hotbar.
const OVERWORLD_CONSUMABLE_ACTIONS := ["recharge_repel"]


static func overworld_consumable_action(item: Dictionary) -> String:
	var action := str(item.get("useAction", "")).strip_edges().to_lower()
	return action if action in OVERWORLD_CONSUMABLE_ACTIONS else ""


static func is_overworld_consumable(item: Dictionary) -> bool:
	return not overworld_consumable_action(item).is_empty()
