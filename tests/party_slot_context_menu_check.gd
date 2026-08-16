extends SceneTree

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

	slot.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)
