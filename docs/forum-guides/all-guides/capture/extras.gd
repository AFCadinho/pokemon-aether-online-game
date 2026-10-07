extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var rental := load("res://scripts/ui/rental_workspace.gd").new() as Window
	rental.set("kind","team")
	view.add_child(rental)
	var team: Dictionary = read_fixture("rental-team.json")
	rental.set("catalog",{"offers":[team],"rentals":[]})
	rental.get("team_catalog").call("set_offers",[team])
	rental.get("team_catalog").call("show_detail",team)
	rental.set("selected",team)
	(rental.get("balance") as Label).text = "Aetherite: 1,000"
	(rental.get("duration") as OptionButton).add_item("24 hours — 200 Aetherite")
	(rental.get("duration") as OptionButton).set_item_metadata(0,team.prices[0])
	rental.popup_centered(Vector2i(940,670))
	await shot_window(86,"02-fixed-rental-team",rental,"Example Team Rental catalog: inspect the six fixed sets and their held items. A full team costs 200 Aetherite for 24 hours.","## Renting a full team")
	rental.hide()
	clear()
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	var bag := battle.get_node("BattleDrawerLayer/BagDrawer") as Control
	bag.reparent(overlay.get("root_control"))
	bag.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bag.size = Vector2(680,360)
	var grid := bag.find_child("BagGrid",true,false) as Control
	grid.show()
	var items: Array = []
	for id: String in ["poke-ball","great-ball","ultra-ball"]:
		items.append({"itemId":id,"name":read_fixture("items.json")[id].name,"quantity":10})
	grid.call("set_items",items)
	root.get_node("LocalizationManager").localize_tree(bag)
	bag.show()
	await settle()
	center(bag)
	await shot(98,"01-battle-bag-balls",bag,"Example wild-battle Bag: choose an available Poké Ball after weakening the target. Throwing it uses your battle action.","## How to throw a ball")
	battle.free()
	clear()
	finish("extras")
