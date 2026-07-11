extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	root.add_child(host)

	var bag_source := HotbarBagItemSlot.new()
	bag_source.hotbar_item = {"id": "potion", "gameplay": {"effects": [{"type": "heal_hp"}]}}
	host.add_child(bag_source)
	var bag_data: Variant = bag_source._get_drag_data(Vector2.ZERO)
	_check(bag_data is Dictionary and str((bag_data as Dictionary).get("kind", "")) == "bag_hotbar_item", "Bag slot produces native drag data")

	var target := PlayerHotbarSlotButton.new()
	target.slot_index = 3
	host.add_child(target)
	var bag_drops: Array = []
	target.bag_item_dropped.connect(func(slot_index: int, item: Dictionary) -> void: bag_drops.append([slot_index, item]))
	_check(target._can_drop_data(Vector2.ZERO, bag_data), "hotbar accepts Bag drag data")
	target._drop_data(Vector2.ZERO, bag_data)
	_check(bag_drops.size() == 1 and int(bag_drops[0][0]) == 3 and str(bag_drops[0][1].get("id", "")) == "potion", "Bag drop targets exact hotbar slot")

	var hotbar_source := PlayerHotbarSlotButton.new()
	hotbar_source.slot_index = 1
	hotbar_source.hotbar_entry = {"slot": 1, "entryType": "item", "entryId": "potion"}
	host.add_child(hotbar_source)
	var hotbar_data: Variant = hotbar_source._get_drag_data(Vector2.ZERO)
	var moves: Array = []
	target.hotbar_entry_dropped.connect(func(source_slot: int, target_slot: int) -> void: moves.append([source_slot, target_slot]))
	_check(target._can_drop_data(Vector2.ZERO, hotbar_data), "hotbar accepts another hotbar entry")
	target._drop_data(Vector2.ZERO, hotbar_data)
	_check(moves == [[1, 3]], "hotbar entry moves between exact slots")

	host.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
