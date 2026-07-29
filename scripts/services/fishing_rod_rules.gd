extends RefCounted
class_name FishingRodRules

const ROD_TIERS := {
	"old-rod": 1,
	"good-rod": 2,
	"super-rod": 3,
}


static func resolve_tier(items: Array) -> int:
	var highest_tier := 0
	for item_value: Variant in items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		if int(item.get("quantity", 0)) <= 0:
			continue
		var item_id := str(item.get("itemId", item.get("id", ""))).strip_edges().to_lower()
		highest_tier = maxi(highest_tier, int(ROD_TIERS.get(item_id, 0)))
	return highest_tier
