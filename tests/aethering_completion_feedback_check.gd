extends SceneTree

class MessageCollector extends Node:
	var messages: Array[String] = []

	func add_system_message(message: String) -> void:
		messages.append(message)

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if value:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)

func _run() -> void:
	for frame in range(4):
		await process_frame
	var auth := root.get_node("AuthService")
	auth.set("current_user", {"id": 812345})
	var api := root.get_node("AetheringService")
	api.get("completion_notices").clear()
	var collector := MessageCollector.new()
	root.add_child(collector)
	collector.add_to_group("ui_overlay")
	var popup = load("res://scenes/interface/aethering_popup.tscn").instantiate()
	root.add_child(popup)
	popup.show()
	var original := {"hp": 10, "atk": 31, "def": 15, "spa": 0, "spd": 31, "spe": 22}
	var changed := {"hp": 10, "atk": 12, "def": 18, "spa": 0, "spd": 31, "spe": 9}
	var receipt := {"plan": {"stats": {}}, "context": {"recipient": {"pokemon": {"ivs": original}}}}
	for stat: String in popup.STATS:
		receipt["plan"]["stats"][stat] = {"recipientIV": original[stat]}
	receipt["context"]["recipient"]["pokemon"]["ivs"] = {"hp": 31, "atk": 31}
	popup.result_before = popup._snapshot_result_before(receipt)
	_check(popup.result_before == original, "Server preview IVs override stale candidate snapshots")
	var fallback: Dictionary = popup._snapshot_result_before({"context": {"recipient": {"pokemon": {"ivs": original}}}})
	_check(fallback == original, "Old durable receipts retain their original comparison")
	_check(popup._snapshot_result_before({}).is_empty(), "Missing before values are not invented as zero")
	popup.last_result = {"auditId": "feedback-test-audit", "requestId": "feedback-test-request", "replayed": true, "recipient": {"speciesId": "eevee", "nickname": "[b]Favorite[/b]"}, "ivs": changed, "processCost": 10000, "consumedWings": [{"itemId": "health-wing", "quantity": 1}]}
	popup._render_result()
	popup._render()
	_check(popup.result_panel.visible and not popup.grid.visible, "Completion replaces the empty preview with prominent actual IVs")
	_check(not popup.results.bbcode_enabled and popup.results.text.contains("[b]Favorite[/b]"), "Nickname markup is rendered as literal text")
	_check(popup.result_panel.get_index() < popup.help_label.get_index(), "Result is above instructions and next ritual controls")
	_check(popup._result_counts() == {"improved": 1, "worsened": 2, "unchanged": 3}, "Summary counts actual increases, decreases and unchanged IVs")
	_check((popup.result_grid.get_child(5) as Label).text == "10" and (popup.result_grid.get_child(6) as Label).text == "10", "Before and new IVs appear in labeled columns")
	_check((popup.result_grid.get_child(15) as Label).text == "↑ +3" and (popup.result_grid.get_child(27) as Label).text == "↓ -13", "Gains and losses have arrows and signed deltas")
	_check((popup.result_grid.get_child(18) as Label).text == "0" and (popup.result_grid.get_child(19) as Label).text == "= 0", "Unchanged competitive zero remains explicit")
	_check(popup.result_details.text.contains("10000") and popup.result_details.text.contains("1"), "Result states actual debit and consumed Wing count")
	var fit := root.get_node("WindowFit")
	var resize_handler := Callable(fit, "apply_ui_scale")
	if root.size_changed.is_connected(resize_handler):
		root.size_changed.disconnect(resize_handler)
	root.mode = Window.MODE_WINDOWED
	root.min_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	for dimensions in [Vector2i(1200, 720), Vector2i(640, 360), Vector2i(360, 640), Vector2i(320, 480)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		popup._fit()
		for frame in range(4):
			await process_frame
		_check(popup.size.x <= dimensions.x and popup.size.y <= dimensions.y, "Completion popup fits " + str(dimensions))
		_check(popup.result_grid.get_global_rect().end.x <= popup.get_global_rect().end.x, "IV results stay inside viewport " + str(dimensions))
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/aethering-completion-%dx%d.png" % [dimensions.x, dimensions.y])
	var sfx := root.get_node("SfxManager")
	var players_before := sfx.get_child_count()
	popup._publish_result_feedback()
	_check(collector.messages.size() == 1 and collector.messages[0].contains("[b]Favorite[/b]"), "First successful replay emits a short system message")
	_check(sfx.get_child_count() == players_before + 1, "Successful confirmation plays one existing SFX")
	var player := sfx.get_child(sfx.get_child_count() - 1) as AudioStreamPlayer
	_check(player != null and player.stream.resource_path.ends_with("wish/PRSFX- Wish.wav"), "Confirmation uses the mystical Wish move-animation sound")
	_check(player != null and player.bus == root.get_node("SettingsManager").call("get_audio_output_bus", "Overworld SFX"), "Confirmation respects the configured SFX output bus")
	popup._publish_result_feedback()
	popup._render()
	popup._render_result()
	_check(collector.messages.size() == 1 and sfx.get_child_count() == players_before + 1, "Repeated audit and renders do not duplicate message or sound")
	for locale in ["en", "nl", "pt_BR", "zh_CN"]:
		root.get_node("LocalizationManager").call("set_locale", locale)
		_check(not popup.results.text.contains("ui.aethering.") and not popup.result_details.text.contains("ui.aethering."), "Result copy translated in " + locale)
	_check(collector.messages.size() == 1, "Locale changes do not announce completion again")
	popup.last_result["ivs"] = original.duplicate(true)
	popup._render_result()
	_check(popup.results.text.contains(popup._t("result_unchanged")), "Unchanged outcome is explained without claiming improvement")
	popup.donor = {"pokemonId": 222, "pokemon": {"speciesId": "eevee"}}
	popup._render()
	_check(not popup.result_panel.visible and popup.grid.visible, "Selecting next Donor restores the normal server comparison")
	popup.last_result = {"refreshOnly": true}
	popup._publish_result_feedback()
	popup.last_result = {}
	popup._publish_result_feedback()
	_check(collector.messages.size() == 1, "Refresh and incomplete outcomes cannot announce success")
	# Notice identity belongs to an account, not to a reused popup instance.
	auth.set("current_user", {"id": 812346})
	_check(api.call("claim_completion_notice", {"auditId": "feedback-test-audit"}), "Notice deduplication is account-scoped")
	auth.set("current_user", {"id": 812345})
	_check(not api.call("claim_completion_notice", {"auditId": "feedback-test-audit"}), "Returning to the same account does not repeat its audit")
	root.get_node("LocalizationManager").call("set_locale", "en")
	popup.free()
	collector.free()
	api.get("completion_notices").clear()
	auth.set("current_user", {})
	print("AETHERING COMPLETION FEEDBACK failures: ", failures)
	quit(1 if failures else 0)
