extends SceneTree

var failures := 0
var api: Node
var popup

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: " + message)

func _fixture(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET) -> Dictionary:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.request(OS.get_environment("POKEAETHER_GATEWAY_URL") + path, PackedStringArray(), method)
	var response: Array = await request.request_completed
	request.queue_free()
	var body: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return body if body is Dictionary else {}

func _idle() -> void:
	for index in range(500):
		if not popup.busy:
			return
		await create_timer(0.02).timeout
	_check(false, "UI operation finishes within timeout")

func _run() -> void:
	var info := await _fixture("/fixture")
	if info.is_empty():
		push_error("Run with isolated tests/aethering_daycare_fixture_app.py")
		quit(1)
		return
	var auth := root.get_node("AuthService")
	auth.set("current_user", {"id": info["userId"]})
	auth.set("session_token", "aethering-disposable-ui-fixture")
	api = root.get_node("AetheringService")
	api.call("clear_pending")
	var merchant := root.get_node("MarketService")
	var catalog: Dictionary = await merchant.call("load_market", "daycare_wing_merchant")
	_check(bool(catalog.get("success", false)), "Wing Merchant catalog reachable")
	for item: Dictionary in catalog.get("market", {}).get("items", []):
		_check(item["costs"][0]["amount"] == 10000 and item["costs"][0]["membershipDiscountPercent"] == 0, "Merchant price exact with Aether Blessing: " + item["itemId"])
		var purchase: Dictionary = await merchant.call("purchase_item", "daycare_wing_merchant", item["itemId"], 1)
		_check(bool(purchase.get("success", false)) and purchase.get("purchase", {}).get("unitPrice") == 10000, "Checkout price: " + item["itemId"])
	popup = load("res://scenes/interface/aethering_popup.tscn").instantiate()
	root.add_child(popup)
	await popup.open_aethering()
	_check(popup.resources_ready, "Candidate, inventory and wallet reads synchronized")
	popup.recipient = popup._find(int(info["recipientId"]))
	popup.donor = popup._find(int(info["donorId"]))
	popup.recipient_lock = "hp"
	popup.donor_lock = "spd"
	popup._render()
	_check(popup.recipient["location"]["type"] == "party" and popup.donor["location"]["type"] == "box", "Party + PC selected through real candidate endpoint")
	_check(popup._wing_count("health-wing") == 3, "Purchased Wings reflected in inventory")
	await popup._preview()
	_check(not popup.plan.is_empty() and popup.plan["processCost"] == 10000, "Real server preview without client RNG")
	_check(popup.plan["stats"]["hp"]["mode"] == "recipient_lock" and popup.plan["stats"]["spd"]["mode"] == "donor_lock", "Both lock modes shown")
	popup._ask_confirm()
	await process_frame
	var dialog: AetherConfirmationDialog
	for child: Node in popup.get_children():
		if child is AetherConfirmationDialog:
			dialog = child
	_check(dialog != null and dialog.confirm_button.disabled, "Real shiny Donor requires acknowledgement")
	dialog.option_checkbox.button_pressed = true
	dialog.confirmed.emit()
	await _idle()
	_check(not api.get("pending").is_empty(), "Lost committed response retains retry receipt")
	var request_id: String = api.get("pending")["requestId"]
	var after_commit := await _fixture("/fixture")
	_check(after_commit["audits"] == 1 and after_commit["money"] == 30000, "One actual atomic consumption after lost response")
	auth.set("session_token", "expired-disposable-fixture")
	await popup._ask_confirm()
	await _idle()
	_check(api.get("pending").get("requestId", "") == request_id, "Auth expiry retains unresolved UUID")
	auth.set("session_token", "aethering-disposable-ui-fixture")
	await popup._ask_confirm()
	await _idle()
	_check(api.get("pending").is_empty(), "Replay resolves pending confirmation")
	_check(popup.last_result.get("replayed", false) and popup.last_result.get("requestId") == request_id, "Replay uses original request ID")
	_check(popup._find(int(info["donorId"])).is_empty(), "Consumed PC Donor removed from picker")
	_check(popup._wing_count("health-wing") == 2 and popup._wing_count("clever-wing") == 2, "Only selected Wings consumed and inventory refreshed")
	_check(root.get_node("PlayerSave").get("money") == 30000, "Wallet refreshed after successful replay")
	_check(popup.results.visible and popup.results.text.contains("→"), "Real IV result displayed")
	# A new donor can be selected immediately. Stale preview must not charge.
	popup.donor = popup._find(int(info["nextDonorId"]))
	popup.recipient_lock = null
	popup.donor_lock = null
	popup._render()
	await popup._preview()
	_check(not popup.plan.is_empty(), "Recipient retained for next Donor with no locks")
	await _fixture("/fixture/stale", HTTPClient.METHOD_POST)
	api.call("begin_confirmation", popup.plan, {"recipient": popup.recipient, "donor": popup.donor})
	await popup._execute()
	_check(popup.plan.is_empty() and api.get("pending").is_empty(), "Stale preview discarded without retrying a new roll")
	var final_state := await _fixture("/fixture")
	_check(final_state["audits"] == 1 and final_state["money"] == 30000, "No double consumption or cost after replay/stale preview")
	if not DisplayServer.get_name() == "headless":
		popup.plan = {}
		popup._render()
		popup.status.text = popup._t("success")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/aethering-desktop.png")
		var window_fit := root.get_node("WindowFit")
		var resize_handler := Callable(window_fit, "apply_ui_scale")
		if root.size_changed.is_connected(resize_handler):
			root.size_changed.disconnect(resize_handler)
		root.mode = Window.MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.min_size = Vector2i.ZERO
		DisplayServer.window_set_min_size(Vector2i.ZERO)
		root.content_scale_size = Vector2i(640, 360)
		root.content_scale_factor = 1.0
		root.size = Vector2i(640, 360)
		await create_timer(0.3).timeout
		popup._fit()
		print("COMPACT dimensions ", popup.size, " minimum=", popup.get_combined_minimum_size(), " viewport=", popup.get_viewport_rect().size)
		_check(popup.size.x <= 640 and popup.size.y <= 360, "Compact viewport fits without horizontal overflow")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/aethering-compact.png")
	api.call("clear_pending")
	auth.set("session_token", "")
	auth.set("current_user", {})
	popup.free()
	print("AETHERING END TO END failures: ", failures)
	quit(1 if failures else 0)
