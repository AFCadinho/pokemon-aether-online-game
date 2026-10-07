extends SceneTree

const INVENTORY_PROBE := "res://tests/fixtures/startup_inventory_probe.gd"
const THIEVING_PROBE := "res://tests/fixtures/startup_thieving_probe.gd"
const LOGIN_PROBE := "res://tests/fixtures/startup_login_probe.gd"
const LOADING_PROBE := "res://tests/fixtures/startup_loading_probe.gd"
const Appearance := preload("res://scripts/services/character_appearance_service.gd")

var failed := false
var results: Dictionary = {}
var auth: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Let autoload startup callbacks finish while no synthetic account exists.
	await process_frame
	# All transport responses below are fixtures. Stop automatic auth-transition
	# polling so a synthetic session can never start unrelated HTTP requests.
	for child in root.get_children():
		child.process_mode = Node.PROCESS_MODE_DISABLED
	auth = root.get_node("AuthService")
	_set_account(1, "startup-fixture-a")
	await _check_inventory()
	await _check_thieving()
	await _check_preview()
	await _check_profile_inventory_and_map()
	auth.current_user = {}
	auth.session_token = ""
	for child in root.get_children():
		child.process_mode = Node.PROCESS_MODE_INHERIT
	await process_frame
	print("startup_request_reuse_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _check_inventory() -> void:
	var inventory: Node = load(INVENTORY_PROBE).new()
	root.add_child(inventory)
	inventory.apply_inventory_state({"items": [{"itemId": "mount-license", "quantity": 1}], "borrowedItems": [{"itemId": "potion"}], "mountLicenseRegions": ["kanto"]})
	var cached: Dictionary = await inventory.ensure_inventory_loaded()
	_expect(inventory.requests == 0 and cached.borrowedItems.size() == 1 and inventory.has_mount_license_for_region("kanto"), "startup readers reuse complete inventory including loans and mount licenses")
	cached.items.clear()
	_expect(inventory.has_item("mount-license"), "consumer changes cannot mutate the inventory cache")
	await inventory.load_inventory()
	_expect(inventory.requests == 1 and not inventory.has_item("mount-license"), "explicit inventory reloads still fetch fresh state")
	auth.session_token = "startup-fixture-a-renewed"
	await inventory.ensure_inventory_loaded()
	_expect(inventory.requests == 2, "a new session cannot reuse the old session's inventory")
	inventory.clear_cached_state()
	await inventory.ensure_inventory_loaded()
	_expect(inventory.requests == 3, "account reset invalidates even a matching identity and token")
	inventory.delayed = true
	_capture_inventory("old-inventory", inventory)
	await _wait_requests(inventory, 4)
	_set_account(2, "startup-fixture-b")
	inventory.apply_inventory_state({"items": [{"itemId": "new-account-item", "quantity": 1}], "borrowedItems": [], "mountLicenseRegions": []})
	inventory.reply.emit(4, {"success": true, "body": {"items": [{"itemId": "old-account-item", "quantity": 1}]}})
	_expect(not results["old-inventory"].success and inventory.has_item("new-account-item") and not inventory.has_item("old-account-item"), "late inventory replies cannot overwrite another account")
	inventory.free()
	_set_account(1, "startup-fixture-a")

func _check_thieving() -> void:
	var thieving: Node = load(THIEVING_PROBE).new()
	root.add_child(thieving)
	thieving.set_process(false)
	_capture_thieving("auto", thieving)
	_capture_thieving("loading", thieving, true)
	_expect(thieving.requests == 1, "loading joins the automatic thieving request")
	thieving.reply.emit(1, {"success": true, "body": {"wanted": 12}})
	_expect(results.auto.success and results.loading.success and thieving.state.wanted == 12, "all waiters receive the authoritative state")
	await thieving.ensure_state_loaded()
	_expect(thieving.requests == 1, "loading also reuses an already completed auth-transition load")
	thieving._process(0.0)
	await process_frame
	_expect(thieving.requests == 1, "a later auth-transition callback does not repeat the loading screen's completed request")
	_capture_thieving("refresh", thieving)
	_expect(thieving.requests == 2, "explicit thieving refreshes still contact the server")
	thieving.reply.emit(2, {"success": false, "error": "fixture timeout"})
	_expect(not results.refresh.success, "load failure reaches callers")
	thieving.clear_state()
	_capture_thieving("retry", thieving, true)
	_expect(thieving.requests == 3, "failed/reset loads can be retried")
	thieving.reply.emit(3, {"success": true, "body": {"wanted": 7}})
	_capture_thieving("old-state", thieving)
	_set_account(2, "startup-fixture-b")
	thieving.clear_state()
	_capture_thieving("new-state", thieving, true)
	_expect(thieving.requests == 5, "account exchange starts its own request instead of joining the old one")
	thieving.reply.emit(4, {"success": true, "body": {"wanted": 99}})
	_expect(not results["old-state"].success and thieving.pending_state_load != null and not thieving.state_loaded, "old completion neither applies state nor clears the new pending request")
	thieving.reply.emit(5, {"success": true, "body": {"wanted": 3}})
	_expect(results["new-state"].success and thieving.state.wanted == 3, "the new account receives only its own state")
	thieving.free()
	_set_account(1, "startup-fixture-a")

func _check_preview() -> void:
	var login: Node = load(LOGIN_PROBE).new()
	var appearance := Appearance.get_default_appearance("male")
	appearance["hair_color"] = "#115599"
	auth.current_user["appearance"] = appearance
	await login._apply_saved_session_preview_state()
	_expect(login.profile_requests == 0 and login.previews == 1, "authenticated appearance renders the login preview without another full profile")
	auth.current_user.erase("appearance")
	login.profile = {"success": true, "user": {"id": 1}, "position": {"hasState": true, "state": {"appearance": appearance}}}
	await login._apply_saved_session_preview_state()
	_expect(login.profile_requests == 1 and login.previews == 2, "older server responses retain the saved-appearance fallback")
	login.profile.user.id = 2
	await login._apply_saved_session_preview_state()
	_expect(login.previews == 2, "a mismatched fallback profile is rejected")
	login.profile.user.id = 1
	login.delayed = true
	login._apply_saved_session_preview_state()
	_set_account(2, "startup-fixture-b")
	login.reply.emit()
	_expect(login.previews == 2, "late preview replies cannot apply after an account exchange")
	login.free()
	_set_account(1, "startup-fixture-a")

func _check_profile_inventory_and_map() -> void:
	var loading: Node = load(LOADING_PROBE).new()
	root.add_child(loading)
	_expect(loading._continue_preparing_session("startup-fixture-a", "1"), "world loading remains bound to its starting identity and session")
	_expect(not loading._continue_preparing_session("old-session", "1") and loading.login_notices == 1, "a changed session cannot finish the old world handoff even for the same user")
	var profile := {"user": {"id": 1}, "inventory": {"items": [{"itemId": "mount-license", "quantity": 1}], "borrowedItems": [], "mountLicenseRegions": ["kanto"]}}
	_expect(loading._apply_profile_inventory(profile) and root.get_node("InventoryService").has_mount_license_for_region("kanto"), "the profile supplies mount entitlements before world restoration")
	profile.user.id = 2
	_expect(not loading._apply_profile_inventory(profile), "inventory from a different profile is rejected")
	profile.user.id = 1
	profile.inventory.erase("mountLicenseRegions")
	_expect(not loading._apply_profile_inventory(profile), "incomplete older inventory schemas use the endpoint fallback")
	auth._reset_account_runtime_state()
	_expect(not root.get_node("InventoryService").has_current_inventory(), "the real account reset clears hydrated startup inventory")
	var path := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
	var map_scene: PackedScene = await loading._load_saved_map_scene_threaded(path)
	_expect(map_scene != null and map_scene.resource_path == path, "saved map resources finish loading before the world handoff")
	var world := load("res://scripts/world/world.gd").new() as Node
	var map: Node = world.call("_instantiate_map", path, map_scene)
	_expect(map != null and map.scene_file_path == path, "world instantiates the retained saved map")
	if map != null:
		map.free()
	world.free()
	loading.free()

func _capture_inventory(key: String, service: Node) -> void:
	results[key] = await service.load_inventory()

func _capture_thieving(key: String, service: Node, ensure_loaded := false) -> void:
	results[key] = await service.ensure_state_loaded() if ensure_loaded else await service.load_state()

func _set_account(id: int, token: String) -> void:
	auth.current_user = {"id": id}
	auth.session_token = token

func _wait_requests(service: Node, count: int) -> void:
	for _frame in range(40):
		if service.requests >= count:
			return
		await process_frame
	_expect(false, "fixture request started")

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
	else:
		print("PASS: ", message)
