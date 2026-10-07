extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var store := overlay.get("donator_store_popup") as Control
	store.call("apply_store_state",{"gems":1000,"gift_voucher_balance":500},read_fixture("store.json"))
	store.call("_select_category","membership")
	store.call("_select_product","aether-blessing-voucher-30-days")
	store.show()
	await settle()
	center(store)
	await shot(56,"01-blessing-voucher",store,"Example Gift Store: select a Blessing voucher, check its duration and price, then use the purchased voucher from your Bag.","## Getting Aether Blessing")
	(store.get("payment_select") as OptionButton).select(1)
	store.call("_refresh_purchase_state")
	await shot(91,"01-card-payment-and-binding",store,"Example: Aether Credit Card payment is available for eligible personal products. Review the binding notice before purchasing.","## Aether Credit Card and binding")
	store.call("_show_currency_info")
	var info := store.get("currency_info_dialog") as Control
	await shot(91,"02-currency-help",info.get("panel"),"The Gift Store's information button explains Gems, credit vouchers and the personal Aether Credit Card.","## Gems and credit")
	info.hide()
	(store.get("payment_select") as OptionButton).select(0)
	store.call("_select_category","mounts")
	store.call("_select_mount_mode","surf")
	store.call("_select_product","gyarados-mount-box")
	await shot(89,"02-mount-box-preview",store,"Example mount preview: inspect the mount box and its price before purchasing. Owning a box and equipping a mount are separate steps.","## Mount boxes")
	clear()
	var mounts := overlay.get("mount_loadout_panel") as Control
	assert(mounts != null)
	var owned: Array[String] = ["cyclizar-mount","gyarados-mount"]
	mounts.set("owned_item_ids",owned)
	mounts.call("_refresh_slots")
	mounts.show()
	await settle()
	center(mounts)
	mounts.call("_open_selector","land")
	await shot(89,"01-mount-loadout",mounts,"Example Mounts manager: choose a mount for each movement type. The list shows mounts unlocked by your items and progression.","## Selecting your mounts")
	clear()
	var atelier := overlay.get("aether_atelier_popup") as Control
	atelier.call("_apply_catalog",{"wallet":{"money":10000},"outfits":[],"chromaItems":[
		{"itemId":"adinho-chroma-shirt","name":"Adinho Chroma Shirt","slot":"top","appearanceId":"Adinho_Shirt_Chroma","genders":["male"],"color":"#ffffff","fee":2500,"equipped":true,"tintable":true},
		{"itemId":"adinho-chroma-trousers","name":"Adinho Chroma Trousers","slot":"bottom","appearanceId":"Adinho_Trousers_Chroma","genders":["male"],"color":"#ffffff","fee":2500,"equipped":true,"tintable":true}]})
	atelier.call("_select_mode","dye")
	atelier.call("_select_chroma_item","adinho-chroma-shirt")
	atelier.call("_select_dye_color","#7a46c5")
	atelier.show()
	await settle()
	center(atelier)
	await shot(93,"01-chroma-dye-preview",atelier,"Example Atelier: select a Chroma item and preview a colour. Review the ₽2,500 fee for each changed item before applying it.","## Dyeing Chroma clothing")
	clear()
	finish("economy")
