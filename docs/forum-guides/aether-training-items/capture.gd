extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	overlay.call("_setup_donator_store_popup")
	var store := overlay.get("donator_store_popup") as Control
	var offers: Array = []
	for item_id in ["aether-band", "aether-power-band"]:
		offers.append({"itemId": item_id, "accountUnique": true, "accountBound": true,
			"owned": false, "voucherEligible": true, "costs": [{"currency": "gems", "amount": 1000}]})
	store.call("apply_store_state", {"gems": 1000, "gift_voucher_balance": 1000}, {"items": offers})
	store.call("_select_category", "held-items")
	store.call("_select_product", "aether-band")
	assert(str(store.call("_category_text", "held-items", "label")) == "Training Items")
	store.show()
	await settle()
	center(store)
	await shot(0, "01-store-aether-band", store, "Example Gift Store: Aether Band, 1,000 Gems, once per account and untradeable.", "## Aether Band")
	store.call("_select_product", "aether-power-band")
	(store.get("payment_select") as OptionButton).select(1)
	store.call("_refresh_purchase_state")
	assert(str(store.call("_payment_currency")) == "gift_voucher")
	await shot(0, "02-store-aether-power-band", store, "Example Gift Store: Aether Power Band with 1,000 Aether Credit Card credits selected.", "## Aether Power Band")
	clear()
	var pokemon := sample_pokemon()
	pokemon.item = "aether-power-band"
	pokemon.evs = {}
	pokemon.stored_evs = {"spe": 11}
	var party: Array[Pokemon] = [pokemon]
	root.get_node("PlayerSave").party = party
	overlay.call("_show_pokemon_summary", 0)
	var summary := overlay.get("pokemon_summary_popup") as Control
	await settle()
	center(summary)
	await shot(0, "03-equipped-power-band", summary, "Example Summary: the Pokémon is carrying Aether Power Band.", "## Getting and equipping a Band")
	overlay.call("_on_pokemon_summary_tab_selected", "evs")
	await shot(0, "04-stored-speed-evs", summary, "Illustrative Summary: 11 Stored Speed EVs, with none allocated yet.", "### Stored EVs and allocation")
	assert(not root.get_node("AuthService").is_authenticated())
	finish("aether-training-items")
