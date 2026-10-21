extends SceneTree

const EXPECTED_POKEMON := {
	"MountainPokemon/Geodude": ["kanto_route_5_mountain_geodude_1", "geodude", Vector2(1104, 48)],
	"MountainPokemon/Onix": ["kanto_route_5_mountain_onix_1", "onix", Vector2(1136, 272)],
	"DaycareGardenPokemon/Oddish": ["kanto_route_5_daycare_garden_oddish_1", "oddish", Vector2(816, 1200)],
	"DaycareGardenPokemon/Bellsprout": ["kanto_route_5_daycare_garden_bellsprout_1", "bellsprout", Vector2(720, 944)],
	"DaycareGardenPokemon/DaycarePond/Magikarp": ["kanto_route_5_daycare_pond_magikarp_1", "magikarp", Vector2(832, 976)],
	"RoutePokemon/Pidgey": ["kanto_route_5_pidgey_1", "pidgey", Vector2(560, 432)],
	"RoutePokemon/Meowth": ["kanto_route_5_meowth_1", "meowth", Vector2(752, 720)],
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route := (load("res://scenes/overworld/kanto/routes/kanto_route_5.tscn") as PackedScene).instantiate()
	root.add_child(route)
	await process_frame
	var collision := route.get_node("Tiles/Collision") as TileMapLayer
	var grass := route.get_node("Tiles/TallGrass") as TileMapLayer
	for relative_path: String in EXPECTED_POKEMON:
		var expected: Array = EXPECTED_POKEMON[relative_path]
		var pokemon := route.get_node_or_null("Entities/Pokemon/" + relative_path) as Node2D
		_check(pokemon != null, "%s exists" % relative_path)
		if pokemon == null:
			continue
		_check(str(pokemon.get("overworld_pokemon_id")) == expected[0], "%s has its metadata ID" % relative_path)
		_check(str(pokemon.get("species_id")) == expected[1], "%s has its species" % relative_path)
		_check(pokemon.position == expected[2], "%s is at the intended placement" % relative_path)
		var cell := collision.local_to_map(pokemon.position)
		_check(grass.get_cell_source_id(cell) < 0, "%s stands outside encounter grass" % relative_path)
		if relative_path.ends_with("/Geodude"):
			_check(str(pokemon.get("movement_behavior")) == "idle", "cliffside Geodude stays clear of blocked patrol tiles")
			continue
		if relative_path.ends_with("/Magikarp"):
			_check(str(pokemon.get("movement_behavior")) == "idle", "daycare pond Magikarp remains in the water")
			continue
	_check(route.get_node_or_null("Entities/NPCs/HikerMilo") != null, "Hiker Milo is present")
	_check(route.get_node_or_null("Entities/NPCs/CamperLena") != null, "Camper Lena is present")
	_check(str(route.get_node("Entities/NPCs/HikerMilo").get("npc_id")) == "kanto_route_5_hiker_milo", "Hiker Milo has a dialogue metadata ID")
	_check(str(route.get_node("Entities/NPCs/CamperLena").get("npc_id")) == "kanto_route_5_camper_lena", "Camper Lena has a dialogue metadata ID")
	var dadinho := route.get_node_or_null("Entities/NPCs/Dadinho") as Node2D
	_check(dadinho != null, "Dadinho waits outside the daycare")
	if dadinho != null:
		var cell := collision.local_to_map(dadinho.position)
		_check(grass.get_cell_source_id(cell) < 0, "Dadinho stands outside encounter grass")
		_check(dadinho.position.distance_to(route.get_node("Spawns/FromDaycare").position) <= 96, "Dadinho is beside the daycare entrance")
		_check(dadinho.get("mugshot") != null and dadinho.get("npc_sprite_frames") != null, "Dadinho has his portrait and overworld sprite")
		var hook := dadinho.get_node("StoryHook")
		_check(str(hook.get("interaction_id")) == "kanto_route_5_dadinho_potential", "Dadinho exposes his server-authorized lesson")
		_check(str(hook.get("entity_id")) == str(dadinho.get("npc_id")), "the story hook and NPC use the same identity")
		_check(bool(dadinho.get("preload_quest_markers")), "Dadinho loads his quest marker before interaction")
		dadinho.call("_apply_npc_metadata", {
			"questMarkers": [{"questId": "discover_pokemon_potential", "stepId": "meet_dadinho", "statuses": ["active"]}],
		})
		var story := root.get_node("StoryService")
		story.call("reset_story")
		_check(not dadinho.visible, "Dadinho is absent before Misty is defeated")
		story.call("apply_story", {"revision": 1, "quests": [
			{"questId": "challenge_cerulean_gym", "status": "completed"},
			{"questId": "discover_pokemon_potential", "questType": "main", "status": "active", "steps": [{"stepId": "meet_dadinho", "status": "active"}]},
		]})
		_check(dadinho.visible, "Dadinho appears after the Cascade Badge")
		var marker := dadinho.get_node_or_null("QuestMarker") as Control
		_check(marker != null and marker.visible, "Dadinho shows the quest icon while his lesson is active")
		var icon := dadinho.get_node_or_null("QuestMarker/Icon") as TextureRect
		_check(icon != null and icon.texture == load("res://assets/ui/main_quest_marker.svg"), "Dadinho uses the main quest icon")
		story.call("apply_story", {"revision": 2, "quests": [
			{"questId": "challenge_cerulean_gym", "status": "completed"},
			{"questId": "discover_pokemon_potential", "questType": "main", "status": "completed", "steps": [{"stepId": "meet_dadinho", "status": "completed"}]},
			{"questId": "board_ss_anne", "status": "active"},
		]})
		_check(dadinho.visible, "Dadinho remains until the current map visit ends after his lesson")
		_check(marker != null and not marker.visible, "Dadinho hides the quest icon after completing his lesson")
		var refreshed_route := (load("res://scenes/overworld/kanto/routes/kanto_route_5.tscn") as PackedScene).instantiate()
		root.add_child(refreshed_route)
		await process_frame
		var refreshed_dadinho := refreshed_route.get_node("Entities/NPCs/Dadinho") as Node2D
		_check(not refreshed_dadinho.visible, "Dadinho is absent after reloading Route 5 with his lesson completed")
		var refreshed_area := refreshed_dadinho.get_node("InteractionArea") as Area2D
		_check(not refreshed_area.monitoring and not refreshed_area.monitorable, "departed Dadinho no longer accepts interactions")
		_check(not bool(refreshed_dadinho.call("blocks_world_position", refreshed_dadinho.global_position)), "departed Dadinho no longer blocks his tile")
		refreshed_route.queue_free()
		await process_frame
		story.call("reset_story")
	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
