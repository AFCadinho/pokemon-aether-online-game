extends SceneTree

class TestOverlay extends Node:
	var system_messages: Array[String] = []
	var system_warnings: Array[String] = []

	func add_system_message(message: String) -> void:
		system_messages.append(message)

	func add_system_warning(message: String) -> void:
		system_warnings.append(message)


var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var overlay := TestOverlay.new()
	overlay.add_to_group("ui_overlay")
	root.add_child(overlay)

	var item_scene := load("res://scenes/world/interactables/overworld_item.tscn") as PackedScene
	_check(item_scene != null, "ground item scene loads for notification checks")
	if item_scene == null:
		quit(1)
		return
	var item := item_scene.instantiate() as Node
	root.add_child(item)
	item.call("_add_pickup_system_message", "You found a Potion!")

	_check(overlay.system_messages.size() == 1, "ground item adds one System message")
	_check(
		not overlay.system_messages.is_empty()
		and overlay.system_messages[0].contains("Potion"),
		"ground item System message names the received item"
	)
	item.call("_notify_pickup_warning", "Pickup unavailable")
	_check(
		overlay.system_warnings == ["Pickup unavailable"],
		"ground item errors use a System warning"
	)

	var item_source := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/overworld_item.gd"
	)
	_check(
		not item_source.contains("show_dialogue("),
		"ground item interactions no longer open a dialogue or mugshot"
	)
	_check(
		item_source.contains('SfxManager.play("item_found")'),
		"ground item keeps the item-found sound"
	)

	item.free()
	overlay.free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
