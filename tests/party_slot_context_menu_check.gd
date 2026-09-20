extends SceneTree

const POKEMON_FACTORY := preload("res://scripts/data/pokemon_factory.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/interface/party_slot.tscn") as PackedScene
	var slot := packed.instantiate()
	root.add_child(slot)
	await process_frame
	slot.set("slot_index", 3)
	var requests: Array = []
	slot.connect("context_requested", func(slot_index: int, position: Vector2) -> void: requests.append([slot_index, position]))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.global_position = Vector2(120, 80)
	slot.call("_on_click_button_gui_input", event)
	_check(requests == [[3, Vector2(120, 80)]], "right-click requests the exact party slot context menu")

	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	for action_name: String in ["PARTY_CONTEXT_SUMMARY", "PARTY_CONTEXT_GIVE_ITEM", "PARTY_CONTEXT_TAKE_ITEM", "PARTY_CONTEXT_SET_LEAD"]:
		_check(overlay_source.contains(action_name), "party context menu exposes %s" % action_name)
	_check(overlay_source.contains("_open_pokemon_summary_held_item_picker"), "give and change item open the held-item picker")
	_check(overlay_source.contains("_take_pokemon_held_item"), "take item uses the existing held-item service flow")
	_check(
		overlay_source.contains("_is_rental_held_item_locked(pokemon)")
			and overlay_source.contains("ui.pokemon_summary.held_item.rental_locked"),
		"locked rental items show a dedicated explanation before mutation"
	)
	var rental := POKEMON_FACTORY.create_pokemon_from_backend_payload({
		"species": "Scizor",
		"level": 100,
		"item": "leftovers",
		"heldItemLocked": true,
		"rentalActive": true,
		"rentalKind": "pokemon",
	})
	_check(
		rental != null and rental.held_item_locked and rental.rental_active and rental.rental_kind == "pokemon",
		"rental held-item lock metadata survives backend payload parsing"
	)
	var english: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en.json"))
	_check(
		english is Dictionary
			and str((english as Dictionary).get("ui.pokemon_summary.held_item.rental_locked", ""))
			== "This item belongs to the rental and cannot be removed or replaced.",
		"rental held-item lock has a clear player-facing message"
	)

	slot.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)
