extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
const IconResolver := preload("res://scripts/services/item_icon_resolver.gd")
var failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 800)
	root.add_child(host)
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	host.add_child(store)
	await process_frame
	var battle_script: Script = load("res://scripts/battle/battle.gd")
	_check(battle_script != null and battle_script.can_instantiate(), "Battle controller compiles with project autoloads")
	if battle_script != null and battle_script.can_instantiate():
		var battle: Node = battle_script.new()
		var save := root.get_node("PlayerSave")
		var old_party: Array[Pokemon] = save.party
		var holder := Pokemon.new("Pikachu", 5, "aether-band")
		var band_party: Array[Pokemon] = [holder]
		save.party = band_party
		_check(bool(battle.call("_party_holds_aether_band")), "Band holder waits for final PP save")
		holder.item = ""
		_check(not bool(battle.call("_party_holds_aether_band")), "Ordinary party retains existing battle exit")
		save.party = old_party
		battle.free()
	for item_id in ["aether-band", "aether-power-band"]:
		var item: Dictionary = store.call("_catalog_item", item_id)
		_check(item.get("price") == 1000, "Band preview uses 1000 Gems")
		_check(item.get("categories") == ["held-items"], "Band is in Held Items")
		var icon: Texture2D = IconResolver.load_icon(item_id)
		_check(icon != null and icon.resource_path.ends_with(item_id.to_upper().replace("-", "") + ".png"), "Band resolves its own Bag and held-item icon")
		var offer := {"itemId": item_id, "accountUnique": true, "accountBound": true, "owned": false,
			"voucherEligible": true, "costs": [{"currency": "gems", "amount": 1000}]}
		store.apply_store_state({"gems": 2000, "gift_voucher_balance": 2000}, {"items": [offer]})
		store.call("_select_category", "held-items")
		store.call("_select_product", item_id)
		_check(not store.purchase_button.disabled, "First purchase is available")
		_check(not store.payment_select.is_item_disabled(1), "Band accepts card credit")
		for locale in ["en", "nl", "pt_BR", "zh_CN"]:
			root.get_node("LocalizationManager").set_locale(locale)
			var expected := str(root.get_node("LocalizationManager").text("ui.store.payment.untradable"))
			_check(store.voucher_notice_label.text == expected, "Gem purchase shows untradeable notice in " + locale)
			_check(str(store.call("_item_description", item)).length() > 20, "Band description exists in " + locale)
		store.payment_select.select(1)
		store.call("_refresh_purchase_state")
		_check(store.call("_payment_currency") == "gift_voucher", "Band supports the card-credit payment selection")
		_check(not store.purchase_button.disabled, "1000 credits can buy the band")
		store.set_voucher_balance(999)
		_check(store.purchase_button.disabled, "Insufficient credit blocks purchase even with enough Gems")
		store.set_voucher_balance(2000)
		store.show_purchase_success(str(item.get("name")), "gift_voucher")
		_check(store.purchase_button.disabled, "Purchase success immediately prevents rebuying")
		offer["owned"] = true
		store.apply_store_state({"gems": 2000, "gift_voucher_balance": 2000}, {"items": [offer]})
		_check(store.purchase_button.disabled, "Purchased or equipped band cannot be bought again with credit")
		store.payment_select.select(0)
		store.call("_refresh_purchase_state")
		_check(store.purchase_button.disabled, "Switching back to Gems does not bypass the purchase limit")
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failed = true
		push_error("FAIL: " + message)
