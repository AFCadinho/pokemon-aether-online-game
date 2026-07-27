extends SceneTree

const STORE_SCENE := preload("res://scenes/interface/donator_store_popup.tscn")
const STORE_SCRIPT_PATH := "res://scripts/ui/donator_store_popup.gd"
const INVENTORY_SERVICE_PATH := "res://scripts/services/inventory_service.gd"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := STORE_SCENE.instantiate() as DonatorStorePopup
	root.add_child(store)
	await process_frame

	_check(store != null, "Donator Store scene instantiates")
	if store == null:
		quit(1)
		return

	var source := FileAccess.get_file_as_string(STORE_SCRIPT_PATH)
	var inventory_service_source := FileAccess.get_file_as_string(INVENTORY_SERVICE_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)
	_check(
		source.contains('const COSMETIC_FILTER_GROUP_ORDER: Array[String]'),
		"cosmetics define a compact primary filter layer"
	)
	for group_id: String in ["all", "outfits", "items"]:
		_check(source.contains('"%s",' % group_id), "cosmetics include the %s primary filter" % group_id)
	_check(
		source.contains('const COSMETIC_ITEM_CATEGORY_ORDER: Array[String]'),
		"loose cosmetic items define a category dropdown"
	)
	for subcategory_id: String in [
		"body",
		"hair",
		"headgear",
		"face",
		"facegear",
		"top",
		"bottom",
		"shoes",
	]:
		_check(source.contains('"%s",' % subcategory_id), "cosmetics include %s" % subcategory_id)

	for placeholder_id: String in [
		"aurora_outfit",
		"profile_accent_pack",
		"chat_flair_pack",
		"wardrobe_preset_slot",
		"aether_body_style",
		"aurora_hair",
		"aurora_headgear",
		"trailblazer_beard",
		"aurora_facegear",
		"aurora_top",
		"aurora_bottom",
		"aurora_shoes",
	]:
		_check(not source.contains('"id": "%s"' % placeholder_id), "placeholder cosmetic %s is absent" % placeholder_id)
	_check(
		not source.contains('scroll.name = "CosmeticSubcategoryScroll"'),
		"cosmetic filters no longer require horizontal scrolling"
	)
	var add_gems_button := store.find_child("AddGemsButton", true, false) as Button
	_check(add_gems_button != null, "Store exposes an Add Gems action beside the balance")
	if add_gems_button != null:
		add_gems_button.pressed.emit()
		_check(
			store.status_label.text == "Adding Aether Gems is not implemented yet.",
			"Add Gems clearly reports that top-ups are not implemented yet"
		)

	store.call("_select_category", "cosmetics")
	_check(store.cosmetic_subcategory_bar.visible, "cosmetic filters appear inside Cosmetics")
	_check(store.cosmetic_filter_group_buttons.size() == 3, "three compact cosmetic primary filters are built")
	_check(store.cosmetic_item_category_select != null, "loose items use a category dropdown")
	_check(store.cosmetic_item_category_select.item_count == 9, "dropdown includes all eight item types")
	var item_category_popup := store.cosmetic_item_category_select.get_popup()
	_check(item_category_popup.has_theme_stylebox_override("panel"), "item category popup uses Store panel styling")
	_check(item_category_popup.has_theme_stylebox_override("hover"), "item category popup has a styled hover state")
	_check(item_category_popup.has_theme_icon_override("radio_checked"), "item category popup uses a custom selected indicator")
	_check(
		store.cosmetic_item_category_select.has_theme_icon_override("arrow"),
		"item category selector uses a custom dropdown arrow"
	)
	_check(not store.cosmetic_item_category_control.visible, "item category dropdown stays hidden for All")
	store.call("_select_cosmetic_filter_group", "items")
	_check(store.active_cosmetic_filter_group == "items", "Loose Items can become the active primary filter")
	_check(store.cosmetic_item_category_control.visible, "item category dropdown appears for Loose Items")
	_check(
		not store.product_buttons.has("adinho-classic-outfit"),
		"Loose Items excludes complete outfit boxes"
	)
	var hair_category_index := -1
	for index: int in range(store.cosmetic_item_category_select.item_count):
		if str(store.cosmetic_item_category_select.get_item_metadata(index)) == "hair":
			hair_category_index = index
			break
	store.call("_on_cosmetic_item_category_selected", hair_category_index)
	_check(store.active_cosmetic_subcategory == "hair", "dropdown applies the selected loose-item category")
	_check(store.product_buttons.has("adinho-chroma-hair"), "Hair dropdown category lists hair products")
	store.call("_select_cosmetic_filter_group", "all")
	_check(store.product_buttons.has("adinho-classic-outfit"), "All includes complete outfit boxes")
	_check(store.catalog_search_input != null, "Gift Store includes a catalog search bar")
	store.call("_on_catalog_search_changed", "adinho chroma beard")
	_check(
		store.product_buttons.size() == 1 and store.product_buttons.has("adinho-chroma-beard"),
		"catalog search filters products in the active category"
	)
	store.call("_on_catalog_search_changed", "")

	store.call("_select_cosmetic_subcategory", "face")
	_check(store.active_cosmetic_subcategory == "face", "Face can become the active cosmetic subtab")
	_check(store.product_buttons.has("adinho-chroma-beard"), "grayscale beard is sold separately")
	_check(not store.product_buttons.has("adinho-classic-outfit"), "Face hides the Classic outfit box")

	store.call("_select_cosmetic_subcategory", "outfits")
	_check(store.product_buttons.has("adinho-classic-outfit"), "Outfits lists Adinho Classic as one six-item box")
	_check(not store.product_buttons.has("aether-blossom-outfit"), "female-only Aether Blossom stays hidden for male models")
	store.call("_select_product", "adinho-classic-outfit")
	var classic_item: Dictionary = store.call("_catalog_item", "adinho-classic-outfit")
	_check(classic_item.get("name", "") == "Adinho Classic Box", "Classic product is clearly labelled as a box")
	_check(classic_item.get("badge", "") == "6-ITEM BOX", "Classic product communicates its six loose contents")
	var classic_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(classic_preview.get("hair", "") == "Adinho_Hair", "Classic preview includes the hairstyle")
	_check(classic_preview.get("facial_hair", "") == "Adinho_Beard", "Classic preview includes the beard")
	_check(classic_preview.get("facegear", "") == "Adinho_Glasses", "Classic preview includes the original glasses")
	_check(classic_preview.get("top", "") == "Adinho_Shirt", "Classic preview includes the original shirt")
	_check(classic_preview.get("bottom", "") == "Adinho_Trousers", "Classic preview includes the trousers")
	_check(classic_preview.get("shoes", "") == "Adinho_Shoes", "Classic preview includes the shoes")
	_check(store.character_preview_palette.visible, "Classic preview exposes its grayscale hair colour")
	_check(store.character_preview_viewport.get_child_count() == 1, "character preview renders the current trainer")
	var preview_visual := store.character_preview_viewport.get_child(0) as Node2D
	_check(preview_visual.position.y <= 160.0 and preview_visual.scale.y <= 3.0, "preview camera leaves room for the trainer's legs and feet")

	store.set_trainer_gender("female")
	_check(not store.product_buttons.has("adinho-classic-outfit"), "male-only Adinho Classic stays hidden for female models")
	_check(store.product_buttons.has("aether-blossom-outfit"), "Aether Blossom is listed for compatible female models")
	store.call("_select_product", "aether-blossom-outfit")
	var blossom_item: Dictionary = store.call("_catalog_item", "aether-blossom-outfit")
	_check(blossom_item.get("name", "") == "Aether Blossom Box", "Aether Blossom product is clearly labelled as a box")
	_check(blossom_item.get("badge", "") == "4-ITEM BOX", "Aether Blossom communicates its four loose contents")
	var blossom_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(blossom_preview.get("hair", "") == "Aether_Blossom_Hair", "Aether Blossom preview includes the hairstyle")
	_check(blossom_preview.get("facegear", "") == "Aether_Blossom_Earrings", "Aether Blossom preview includes the earrings")
	_check(blossom_preview.get("top", "") == "Aether_Blossom_Dress", "Aether Blossom preview includes the dress")
	_check(blossom_preview.get("shoes", "") == "Aether_Blossom_Shoes", "Aether Blossom preview includes the shoes")
	_check(store.call("_item_gender_badge", blossom_item) == "FEMALE ONLY", "Aether Blossom cards identify female-only compatibility")
	store.call("_select_character_preview_direction", "up")
	var blossom_preview_visual := store.character_preview_viewport.get_child(0) as Node2D
	var blossom_hair_sprite := blossom_preview_visual.find_child("HairSprite", true, false) as AnimatedSprite2D
	var blossom_earrings_sprite := blossom_preview_visual.find_child("FaceGearSprite", true, false) as AnimatedSprite2D
	_check(
		blossom_earrings_sprite.z_index < blossom_hair_sprite.z_index,
		"Aether Blossom earrings render behind the hair while facing up"
	)
	store.call("_select_character_preview_direction", "down")
	_check(
		blossom_earrings_sprite.z_index > blossom_hair_sprite.z_index,
		"Aether Blossom earrings render in front of the hair while facing down"
	)
	store.call("_select_cosmetic_subcategory", "hair")
	_check(store.product_buttons.has("aether-blossom-chroma-hair"), "Aether Blossom Chroma Hair is sold separately")
	store.call("_select_product", "aether-blossom-chroma-hair")
	var blossom_chroma_hair_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(
		blossom_chroma_hair_preview.get("hair", "") == "Aether_Blossom_Hair_Chroma",
		"Aether Blossom Chroma Hair previews the BlackWhite asset"
	)
	_check(store.character_preview_palette.visible, "Aether Blossom Chroma Hair exposes the colour palette")
	var blossom_chroma_before_invalid: Dictionary = store.call("_current_character_preview_appearance")
	store.call("_on_character_preview_hex_text_changed", "#12zz34")
	var blossom_chroma_after_invalid: Dictionary = store.call("_current_character_preview_appearance")
	_check(
		blossom_chroma_after_invalid.get("hair_color", "")
			== blossom_chroma_before_invalid.get("hair_color", ""),
		"invalid Store preview hex colours are ignored"
	)
	store.call("_on_character_preview_hex_text_changed", "7A46C5")
	var blossom_chroma_custom_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(
		blossom_chroma_custom_preview.get("hair_color", "") == "#7a46c5",
		"Store Chroma preview accepts a custom hex colour"
	)
	store.call("_select_cosmetic_subcategory", "facegear")
	_check(store.product_buttons.has("aether-blossom-chroma-earrings"), "Aether Blossom Chroma Earrings are sold separately")
	store.call("_select_cosmetic_subcategory", "shoes")
	_check(store.product_buttons.has("aether-blossom-chroma-shoes"), "Aether Blossom Chroma Shoes are sold separately")
	_check(
		not source.contains("Aether_Blossom_Dress_Chroma"),
		"Aether Blossom Dress has no Chroma Store product"
	)
	store.call("_select_cosmetic_subcategory", "outfits")
	store.set_trainer_gender("male")
	_check(store.product_buttons.has("adinho-classic-outfit"), "Adinho Classic is listed for compatible male models")
	_check(not store.product_buttons.has("aether-blossom-outfit"), "female-only Aether Blossom stays hidden for male models")
	_check(store.call("_item_gender_badge", classic_item) == "MALE ONLY", "Adinho cards visibly identify male-only compatibility")
	_check(
		store.call("_item_gender_compatibility_note", classic_item) == "Male character models only.",
		"Adinho selection details explain male-only compatibility"
	)
	store.call("_select_product", "adinho-classic-outfit")
	store.call("_select_character_preview_color", "#2b5f64")
	var recolored_classic_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(recolored_classic_preview.get("hair_color", "") == "#2b5f64", "Classic hair and beard colour changes stay inside the Store preview")
	_check(store.trainer_appearance.get("hair", "") != "Adinho_Hair", "preview never equips the cosmetic on the saved trainer")
	store.call("_select_character_preview_direction", "up")
	_check(store.character_preview_direction == "up", "preview can show the cosmetic from the back")

	store.call("_select_cosmetic_subcategory", "hair")
	_check(store.product_buttons.has("adinho-chroma-hair"), "grayscale hair is sold separately")
	store.call("_select_product", "adinho-chroma-hair")
	var hair_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(hair_preview.get("hair", "") == "Adinho_Hair", "separate hair product previews the hair with linked eyebrows")
	_check(
		hair_preview.get("top", "") == "Shirt"
			and hair_preview.get("bottom", "") == "Trousers"
			and hair_preview.get("shoes", "") == "Shoes",
		"hair preview keeps the complete starter outfit"
	)

	store.call("_select_cosmetic_subcategory", "body")
	_check(store.product_buttons.has("adinho-chroma-shirt"), "Chroma shirt is listed in the Body tab")

	store.call("_select_cosmetic_subcategory", "top")
	_check(store.product_buttons.has("adinho-chroma-shirt"), "Chroma shirt remains listed in the Top tab")
	store.call("_select_product", "adinho-chroma-shirt")
	var shirt_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(shirt_preview.get("top", "") == "Adinho_Shirt_Chroma", "selected Chroma shirt is the only clothing applied to the preview")
	_check(
		shirt_preview.get("bottom", "") == "Trousers" and shirt_preview.get("shoes", "") == "Shoes",
		"starter bottom and shoes remain while previewing a shirt"
	)

	store.call("_select_cosmetic_subcategory", "bottom")
	_check(store.product_buttons.has("adinho-chroma-trousers"), "grayscale trousers are sold separately")
	store.call("_select_product", "adinho-chroma-trousers")
	store.call("_select_character_preview_color", "#6b5c91")
	var trousers_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(trousers_preview.get("bottom", "") == "Adinho_Trousers_Chroma", "separate trousers use the Chroma appearance")
	_check(
		trousers_preview.get("top", "") == "Shirt" and trousers_preview.get("shoes", "") == "Shoes",
		"starter top and shoes remain while previewing trousers"
	)
	_check(trousers_preview.get("bottom_color", "") == "#6b5c91", "trousers have an independent preview colour")
	store.call("_select_cosmetic_subcategory", "shoes")
	_check(store.product_buttons.has("adinho-chroma-shoes"), "grayscale shoes are sold separately")
	store.call("_select_product", "adinho-chroma-shoes")
	var shoes_preview: Dictionary = store.call("_current_character_preview_appearance")
	_check(shoes_preview.get("shoes", "") == "Adinho_Shoes_Chroma", "separate shoes replace the starter shoes")
	_check(
		shoes_preview.get("top", "") == "Shirt" and shoes_preview.get("bottom", "") == "Trousers",
		"starter top and bottom remain while previewing shoes"
	)

	var client_target_prices := {
		"aether-blessing-voucher-3-days": 75,
		"aether-blessing-voucher-7-days": 150,
		"aether-blessing-voucher-14-days": 275,
		"aether-blessing-voucher-30-days": 500,
		"adinho-classic-outfit": 500,
		"aether-blossom-outfit": 400,
		"aether-blossom-chroma-hair": 100,
		"aether-blossom-chroma-earrings": 100,
		"aether-blossom-chroma-shoes": 75,
		"adinho-chroma-hair": 100,
		"adinho-chroma-beard": 75,
		"adinho-chroma-glasses": 100,
		"adinho-chroma-shirt": 150,
		"adinho-chroma-trousers": 125,
		"adinho-chroma-shoes": 75,
		"nimbus_mount": 600,
		"aether_board_mount": 600,
		"surf-charm": 350,
		"cut-charm": 250,
		"strength-charm": 300,
		"rock-smash-charm": 250,
		"flash-charm": 200,
		"dive-charm": 350,
		"defog-charm": 250,
		"rain-dance-charm": 250,
		"snowscape-charm": 250,
		"name-change-ticket": 250,
		"gender-chance-ticket": 100,
		"squirtle-guild-emblem-template": 150,
		"charmander-guild-emblem-template": 150,
		"bulbasaur-guild-emblem-template": 150,
		"venusaur-guild-emblem-template": 150,
		"charizard-guild-emblem-template": 150,
		"blastoise-guild-emblem-template": 150,
	}
	for item_id: String in client_target_prices:
		var priced_item: Dictionary = store.call("_catalog_item", item_id)
		_check(not priced_item.is_empty(), "%s exists in the client pricing catalog" % item_id)
		_check(
			int(priced_item.get("price", -1)) == int(client_target_prices[item_id]),
			"%s uses its canonical client preview price" % item_id
		)

	store.apply_store_state(
		{"gems": 500},
		{
			"items": [
				{
					"itemId": "aether-blessing-voucher-3-days",
					"genders": [],
					"costs": [{"currency": "gems", "amount": 75}],
				},
				{
					"itemId": "adinho-chroma-shirt",
					"genders": ["male"],
					"costs": [{"currency": "gems", "amount": 150}],
				},
				{
					"itemId": "squirtle-guild-emblem-template",
					"genders": [],
					"costs": [{"currency": "gems", "amount": 150}],
				},
				{
					"itemId": "charmander-guild-emblem-template",
					"genders": [],
					"costs": [{"currency": "gems", "amount": 150}],
				},
				{
					"itemId": "bulbasaur-guild-emblem-template",
					"genders": [],
					"costs": [{"currency": "gems", "amount": 150}],
				},
				{"itemId": "venusaur-guild-emblem-template", "genders": [], "costs": [{"currency": "gems", "amount": 150}]},
				{"itemId": "charizard-guild-emblem-template", "genders": [], "costs": [{"currency": "gems", "amount": 150}]},
				{"itemId": "blastoise-guild-emblem-template", "genders": [], "costs": [{"currency": "gems", "amount": 150}]},
				{"itemId": "surf-charm", "genders": [], "costs": [{"currency": "gems", "amount": 350}]},
				{"itemId": "cut-charm", "genders": [], "costs": [{"currency": "gems", "amount": 250}]},
				{"itemId": "strength-charm", "genders": [], "costs": [{"currency": "gems", "amount": 300}]},
				{"itemId": "rock-smash-charm", "genders": [], "costs": [{"currency": "gems", "amount": 250}]},
				{"itemId": "flash-charm", "genders": [], "costs": [{"currency": "gems", "amount": 200}]},
				{"itemId": "dive-charm", "genders": [], "costs": [{"currency": "gems", "amount": 350}]},
				{"itemId": "defog-charm", "genders": [], "costs": [{"currency": "gems", "amount": 250}]},
				{"itemId": "rain-dance-charm", "genders": [], "costs": [{"currency": "gems", "amount": 250}]},
				{"itemId": "snowscape-charm", "genders": [], "costs": [{"currency": "gems", "amount": 250}]},
			],
		}
	)
	store.call("_select_category", "guilds")
	_check(store.product_buttons.has("squirtle-guild-emblem-template"), "Guilds lists the Squirtle emblem template")
	store.call("_select_product", "squirtle-guild-emblem-template")
	var emblem_template: Dictionary = store.call("_catalog_item", "squirtle-guild-emblem-template")
	var emblem_icon := load("res://assets/items/icons/SQUIRTLEGUILDEMBLEMTEMPLATE.png") as Texture2D
	_check(
		emblem_icon != null and emblem_icon.get_width() == 32 and emblem_icon.get_height() == 32,
		"Squirtle Guild emblem uses a transparent 32 by 32 pixel asset"
	)
	_check(emblem_template.get("icon") == emblem_icon, "Guild emblem Store product uses its template preview")
	_check(store.find_child("GuildEmblemStorePreview", true, false) != null, "Gift Store previews the Guild emblem")
	_check(store.call("_gem_price", "squirtle-guild-emblem-template") == 150, "Guild emblem uses its server Aether Gem price")
	_check(
		str(emblem_template.get("description", "")).contains("Consume")
		and str(emblem_template.get("badge", "")) == "GUILD UNLOCK",
		"Guild emblem Store product explains its consumable Guild unlock"
	)
	_check(
		inventory_service_source.contains('"guild": _dictionary_from_value(body.get("guild", {}))'),
		"inventory service returns the Guild updated by a template"
	)
	_check(
		overlay_source.contains('"apply_guild_emblem_template"')
		and overlay_source.contains('return "Unlock for Guild"'),
		"Bag exposes the consumable Guild emblem unlock action"
	)
	for starter_id: String in [
		"charmander-guild-emblem-template",
		"bulbasaur-guild-emblem-template",
		"venusaur-guild-emblem-template",
		"charizard-guild-emblem-template",
		"blastoise-guild-emblem-template",
	]:
		_check(store.product_buttons.has(starter_id), "Guilds lists %s" % starter_id)
		var starter_template: Dictionary = store.call("_catalog_item", starter_id)
		var starter_icon := starter_template.get("icon") as Texture2D
		_check(
			starter_icon != null
			and starter_icon.get_width() == 32
			and starter_icon.get_height() == 32,
			"%s uses a 32 by 32 pixel asset" % starter_id
		)
		_check(
			store.call("_gem_price", starter_id) == 150,
			"%s uses its server Aether Gem price" % starter_id
		)

	store.call("_select_category", "charms")
	var charm_prices := {
		"surf-charm": 350,
		"cut-charm": 250,
		"strength-charm": 300,
		"rock-smash-charm": 250,
		"flash-charm": 200,
		"dive-charm": 350,
		"defog-charm": 250,
		"rain-dance-charm": 250,
		"snowscape-charm": 250,
	}
	for charm_id: String in charm_prices:
		_check(store.product_buttons.has(charm_id), "%s is listed as an available Charm" % charm_id)
		_check(store.call("_gem_price", charm_id) == charm_prices[charm_id], "%s uses its server Aether Gem price" % charm_id)
	store.call("_select_product", "surf-charm")
	_check(not store.purchase_button.disabled, "server-listed Surf Charm can be purchased")

	store.call("_select_category", "cosmetics")
	store.call("_select_cosmetic_subcategory", "top")
	store.call("_select_product", "adinho-chroma-shirt")
	_check(not store.purchase_button.disabled, "server-listed cosmetic can be purchased with enough Aether Gems")
	_check(store.selection_price_label.text.contains("150"), "server Aether Gem price overrides the preview catalog price")
	store.set_gem_balance(100)
	_check(store.purchase_button.disabled, "purchase is disabled when the Aether Gem balance is insufficient")

	store.call("_select_category", "membership")
	_check(not store.cosmetic_subcategory_bar.visible, "cosmetic subtabs stay out of other Store categories")
	store.call("_select_product", "aether-blessing-voucher-3-days")
	var blessing_item: Dictionary = store.call("_catalog_item", "aether-blessing-voucher-3-days")
	_check(
		blessing_item.get("name", "") == "Aether Blessing Voucher · 3 Days",
		"temporary supporter benefit is sold as a voucher"
	)
	_check(not store.purchase_button.disabled, "server-listed Blessing Vouchers can be purchased with Aether Gems")
	_check(store.selection_price_label.text.contains("75"), "Blessing Vouchers use their authoritative Aether Gem price")
	_check(store.status_label.text.contains("item goes to your Bag"), "Blessing checkout sends the voucher to the Bag")
	var blessing_icon_paths := {
		"aether-blessing-voucher-3-days": "res://assets/items/icons/AETHERBLESSINGVOUCHER3DAYS.png",
		"aether-blessing-voucher-7-days": "res://assets/items/icons/AETHERBLESSINGVOUCHER7DAYS.png",
		"aether-blessing-voucher-14-days": "res://assets/items/icons/AETHERBLESSINGVOUCHER14DAYS.png",
		"aether-blessing-voucher-30-days": "res://assets/items/icons/AETHERBLESSINGVOUCHER30DAYS.png",
	}
	var blessing_icons: Array[Texture2D] = []
	for voucher_id: String in blessing_icon_paths:
		var voucher_icon := load(str(blessing_icon_paths[voucher_id])) as Texture2D
		var voucher_item: Dictionary = store.call("_catalog_item", voucher_id)
		_check(
			voucher_icon != null
			and voucher_icon.get_width() == 48
			and voucher_icon.get_height() == 48,
			"%s has a transparent 48x48 pixel-art item icon" % voucher_id
		)
		_check(voucher_item.get("icon") == voucher_icon, "%s uses its own Store icon" % voucher_id)
		blessing_icons.append(voucher_icon)
	_check(
		blessing_icons.size() == 4
		and blessing_icons[0] != blessing_icons[1]
		and blessing_icons[1] != blessing_icons[2]
		and blessing_icons[2] != blessing_icons[3],
		"Blessing durations use four distinct icon resources"
	)

	store.call("_select_category", "services")
	_check(store.product_buttons.size() == 2, "Trainer Services contains exactly two tickets")
	_check(store.product_buttons.has("name-change-ticket"), "Name Change Ticket is listed")
	_check(store.product_buttons.has("gender-chance-ticket"), "Gender Chance Ticket is listed")
	_check(not store.product_buttons.has("appearance_reset_ticket"), "Appearance Reset is removed")
	var name_ticket_icon := load("res://assets/items/icons/NAMECHANGETICKET.png") as Texture2D
	var gender_ticket_icon := load("res://assets/items/icons/GENDERCHANCETICKET.png") as Texture2D
	_check(
		name_ticket_icon != null
		and name_ticket_icon.get_width() == 48
		and name_ticket_icon.get_height() == 48,
		"Name Change Ticket has a 48x48 pixel-art item icon"
	)
	_check(
		gender_ticket_icon != null
		and gender_ticket_icon.get_width() == 48
		and gender_ticket_icon.get_height() == 48,
		"Gender Chance Ticket has a 48x48 pixel-art item icon"
	)

	store.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return

	failed = true
	push_error("FAIL %s" % message)
