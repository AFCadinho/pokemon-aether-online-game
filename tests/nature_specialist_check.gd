extends SceneTree
var failed := false
func _init() -> void:
	call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failed = true
func _run() -> void:
	var localization = root.get_node("LocalizationManager")
	var original_locale: String = localization.current_locale
	localization.set_locale("en")
	var factory := load("res://scripts/data/pokemon_factory.gd")
	var pokemon: Pokemon = factory.create_pokemon_from_backend_payload({"species":"pikachu", "nature":"Hardy", "effectiveNature":"Jolly", "natureTreatment":{"id":"mint"}, "level":5, "stats":{"hp":20}, "ivs":{}, "evs":{}, "moves":[]})
	_check(pokemon.nature == "Hardy" and pokemon.get_effective_nature() == "Jolly", "Original and effective natures stay distinct")
	_check(pokemon.to_persistence_dict().get("nature") == "Hardy" and pokemon.to_battle_dict().get("effectiveNature") == "Jolly", "Serialization preserves provenance and battle effect")
	_check(pokemon.nature_treatment.get("id") == "mint", "Details retain treatment marker")
	_check(load("res://scripts/ui/ui_overlay.gd") != null, "Nature Specialist integrates with the existing overlay")
	var packed := load("res://scenes/overworld/kanto/reusable_interiors/pokemon_center_template.tscn") as PackedScene
	_check(packed != null, "Pokemon Center loads")
	if packed:
		var center := packed.instantiate()
		_check(center.get_node_or_null("Entities/NPCs/NatureSpecialist") == null, "Nature NPC is absent from Pokemon Centers")
		center.free()
	var daycare := load("res://scenes/overworld/kanto/routes/route5/daycare.tscn") as PackedScene
	_check(daycare != null, "Daycare loads")
	if daycare:
		var interior := daycare.instantiate()
		var specialist := interior.get_node_or_null("Entities/NPCs/NatureSpecialist")
		_check(specialist != null and specialist.npc_definition_id == "kanto_route_5_nature_specialist", "Nature NPC is wired to its Daycare definition")
		if specialist:
			_check(specialist.portrait_id == "showdown_gardener" and specialist.mugshot.resource_path.ends_with("gardener.png"), "Gardener portrait overrides Oak fallback")
			_check("NPC_Z07_Breeder_M" in specialist.npc_sprite_frames.get_frame_texture("idle_down",0).atlas.resource_path, "Green gardener overworld is assigned")
			var collision := interior.get_node("Tiles/Collision") as TileMapLayer
			var cell := collision.local_to_map(specialist.position)
			_check(collision.get_cell_source_id(cell) == -1 and collision.get_cell_source_id(cell + Vector2i.DOWN) == -1, "Daycare specialist has a clear approach tile")
		interior.free()
	var popup := load("res://scenes/interface/nature_specialist_popup.tscn") as PackedScene
	_check(popup != null, "Nature Specialist interface loads")
	if popup:
		var panel := popup.instantiate()
		root.add_child(panel)
		await process_frame
		_check(panel.get("confirm_button") != null and panel.get("nature_select") != null, "Selection and confirmation controls exist")
		panel.call("_apply_state", {"pokemon":[{"pokemon":{"ownedPokemonId":123.0,"level":50.0,"species":"Pikachu","nature":"Hardy","shiny":true,"ivs":{"hp":31.0,"spe":31.0}},"price":2500000,"rarity":"uncommon","eligible":true,"location":{"type":"party","partySlot":0}}],"natures":[{"name":"Hardy"},{"name":"Jolly","boosted_stat":"spe","lowered_stat":"spa"}],"serverTime":"2026-10-13T12:00:00+00:00","nextAvailableAt":null,"money":10000000})
		_check("Pikachu" in panel.pokemon_select.get_item_text(0) and "2,500,000" in panel.pokemon_select.get_item_text(0), "Server-priced selection shows species rather than boolean values")
		_check(".0" not in panel.pokemon_select.get_item_text(0) and ".0" not in panel.iv_values["hp"].text, "JSON floats render as integer IDs, levels and IVs")
		_check(panel.pokemon_select.has_theme_stylebox_override("normal") and panel.pokemon_select.get_popup().has_theme_stylebox_override("panel"), "Selection and opened popup use custom styling")
		_check(panel.nature_select.get_popup().has_theme_icon_override("radio_checked"), "Dropdown indicators use PokeAether art")
		_check(panel.close_button.tooltip_text == root.get_node("LocalizationManager").text("common.close"), "Close action uses an existing translated key")
		panel.nature_select.select(1)
		panel.call("_show_quote", {"previewId":"test-preview","originalNature":"Hardy","oldNature":"Hardy","newNature":"Jolly","price":2500000,"oldStats":{"spe":100,"spa":60},"newStats":{"spe":110,"spa":54}})
		panel.call("_set_busy", false)
		_check(panel.stat_values["spe"][0].text == "100" and panel.stat_values["spa"][0].text == "60" and panel.stat_values["spa"][1].text == "54", "Server stat comparison displays both effects")
		_check(panel.stat_values["spe"][1].text == "110" and panel.stat_values["spe"][2].text == "+10", "Visible stat grid shows exact new values and delta")
		panel.call("_ask_confirm")
		_check(panel.confirmation.visible and "2,500,000" in panel.confirmation.message_label.text, "Explicit paid confirmation displays quoted cost")
		panel.confirmation.hide_dialog()
		for locale: String in ["en","nl","pt_BR","zh_CN"]:
			localization.set_locale(locale)
			_check(not panel.section_labels["price_label"].text.begins_with("ui."), "Specialist labels translate in " + locale)
			_check(panel.nature_select.get_item_metadata(panel.nature_select.selected) == "Jolly", "Locale changes retain selected nature")
			_check(panel.price_label.text == ("2.500.000 ₽" if locale in ["nl","pt_BR"] else "2,500,000 ₽"), "Price grouping follows locale " + locale)
		localization.set_locale("en")
		var nature_service = root.get_node("NatureSpecialistService")
		nature_service.pending_request = {"previewId":"pending-preview", "requestId":"pending-request"}
		nature_service.pending_display = {"originalNature":"Hardy", "oldNature":"Hardy", "newNature":"Jolly", "price":2500000,"oldStats":{"spe":100},"newStats":{"spe":110}}
		panel.call("_set_busy", false)
		_check(panel.pokemon_select.disabled and not panel.confirm_button.disabled, "Unresolved request locks new selection and permits retry")
		nature_service.pending_account_id = "another-account"
		nature_service.call("_reset_for_account")
		_check(nature_service.pending_request.is_empty(), "Pending confirmation cannot cross an account switch")
		var sample_state: Dictionary = panel.cached_state.duplicate(true)
		var rows: Array = [{"pokemon":{"ownedPokemonId":55,"species":"Venusaur","level":100,"nature":"Hardy"},"price":2000000,"location":{"type":"box","boxIndex":0,"slotIndex":11}}]
		for position in [5,3,4,2,1,0]:
			var p: Dictionary = {"ownedPokemonId":100+position,"species":"Tyranitar" if position==0 else "Magikarp","level":20-position,"nature":"Hardy"}
			rows.append({"pokemon":p,"price":125000,"eligible":position not in [2,4],"blockedReason":"nature_not_ot" if position==2 else ("nature_protected" if position==4 else null),"location":{"type":"party","partySlot":position}})
		panel.call("_apply_state", {"pokemon":rows,"natures":[{"name":"Hardy"}],"money":1000000,"serverTime":"2026-10-14T12:00:00+00:00","nextAvailableAt":null})
		_check(panel.entries.size()==6 and panel.pokemon_select.item_count==6, "All six Party members remain visible and PC Venusaur is excluded")
		for position in range(6):
			_check(panel.pokemon_select.get_item_metadata(position)==100+position, "Picker follows Party slot order")
		_check(panel.pokemon_select.is_item_disabled(2) and panel.pokemon_select.is_item_disabled(4), "Ineligible Party members are disabled rather than hidden")
		_check("OT" in panel.pokemon_select.get_item_text(2) and "Test" in panel.pokemon_select.get_item_text(4), "Unavailable entries explain their protection reason")
		_check(panel.pokemon_select.selected==0 and "Party 1" in panel.pokemon_info.text, "Selected card identifies the actual Party slot")
		for row: Dictionary in rows:
			row["eligible"]=false
			row["blockedReason"]="nature_not_ot"
		panel.call("_apply_state", {"pokemon":rows,"natures":[{"name":"Hardy"}],"money":1000000,"serverTime":"2026-10-14T12:00:00+00:00","nextAvailableAt":null})
		_check(panel.entries.size()==6 and panel.preview_button.disabled and panel.confirm_button.disabled, "All-blocked Party stays visible without permitting treatment")
		panel.free()
		var small_viewport := SubViewport.new()
		small_viewport.size = Vector2i(520,700)
		root.add_child(small_viewport)
		var small_panel = popup.instantiate()
		small_viewport.add_child(small_panel)
		small_panel.show()
		small_panel.call("_apply_state", sample_state)
		small_panel.call("_show_quote", {"originalNature":"Hardy","oldNature":"Hardy","newNature":"Jolly","price":2500000,"oldStats":{"spe":100,"spa":60},"newStats":{"spe":110,"spa":54}})
		for _frame in range(8):
			await process_frame
		_check(small_panel.size.x <= 520 and small_panel.size.y <= 700, "Popup fits compact viewports")
		var last_stat: Label = small_panel.stat_values["spe"][2]
		_check(last_stat.get_global_rect().end.y <= small_panel.content_scroll.get_global_rect().end.y, "Preview scrolls the entire stat comparison into view on compact screens")
		small_viewport.free()
	localization.set_locale(original_locale)
	quit(1 if failed else 0)
