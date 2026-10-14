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

func _automatic_preview() -> void:
	await create_timer(0.3).timeout
	await _idle()

func _run() -> void:
	var collector = load("res://tests/aethering_completion_feedback_check.gd").MessageCollector.new()
	root.add_child(collector)
	collector.add_to_group("ui_overlay")
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
	_check(popup._find(int(info["boxedId"])).is_empty(), "Real server excludes PC Pokémon from picker")
	var rejected: Dictionary = await api.call("preview", {"recipientId": int(info["recipientId"]), "donorId": int(info["boxedId"])})
	_check(not rejected.get("success", false) and rejected.get("body", {}).get("detail", {}).get("code") == "aethering_party_required", "Direct PC ID cannot bypass Party-only rule")
	for selection in [{"donor": false, "id": info["recipientId"]}, {"donor": true, "id": info["donorId"]}]:
		popup._open_picker(selection["donor"])
		for index in range(popup.picker_rows.size()):
			if popup.picker_rows[index].get("pokemonId") == selection["id"]:
				popup.picker_buttons[index].pressed.emit()
				break
	await _automatic_preview()
	_check(not popup.plan.is_empty(), "Selecting a Donor automatically requests a real server preview")
	_check((popup.grid.get_child(7) as Label).text.begins_with("?"), "Server random outcome displayed as question mark")
	await _fixture("/fixture/missing-wings", HTTPClient.METHOD_POST)
	popup._lock_changed(2, false)
	popup._lock_changed(3, true)
	await popup.refresh()
	await _automatic_preview()
	_check(popup.plan.is_empty() and not popup.stat_preview.is_empty(), "Missing Wings retain a non-executable server comparison")
	_check((popup.grid.get_child(11) as Label).text.begins_with("10") and (popup.grid.get_child(15) as Label).text.begins_with("20"), "Both prospective locks show server-guaranteed values without Wings")
	_check(popup.confirm_button.disabled and popup.status.text.contains("Muscle Wing") and popup.status.text.contains("Resist Wing"), "Missing Wing names explain disabled confirmation")
	await _fixture("/fixture/restore-wings", HTTPClient.METHOD_POST)
	await popup.refresh()
	await _automatic_preview()
	_check(not popup.plan.is_empty() and not popup.confirm_button.disabled, "Restored Wings enable confirmation after automatic revalidation")
	popup.recipient_lock = "hp"
	popup.donor_lock = "spd"
	popup._render()
	_check(popup.recipient["location"]["type"] == "party" and popup.donor["location"]["type"] == "party", "Two Party Pokémon selected through real candidate endpoint")
	_check(popup._wing_count("health-wing") == 3, "Purchased Wings reflected in inventory")
	await popup._preview()
	_check(not popup.plan.is_empty() and popup.plan["processCost"] == 10000, "Real server preview without client RNG")
	_check(popup.plan["stats"]["hp"]["mode"] == "recipient_lock" and popup.plan["stats"]["spd"]["mode"] == "donor_lock", "Both lock modes shown")
	if DisplayServer.get_name() != "headless":
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/aethering-preview-desktop.png")
		popup.donor_options.show_popup()
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/aethering-preview-dropdown.png")
		popup.donor_options.get_popup().hide()
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
	_check(collector.messages.is_empty(), "Lost response does not announce an unconfirmed success")
	var request_id: String = api.get("pending")["requestId"]
	var after_commit := await _fixture("/fixture")
	_check(after_commit["audits"] == 1 and after_commit["money"] == 30000, "One actual atomic consumption after lost response")
	auth.set("session_token", "expired-disposable-fixture")
	await popup._ask_confirm()
	await _idle()
	_check(api.get("pending").get("requestId", "") == request_id, "Auth expiry retains unresolved UUID")
	_check(collector.messages.is_empty(), "Auth failure does not announce success")
	auth.set("session_token", "aethering-disposable-ui-fixture")
	await popup._ask_confirm()
	await _idle()
	_check(api.get("pending").is_empty(), "Replay resolves pending confirmation")
	_check(popup.last_result.get("replayed", false) and popup.last_result.get("requestId") == request_id, "Replay uses original request ID")
	_check(popup._find(int(info["donorId"])).is_empty(), "Consumed Party Donor removed from picker")
	_check(popup._wing_count("health-wing") == 2 and popup._wing_count("clever-wing") == 2, "Only selected Wings consumed and inventory refreshed")
	_check(root.get_node("PlayerSave").get("money") == 30000, "Wallet refreshed after successful replay")
	_check(popup.result_panel.visible and popup.results.visible and popup.result_grid.get_child_count() == 28, "Real IV result displayed")
	_check(collector.messages.size() == 1 and collector.messages[0].contains("Aethering"), "Recovered commit announces success exactly once")
	popup._publish_result_feedback()
	popup._render_result()
	await popup.refresh()
	_check(collector.messages.size() == 1, "Replay, rerender and resource refresh do not repeat completion feedback")
	_check(popup.result_before.get("hp") == 10 and popup.result_before.get("spd") == 10, "Original preview IVs retained after replay")
	var successful_before: Dictionary = popup.result_before.duplicate(true)
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
	_check(collector.messages.size() == 1, "Rejected stale preview produces no completion message")
	_check(popup.result_before == successful_before, "Failed later rituals preserve the previous successful comparison")
	var final_state := await _fixture("/fixture")
	_check(final_state["audits"] == 1 and final_state["money"] == 30000, "No double consumption or cost after replay/stale preview")
	if not DisplayServer.get_name() == "headless":
		popup.plan = {}
		popup._render()
		popup.status.text = popup._t("success")
		await process_frame
		RenderingServer.force_draw()
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
		# A resized test window may stop drawing when the desktop changes focus.
		# Draw explicitly instead of waiting indefinitely for a visible-window signal.
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/aethering-compact.png")
	api.call("clear_pending")
	auth.set("session_token", "")
	auth.set("current_user", {})
	popup.free()
	collector.free()
	print("AETHERING END TO END failures: ", failures)
	quit(1 if failures else 0)
