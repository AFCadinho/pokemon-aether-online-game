extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var skills: Array = read_fixture("skills.json")
	root.get_node("SkillsService").skills = skills
	root.get_node("SkillsService").state_loaded = true
	var panel := overlay.get("skills_panel") as Control
	panel.call("_render_skills",skills)
	panel.show()
	await settle()
	center(panel)
	await shot(60,"01-skills-overview",panel,"Example Skills overview: select Fishing, Thieving or Rock Smash to inspect its level, XP and unlocks.","## Opening Skills")
	panel.call("_select_skill","rock_smash")
	await shot(60,"02-level-roadmap",panel,"Example skill page: the roadmap distinguishes unlocked rewards from later milestones.","## Unlocking and progressing")
	panel.call("_select_detail_tab","catalog")
	await shot(59,"01-daily-rocks",panel,"Example: Skills → Rock Smash → Rocks lists exact locations, required levels and today's availability.","## Daily rocks and locations")
	(panel.get("targets_section") as Control).hide()
	(panel.get("progression_section") as Control).hide()
	var rewards := panel.get("rewards_section") as Control
	rewards.show()
	rewards.set("player_level",20)
	rewards.set("catalog",read_fixture("rock-rewards.json"))
	rewards.call("_render")
	panel.set("selected_detail_tab","rewards")
	panel.call("_style_detail_tab",panel.get("catalog_tab_button"),false)
	panel.call("_style_detail_tab",panel.get("rewards_tab_button"),true)
	await shot(59,"02-rock-smash-rewards",panel,"Check Rock Smash's Rewards tab for money, treasure and fossil information as your level increases.","## Items you can find")
	clear()
	var transit := load("res://scripts/ui/transit_menu.gd").new() as CanvasLayer
	transit.custom_viewport = view
	view.add_child(transit)
	transit.call("open",{"sourceRegionId":"kanto","sourceMapId":"kanto_viridian_city","wallet":{"money":5000},"membershipDiscountActive":false,"destinations":[
		{"destinationId":"kanto_viridian_city","regionId":"kanto","name":"Viridian City","attuned":true,"isAnchor":false,"fare":200},
		{"destinationId":"kanto_pallet_town","regionId":"kanto","name":"Pallet Town","attuned":true,"isAnchor":true,"fare":0},
		{"destinationId":"kanto_pewter_city","regionId":"kanto","name":"Pewter City","attuned":true,"isAnchor":false,"fare":200},
		{"destinationId":"kanto_cerulean_city","regionId":"kanto","name":"Cerulean City","attuned":false,"isAnchor":false,"fare":200},
		{"destinationId":"aether_clash_lobby","regionId":"all","name":"Aether Clash Lobby","attuned":true,"isGlobalHub":true,"guildBenefitActive":true,"fare":0}]})
	await settle()
	(transit.find_child("Destination_kanto_pewter_city",true,false) as Button).pressed.emit()
	await shot(30,"01-aethernet-destinations",transit.find_child("TransitPanel",true,false),"Example Aethernet menu: select an attuned destination, then check its fare. Normal regional travel costs ₽200; your Anchor is free.","## Travelling")
	transit.queue_free()
	await process_frame
	clear()
	var starter := load("res://scripts/ui/starter_choice_dialog.gd").new() as CanvasLayer
	starter.custom_viewport = view
	view.add_child(starter)
	starter.call("open",read_fixture("starters.json"))
	starter.call("_select_choice",read_fixture("starters.json")[0])
	await shot(84,"01-choose-starter",starter.find_child("StarterChoicePanel",true,false),"Browse the starter choices, inspect the selected Pokémon and confirm the partner you want.","## 1. Choose your first Pokémon")
	starter.queue_free()
	await process_frame
	clear()
	root.get_node("GameState").apply_pokemon_level_cap_state({"levelCap":20,"tradeLevelCap":5,"region":"kanto","stageId":"before_brock","badgeCount":0})
	var caps := overlay.call("_create_trainer_card_caps_panel") as Control
	(overlay.get("root_control") as Control).add_child(caps)
	caps.custom_minimum_size = Vector2(520,120)
	await settle()
	center(caps)
	await shot(85,"01-level-and-trade-caps",caps,"Example with no badges: the Trainer Card shows a normal level cap of 20 and a separate trade cap of 5.","## The two limits")
	caps.hide()
	clear()
	var boss := load("res://scenes/interface/weekly_boss_dialog.tscn").instantiate() as Control
	(overlay.get("root_control") as Control).add_child(boss)
	boss.call("configure_boss","Zapdos",{"state":"available","hardDefeated":false},root.get_node("LocalizationManager").text("weekly_boss.hard_unlock"))
	boss.call("popup_centered")
	await shot(88,"01-zapdos-difficulty",boss.get("panel"),"Choose the Weekly Boss difficulty before starting. The boss challenge is separate from a catchable wild encounter.","## Starting a challenge")
	boss.queue_free()
	await process_frame
	clear()
	for buff: Dictionary in overlay.get("global_buffs_data"):
		if str(buff.get("id","")) == "global_shiny":
			var example := buff.duplicate(true)
			example["goal"] = 1000000
			example["current"] = 0
			example["state"] = "funding"
			overlay.set("selected_global_buff",example)
			overlay.call("_render_global_buff_details")
			var boost := overlay.get("global_buff_details_panel") as Control
			boost.show()
			await settle()
			center(boost)
			await shot(55,"01-global-shiny-boost",boost,"Example funding panel: the Global Shiny Boost activates only after its community goal is filled.","## Global Shiny Boost")
	finish("activities")
