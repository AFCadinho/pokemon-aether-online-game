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

	var pokemon_stack := REWARD_NOTIFICATION_STACK_SCRIPT.new() as VBoxContainer
	pokemon_stack.set("auto_expire", false)
	root.add_child(pokemon_stack)
	pokemon_stack.call(
		"show_event",
		"global-buff:exp:test",
		"Global EXP Boost",
		"Activated",
		null,
		"1h",
		"",
		Color("#d8b767"),
		null,
		0,
		0,
		6.0
	)
	var buff_card := pokemon_stack.get_child(0) as PanelContainer
	_check(_label_text(buff_card, "RewardTitle") == "Global EXP Boost", "generic event cards show a title")
	_check(_label_text(buff_card, "RewardSubtitle") == "Activated", "generic event cards show a subtitle")
	_check(_detail_text(buff_card) == "1h", "generic event cards show a duration")
	_check(
		is_equal_approx(float(buff_card.get_meta("display_seconds", 0.0)), 6.0),
		"generic event cards can override their display duration"
	)
	pokemon_stack.remove_child(buff_card)
	buff_card.free()
	pokemon_stack.call(
		"show_pokemon_event",
		"pokemon-level:owned:42",
		"Sparky",
		"Level omhoog",
		null,
		"",
		"",
		Color("#d8b767"),
		null,
		23,
		24
	)
	var level_card := pokemon_stack.get_child(0) as PanelContainer
	_check(_label_text(level_card, "RewardTitle") == "Sparky", "Pokemon cards show the nickname")
	_check(_label_text(level_card, "RewardSubtitle") == "Level omhoog", "level cards show their event")
	_check(_detail_text(level_card) == "Lv. 24", "a single level-up shows the new level")
	pokemon_stack.call(
		"show_pokemon_event",
		"pokemon-level:owned:42",
		"Sparky",
		"Level omhoog",
		null,
		"",
		"",
		Color("#d8b767"),
		null,
		24,
		26
	)
	_check(pokemon_stack.get_child_count() == 1, "quick level-ups for the same Pokemon merge")
	_check(_detail_text(level_card) == "Lv. 23 → 26", "merged level-ups retain the full level range")
	pokemon_stack.call(
		"show_pokemon_event",
		"pokemon-move:owned:42:1",
		"Sparky",
		"Thunderbolt",
		null,
		"",
		"ELECTRIC",
		Color("#f0d44b")
	)
	var move_card := pokemon_stack.get_child(0) as PanelContainer
	_check(_label_text(move_card, "RewardSubtitle") == "Thunderbolt", "move cards show the learned move")
	_check(_label_text(move_card, "RewardBadgeLabel") == "ELECTRIC", "move cards show a type badge")
	var ball_icon := GradientTexture1D.new()
	pokemon_stack.call(
		"show_pokemon_event",
		"pokemon-caught:owned:99:2",
		"Pikachu",
		"Gevangen",
		null,
		"",
		"",
		Color("#73d98b"),
		ball_icon
	)
	var caught_card := pokemon_stack.get_child(0) as PanelContainer
	_check(_label_text(caught_card, "RewardSubtitle") == "Gevangen", "caught cards identify the event")
	_check(caught_card.find_child("RewardTrailingIcon", true, false) != null, "caught cards show the used ball")

	var inventory_source := FileAccess.get_file_as_string("res://scripts/services/inventory_service.gd")
	_check(inventory_source.contains("signal item_received"), "inventory rewards expose structured item events")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(overlay_source.contains("func add_reward_notification("), "overlay exposes a reusable reward-card API")
	_check(overlay_source.contains("func add_currency_reward_notification("), "reward cards support currencies")
	_check(overlay_source.contains("func add_pokemon_level_reward_notification("), "overlay exposes level-up cards")
	_check(overlay_source.contains("func add_pokemon_move_reward_notification("), "overlay exposes learned-move cards")
	_check(overlay_source.contains("func add_caught_pokemon_reward_notification("), "overlay exposes caught-Pokemon cards")
	_check(overlay_source.contains("func _show_global_boost_activation_notification("), "overlay exposes global boost activation cards")
	_check(overlay_source.contains("func _show_global_heal_activation_notification("), "overlay exposes Global Heal activation cards")
	var overlay_script := load("res://scripts/ui/ui_overlay.gd") as Script
	var overlay: Node = overlay_script.new() if overlay_script != null else null
	_check(overlay != null, "reward icon checks can load the overlay")
	if overlay != null:
		_check(
			overlay.call("_machine_item_icon_path", "tm-thief", "", "")
				== "res://assets/items/icons/machine_DARK.png",
			"TM reward icons infer their move type without waiting for Bag metadata"
		)
		_check(
			overlay.call("_machine_item_icon_path", "hm-surf", "", "")
				== "res://assets/items/icons/machine_tr_WATER.png",
			"HM reward icons infer their move type without waiting for Bag metadata"
		)
		overlay.free()
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
	_check(
		world_source.contains('"add_pokemon_level_reward_notification", level_up')
		and world_source.contains('"add_pokemon_move_reward_notification"')
		and world_source.contains('"add_caught_pokemon_reward_notification"'),
		"Pokemon progression events use reward cards"
	)
	var sfx_source := FileAccess.get_file_as_string("res://scripts/services/sfx_manager.gd")
	_check(
		load("res://assets/audio/sfx/overworld/pokemon_level_up.ogg") is AudioStream,
		"level-up cards use an importable Ogg sound"
	)
	_check(
		sfx_source.contains('"pokemon_level_up"')
		and sfx_source.contains('"path": "res://assets/audio/sfx/overworld/pokemon_level_up.ogg"'),
		"the level-up sound is registered with the SFX manager"
	)
	_check(
		world_source.count('SfxManager.play("pokemon_level_up")') == 1
		and world_source.contains("if has_level_up:"),
		"a reward batch plays the level-up sound only once"
	)

	pokemon_stack.free()
	stack.free()
	quit(1 if failed else 0)


func _detail_text(card: PanelContainer) -> String:
	if card == null:
		return ""
	var detail := card.find_child("RewardDetail", true, false) as Label
	return detail.text if detail != null else ""


func _label_text(card: PanelContainer, node_name: String) -> String:
	if card == null:
		return ""
	var label := card.find_child(node_name, true, false) as Label
	return label.text if label != null else ""


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
