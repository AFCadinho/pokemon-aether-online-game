extends SceneTree

const ITEM_GIFT_NPC_SCENE_PATH := "res://scenes/npcs/item_gift_npc.tscn"
const CHAIRMAN_SCRIPT_PATH := (
	"res://scripts/world/kanto/towns/pokemon_fan_club_chairman.gd"
)
const DIALOGUE_BOX_SCENE_PATH := "res://scripts/ui/dialogue_box.tscn"
const BIKE_STORE_SCENE_PATH := (
	"res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn"
)

const FAN_CLUB_SCENE_PATH := (
	"res://scenes/overworld/kanto/towns/vermilion_city/pokemon_fan_club.tscn"
)

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var test_scene := Node2D.new()
	test_scene.name = "PokemonFanClubChairmanTest"
	root.add_child(test_scene)
	current_scene = test_scene

	var dialogue_layer := (load(DIALOGUE_BOX_SCENE_PATH) as PackedScene).instantiate()
	test_scene.add_child(dialogue_layer)
	var dialogue_box := dialogue_layer.get_node("Box")

	var chairman := (load(ITEM_GIFT_NPC_SCENE_PATH) as PackedScene).instantiate()
	chairman.set_script(load(CHAIRMAN_SCRIPT_PATH))
	chairman.set("npc_id", "")
	chairman.set("display_name", "Pokemon Fan Club Chairman")
	test_scene.add_child(chairman)
	await process_frame

	chairman.call("_apply_npc_metadata", {
		"offeredQuestId": "pokemon_fan_club_chairman",
		"rewardId": "kanto_pokemon_fan_club_bike_voucher",
		"rewardItemId": "bike-voucher",
		"introDialogueId": "chairman_intro",
		"notNowDialogueId": "chairman_not_now",
		"storyDialogueId": "chairman_story",
	})
	_expect(
		str(chairman.get("reward_id")) == "kanto_pokemon_fan_club_bike_voucher",
		"Chairman loads the authoritative Bike Voucher reward"
	)
	_expect(
		str(chairman.get("story_dialogue_id")) == "chairman_story",
		"Chairman loads his interactive story dialogue"
	)
	chairman.set("intro_dialogue_id", "")
	chairman.set("not_now_dialogue_id", "")
	chairman.set("story_dialogue_id", "")

	root.get_node("StoryService").call("apply_story", _chairman_story("available"))
	chairman.call("interact_with_player", null)
	await process_frame
	_expect(
		bool(dialogue_box.get("quest_offer_open")),
		"Chairman opens the side-quest summary before any story dialogue"
	)
	_expect(
		str((dialogue_box.get("offered_quest") as Dictionary).get("questId", ""))
		== "pokemon_fan_club_chairman",
		"Chairman offers the location-independent quest id"
	)
	dialogue_box.call("_finish_quest_offer", false)
	await process_frame
	_expect(
		str(root.get_node("StoryService").call(
			"get_quest",
			"pokemon_fan_club_chairman"
		).get("status", "")) == "available",
		"Declining leaves the Chairman's quest available"
	)

	root.get_node("StoryService").call("apply_story", _chairman_story("active"))
	chairman.call("interact_with_player", null)
	await process_frame
	_expect(bool(dialogue_box.get("is_open")), "Active quest starts with the Chairman's introduction")
	dialogue_box.call("hide_dialogue")
	var choice_root: Node = null
	for _frame: int in range(30):
		choice_root = chairman.find_child("MentorTopicMenu", true, false)
		if choice_root != null:
			break
		await process_frame
	_expect(choice_root != null, "Chairman opens the follow-up dialogue choice")
	if choice_root != null:
		var buttons := choice_root.find_children("*", "Button", true, false)
		_expect(buttons.size() == 2, "Dialogue choice shows only Not now and Tell me more")
		if buttons.size() == 2:
			(buttons[0] as Button).pressed.emit()
			await process_frame
			_expect(
				bool(dialogue_box.get("is_open")),
				"Not now closes the choice without abandoning the active quest"
			)
			dialogue_box.call("hide_dialogue")

	var bike_store := (load(BIKE_STORE_SCENE_PATH) as PackedScene).instantiate()
	_expect(not bike_store.has_node("Entities/NPCs/PokemonFanClubChairman"), "Chairman no longer appears in the Cerulean Bike Shop")
	_expect(bike_store.has_node("Entities/NPCs/BikeShopOwner"), "Cerulean merchant still redeems vouchers")
	bike_store.free()
	var club := (load(FAN_CLUB_SCENE_PATH) as PackedScene).instantiate()
	var placed_chairman := club.get_node("Entities/NPCs/PokemonFanClubChairman")
	_expect(placed_chairman.get_script().resource_path == CHAIRMAN_SCRIPT_PATH, "Fan Club Chairman retains interactive quest and reward behavior")
	_expect(placed_chairman.npc_id == "kanto_pokemon_fan_club_chairman" and placed_chairman.preload_quest_markers, "Stable Chairman identity and quest marker")
	_expect(club.map_id == "kanto_vermilion_city_pokemon_fan_club", "Fan Club map identity")
	_expect(club.get_node("Entities/NPCs").get_child_count() == 4 and club.get_node("Entities/Pokemon").get_child_count() == 3, "Three visitors and three Pokemon accompany the Chairman")
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_expect(validator.validate(club.get_node("Visual"), "res://generated/tiled_visuals/vermilion_fan_club/vermilion_fan_club.visual.tileset.tres").is_empty(), "Fan Club visual uses valid portable compact atlases")
	var collision := club.get_node("Tiles/Collision") as TileMapLayer
	var occupied: Dictionary = {}
	for container in ["Entities/NPCs", "Entities/Pokemon"]:
		for actor: Node2D in club.get_node(container).get_children():
			var cell := collision.local_to_map(actor.position)
			_expect(collision.get_cell_source_id(cell) == -1, str(actor.name) + " stands on free floor")
			_expect(not occupied.has(cell), str(actor.name) + " has a separate tile")
			occupied[cell] = true
			if container == "Entities/Pokemon":
				_expect(not str(actor.get("overworld_pokemon_id")).is_empty() and not str(actor.get("species_id")).is_empty(), "Pokemon has its metadata and species")
	# Verify each actor can be reached from the entrance without passing through furniture or another actor.
	var reached: Dictionary = {}
	var pending: Array[Vector2i] = [Vector2i(11,22)]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if reached.has(cell) or occupied.has(cell) or collision.get_cell_source_id(cell) != -1 or cell.x < 0 or cell.y < 0 or cell.x >= 24 or cell.y >= 28:
			continue
		reached[cell] = true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(cell + direction)
	for cell: Vector2i in occupied:
		var reachable := false
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			reachable = reachable or reached.has(cell + direction)
		_expect(reachable, "Actor at " + str(cell) + " is accessible for interaction")
	var city := (load("res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn") as PackedScene).instantiate()
	var entrance := city.get_node("Exits/ToFanClub")
	var exit := club.get_node("Exits/ToVermilionCity")
	_expect(entrance.target_scene_path == FAN_CLUB_SCENE_PATH and entrance.target_spawn_name == "FromVermilionCity", "City door enters the Fan Club")
	_expect(exit.target_spawn_name == "FromFanClub" and exit.target_scene_path == city.scene_file_path, "Fan Club returns to the correct building")
	_expect(not exit.contains_world_position(club.get_node("Spawns/FromVermilionCity").position), "Arrival avoids immediate exit")
	_expect(not entrance.contains_world_position(city.get_node("Spawns/FromFanClub").position), "Return avoids immediate re-entry")
	for cell in [Vector2i(11,27), Vector2i(11,28), Vector2i(11,29)]:
		_expect(city.get_node("Tiles/Collision").get_cell_source_id(cell) == -1, "Fan Club doorway and return path are walkable")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_expect(catalog.areas.has(club.map_id), "Fan Club is registered in world catalog")
	_expect(catalog.transitions.has("kanto_vermilion_city__to_pokemon_fan_club") and catalog.transitions.has("kanto_vermilion_city_pokemon_fan_club__to_outside"), "Both Fan Club transitions registered")
	club.free()
	city.free()

	test_scene.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _chairman_story(status: String) -> Dictionary:
	var step_status := "active" if status == "active" else "inactive"
	return {
		"revision": 12,
		"quests": [{
			"questId": "pokemon_fan_club_chairman",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "side",
			"status": status,
			"titleKey": "story.kanto.pokemon_fan_club_chairman.title",
			"summaryKey": "story.kanto.pokemon_fan_club_chairman.summary",
			"rewardPreviews": [{
				"type": "item",
				"itemId": "bike-voucher",
				"quantity": 1,
			}],
			"steps": [{
				"stepId": "listen_to_chairman",
				"status": step_status,
				"objectiveKey": (
					"story.kanto.pokemon_fan_club_chairman.listen_to_chairman"
				),
			}],
		}],
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
