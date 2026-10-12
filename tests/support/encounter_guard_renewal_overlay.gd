extends "res://tests/support/mount_box_test_overlay.gd"

var inventory: Node
var bag_refreshes := 0

func _ready() -> void:
	_setup_ui_confirm_popup()
	set_process(false)

func _encounter_guard_inventory_service() -> Node:
	return inventory

func _refresh_bag_items() -> void:
	bag_refreshes += 1

func _refresh_bag_detail() -> void:
	pass
