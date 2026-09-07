extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var overlay_script := load("res://scripts/ui/ui_overlay.gd") as GDScript
	if overlay_script == null or not overlay_script.can_instantiate():
		push_error("Bag overlay failed to compile")
		quit(1)
		return
	var overlay = overlay_script.new()
	var host := Control.new()
	root.add_child(host)
	overlay.root_control = host
	_check(overlay._bag_discard_quantity({"borrowed": true, "discardQuantity": 3}) == 0, "Borrowed copies cannot be discarded")
	_check(overlay._bag_discard_quantity({"quantity": 5}) == 0, "Missing server permission fails closed")
	var ordinary: Array[Dictionary] = overlay._normalize_bag_inventory_items([
		{"itemId": "potion", "quantity": 5, "discardable": true},
		{"itemId": "hm-surf", "quantity": 1, "discardable": false},
	])
	_check(overlay._bag_discard_quantity(ordinary[0]) == 5, "Owned quantity is available for discard")
	_check(overlay._bag_discard_quantity(ordinary[1]) == 0, "Protected item stays protected")
	for reverse in [false, true]:
		var stones: Array[Dictionary] = [
			{"id": "venusaurite", "canonicalItemId": "venusaurite", "ownershipVariant": "tradeable", "quantity": 3, "discardQuantity": 3},
			{"id": "venusaurite-bound", "canonicalItemId": "venusaurite", "ownershipVariant": "account_bound", "quantity": 1, "discardQuantity": 0},
		]
		if reverse:
			stones.reverse()
		var grouped: Array[Dictionary] = overlay._group_mega_stone_bag_items(stones)
		_check(grouped.size() == 1 and grouped[0]["discardQuantity"] == 3, "Grouped stones exclude bound quantity in either order")
		_check(grouped[0]["discardItemId"] == "venusaurite", "Grouped discard targets only tradable ID")
	for count in [1, 5]:
		overlay._show_bag_discard_dialog({"id": "potion", "name": "Potion", "discardQuantity": count})
		var dialog = host.get_child(host.get_child_count() - 1)
		var spin: SpinBox = dialog.custom_content.get_child(0)
		_check(spin.min_value == 1 and spin.max_value == count and spin.value == 1, "Quantity defaults to one and is bounded")
		_check(spin.visible == (count > 1), "Only stacks show a quantity picker")
		spin.value = 999
		_check(spin.value == count, "Quantity cannot exceed stack")
		dialog._cancel()
		_check(not overlay.bag_discard_busy, "Cancel releases the pending dialog")
		await process_frame
	# These loaders normally acquire a parent in the full overlay's _ready().
	overlay.pokemon_summary_sprite_loader.free()
	overlay.pokedex_sprite_loader.free()
	overlay.free()
	host.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS " + message)
