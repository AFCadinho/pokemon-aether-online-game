extends "res://docs/forum-guides/all-guides/capture/base.gd"

func _run() -> void:
	await setup()
	var pokemon := sample_pokemon()
	var party: Array[Pokemon] = [pokemon]
	root.get_node("PlayerSave").party = party
	var mentor := overlay.get("move_mentor_popup") as Control
	var moves: Array[Dictionary] = []
	for move: Dictionary in read_fixture("bulbasaur.json").moves.levelUp:
		if int(move.level) <= pokemon.level and str(move.moveId) not in ["tackle","growl","vine-whip"]:
			moves.append({"moveId":move.moveId,"source":"relearn","level":move.level,"cost":{"itemId":"heart-scale","quantity":1,"ownedQuantity":3}})
	mentor.set("selected_party_index",0)
	mentor.set("candidates",moves)
	mentor.call("_refresh_party_list")
	mentor.call("_refresh_move_list")
	mentor.call("_refresh_current_moves")
	mentor.call("_on_move_selected","leech-seed")
	mentor.show()
	await settle()
	center(mentor)
	await shot(87,"01-relearn-a-move",mentor,"Example Move Maniac: select Bulbasaur, inspect the available moves and check the Heart Scale cost for Leech Seed.","## Teaching a move with the Move Maniac")
	clear()
	var deleter := overlay.get("move_deleter_popup") as Control
	deleter.call("open_deleter")
	deleter.call("_on_move_selected",1)
	await settle()
	center(deleter)
	await shot(87,"02-free-move-deletion",deleter,"Example Move Deleter: select the move to remove and confirm only after checking it. Deletion is free, and the final move cannot be removed.","## Removing a move with the Move Deleter")
	clear()
	root.get_node("StoryService").apply_story(read_fixture("quest.json"))
	var journal := overlay.get("quest_journal_view") as Control
	journal.show()
	journal.call("open_journal","oaks_parcel")
	await shot(84,"02-follow-current-quest",journal.get("journal_panel"),"Example Quest Log: the active objective identifies your next task. Completed and later steps remain separate.","## 2. Keep following the story")
	await shot(102,"01-oaks-parcel-quest",journal.get("journal_panel"),"Example Oak's Parcel quest: collect the parcel in Viridian City, then finish the return conversation with Oak.","### Oak's Parcel")
	journal.call("close_journal")
	for quest_id: String in ["challenge_pewter_gym","challenge_cerulean_gym","challenge_vermilion_gym"]:
		var stories: Dictionary = read_fixture("story-quests.json")
		assert(stories.has(quest_id))
		root.get_node("StoryService").apply_story(stories[quest_id])
		journal.call("open_journal",quest_id)
		var key := "02-brock-quest" if quest_id == "challenge_pewter_gym" else "03-misty-quest" if quest_id == "challenge_cerulean_gym" else "04-surge-quest"
		var heading := "### Reaching Pewter City" if quest_id == "challenge_pewter_gym" else "### Your second badge" if quest_id == "challenge_cerulean_gym" else "### The third Gym battle"
		await shot(102,key,journal.get("journal_panel"),"Example Gym quest: read the current objective before challenging this Gym. Progression can require an earlier story step.",heading)
		journal.call("close_journal")
	finish("moves-story")
