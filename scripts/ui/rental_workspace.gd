extends Window

signal finished

const SERVICE := preload("res://scripts/services/rental_service.gd")
const CONFIRM := preload("res://scenes/interface/aether_confirmation_dialog.tscn")
var service: Node
var kind := "team"
var catalog: Dictionary = {}
var offers: Array = []
var selected: Dictionary = {}
var listing: ItemList
var description: RichTextLabel
var duration: OptionButton
var status: Label
var balance: Label
var rent_button: Button
var active_list: VBoxContainer
var search: LineEdit
var busy := false
var detail_generation := 0

func _ready() -> void:
	hide()
	title = "Aether Rentals"
	size = Vector2i(940, 670)
	min_size = Vector2i(800, 600)
	close_requested.connect(_close)
	service = SERVICE.new()
	add_child(service)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("081522")
	style.border_color = Color("62d7ff")
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	var heading := Label.new()
	heading.text = "AETHER RENTALS  /  " + ("TEAMS" if kind == "team" else "POKÉMON")
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("62d7ff"))
	root.add_child(heading)
	balance = Label.new()
	root.add_child(balance)
	var note := Label.new()
	note.text = "Level 100 • NPC Original Trainer • No caught credit • Real time, including offline"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	var browse := HBoxContainer.new()
	browse.name = "Catalog"
	browse.add_theme_constant_override("separation", 16)
	tabs.add_child(browse)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	browse.add_child(left)
	search = LineEdit.new()
	search.placeholder_text = "Search name, Pokémon or tier…"
	search.text_changed.connect(func(_value: String): _filter())
	left.add_child(search)
	listing = ItemList.new()
	listing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listing.item_selected.connect(_select)
	left.add_child(listing)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse.add_child(right)
	description = RichTextLabel.new()
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.text = "Select an offer to inspect its complete set."
	right.add_child(description)
	duration = OptionButton.new()
	right.add_child(duration)
	rent_button = Button.new()
	rent_button.text = "Rent with Aetherite"
	rent_button.disabled = true
	rent_button.pressed.connect(_rent)
	right.add_child(rent_button)
	var scroll := ScrollContainer.new()
	scroll.name = "My rentals"
	tabs.add_child(scroll)
	active_list = VBoxContainer.new()
	active_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_list.add_theme_constant_override("separation", 12)
	scroll.add_child(active_list)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close)
	root.add_child(close_button)

func open_vendor() -> void:
	popup_centered(size)
	await refresh()

func refresh() -> void:
	busy = true
	status.text = "Loading rentals…"
	var result: Dictionary = await service.request("/catalog/" + kind)
	busy = false
	if not bool(result.get("success", false)):
		status.text = str(result.get("error", "Unavailable"))
		return
	catalog = result["body"]
	balance.text = "Balance: %d Aetherite  •  Limit: %d team + %d individual Pokémon" % [int(catalog.get("aetherite", 0)), int(catalog.get("maxTeams", 1)), int(catalog.get("maxPokemon", 6))]
	duration.clear()
	for price: Dictionary in catalog.get("prices", []):
		duration.add_item("%d hours — %d Aetherite" % [int(price["durationSeconds"]) / 3600, int(price["amount"])])
		duration.set_item_metadata(duration.item_count - 1, price)
	_filter()
	_render_active()
	status.text = "Rentals arrive in your PC (or free Party slots if the PC is full). Early returns are not refunded."

func _filter() -> void:
	listing.clear()
	offers.clear()
	selected = {}
	detail_generation += 1
	rent_button.disabled = true
	for offer: Dictionary in catalog.get("offers", []):
		if not search.text.is_empty() and search.text.to_lower() not in JSON.stringify(offer).to_lower():
			continue
		offers.append(offer)
		listing.add_item(str(offer.get("displayName", "")) + (" · " + str(offer.get("homeTierId", "Open")) if kind == "team" else ""))

func _select(index: int) -> void:
	if busy:
		return
	detail_generation += 1
	var generation := detail_generation
	selected = {}
	rent_button.disabled = true
	description.text = "Loading set…"
	var offer: Dictionary = offers[index]
	var result: Dictionary = await service.request("/catalog/%s/%s" % [kind, str(offer["offerId"]).uri_encode()])
	if generation != detail_generation:
		return
	if not bool(result.get("success", false)):
		description.text = str(result.get("error", "Unavailable"))
		return
	selected = result["body"]
	var text := str(selected.get("displayName", "")) + "\n\n"
	for pokemon: Dictionary in selected.get("pokemon", []):
		var held_item := str(pokemon.get("item", ""))
		text += "%s • Lv.100\n%s / %s / %s\n" % [str(pokemon.get("species", pokemon.get("speciesId", ""))), str(pokemon.get("nature", "")), str(pokemon.get("ability", "")), "No item" if held_item.is_empty() else held_item]
		text += "Moves: %s\nEVs: %s\nIVs: %s\n\n" % [", ".join(pokemon.get("moves", [])), JSON.stringify(pokemon.get("evs", {})), JSON.stringify(pokemon.get("ivs", {}))]
	text += "Full rental team: fixed sets and items; no permanent purchase. Use all six together in Aether Clash." if kind == "team" else "Permanent purchase: %d Aetherite total, minus this rental fee. NPC OT stays; no caught credit." % int(selected.get("buyoutTotal", 0))
	description.text = text
	rent_button.disabled = false

func _rent() -> void:
	if busy or selected.is_empty():
		return
	var price: Dictionary = duration.get_selected_metadata()
	await _mutate("", {"kind": kind, "offerId": selected["offerId"], "durationSeconds": price["durationSeconds"]}, "Rent %s for %d Aetherite?\nThe timer includes offline time. No refund for early return." % [selected["displayName"], int(price["amount"])])

func _render_active() -> void:
	for child: Node in active_list.get_children():
		child.queue_free()
	var count := 0
	for loan: Dictionary in catalog.get("rentals", []):
		if str(loan.get("context", "")) != "npc_" + kind or str(loan.get("status", "")) not in ["active", "return_pending"]:
			continue
		count += 1
		var data: Dictionary = loan.get("rental", {})
		var label := Label.new()
		label.text = "%s\nExpires: %s UTC • %s" % [data.get("displayName", "Rental"), str(loan.get("dueAt", "")).replace("T", " ").left(19), loan.get("status", "")]
		active_list.add_child(label)
		var actions := HBoxContainer.new()
		active_list.add_child(actions)
		var return_button := Button.new()
		return_button.text = "Return rental"
		return_button.pressed.connect(func(): await _mutate("/%s/return" % loan["loanId"], {}, "Return this rental now? No Aetherite will be refunded."))
		actions.add_child(return_button)
		if kind == "pokemon" and loan.get("status") == "active":
			var buy := Button.new()
			buy.text = "Keep permanently — %d Aetherite" % int(data.get("buyoutPrice", 0))
			buy.pressed.connect(func(): await _mutate("/%s/buyout" % loan["loanId"], {}, "Pay %d Aetherite to keep this Pokémon?\nOT stays Aether Rental Service. This does not count as caught." % int(data.get("buyoutPrice", 0))))
			actions.add_child(buy)
	if count == 0:
		var empty := Label.new()
		empty.text = "No active rentals from this vendor."
		active_list.add_child(empty)

func _mutate(path: String, payload: Dictionary, message: String) -> void:
	if busy:
		return
	busy = true
	var confirm := CONFIRM.instantiate() as AetherConfirmationDialog
	add_child(confirm)
	confirm.configure("Aether Rentals", message, "Confirm", "Cancel")
	var choice := {"yes": false, "done": false}
	confirm.confirmed.connect(func(): choice["yes"] = true; choice["done"] = true)
	confirm.canceled.connect(func(): choice["done"] = true)
	confirm.popup_centered(Vector2i(620, 340))
	while not bool(choice["done"]):
		await get_tree().process_frame
	confirm.queue_free()
	if not bool(choice["yes"]):
		busy = false
		return
	status.text = "Processing…"
	var result: Dictionary = await service.request(path, payload, true)
	busy = false
	if not bool(result.get("success", false)):
		status.text = str(result.get("error", "Request failed."))
		return
	for entry: Array in [["PlayerPartyStateService", "refresh_party"], ["InventoryService", "load_inventory"], ["PlayerWalletService", "load_wallet"]]:
		var target := get_node_or_null("/root/" + str(entry[0]))
		if target != null and target.has_method(str(entry[1])):
			var updated: Dictionary = await target.call(str(entry[1]))
			if str(entry[0]) == "PlayerWalletService" and target.has_method("apply_wallet_result"):
				target.call("apply_wallet_result", updated)
	await refresh()
	status.text = "Done. Your Pokémon, wallet and rentals are up to date."

func _close() -> void:
	if busy:
		return
	hide()
	finished.emit()
