extends "res://tests/support/mount_box_test_overlay.gd"

var pokemon_target_requests := 0

func _show_bag_item_use_popup(_item: Dictionary) -> void:
	pokemon_target_requests += 1
