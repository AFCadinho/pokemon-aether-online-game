extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	root.get_node("LocalizationManager").set_locale("en")
	var buyer = load("res://tests/fixtures/museum_ore_buyer_probe.gd").new()
	root.add_child(buyer)
	await buyer._offer_sale()
	assert(buyer.offered and buyer.stub.calls == 0 and buyer.pending_request_id.is_empty())
	print("PASS Cancelling the quote never submits a sale")
	buyer.accepted = true
	await buyer._offer_sale()
	assert(buyer.stub.calls == 1 and buyer.last_dialogue.contains("10,000"))
	assert(buyer.pending_request_id.is_empty())
	print("PASS Confirmed sale reports the authoritative payout")
	buyer.pending_request_id = "original-confirmed-request"
	buyer.pending_quote_id = "original-quote"
	buyer.offered = false
	await buyer._offer_sale()
	assert(not buyer.offered and buyer.stub.last_request == "original-confirmed-request")
	print("PASS Lost response retries the original confirmed receipt")
	buyer.free()
	quit()
