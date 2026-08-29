extends SceneTree

const REWARD_NOTIFICATION_STACK_SCRIPT := preload("res://scripts/ui/reward_notification_stack.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stack := REWARD_NOTIFICATION_STACK_SCRIPT.new() as VBoxContainer
	stack.set("auto_expire", false)
	stack.set("max_visible", 4)
	root.add_child(stack)

	stack.call("show_reward", "item:potion", "Potion", null, 2, "×")
	_check(stack.get_child_count() == 1, "first reward creates one card")
	var potion_card := stack.get_child(0) as PanelContainer
	_check(potion_card != null, "reward entry is a card")
	_check(_detail_text(potion_card) == "×2", "item card shows its quantity")

	stack.call("show_reward", "item:potion", "Potion", null, 3, "×")
	_check(stack.get_child_count() == 1, "matching rewards reuse the existing card")
	_check(_detail_text(potion_card) == "×5", "matching rewards add their quantities")

	stack.call("show_reward", "currency:money", "Pokédollars", null, 1250, "₽")
	_check(stack.get_child(0).get_meta("reward_key") == "currency:money", "newest reward appears first")
	_check(_detail_text(stack.get_child(0) as PanelContainer) == "₽1,250", "money card formats its amount")

	stack.call("show_reward", "item:antidote", "Antidote", null, 1, "×")
	stack.call("show_reward", "item:ether", "Ether", null, 1, "×")
	stack.call("show_reward", "item:revive", "Revive", null, 1, "×")
	_check(stack.get_child_count() == 4, "stack keeps at most four cards")
	_check(_find_reward(stack, "item:potion") == null, "oldest card is removed when the stack is full")

	var inventory_source := FileAccess.get_file_as_string("res://scripts/services/inventory_service.gd")
	_check(inventory_source.contains("signal item_received"), "inventory rewards expose structured item events")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(overlay_source.contains("func add_reward_notification("), "overlay exposes a reusable reward-card API")
	_check(overlay_source.contains("func add_currency_reward_notification("), "reward cards support currencies")
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(
		world_source.contains('"add_money_reward_notification", money_awarded'),
		"battle money uses reward cards"
	)
	_check(
		world_source.contains("_story_reward_item_grants")
		and world_source.contains('"add_item_reward_notification"'),
		"story and fishing items use reward cards"
	)
	_check(
		overlay_source.contains("purchased_item_id,")
		and overlay_source.contains("add_item_reward_notification(box_item_id, 1)")
		and overlay_source.contains("add_item_reward_notification(item_id, transacted_quantity)"),
		"purchased and crafted items use reward cards"
	)

	stack.free()
	quit(1 if failed else 0)


func _detail_text(card: PanelContainer) -> String:
	if card == null:
		return ""
	var detail := card.find_child("RewardDetail", true, false) as Label
	return detail.text if detail != null else ""


func _find_reward(stack: VBoxContainer, reward_key: String) -> Control:
	for child: Node in stack.get_children():
		if str(child.get_meta("reward_key", "")) == reward_key:
			return child as Control
	return null


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
