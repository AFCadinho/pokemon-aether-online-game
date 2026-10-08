extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const MapMetadata := preload("res://scripts/world/map_metadata.gd")

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var auth := root.get_node("AuthService")
	var inventory := root.get_node("InventoryService")
	var settings := root.get_node("SettingsManager")
	var previous_user: Dictionary = auth.current_user
	var previous_items: Array = inventory.cached_inventory_items
	var previous_inventory_user: int = inventory.cached_inventory_user_id
	var previous_license_regions: Array[String] = inventory.cached_mount_license_regions
	var previous_land_mount: String = settings.selected_land_mount_id
	var license_regions: Array[String] = ["kanto"]
	var no_license_regions: Array[String] = []
	auth.current_user = {"id": 123}
	inventory.cached_inventory_user_id = 123
	inventory.cached_mount_license_regions = license_regions
	var map := MapMetadata.new()
	map.world_access_area_type = "route"
	map.mount_license_region_id = "kanto"
	var player := load("res://scenes/player.tscn").instantiate() as Node2D
	player.set_script(load("res://tests/fixtures/mount_depth_player.gd"))
	player.set("depth_map", map)
	root.add_child(player)
	var checked_variants := 0
	for mode: String in ["land", "surf"]:
		for mount_id: String in Mounts.get_mount_ids_for_mode(mode):
			var item_id := Mounts.get_mount_unlock_item_id(mount_id)
			if item_id.is_empty():
				continue
			for suffix: String in ["", "-bound"]:
				inventory.cached_inventory_items = [{"itemId": item_id + suffix, "quantity": 1}]
				_check(bool(player.call("_is_mount_owned", mount_id)), mount_id + suffix + " unlocks riding")
				if mode == "surf":
					_check(player.call("_resolve_owned_surf_mount", mount_id) == mount_id, mount_id + suffix + " keeps the selected Surf mount")
				inventory.cached_inventory_items = [{"itemId": item_id + suffix, "quantity": 0}]
				_check(not bool(player.call("_is_mount_owned", mount_id)), mount_id + suffix + " requires positive stock")
			inventory.cached_inventory_items = []
			_check(not bool(player.call("_is_mount_owned", mount_id)), mount_id + " requires an owned item")
			checked_variants += 1
	_check(bool(player.call("_is_mount_owned", "lapras")), "default Lapras needs no unlock item")
	inventory.cached_inventory_items = [
		{"itemId": "mount-license", "quantity": 1},
		{"itemId": "glaceon-mount-bound", "quantity": 1},
		{"itemId": "shiny-glaceon-mount-bound", "quantity": 1},
	]
	settings.selected_land_mount_id = "glaceon"
	_check(bool(player.call("request_land_mount_toggle")), "selected credit-bought Glaceon can be mounted")
	_check(player.call("get_active_land_mount_id") == "glaceon", "credit purchase activates the selected land mount")
	player.call("_on_mount_loadout_changed", "land", "glaceon_shiny")
	_check(player.call("get_active_land_mount_id") == "glaceon_shiny", "bound shiny selection remains mounted")
	player.call("toggle_land_mount")
	_check(bool(player.call("restore_land_mount", "glaceon_shiny")), "bound shiny mount can be restored after a transition")
	player.call("toggle_land_mount")
	inventory.cached_mount_license_regions = no_license_regions
	_check(not bool(player.call("toggle_land_mount")), "credit mounts still require a regional license")
	inventory.cached_mount_license_regions = license_regions
	map.world_access_area_type = "interior"
	_check(not bool(player.call("toggle_land_mount")), "credit mounts still respect interior restrictions")
	map.world_access_area_type = "route"
	inventory.cached_inventory_user_id = 456
	_check(not bool(player.call("_is_mount_owned", "glaceon")), "another account's cached bound mount cannot unlock riding")
	inventory.cached_inventory_user_id = 123
	inventory.cached_inventory_items = [{"itemId": "glaceon-mount-bound", "quantity": 1}]
	_check(not bool(player.call("_is_mount_owned", "glaceon_shiny")), "normal bound Glaceon does not unlock shiny Glaceon")
	_check(not inventory.has_item("glaceon-mount"), "general inventory lookup still distinguishes bound items")
	player.free()
	map.free()
	settings.selected_land_mount_id = previous_land_mount
	_check(settings.save_settings(), "restore the previous saved mount selection")
	inventory.cached_inventory_items = previous_items
	inventory.cached_inventory_user_id = previous_inventory_user
	inventory.cached_mount_license_regions = previous_license_regions
	auth.current_user = previous_user
	print("Mount ownership checks: ", "FAILED" if failed else "PASS", " variants=", checked_variants)
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
