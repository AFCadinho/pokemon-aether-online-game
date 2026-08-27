extends SceneTree

const MountServiceScript := preload("res://scripts/services/mount_service.gd")

var failed := false


func _init() -> void:
	_check_catalog_and_frames()
	_check_land_mount_runtime_contract()
	_check_bike_shop_owner_contract()
	quit(1 if failed else 0)


func _check_catalog_and_frames() -> void:
	var definition := MountServiceScript.get_mount_definition("cyclizar")
	_check(str(definition.get("movementMode", "")) == "land", "Cyclizar is a land mount")
	_check(
		str(definition.get("unlockItemId", "")) == "cyclizar-mount",
		"Cyclizar requires its server-owned mount item"
	)
	_check(
		MountServiceScript.get_mount_id_for_unlock_item("cyclizar-mount") == "cyclizar",
		"mount entitlements resolve back to their reusable mount definition"
	)
	var texture := load("res://assets/mounts/cyclizar/mount.png") as Texture2D
	_check(
		texture != null and Vector2i(texture.get_size()) == Vector2i(128, 128),
		"Cyclizar keeps its supplied 4x4 grid of 32px frames"
	)
	var frames := MountServiceScript.get_mount_frames("cyclizar")
	_check(frames != null, "Cyclizar mount frames load")
	if frames != null:
		_check(frames.get_frame_count(&"walk_down") == 4, "Cyclizar has four down movement frames")
		var frame_texture := frames.get_frame_texture(&"idle_down", 0)
		_check(
			frame_texture != null and Vector2i(frame_texture.get_size()) == Vector2i(32, 32),
			"Cyclizar frames preserve their native pixel dimensions"
		)
	var foreground_frames := MountServiceScript.get_mount_foreground_frames("cyclizar")
	_check(foreground_frames != null, "Cyclizar has a foreground head layer for its rider")
	if foreground_frames != null:
		_check(
			Vector2i(foreground_frames.get_frame_texture(&"idle_down", 0).get_size())
			== Vector2i(32, 32),
			"Cyclizar foreground frames match its native frame size"
		)
	var bag_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(
		bag_source.contains('{"id": "mounts", "labelKey": "ui.bag.category.mounts", "iconItemId": "cyclizar-mount"}')
		and bag_source.contains('"power_stones", "mounts", "cosmetics"')
		and bag_source.contains("MountService.get_mount_id_for_unlock_item(item_id)"),
		"mount entitlements have their own visible Bag category and reuse the mount sprite as icon"
	)
	var voucher_icon := load("res://assets/items/icons/BIKEVOUCHER.png") as Texture2D
	_check(
		voucher_icon != null and Vector2i(voucher_icon.get_size()) == Vector2i(48, 48),
		"the Bike Voucher has a dedicated 48px pixel-art Bag icon"
	)


func _check_land_mount_runtime_contract() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var settings_source := FileAccess.get_file_as_string("res://scripts/services/settings_manager.gd")
	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	_check(project_source.contains("mount={"), "the land mount toggle has an input action")
	_check(
		settings_source.contains('"mount": KEY_M')
		and settings_source.contains('"fish", "mount", "pickpocket"'),
		"the mount hotkey defaults to M and remains configurable"
	)
	_check(
		player_source.contains("func toggle_land_mount()")
		and player_source.contains("LAND_MOUNT_TILE_MOVE_DURATION")
		and player_source.contains("InventoryService"),
		"the player can toggle an owned, faster land mount"
	)


func _check_bike_shop_owner_contract() -> void:
	var scene_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn"
	)
	var owner_source := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/cerulean_bike_shop_owner.gd"
	)
	_check(
		scene_source.contains("cerulean_bike_shop_owner.gd")
		and scene_source.contains('script = ExtResource("8_owner")'),
		"the Bike Shop owner uses the voucher-aware interaction"
	)
	_check(
		owner_source.contains('voucher_item_id := "bike-voucher"')
		and owner_source.contains('mount_item_id := "cyclizar-mount"')
		and owner_source.contains("turn_in_npc_quest_item"),
		"the owner exchanges the Bike Voucher for the Cyclizar entitlement"
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
