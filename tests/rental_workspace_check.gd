extends SceneTree

const WORKSPACE := preload("res://scripts/ui/rental_workspace.gd")

class FakeRentalService extends Node:
	func request(path: String, _payload: Dictionary = {}, _mutate := false) -> Dictionary:
		if path.begins_with("/catalog/team/"):
			return {"success": true, "body": _team(true)}
		return {"success": true, "body": {"displayName": "Scizor", "buyoutTotal": 1000, "pokemon": [{"speciesId": "scizor", "nature": "Adamant", "ability": "technician", "item": "", "moves": ["bullet-punch"], "ivs": {"atk": 31}}]}}

	func _team(detail := false) -> Dictionary:
		var pokemon: Array = []
		for species: String in ["garchomp", "rotom-wash", "scizor", "dragonite", "gengar", "tyranitar"]:
			pokemon.append({"species": species, "nature": "Jolly", "ability": "pressure", "item": "leftovers", "moves": ["protect", "substitute", "toxic", "earthquake"], "evs": {"hp": 252, "spe": 252}, "ivs": {"hp": 31}} if detail else {"species": species})
		return {"offerId": "test", "teamId": "test", "displayName": "Test Balance", "archetype": "balance", "eligibleTierIds": ["aether-ou"], "pokemon": pokemon}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var team_workspace := WORKSPACE.new()
	root.add_child(team_workspace)
	team_workspace.service.queue_free()
	team_workspace.service = FakeRentalService.new()
	team_workspace.add_child(team_workspace.service)
	var team_offer: Dictionary = team_workspace.service._team(false)
	team_workspace.catalog = {"offers": [team_offer], "rentals": []}
	team_workspace.team_catalog.set_offers([team_offer])
	team_workspace._render_active()
	assert(team_workspace.team_catalog.results.get_child_count() == 1)
	assert(team_workspace.team_catalog.archetype_filter.item_count == 2)
	assert(team_workspace.team_catalog.tier_filter.item_count == 2)
	assert(team_workspace.team_catalog.action_bar.get_child_count() == 2)
	assert(team_workspace._duration_label(604800) == "7 days")
	assert(team_workspace.team_catalog.results.get_child(0).find_children("*", "TextureRect", true, false).size() == 6)
	await team_workspace._select_team_offer(team_offer)
	assert(team_workspace.team_catalog.team_grid.get_child_count() == 6)
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
	pokemon_workspace.catalog = {"offers": [{"offerId": "test", "displayName": "Test Pokémon", "pokemon": []}], "rentals": []}
	pokemon_workspace._filter()
	assert(pokemon_workspace.listing.item_count == 1)
	pokemon_workspace.service.queue_free()
	pokemon_workspace.service = FakeRentalService.new()
	pokemon_workspace.add_child(pokemon_workspace.service)
	await pokemon_workspace._select(0)
	assert(not pokemon_workspace.rent_button.disabled)
	assert(pokemon_workspace.description.text.contains("No item"))
	assert(pokemon_workspace.description.text.contains("bullet-punch"))
	pokemon_workspace.queue_free()
	var npc: PackedScene = load("res://scenes/npcs/rental_npc.tscn")
	assert(npc != null)
	print("PASS rental team catalog mirrors AI Sparring cards, filters and six-set detail")
	quit(0)
