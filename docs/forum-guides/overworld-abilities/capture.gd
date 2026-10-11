extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var abra := sample_pokemon()
	abra.species = "abra"
	abra.species_id = "abra"
	abra.ability = "synchronize"
	abra.possible_abilities = ["synchronize", "innerfocus", "magicguard"]
	abra.types = ["psychic"]
	abra.can_evolve = false
	abra.moves = [{"id":"teleport", "name":"Teleport", "pp":20}]
	abra.stats = {"hp":37,"atk":13,"def":14,"spa":45,"spd":26,"spe":36}
	abra.max_hp = 37
	abra.current_hp = 37
	var meowth := sample_pokemon()
	meowth.species = "meowth"
	meowth.species_id = "meowth"
	meowth.owned_pokemon_id = 102
	meowth.instance_id = "example-pickup"
	meowth.level = 20
	meowth.nature = "Hardy"
	meowth.ability = "pickup"
	meowth.possible_abilities = ["pickup", "technician", "unnerve"]
	meowth.types = ["normal"]
	meowth.can_evolve = false
	meowth.moves = [{"id":"scratch", "name":"Scratch", "pp":35}]
	meowth.stats = {"hp":52,"atk":29,"def":25,"spa":23,"spd":25,"spe":47}
	meowth.max_hp = 52
	meowth.current_hp = 52
	meowth.experience = 8200
	meowth.current_level_exp = 8000
	meowth.next_level_exp = 9261
	var party: Array[Pokemon] = [abra, meowth]
	root.get_node("PlayerSave").party = party
	overlay.call("_refresh_party")
	var panel := overlay.get("party_panel") as Control
	panel.show()
	await settle()
	center(panel)
	await shot(0, "01-party-leader", panel, "Example party: Abra is the leader in slot 1; Meowth can use Pickup from another slot.", "## Choose your party leader")
	panel.hide()
	overlay.call("_show_pokemon_summary", 0)
	var summary := overlay.get("pokemon_summary_popup") as Control
	await settle()
	center(summary)
	await shot(0, "02-synchronize-nature", summary, "Example: this Abra has Synchronize and a Modest nature. Put it in slot 1 to use the nature effect.", "## Synchronize")
	overlay.call("_hide_pokemon_summary_popup")
	meowth.item = "antidote"
	overlay.call("_show_pokemon_summary", 1)
	summary = overlay.get("pokemon_summary_popup") as Control
	await settle()
	center(summary)
	overlay.call("_populate_party_slot_context_menu", meowth, 1)
	var menu := overlay.get("party_slot_context_menu") as PopupMenu
	var has_take := false
	for index in range(menu.item_count):
		if menu.get_item_text(index).to_lower().contains("take"):
			has_take = true
	assert(has_take, "Pickup Bag items must expose Take item")
	menu.position = Vector2i(summary.position + Vector2(summary.size.x - 230, summary.size.y - 170))
	menu.popup()
	await shot(0, "03-pickup-take-item", summary, "Example: Meowth carries an Antidote. Right-click its Party slot and choose Take held item to move it to the Bag.", "## Collect your Pickup item")
	menu.hide()
	finish("overworld-abilities")
