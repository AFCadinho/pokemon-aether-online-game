extends SceneTree
var failed := false
func _init() -> void:
	call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failed = true
func _run() -> void:
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
		panel.call("_apply_state", {"pokemon":[{"pokemon":{"ownedPokemonId":123,"species":"Pikachu","nature":"Hardy","shiny":true},"price":2500000,"rarity":"uncommon"}],"natures":[{"name":"Hardy"},{"name":"Jolly","boosted_stat":"spe","lowered_stat":"spa"}],"serverTime":"2026-10-13T12:00:00+00:00","nextAvailableAt":null,"money":10000000})
		_check("Pikachu" in panel.pokemon_select.get_item_text(0) and "2500000" in panel.pokemon_select.get_item_text(0), "Server-priced selection shows species rather than boolean values")
		panel.call("_show_quote", {"previewId":"test-preview","originalNature":"Hardy","oldNature":"Hardy","newNature":"Jolly","price":2500000,"oldStats":{"spe":100,"spa":60},"newStats":{"spe":110,"spa":54}})
		panel.call("_set_busy", false)
		_check("100 → 110" in panel.comparison.text and "60 → 54" in panel.comparison.text, "Server stat comparison displays both effects")
		panel.call("_ask_confirm")
		_check(panel.confirmation.visible and "2500000" in panel.confirmation.message_label.text, "Explicit paid confirmation displays quoted cost")
		panel.confirmation.hide_dialog()
		var nature_service = root.get_node("NatureSpecialistService")
		nature_service.pending_request = {"previewId":"pending-preview", "requestId":"pending-request"}
		nature_service.pending_display = {"originalNature":"Hardy", "oldNature":"Hardy", "newNature":"Jolly", "price":2500000,"oldStats":{"spe":100},"newStats":{"spe":110}}
		panel.call("_set_busy", false)
		_check(panel.pokemon_select.disabled and not panel.confirm_button.disabled, "Unresolved request locks new selection and permits retry")
		nature_service.pending_account_id = "another-account"
		nature_service.call("_reset_for_account")
		_check(nature_service.pending_request.is_empty(), "Pending confirmation cannot cross an account switch")
		panel.free()
	quit(1 if failed else 0)
