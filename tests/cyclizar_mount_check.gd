extends SceneTree

const MountServiceScript := preload("res://scripts/services/mount_service.gd")
const MapMetadataScript := preload("res://scripts/world/map_metadata.gd")

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
	var license_icon := load("res://assets/items/icons/MOUNTLICENSE.png") as Texture2D
	_check(
		license_icon != null and Vector2i(license_icon.get_size()) == Vector2i(48, 48),
		"the Mount License has a dedicated 48px pixel-art Key Item icon"
	)


func _check_land_mount_runtime_contract() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var settings_source := FileAccess.get_file_as_string("res://scripts/services/settings_manager.gd")
	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var map_metadata_source := FileAccess.get_file_as_string("res://scripts/world/map_metadata.gd")
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var loading_source := FileAccess.get_file_as_string("res://scripts/ui/loading_screen.gd")
	var settings_menu_source := FileAccess.get_file_as_string("res://scripts/ui/settings_menu.gd")
	_check(project_source.contains("mount={"), "the land mount toggle has an input action")
	_check(
		settings_source.contains('"mount": KEY_M')
		and settings_source.contains('"mount",')
		and settings_source.contains('"fish",')
		and settings_source.contains('"pickpocket",'),
		"the mount hotkey defaults to M and remains configurable"
	)
	_check(
		player_source.contains("func toggle_land_mount()")
		and player_source.contains("func restore_land_mount(mount_id: String)")
		and player_source.contains("func _has_mount_license_for_current_region()")
		and player_source.contains("func _get_current_mount_license_region_id()")
		and player_source.contains('["mountLicenseRegionId", "regionId"]')
		and player_source.contains('"ui.mounts.license_required"')
		and player_source.contains("LAND_MOUNT_TILE_MOVE_DURATION := 0.065")
		and player_source.contains("LAND_MOUNT_WALK_ANIMATION_SPEED := 18.0")
		and player_source.contains("InventoryService"),
		"the player can toggle an owned, faster land mount"
	)
	_check(
		map_metadata_source.contains("@export var mount_license_region_id")
		and map_metadata_source.contains('"mountLicenseRegionId"'),
		"maps can define a mount-license region independently from their world region"
	)
	var metadata_node := MapMetadataScript.new()
	metadata_node.map_region_name = "Aether Clash"
	metadata_node.region_id = "aether_clash"
	metadata_node.mount_license_region_id = "kanto"
	var location_metadata: Dictionary = metadata_node.get_location_metadata()
	_check(
		str(location_metadata.get("regionId", "")) == "aether_clash"
		and str(location_metadata.get("mountLicenseRegionId", "")) == "kanto",
		"Aether Clash metadata resolves world and mount-license regions separately"
	)
	metadata_node.free()
	for aether_clash_scene_path: String in [
		"res://scenes/overworld/aether_clash/aether_clash_lobby.tscn",
		"res://scenes/overworld/aether_clash/aether_clash_duel.tscn",
		"res://scenes/overworld/aether_clash/aether_clash_duel_preview.tscn",
		"res://scenes/overworld/aether_clash/aether_clash_battle_royale_preview.tscn",
		"res://scenes/overworld/aether_clash/waiting_area_preview.tscn",
	]:
		var aether_clash_scene_source := FileAccess.get_file_as_string(aether_clash_scene_path)
		_check(
			aether_clash_scene_source.contains('region_id = "aether_clash"')
			and aether_clash_scene_source.contains('mount_license_region_id = "kanto"'),
			"%s keeps its Aether Clash identity while accepting the Kanto Mount License"
			% aether_clash_scene_path
		)
	_check(
		world_source.contains('"mountId": active_land_mount_id')
		and world_source.contains('state.get("mountId", "")')
		and world_source.contains('player.call("restore_land_mount", saved_mount_id)'),
		"the active owned land mount is saved with player position and restored on login"
	)
	var loading_prepare_source := _function_source(loading_source, "_prepare_world")
	var logout_source := _function_source(settings_menu_source, "_logout_confirmed")
	_check(
		loading_prepare_source.contains("await InventoryService.load_inventory()")
		and loading_prepare_source.find("await InventoryService.load_inventory()")
		< loading_prepare_source.find("GameState.set_prepared_world_state")
		and logout_source.contains('world.call("prepare_for_account_switch")')
		and logout_source.find('world.call("prepare_for_account_switch")')
		< logout_source.find("change_scene_to_file(LOGIN_SCENE_PATH)"),
		"logout saves the active mount and login loads its entitlement before restoring it"
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
	var battle_lock_source := _function_source(world_source, "_lock_overworld_for_battle")
	var battle_unlock_source := _function_source(world_source, "_unlock_overworld_after_battle")
	_check(
		battle_lock_source.contains('player.call("get_active_land_mount_id")')
		and battle_lock_source.find('player.call("get_active_land_mount_id")')
		< battle_lock_source.find("player.reset_movement_state()")
		and battle_unlock_source.contains(
			'player.call("restore_land_mount", mount_id_to_restore)'
		)
		and battle_unlock_source.find("player.reset_movement_state()")
		< battle_unlock_source.find('player.call("restore_land_mount", mount_id_to_restore)'),
		"wild and Trainer battle returns restore the land mount active before battle"
	)
	var battle_end_source := _function_source(world_source, "end_wild_battle")
	_check(
		battle_end_source.contains(
			'if keep_overworld_locked:\n\t\t# A blackout moves the player to a recovery location'
		)
		and battle_end_source.contains('land_mount_id_before_battle = ""'),
		"blackout respawns discard the pre-battle land mount"
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
		and owner_source.contains('license_item_id := "mount-license"')
		and owner_source.contains('license_region_id := "kanto"')
		and owner_source.contains("turn_in_npc_quest_item"),
		"the owner exchanges the Bike Voucher for Cyclizar and a Kanto Mount License"
	)
	_check(
		owner_source.contains("MENTOR_TOPIC_MENU")
		and owner_source.contains("await _show_mount_guide()")
		and owner_source.contains("func _show_mount_guide()")
		and owner_source.contains('"id": "selecting"')
		and owner_source.contains('"id": "riding"')
		and owner_source.contains('"id": "purpose"')
		and owner_source.contains('"id": "license"'),
		"the owner becomes a reusable mount and license guide after Cyclizar is owned"
	)
	var inventory_source := FileAccess.get_file_as_string(
		"res://scripts/services/inventory_service.gd"
	)
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(
		inventory_source.contains("cached_mount_license_regions")
		and inventory_source.contains("func has_mount_license_for_region")
		and overlay_source.contains('use_action == "open_mount_license"')
		and overlay_source.contains("func _show_mount_license()"),
		"the inventory caches regional registrations and the Key Item opens their overview"
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
			and locale_source.contains('"mentor.bike_seller.help.topic.purpose"')
			and locale_source.contains('"mentor.bike_seller.help.topic.license"')
			and locale_source.contains('"ui.mounts.license_required"')
			and locale_source.contains('"ui.mount_license.registration"'),
			"%s contains the Bike Seller license guide and rider feedback" % locale_path
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
