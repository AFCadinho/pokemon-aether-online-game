extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var pokemon := sample_pokemon()
	var party: Array[Pokemon] = [pokemon]
	root.get_node("PlayerSave").party = party
	overlay.call("_show_pokemon_summary",0)
	var popup := overlay.get("pokemon_summary_popup") as Control
	await settle()
	center(popup)
	await shot(99,"01-happiness",popup,"Example Summary: check Happiness in the Info tab. Raising it does not currently activate friendship evolutions.","## How Happiness works")
	await shot(85,"02-experience",popup,"Example Summary: the EXP indicator shows progress towards the next level. Your current level cap still applies.","## What happens to EXP at the cap?")
	var stack := overlay.get("pokemon_summary_content_stack") as Control
	var grid := stack.get_child(1) as Control
	var nodes: Dictionary = popup.get_meta("summary_hover_nodes",{})
	overlay.call("_show_readonly_summary_detail_hover",grid.get_child(2),nodes)
	await shot(100,"03-nature",popup,"Example: hover over Modest to see which stat it raises and which it lowers.","## What does Nature do?")
	overlay.call("_hide_readonly_summary_detail_hover",nodes)
	overlay.call("_show_readonly_summary_detail_hover",grid.get_child(1),nodes)
	await shot(100,"04-ability",popup,"Example: hover over the current Ability to read its battle effect.","## What is an Ability?")
	overlay.call("_hide_readonly_summary_detail_hover",nodes)
	overlay.call("_on_pokemon_summary_tab_selected","ivs")
	await shot(100,"01-ivs-and-stats",popup,"Example Summary: compare each stat and its IV. Individual values remain separate from level and training.","## What are IVs?")
	overlay.call("_on_pokemon_summary_tab_selected","evs")
	await shot(100,"02-stored-and-allocated-evs",popup,"Example Summary: Stored EVs are available training points; Allocated EVs are already assigned to stats.","## What are EVs?")
	overlay.call("_on_pokemon_summary_tab_selected","general")
	overlay.set("bag_inventory_items",overlay.call("_normalize_bag_inventory_items",read_fixture("held-items.json")))
	overlay.set("bag_inventory_loaded",true)
	overlay.call("_refresh_pokemon_summary_item_picker")
	assert((overlay.get("pokemon_summary_item_list") as Control).get_child_count() == 4)
	(overlay.get("pokemon_summary_item_picker") as Control).show()
	await shot(101,"01-choose-held-item",popup,"Example: select the held-item slot, then choose an eligible item from your Bag.","## Giving or taking an item")
	(overlay.get("pokemon_summary_item_picker") as Control).hide()
	pokemon.item = "exp-share"
	overlay.call("_refresh_pokemon_summary")
	await shot(101,"02-equipped-exp-share",popup,"Example: Exp. Share is equipped on this Pokémon. Owning it in the Bag alone does not activate its held-item effect.","## Exp. Share: who gets the EXP?")
	clear()
	overlay.call("_setup_item_dex_popup")
	var dex := overlay.get("item_dex_popup") as Control
	for item_id: String in ["poke-ball","great-ball","ultra-ball"]:
		var item: Dictionary = read_fixture("items.json")[item_id]
		var results := overlay.get("item_dex_results_list") as Control
		for child in results.get_children():
			child.queue_free()
		results.add_child(overlay.call("_create_item_dex_result_button",item))
		(overlay.get("item_dex_results_count_label") as Label).text = "1 result"
		overlay.call("_on_item_dex_result_selected",item)
		(overlay.get("item_dex_search_input") as LineEdit).text = item.name
		await shot(98,item_id,dex,"Check each ball's Item Dex entry for its capture rules before choosing what to throw.","## Choosing a ball")
	clear()
	overlay.call("_setup_pokedex_popup")
	var pd := overlay.get("pokedex_popup") as Control
	overlay.set("pokedex_selected_species",read_fixture("bulbasaur.json"))
	overlay.set("pokedex_selected_species_id","bulbasaur")
	overlay.set("pokedex_active_tab","evolutions")
	overlay.call("_set_pokedex_header_from_species",read_fixture("bulbasaur.json"))
	overlay.call("_refresh_pokedex_tab_buttons")
	(overlay.get("pokedex_results_count_label") as Label).text = "1 species"
	var pd_results := overlay.get("pokedex_results_list") as Control
	for child in pd_results.get_children():
		child.queue_free()
	pd_results.add_child(overlay.call("_create_pokedex_species_button",read_fixture("bulbasaur.json")))
	overlay.call("_refresh_pokedex_detail")
	await shot(99,"02-pokedex-evolutions",pd,"Check the Pokédex Evolutions tab for the next form and its listed requirements. Some special methods are not active yet.","## Check the Pokédex first")
	finish("summary")
