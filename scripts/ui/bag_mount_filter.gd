extends RefCounted

const Mounts := preload("res://scripts/services/mount_service.gd")
const TAB_IDS: Array[String] = ["all", "land", "surf", "boxes"]

static func normalize_tab(tab: String) -> String:
	return tab if tab in TAB_IDS else "all"

static func canonical_id(item: Dictionary) -> String:
	var value := str(item.get("canonicalItemId", "")).strip_edges()
	if value.is_empty():
		value = str(item.get("id", item.get("itemId", ""))).strip_edges()
	return value.to_lower().replace("_", "-").trim_suffix("-bound")

static func is_box(item: Dictionary) -> bool:
	return str(item.get("useAction", "")) == "open_mount_box" or canonical_id(item).ends_with("-mount-box")

static func movement_mode(item: Dictionary) -> String:
	var item_id := canonical_id(item)
	if is_box(item):
		item_id = item_id.trim_suffix("-box")
	var mount_id := Mounts.get_mount_id_for_unlock_item(item_id)
	return Mounts.get_mount_movement_mode(mount_id) if not mount_id.is_empty() else ""

static func matches(item: Dictionary, tab: String, tradeability: int = 0) -> bool:
	if str(item.get("category", "")) != "mounts":
		return false
	var tradeable := bool(item.get("tradable", false)) and not bool(item.get("borrowed", false))
	if tradeability == 1 and not tradeable or tradeability == 2 and tradeable:
		return false
	match normalize_tab(tab):
		"boxes":
			return is_box(item)
		"land", "surf":
			return not is_box(item) and movement_mode(item) == tab
	return true

static func matches_search(item: Dictionary, search: String) -> bool:
	var query := search.strip_edges().to_lower()
	return query.is_empty() or str(item.get("name", "")).to_lower().contains(query) or str(item.get("id", "")).to_lower().contains(query)

static func sort_items(items: Array[Dictionary]) -> void:
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order := str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", "")))
		return str(a.get("id", "")) < str(b.get("id", "")) if order == 0 else order < 0)
