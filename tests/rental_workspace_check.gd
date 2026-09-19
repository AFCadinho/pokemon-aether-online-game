extends SceneTree

const WORKSPACE := preload("res://scripts/ui/rental_workspace.gd")

class FakeRentalService extends Node:
	func request(path: String, _payload: Dictionary = {}, _mutate := false, _post := false) -> Dictionary:
		if path.begins_with("/catalog/team/"):
			return {"success": true, "body": _team(true)}
		return {"success": true, "body": {"offerId": "custom-test", "displayName": "Scizor", "rarity": "uncommon", "buyoutTotal": 1250, "prices": [{"durationSeconds": 3600, "amount": 25}], "pokemon": [{"species": "Scizor", "nature": "Adamant", "ability": "Technician", "item": "", "moves": [{"id": "bullet-punch", "name": "Bullet Punch"}], "evs": {"atk": 252}, "ivs": {"atk": 31}}]}}

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
	team_workspace.catalog["rentals"] = [{"context": "npc_team", "status": "return_pending"}]
	await team_workspace._select_team_offer(team_offer)
	assert(team_workspace.rent_button.disabled)
	assert(team_workspace.rent_button.text == "Team rental limit reached")
	team_workspace.team_catalog.search.text = "missing"
	team_workspace.team_catalog._refresh_results()
	assert(team_workspace.team_catalog.results.get_child_count() == 0)
	team_workspace.queue_free()
	var pokemon_workspace := WORKSPACE.new()
	pokemon_workspace.kind = "pokemon"
	root.add_child(pokemon_workspace)
	assert(pokemon_workspace.quote_button.disabled)
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
	pokemon_workspace.pokemon_paste.text = "Scizor\nAbility: Technician\n- Bullet Punch"
	pokemon_workspace._refresh_builder_actions()
	assert(not pokemon_workspace.quote_button.disabled)
	await pokemon_workspace._quote_pokemon()
	assert(not pokemon_workspace.rent_button.disabled)
	assert(pokemon_workspace.description.text.contains("Uncommon"))
	assert(pokemon_workspace.description.text.contains("Bullet Punch"))
	assert(pokemon_workspace.duration.get_item_text(0).contains("25 Aetherite"))
	assert(pokemon_workspace.selected_build["source"] == "paste")
	pokemon_workspace.pokemon_paste.text += "\nJolly Nature"
	pokemon_workspace._invalidate_pokemon_quote()
	assert(pokemon_workspace.rent_button.disabled)
	pokemon_workspace.pokemon_source.current_tab = 1
	(pokemon_workspace.pokemon_fields["species"] as LineEdit).text = "Garchomp"
	var manual_build: Dictionary = pokemon_workspace._pokemon_build()
	assert(manual_build["source"] == "manual")
	assert(manual_build["pokemon"]["species"] == "Garchomp")
	assert(manual_build["pokemon"]["ivs"]["spe"] == 31)
	pokemon_workspace.queue_free()
	var rental_service := preload("res://scripts/services/rental_service.gd").new()
	assert(rental_service._error_message([{"msg": "Value error, Paste a Pokémon set first."}]) == "Paste a Pokémon set first.")
	rental_service.queue_free()
	var npc: PackedScene = load("res://scenes/npcs/rental_npc.tscn")
	assert(npc != null)
	var npc_source := FileAccess.get_file_as_string("res://scripts/world/npcs/rental_npc.gd")
	assert(npc_source.contains("func _show_rental_choice()"))
	assert(npc_source.contains('choice.add_item("How rentals work")'))
	assert(npc_source.contains("func _rental_explanation()"))
	print("PASS rental team catalog and custom Pokemon builder")
	quit(0)
