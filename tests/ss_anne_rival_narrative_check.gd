extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var skipper := (load("res://scenes/npcs/ss_anne_skipper.tscn") as PackedScene).instantiate()
	skipper.allowed_dialogue_id = "kanto_ss_anne_skipper_allowed"
	skipper.name = "NarrativeSkipper"
	# No guarded transition or metadata ID: use the real StoryService
	# without starting gate/network requests.
	root.add_child(skipper)
	var story = root.get_node("StoryService")
	var original: Dictionary = story.get_story()
	story.apply_story({"revision": 1, "quests": []})
	check(skipper.select_allowed_dialogue_id() == "kanto_ss_anne_skipper_allowed", "Normal welcome before the rival request")
	story.apply_story({"revision": 2, "quests": [{"questId": "ss_anne_rival", "status": "active"}]})
	check(skipper.select_allowed_dialogue_id() == "kanto_ss_anne_skipper_reminder", "Repeat ticket visits remind the player to find the trainer")
	story.apply_story({"revision": 3, "quests": [{"questId": "ss_anne_rival", "status": "completed"}]})
	check(skipper.select_allowed_dialogue_id() == "kanto_ss_anne_skipper_thanks", "Skipper thanks the player after Gary is defeated")
	check(skipper.select_gate_dialogue_id("kanto_ss_anne_skipper_ticket_required") == "kanto_ss_anne_skipper_ticket_required", "Ticket denial is never replaced with story thanks")
	check(skipper.select_gate_dialogue_id("") == "", "Empty gate references keep their fallback")
	var guest := (load("res://scenes/npcs/dialogue_npc.tscn") as PackedScene).instantiate()
	guest.name = "NarrativeGuest"
	root.add_child(guest)
	guest._apply_npc_metadata({
		"dialogueId": "guest_default",
		"dialogueVariants": [
			{"dialogueId": "guest_relief", "requiredQuestId": "ss_anne_rival", "requiredQuestStatus": "completed"},
			{"dialogueId": "guest_clue", "requiredQuestId": "ss_anne_rival", "requiredQuestStatus": "active"},
		],
	})
	check(guest._resolve_story_dialogue_id() == "guest_relief", "Guests stop giving search clues after the win")
	story.apply_story({"revision": 4, "quests": [{"questId": "ss_anne_rival", "status": "active"}]})
	check(guest._resolve_story_dialogue_id() == "guest_clue", "Guests give clues during the search")
	story.apply_story({"revision": 5, "quests": []})
	check(guest._resolve_story_dialogue_id() == "guest_default", "Guests keep ordinary dialogue outside the quest")
	story.apply_story(original)
	guest.free()
	skipper.free()
	if not failed:
		print("SS_ANNE_NARRATIVE PASS: skipper welcome/reminder/thanks and guest clue/relief transitions")
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
