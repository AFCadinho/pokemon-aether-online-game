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
		texture != null and Vector2i(texture.get_size()) == Vector2i(256, 256),
		"Cyclizar uses the standard 4x4 grid of 64px mount frames"
	)
	var rider_mask := load("res://assets/mounts/cyclizar/rider_mask.png") as Texture2D
	_check(
		str(definition.get("riderMaskSheet", ""))
		== "res://assets/mounts/cyclizar/rider_mask.png"
		and rider_mask != null
		and Vector2i(rider_mask.get_size()) == Vector2i(256, 256),
		"Cyclizar uses its 4x4 rider occlusion mask at the standard mount scale"
	)
	_check(
		MountServiceScript.get_rider_frame_offset("cyclizar", "left", 0) == Vector2i(10, -10)
		and MountServiceScript.get_rider_frame_offset("cyclizar", "left", 2) == Vector2i(10, -8)
		and MountServiceScript.get_rider_frame_offset("cyclizar", "right", 0) == Vector2i(-10, -10)
		and MountServiceScript.get_rider_frame_offset("cyclizar", "right", 2) == Vector2i(-10, -8)
		and MountServiceScript.get_rider_frame_offset("cyclizar", "up", 3) == Vector2i(2, -4),
		"Cyclizar rider offsets follow the supplied mounted reference in every animation frame"
	)
	var frames := MountServiceScript.get_mount_frames("cyclizar")
	_check(frames != null, "Cyclizar mount frames load")
	if frames != null:
		_check(frames.get_frame_count(&"walk_down") == 4, "Cyclizar has four down movement frames")
		var frame_texture := frames.get_frame_texture(&"idle_down", 0)
		_check(
			frame_texture != null and Vector2i(frame_texture.get_size()) == Vector2i(64, 64),
			"Cyclizar frames use the standard mount dimensions"
		)
	var foreground_frames := MountServiceScript.get_mount_foreground_frames("cyclizar")
	_check(foreground_frames != null, "Cyclizar has a foreground head layer for its rider")
	if foreground_frames != null:
		_check(
			Vector2i(foreground_frames.get_frame_texture(&"idle_down", 0).get_size())
			== Vector2i(64, 64),
			"Cyclizar foreground frames match its mount frame size"
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
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(project_source.contains("mount={"), "the land mount toggle has an input action")
	_check(
		settings_source.contains('"mount": KEY_M')
		and settings_source.contains('"fish", "mount", "pickpocket"'),
		"the mount hotkey defaults to M and remains configurable"
	)
	_check(
		player_source.contains("func toggle_land_mount()")
		and player_source.contains("func restore_land_mount(mount_id: String)")
		and player_source.contains("LAND_MOUNT_TILE_MOVE_DURATION := 0.065")
		and player_source.contains("LAND_MOUNT_WALK_ANIMATION_SPEED := 18.0")
		and player_source.contains("InventoryService"),
		"the player can toggle an owned, faster land mount"
	)
	_check(
		world_source.contains('"mountId": active_land_mount_id')
		and world_source.contains('state.get("mountId", "")')
		and world_source.contains('player.call("restore_land_mount", saved_mount_id)'),
		"the active owned land mount is saved with player position and restored on login"
	)
	var load_map_source := _function_source(world_source, "load_map")
	_check(
		load_map_source.contains('player.call("get_active_land_mount_id")')
		and load_map_source.contains('player.call("restore_land_mount", land_mount_id_to_restore)')
		and load_map_source.find('player.call("get_active_land_mount_id")')
		< load_map_source.find("player.get_parent().remove_child(player)")
		and load_map_source.find("GameState.current_map = new_map")
		< load_map_source.find('player.call("restore_land_mount", land_mount_id_to_restore)'),
		"ordinary map changes preserve land mounts when the destination permits them"
	)
	_check(
		player_source.contains("and not land_mount_activity_active")
		and player_source.count("refresh_pokemon_follower()") >= 4
		and world_source.contains('player.call("is_land_mount_activity_active")'),
		"land mounts hide local and remote follower Pokemon until dismounting"
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
	_check(
		owner_source.contains("MENTOR_TOPIC_MENU")
		and owner_source.contains("await _show_mount_guide()")
		and owner_source.contains("func _show_mount_guide()")
		and owner_source.contains('"id": "selecting"')
		and owner_source.contains('"id": "riding"')
		and owner_source.contains('"id": "purpose"'),
		"the owner becomes a reusable mount guide after Cyclizar is owned"
	)
	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
		"res://localization/zh_CN.json",
	]:
		var locale_source := FileAccess.get_file_as_string(locale_path)
		_check(
			locale_source.contains('"mentor.bike_seller.help.topic.selecting"')
			and locale_source.contains('"mentor.bike_seller.help.topic.riding"')
			and locale_source.contains('"mentor.bike_seller.help.topic.purpose"'),
			"%s contains the Bike Seller mount guide" % locale_path
		)


func _function_source(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
