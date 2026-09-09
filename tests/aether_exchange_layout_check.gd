extends SceneTree

# Run with EXCHANGE_CAPTURE_DIR and a rendering display to save review images.
# All data is synthetic; this check never opens a session or performs a trade.
const POPUP := preload("res://scenes/interface/aether_exchange_popup.tscn")
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1040, 660)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.size = Vector2(1040, 660)
	viewport.add_child(host)
	var popup := POPUP.instantiate() as AetherExchangePopup
	host.add_child(popup)
	popup.visible = true
	var summary_overlay := (load("res://scenes/interface/ui_overlay.tscn") as PackedScene).instantiate()
	summary_overlay.set("root_control", host)
	var pokemon := {
		"pokemonId": 42, "species": "mew", "speciesId": "mew",
		"speciesName": "Mew", "level": 26, "nature": "Hardy",
		"ability": "Synchronize", "types": ["psychic"],
		"hp": 86, "maxHp": 86,
		"stats": {"hp": 86, "atk": 65, "def": 61, "spa": 70, "spd": 70, "spe": 71},
		"ivs": {"hp": 31, "atk": 0, "def": 31, "spa": 31, "spd": 31, "spe": 31},
		"evs": {"hp": 4, "spa": 252, "spe": 252},
		"moves": ["Grass Knot", "Thunderbolt", "Calm Mind", "Substitute"],
	}
	var item := {"itemId": "poke-ball", "name": "Poké Ball", "shortDesc": "A ball used to catch wild Pokémon.", "quantity": 20}
	var cut_charm := {"itemId": "cut-charm", "name": "Cut Charm", "shortDesc": "Lets you use Cut without a Pokémon knowing it.", "quantity": 1}
	var tm := {"itemId": "tm-thunderbolt", "name": "TM: Thunderbolt", "machineKind": "tm", "machineMoveType": "electric", "quantity": 1}
	var outfit := {"itemId": "mysterious-outfit", "name": "Mysterious Outfit", "quantity": 1}
	var mount := {"itemId": "cyclizar-mount", "name": "Cyclizar Mount", "quantity": 1}
	var listing := {"id": "preview-1", "assetType": "pokemon", "asset": pokemon, "quantity": 1, "unitPrice": 100, "totalPrice": 100, "status": "active"}
	var wish := {"id": "preview-wish", "item": item, "quantity": 10, "unitPrice": 100, "totalPrice": 1000, "status": "active", "isMine": false}
	var listings: Array = []
	for index in range(20):
		var entry := listing.duplicate(true)
		entry["id"] = "preview-%d" % index
		entry["totalPrice"] = 100 + index * 500
		if index == 1:
			entry["asset"]["species"] = "bulbasaur"
			entry["asset"]["speciesId"] = "bulbasaur"
			entry["asset"]["speciesName"] = "Bulbasaur"
			entry["asset"]["hiddenAbility"] = true
		if index == 2:
			entry["asset"]["shiny"] = true
		listings.append(entry)
	var localization := root.get_node("LocalizationManager")
	var previous_locale: String = localization.current_locale
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		for screen: String in ["buy", "hover", "items", "tm", "outfit", "mount", "sell", "request", "wanted", "mine", "mine-items", "history"]:
			summary_overlay.call("_hide_aether_exchange_pokemon_summary_hover")
			await process_frame
			popup.search_input.text = ""
			popup.wallet_money = 24826
			popup.sellable_items = [item]
			popup.sellable_pokemon = [pokemon]
			popup.browse_listings = listings
			popup.browse_wishes = [wish]
			popup.wishlist_catalog = [item]
			popup.my_wishes = [wish.merged({"isMine": true}, true)]
			var own_listing := listing.merged({"status": "sold" if screen == "history" else "active"}, true)
			if screen == "mine-items":
				own_listing = {"id": "own-item", "assetType": "item", "asset": item, "quantity": 2, "unitPrice": 100, "totalPrice": 200, "status": "active"}
			popup.my_listings = [own_listing]
			popup.portfolio_history = screen == "history"
			popup.active_tab = {"buy": "browse", "hover": "browse", "items": "browse", "tm": "browse", "outfit": "browse", "mount": "browse", "request": "wishlist", "mine-items": "mine", "history": "mine"}.get(screen, screen)
			popup.asset_filter = "pokemon" if screen in ["buy", "hover", "sell", "mine"] else "item"
			if screen in ["items", "tm", "outfit", "mount"]:
				var preview_item: Dictionary = {"items": cut_charm, "tm": tm, "outfit": outfit, "mount": mount}[screen]
				popup.browse_listings = [{"id": "item-offer", "assetType": "item", "asset": preview_item, "quantity": 1, "unitPrice": 100000, "totalPrice": 100000, "status": "active"}]
			if screen == "history":
				popup.asset_filter = "pokemon"
			elif screen == "mine-items":
				popup.asset_filter = "item"
			popup.selected_entry = {}
			popup.selected_kind = ""
			popup._refresh_controls()
			popup._render_current_list()
			match screen:
				"buy": popup._select_entry(listings[0], "listing")
				"hover":
					var hover_source := popup.list_container.get_child(0) as Button
					summary_overlay.call("_on_aether_exchange_pokemon_summary_hover_requested", popup._pokemon_summary_payload(pokemon), hover_source.get_global_rect())
				"items", "tm", "outfit", "mount": popup._select_entry(popup.browse_listings[0], "listing")
				"sell": popup._select_entry(pokemon, "sell")
				"request": popup._select_entry(item, "wish_catalog")
				"wanted": popup._select_entry(wish, "wish")
				"mine": popup._select_entry(popup.my_listings[0], "listing")
				"mine-items": popup._select_entry(popup.my_wishes[0], "wish")
				"history": popup._select_entry(popup.my_listings[0], "listing")
			for frame in range(5):
				await process_frame
			var description := locale + "/" + screen
			_check(popup.size == Vector2(1040, 660), description + ": fixed window")
			if popup.context_panel.visible:
				_check_bounds(popup.context_panel, popup, description)
				_check(not popup.context_title_label.text.begins_with("ui.exchange."), description + ": translated page title")
				_check(not popup.context_description_label.text.begins_with("ui.exchange."), description + ": translated page description")
			for collection: Dictionary in [popup.tab_buttons, popup.context_buttons, popup.asset_buttons]:
				for button: Button in collection.values():
					if button.is_visible_in_tree():
						_check_bounds(button, popup, description)
			for control: Control in [popup.search_input, popup.browse_sort_button, popup.advanced_filter_button, popup.refresh_button, popup.request_item_button, popup.action_bar, popup.detail_panel]:
				if control.is_visible_in_tree():
						_check_bounds(control, popup, description)
			if screen == "hover":
				var summary_popup := summary_overlay.get("pokemon_summary_popup") as PanelContainer
				_check(summary_popup != null and summary_popup.visible, description + ": full read-only Summary is visible")
				_check(summary_popup.name == "PokemonReadonlySummaryPopup", description + ": hover uses the existing Summary card")
				_check_bounds(summary_popup, popup, description)
			if screen in ["items", "tm", "outfit", "mount"]:
				var item_icon := popup.list_container.get_child(0).find_child("BrowseCardIcon", true, false) as TextureRect
				_check(item_icon != null, description + ": item offer has an icon")
				if item_icon != null:
					_check(item_icon.texture != null and not item_icon.texture.resource_path.ends_with("/000.png"), description + ": item uses its Item Dex icon")
					if screen == "items":
						_check(item_icon.texture.resource_path.ends_with("/field_move_charms/CUTCHARM.png"), description + ": Cut Charm uses its own icon")
					elif screen == "tm":
						_check(item_icon.texture.resource_path.ends_with("/machine_ELECTRIC.png"), description + ": TM uses its type icon")
			if screen in ["mine", "mine-items", "history"]:
				var listings_section := popup.list_container.find_child("ExchangePortfolioListingsSection", true, false) as Control
				_check(listings_section != null, description + ": sale listings have their own section")
				if listings_section != null:
					_check_bounds(listings_section, popup, description)
					_check(not (listings_section.find_child("PortfolioSectionTitle", true, false) as Label).text.begins_with("ui.exchange."), description + ": sale section title is translated")
				if screen == "mine-items":
					var requests_section := popup.list_container.find_child("ExchangePortfolioRequestsSection", true, false) as Control
					_check(requests_section != null, description + ": item requests have a separate section")
					_check(popup.list_container.columns == 2, description + ": sale listings and requests are side by side")
					if requests_section != null:
						_check_bounds(requests_section, popup, description)
						_check(requests_section.size.x < popup.list_scroll.size.x * 0.6, description + ": request section does not consume the full width")
			var active_content: Control = popup.detail_stack if popup.detail_panel.visible else popup.action_content
			for button: Button in active_content.find_children("*", "Button", true, false):
				if button.is_visible_in_tree():
					_check_bounds(button, popup, description)
					_check(not button.text.begins_with("ui.exchange."), description + ": translated action")
			if screen == "buy":
				popup.list_scroll.scroll_vertical = 100
				await process_frame
				var before := popup.list_scroll.scroll_vertical
				popup._select_entry(listings[5], "listing")
				await process_frame
				_check(popup.list_scroll.scroll_vertical == before and before > 0, description + ": selecting another Pokémon retains scroll")
				popup.list_scroll.scroll_vertical = 0
				popup._select_entry(listings[0], "listing")
			var capture_dir := OS.get_environment("EXCHANGE_CAPTURE_DIR")
			if not capture_dir.is_empty():
				await RenderingServer.frame_post_draw
				_check(viewport.get_texture().get_image().save_png(capture_dir.path_join("%s-%s.png" % [locale, screen])) == OK, description + ": screenshot")
	localization.set_locale(previous_locale)
	summary_overlay.call("_hide_aether_exchange_pokemon_summary_hover")
	summary_overlay.free()
	viewport.queue_free()
	await process_frame
	PokemonAssets.party_icon_cache.clear()
	await process_frame
	print("Exchange layout (4 locales, 12 screens): ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check_bounds(control: Control, popup: Control, description: String) -> void:
	var rect := control.get_global_rect()
	_check(popup.get_global_rect().grow(1).encloses(rect), description + ": " + control.name + " fits window")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)
