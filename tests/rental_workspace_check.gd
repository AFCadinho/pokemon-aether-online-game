extends SceneTree

const WORKSPACE := preload("res://scripts/ui/rental_workspace.gd")

class FakeRentalService extends Node:
	func request(path: String, _payload: Dictionary = {}, _mutate := false, _post := false) -> Dictionary:
		if path.begins_with("/catalog/team/"):
			return {"success": true, "body": _team(true)}
		return {"success": true, "body": {"offerId": "custom-test", "displayName": "Scizor", "rarity": "uncommon", "buyoutTotal": 1500, "prices": [{"durationSeconds": 86400, "amount": 100}], "pokemon": [{"species": "Scizor", "nature": "Adamant", "ability": "Technician", "item": "leftovers", "moves": [{"id": "bullet-punch", "name": "Bullet Punch"}], "evs": {"atk": 252}, "ivs": {"atk": 31}}]}}

	func _team(detail := false) -> Dictionary:
		var pokemon: Array = []
		for species: String in ["garchomp", "rotom-wash", "scizor", "dragonite", "gengar", "tyranitar"]:
			pokemon.append({"species": species, "nature": "Jolly", "ability": "pressure", "item": "leftovers", "moves": ["protect", "substitute", "toxic", "earthquake"], "evs": {"hp": 252, "spe": 252}, "ivs": {"hp": 31}} if detail else {"species": species})
		return {"offerId": "test", "teamId": "test", "displayName": "Test Balance", "archetype": "balance", "eligibleTierIds": ["aether-ou", "aether-uu", "aether-ubers"], "pokemon": pokemon}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var team_workspace := WORKSPACE.new()
	root.add_child(team_workspace)
	assert(team_workspace.borderless)
	assert(team_workspace.balance.get_parent() is HBoxContainer)
	team_workspace.service.queue_free()
	team_workspace.service = FakeRentalService.new()
	team_workspace.add_child(team_workspace.service)
	var team_offer: Dictionary = team_workspace.service._team(false)
	team_workspace.catalog = {"offers": [team_offer], "rentals": []}
	team_workspace.team_catalog.set_offers([team_offer])
	team_workspace._render_active()
	assert(team_workspace.team_catalog.results.get_child_count() == 1)
	assert(team_workspace.team_catalog.result_status.text == "1 rental team")
	assert(team_workspace.team_catalog.archetype_filter.item_count == 2)
	assert(team_workspace.team_catalog.tier_filter.item_count == 3)
	assert(team_workspace.team_catalog.tier_filter.get_item_text(1) == "AETHER OU")
	assert(team_workspace.team_catalog.tier_filter.get_item_text(2) == "AETHER UU")
	for index: int in range(team_workspace.team_catalog.tier_filter.item_count):
		assert(team_workspace.team_catalog.tier_filter.get_item_text(index) != "AETHER UBERS")
	assert(team_workspace.team_catalog.action_bar.get_child_count() == 2)
	assert(team_workspace.team_catalog.archetype_filter.get_popup().has_theme_stylebox_override("panel"))
	assert(team_workspace.duration.get_popup().has_theme_stylebox_override("panel"))
	assert(team_workspace._duration_label(604800) == "7 days")
	assert(team_workspace.team_catalog.results.get_child(0).find_children("*", "TextureRect", true, false).size() == 6)
	await team_workspace._select_team_offer(team_offer)
	assert(team_workspace.team_catalog.team_grid.get_child_count() == 6)
	assert(team_workspace.team_catalog.team_grid.columns == 3)
	assert((team_workspace.team_catalog.team_grid.get_child(0) as Control).custom_minimum_size.y == 180)
	assert(team_workspace.team_catalog.detail_title.text == "Test Balance")
	assert(team_workspace.team_catalog.detail_meta.text.contains("AETHER OU"))
	assert(not team_workspace.rent_button.disabled)
	var team_rent_payload := team_workspace._build_rent_payload({"durationSeconds": 86400.0})
	assert(typeof(team_rent_payload["durationSeconds"]) == TYPE_INT)
	assert(team_rent_payload["durationSeconds"] == 86400)
	assert(not team_rent_payload.has("pokemonBuild"))
	team_workspace.catalog["rentals"] = [{"context": "npc_team", "status": "return_pending"}]
	await team_workspace._select_team_offer(team_offer)
	assert(team_workspace.rent_button.disabled)
	assert(team_workspace.rent_button.text == "Team rental limit reached")
	team_workspace.team_catalog.search.text = "missing"
	team_workspace.team_catalog._refresh_results()
	assert(team_workspace.team_catalog.results.get_child_count() == 0)
	assert(team_workspace.team_catalog.result_status.text == "0 rental teams")
	var batched_offers: Array = []
	for index: int in range(9):
		var batched_offer := team_offer.duplicate(true)
		batched_offer["offerId"] = "batch-%d" % index
		batched_offer["teamId"] = "batch-%d" % index
		batched_offer["displayName"] = "Batch %d" % index
		batched_offers.append(batched_offer)
	team_workspace.team_catalog.search.text = ""
	team_workspace.team_catalog.set_offers(batched_offers)
	assert(team_workspace.team_catalog.results.get_child_count() == 4)
	assert(team_workspace.team_catalog.result_status.text == "Loading teams… 4/9")
	await team_workspace.team_catalog.results_rendered
	assert(team_workspace.team_catalog.results.get_child_count() == 9)
	assert(team_workspace.team_catalog.result_status.text == "9 rental teams")
	var active_assets: Array = []
	for set_data: Dictionary in team_workspace.service._team(true)["pokemon"]:
		active_assets.append({"assetType": "pokemon", "snapshot": set_data})
	team_workspace.catalog["rentals"] = [{"loanId": "team-loan", "context": "npc_team", "status": "active", "dueAt": "2026-09-21T12:00:00Z", "assets": active_assets, "rental": {"displayName": "Test Balance"}}]
	team_workspace._render_active()
	var active_team_card := team_workspace.active_list.get_node("ActiveTeamRentalCard")
	var active_team_sets := active_team_card.find_child("ActiveTeamSets", true, false)
	assert(active_team_sets.get_child_count() == 6)
	assert((active_team_sets.get_child(0) as Control).custom_minimum_size.y == 160)
	assert(active_team_sets.get_child(0).find_children("*", "TextureRect", true, false).size() == 1)
	var active_team_buttons := active_team_card.find_children("*", "Button", true, false)
	assert(active_team_buttons.any(func(button: Button): return button.text == "Extend 24 hours — 100 Aetherite" and button.has_theme_stylebox_override("normal")))
	assert(active_team_buttons.any(func(button: Button): return button.text == "Return team" and button.has_theme_stylebox_override("normal")))
	team_workspace.queue_free()
	var pokemon_workspace := WORKSPACE.new()
	pokemon_workspace.kind = "pokemon"
	root.add_child(pokemon_workspace)
	assert(pokemon_workspace.quote_button.disabled)
	assert(pokemon_workspace.pokemon_edit_step.visible)
	assert(not pokemon_workspace.pokemon_review_step.visible)
	assert(pokemon_workspace.pokemon_source.get_tab_title(0) == "Paste a set")
	assert(pokemon_workspace.pokemon_source.get_tab_title(1) == "Build manually")
	assert(pokemon_workspace.pokemon_source.has_theme_stylebox_override("tab_selected"))
	assert(pokemon_workspace.pokemon_paste.has_theme_stylebox_override("normal"))
	assert((pokemon_workspace.pokemon_fields["species"] as LineEdit).has_theme_stylebox_override("normal"))
	assert((pokemon_workspace.pokemon_evs["atk"] as SpinBox).get_line_edit().has_theme_stylebox_override("normal"))
	assert(pokemon_workspace.pokemon_gender.get_popup().has_theme_stylebox_override("panel"))
	assert(pokemon_workspace.duration.get_popup().has_theme_stylebox_override("panel"))
	pokemon_workspace.service.queue_free()
	pokemon_workspace.service = FakeRentalService.new()
	pokemon_workspace.add_child(pokemon_workspace.service)
	pokemon_workspace.catalog = {"offers": [], "rentals": [], "maxPokemon": 6}
	pokemon_workspace.pokemon_paste.text = "Scizor @ Leftovers\nAbility: Technician\nEVs: 252 Atk / 4 SpD / 252 Spe\nAdamant Nature\n- Bullet Punch"
	pokemon_workspace._update_pokemon_preview()
	assert(pokemon_workspace.pokemon_preview_species.text == "Scizor")
	assert(pokemon_workspace.pokemon_preview_item_name.text == "Leftovers")
	assert(pokemon_workspace.pokemon_preview_item_icon.texture != null)
	assert(pokemon_workspace.pokemon_preview_details.text.contains("Ability:[/color] Technician"))
	assert(pokemon_workspace.pokemon_preview_details.text.contains("EVs:[/color] 252 Atk / 4 SpD / 252 Spe"))
	assert(pokemon_workspace.pokemon_preview_details.text.contains("Adamant Nature"))
	assert(pokemon_workspace.pokemon_preview_details.text.contains("Bullet Punch"))
	pokemon_workspace._refresh_builder_actions()
	assert(not pokemon_workspace.quote_button.disabled)
	await pokemon_workspace._quote_pokemon()
	assert(not pokemon_workspace.rent_button.disabled)
	assert(not pokemon_workspace.pokemon_edit_step.visible)
	assert(pokemon_workspace.pokemon_review_step.visible)
	assert(pokemon_workspace.pokemon_review_species.text == "Scizor")
	assert(pokemon_workspace.pokemon_review_rarity.text == "UNCOMMON")
	assert(pokemon_workspace.pokemon_review_rarity.get_parent().name == "RarityBadge")
	assert(pokemon_workspace.pokemon_review_item_name.text == "Leftovers")
	assert(pokemon_workspace.pokemon_review_item_name.get_parent().get_parent().name == "HeldItemChip")
	assert(pokemon_workspace.pokemon_review_item_icon.texture != null)
	assert(pokemon_workspace.pokemon_review_rental_price.text == "100 Aetherite")
	assert(pokemon_workspace.pokemon_review_buyout_price.text == "1400 Aetherite")
	assert(pokemon_workspace.description.text.contains("Scizor[/color] @ Leftovers"))
	assert(not pokemon_workspace.description.scroll_active)
	assert(pokemon_workspace.description.text.contains("Bullet Punch"))
	assert(not pokemon_workspace.description.text.contains("IVs:"))
	assert(pokemon_workspace.duration.get_item_text(0).contains("100 Aetherite"))
	assert(not pokemon_workspace.duration.visible)
	assert(pokemon_workspace.rent_button.text == "Rent for 24 hours — 100 Aetherite")
	assert(pokemon_workspace.selected_build["source"] == "paste")
	var pokemon_rent_payload := pokemon_workspace._build_rent_payload({"durationSeconds": 86400.0})
	assert(typeof(pokemon_rent_payload["durationSeconds"]) == TYPE_INT)
	assert(pokemon_rent_payload["durationSeconds"] == 86400)
	assert(pokemon_rent_payload["pokemonBuild"] == pokemon_workspace.selected_build)
	var rental_snapshot := {"species": "Scizor", "nature": "Adamant", "ability": "Technician", "item": "leftovers", "teraType": "Steel", "moves": [{"id": "bullet-punch", "name": "Bullet Punch"}], "evs": {"atk": 252}, "ivs": {"atk": 31}}
	var second_snapshot := {"species": "Garchomp", "nature": "Jolly", "ability": "Rough Skin", "item": "rocky-helmet", "moves": ["Earthquake", "Dragon Claw"], "evs": {"atk": 252, "spe": 252}, "ivs": {}}
	pokemon_workspace.catalog["rentals"] = [
		{"loanId": "loan-1", "context": "npc_pokemon", "status": "active", "dueAt": "2026-09-21T12:00:00Z", "assets": [{"assetType": "pokemon", "snapshot": rental_snapshot}], "rental": {"displayName": "Scizor", "rarity": "uncommon", "buyoutPrice": 1400}},
		{"loanId": "loan-2", "context": "npc_pokemon", "status": "active", "dueAt": "2026-09-22T12:00:00Z", "assets": [{"assetType": "pokemon", "snapshot": second_snapshot}], "rental": {"displayName": "Garchomp", "rarity": "rare", "buyoutPrice": 1800}},
	]
	pokemon_workspace._render_active()
	var rental_grid := pokemon_workspace.active_list.get_node("ActivePokemonRentalGrid") as GridContainer
	assert(rental_grid.columns == 3)
	assert(rental_grid.get_child_count() == 2)
	assert(rental_grid.get_node("ActivePokemonRentalCard-loan-1") != null)
	assert(rental_grid.get_node("ActivePokemonRentalCard-loan-2") != null)
	var first_set_details := rental_grid.get_node("ActivePokemonRentalCard-loan-1").find_child("RentalSetDetails", true, false) as RichTextLabel
	assert(first_set_details.text.contains("Bullet Punch"))
	assert(first_set_details.text.contains("EVs:[/color] 252 Atk"))
	var active_buttons := rental_grid.find_children("*", "Button", true, false)
	assert(active_buttons.filter(func(button: Button): return button.text == "Extend").size() == 2)
	assert(active_buttons.filter(func(button: Button): return button.text == "Make Permanent").size() == 2)
	assert(active_buttons.filter(func(button: Button): return button.text == "Return").size() == 2)
	pokemon_workspace._show_pokemon_review(false)
	assert(pokemon_workspace.pokemon_edit_step.visible)
	assert(not pokemon_workspace.pokemon_review_step.visible)
	pokemon_workspace.pokemon_paste.text += "\nJolly Nature"
	pokemon_workspace._invalidate_pokemon_quote()
	assert(pokemon_workspace.rent_button.disabled)
	pokemon_workspace.pokemon_source.current_tab = 1
	(pokemon_workspace.pokemon_fields["species"] as LineEdit).text = "Garchomp"
	(pokemon_workspace.pokemon_fields["item"] as LineEdit).text = "Rocky Helmet"
	(pokemon_workspace.pokemon_fields["moves"] as LineEdit).text = "Earthquake, Dragon Claw"
	pokemon_workspace._update_pokemon_preview()
	assert(pokemon_workspace.pokemon_preview_species.text == "Garchomp")
	assert(pokemon_workspace.pokemon_preview_details.text.contains("Earthquake"))
	var manual_build: Dictionary = pokemon_workspace._pokemon_build()
	assert(manual_build["source"] == "manual")
	assert(manual_build["pokemon"]["species"] == "Garchomp")
	assert(manual_build["pokemon"]["item"] == "Rocky Helmet")
	assert(manual_build["pokemon"]["ivs"]["spe"] == 31)
	pokemon_workspace.queue_free()
	var rental_service := preload("res://scripts/services/rental_service.gd").new()
	assert(rental_service._error_message([{"msg": "Value error, Paste a Pokémon set first."}]) == "Paste a Pokémon set first.")
	rental_service.queue_free()
	var npc: PackedScene = load("res://scenes/npcs/rental_npc.tscn")
	assert(npc != null)
	var rental_npc := npc.instantiate()
	assert(rental_npc.display_name == "Team Rental")
	assert(rental_npc.manual_interaction_reach_tiles == 3)
	assert((rental_npc.get_node("InteractionArea") as Area2D).position == Vector2(0, 64))
	assert(((rental_npc.get_node("InteractionArea/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size == Vector2(96, 192))
	rental_npc.free()
	var npc_source := FileAccess.get_file_as_string("res://scripts/world/npcs/rental_npc.gd")
	assert(npc_source.contains("func _show_rental_choice()"))
	assert(npc_source.contains('choice.add_item("How rentals work")'))
	assert(npc_source.contains("func _rental_explanation()"))
	print("PASS rental team catalog and custom Pokemon builder")
	quit(0)
