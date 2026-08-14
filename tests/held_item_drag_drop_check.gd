extends SceneTree

const HeldItemDropTarget := preload("res://scripts/ui/held_item_drop_target_button.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	root.add_child(host)

	var source := HotbarBagItemSlot.new()
	source.hotbar_item = {
		"id": "leftovers",
		"name": "Leftovers",
		"category": "held_items",
		"quantity": 1,
	}
	host.add_child(source)
	var drag_data: Variant = source._get_drag_data(Vector2.ZERO)
	_check(
		drag_data is Dictionary and str((drag_data as Dictionary).get("kind", "")) == "bag_held_item",
		"held items in the Bag produce native drag data"
	)

	var target := HeldItemDropTarget.new()
	host.add_child(target)
	var drops: Array[Dictionary] = []
	target.held_item_dropped.connect(func(item: Dictionary) -> void: drops.append(item))
	_check(target._can_drop_data(Vector2.ZERO, drag_data), "Summary held-item target accepts a holdable Bag item")
	target._drop_data(Vector2.ZERO, drag_data)
	_check(drops.size() == 1 and str(drops[0].get("id", "")) == "leftovers", "Summary held-item drop preserves the item")

	var invalid_source := HotbarBagItemSlot.new()
	invalid_source.hotbar_item = {
		"id": "potion",
		"category": "medicine",
		"gameplay": {"effects": [{"type": "heal_hp"}]},
	}
	host.add_child(invalid_source)
	var invalid_drag: Variant = invalid_source._get_drag_data(Vector2.ZERO)
	_check(not target._can_drop_data(Vector2.ZERO, invalid_drag), "held-item targets reject ordinary Bag items")

	var party_scene := load("res://scenes/interface/party_slot.tscn") as PackedScene
	var party_slot := party_scene.instantiate()
	host.add_child(party_slot)
	await process_frame
	party_slot.call("set_pokemon_data", {"species": "pikachu", "level": 5, "maxHp": 20, "hp": 20})
	_check(not party_slot.call("_can_drop_data", Vector2.ZERO, drag_data), "read-only party projections reject held-item drops")
	party_slot.set("held_item_drop_enabled", true)
	var party_drops: Array = []
	party_slot.connect("held_item_dropped", func(slot_index: int, item: Dictionary) -> void: party_drops.append([slot_index, item]))
	party_slot.set("slot_index", 2)
	_check(party_slot.call("_can_drop_data", Vector2.ZERO, drag_data), "owned party slots accept held-item drops")
	party_slot.call("_drop_data", Vector2.ZERO, drag_data)
	_check(
		party_drops.size() == 1 and int(party_drops[0][0]) == 2 and str(party_drops[0][1].get("id", "")) == "leftovers",
		"party held-item drops retain the exact party slot and item"
	)

	host.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)
