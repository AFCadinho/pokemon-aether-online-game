extends SceneTree

const MapMetadata := preload("res://scripts/world/map_metadata.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var auth := root.get_node("AuthService")
	var inventory := root.get_node("InventoryService")
	var settings := root.get_node("SettingsManager")
	var clock := root.get_node("WorldTimeService")
	# The isolated check starts logged out, so opening the panel makes no request.
	var panel := load("res://scenes/interface/mount_loadout_panel.tscn").instantiate() as Control
	root.add_child(panel)
	await process_frame
	auth.current_user = {"id": 123}
	var owned := [{"itemId": "mount-license", "quantity": 1}]
	var loan := {
		"itemId": "arcanine-mount", "quantity": 1, "category": "mounts",
		"isHoldable": false, "borrowed": true, "loanAssetId": "guild-mount-test",
		"loanLenderKind": "guild", "loanStatus": "active", "loanDueAt": "2030-01-01T01:00:00+00:00",
	}
	clock.sync_server_time("2030-01-01T00:00:00+00:00")
	inventory.apply_inventory_state({"items": owned, "borrowedItems": [loan], "mountLicenseRegions": ["kanto"]})
	var map := MapMetadata.new()
	map.world_access_area_type = "route"
	map.mount_license_region_id = "kanto"
	var collision := TileMapLayer.new()
	collision.name = "Collision"
	map.add_child(collision)
	var player := load("res://scenes/player.tscn").instantiate() as Node2D
	player.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	player.set("depth_map", map)
	root.add_child(player)
	inventory.inventory_changed.connect(Callable(player, "_on_mount_inventory_changed"))
	_check(not inventory.has_item("arcanine-mount"), "a borrowed mount does not become owned inventory")
	_check(inventory.has_mount_item("arcanine-mount"), "an active guild loan grants mount access")
	_check("arcanine-mount" in panel.get("owned_item_ids"), "the mount manager includes temporary access")
	settings.selected_land_mount_id = "arcanine"
	panel.call("_open_selector", "land")
	var option := (panel.get("selector_options") as VBoxContainer).get_node_or_null("ArcanineOption") as Button
	_check(option != null and option.text.contains("Guild loan"), "selector labels the guild loan")
	_check(option != null and option.tooltip_text.contains("2030-01-01 01:00:00"), "selector shows the loan deadline")
	_check(bool(player.call("toggle_land_mount")), "a borrowed mount can be ridden with a regional license")
	player.global_position = Vector2(32, 48)
	player.set("is_moving", true)
	player.set("move_start_position", Vector2(32, 48))
	player.set("target_position", Vector2(64, 48))
	player.set("move_elapsed", 0.0)
	player.set("move_duration", 0.1)
	clock.sync_server_time("2030-01-01T01:00:01+00:00")
	inventory.call("_refresh_borrowed_mount_access")
	_check(bool(player.call("is_land_mount_activity_active")), "expiry lets the current tile finish")
	_check(not inventory.has_mount_item("arcanine-mount"), "expired access is unavailable before server cleanup")
	_check("arcanine-mount" not in panel.get("owned_item_ids"), "expiry removes the mount from the selector")
	player.call("_advance_tile_movement", 0.1)
	_check(not bool(player.call("is_land_mount_activity_active")), "the player dismounts at the tile boundary")
	_check(player.global_position == Vector2(64, 48), "expiry preserves the completed world position")
	_check(not bool(player.call("restore_land_mount", "arcanine")), "a transition cannot restore an expired mount")

	clock.sync_server_time("2030-01-01T00:00:00+00:00")
	inventory.apply_inventory_state({"items": owned, "borrowedItems": [loan], "mountLicenseRegions": ["kanto"]})
	_check(bool(player.call("toggle_land_mount")), "active loan can be mounted again")
	inventory.call("_on_mount_loan_event", {"type": "guild.mount_loan.changed", "assets": [{"loanAssetId": "guild-mount-test", "status": "returned"}]})
	_check(not bool(player.call("is_land_mount_activity_active")), "a committed recall immediately ends idle riding")
	_check(not inventory.has_mount_item("arcanine-mount"), "recall revokes the cached mount access")
	inventory.apply_inventory_state({"items": owned, "borrowedItems": [loan], "mountLicenseRegions": ["kanto"]})
	_check(not inventory.has_mount_item("arcanine-mount"), "an older inventory response cannot restore a recalled loan")
	var second_loan := loan.duplicate(true)
	second_loan["loanAssetId"] = "guild-second-mount-test"
	inventory.apply_inventory_state({"items": owned, "borrowedItems": [loan, second_loan], "mountLicenseRegions": ["kanto"]})
	_check(bool(player.call("toggle_land_mount")), "a second valid loan keeps the same mount usable")
	inventory.call("_on_mount_loan_event", {"type": "guild.mount_loan.changed", "assets": [{"loanAssetId": "guild-mount-test", "status": "returned"}]})
	_check(bool(player.call("is_land_mount_activity_active")), "recalling one copy preserves another active loan")
	player.call("toggle_land_mount")

	var surf_loan := loan.duplicate(true)
	surf_loan["itemId"] = "primal-kyogre-mount"
	surf_loan["loanAssetId"] = "guild-surf-test"
	inventory.apply_inventory_state({"items": owned, "borrowedItems": [surf_loan], "mountLicenseRegions": ["kanto"]})
	settings.selected_surf_mount_id = "primal_kyogre"
	player.call("_start_surf_activity")
	_check(player.get("active_mount_id") == "primal_kyogre", "Surf uses the borrowed mount")
	var surf_position := player.global_position
	player.set("is_moving", true)
	inventory.call("_on_mount_loan_event", {"type": "guild.mount_loan.changed", "assets": [{"loanAssetId": "guild-surf-test", "status": "return_pending"}]})
	_check(player.get("active_mount_id") == "primal_kyogre", "Surf recall also lets the current tile finish")
	player.set("is_moving", false)
	player.call("_reconcile_mount_access")
	_check(bool(player.get("surf_activity_active")), "recall preserves Surf on water")
	_check(player.get("active_mount_id") == "lapras", "recall safely switches to the default Surf mount")
	_check(player.global_position == surf_position, "Surf fallback does not move or strand the player")
	player.set("surf_activity_active", false)
	player.set("active_mount_id", "")

	var own_copy := owned.duplicate(true)
	own_copy.append({"itemId": "arcanine-mount-bound", "quantity": 1})
	inventory.apply_inventory_state({"items": own_copy, "borrowedItems": [loan], "mountLicenseRegions": ["kanto"]})
	_check(bool(player.call("toggle_land_mount")), "an owned bound copy remains rideable")
	inventory.call("_on_mount_loan_event", {"type": "guild.mount_loan.changed", "assets": [{"loanAssetId": "guild-mount-test", "status": "returned"}]})
	_check(bool(player.call("is_land_mount_activity_active")), "recall keeps riding when an own copy remains")
	player.call("toggle_land_mount")
	loan["loanAssetId"] = "guild-next-mount-test"
	inventory.apply_inventory_state({"items": owned, "borrowedItems": [loan], "mountLicenseRegions": []})
	_check(inventory.has_mount_item("arcanine-mount"), "the fresh loan grants access before the license check")
	_check(not bool(player.call("toggle_land_mount")), "guild lending does not bypass the regional license")
	inventory.cached_inventory_user_id = 456
	_check(not inventory.has_mount_item("arcanine-mount"), "another account's mount loan cannot grant access")
	inventory.cached_inventory_user_id = 123
	inventory.cached_inventory_session = "another-session"
	_check(not inventory.has_mount_item("arcanine-mount"), "another session's mount loan cannot grant access")
	player.free()
	map.free()
	panel.free()
	print("Guild mount lending checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
