extends SceneTree

const POPULATION := {
	"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn": {
		"Entities/NPCs/GaryOak": "kanto_route_24_gary_oak",
		"Entities/NPCs/GymAttendant": "kanto_cerulean_city_gym_attendant",
		"Entities/NPCs/CeruleanCaveAgent": "kanto_cerulean_city_cave_agent",
		"Entities/NPCs/OfficerJenny": "kanto_cerulean_city_patrol_officer",
		"Entities/NPCs/WaterwayVisitorMaya": "kanto_cerulean_city_waterway_visitor_maya",
		"Entities/NPCs/BikeEnthusiastTheo": "kanto_cerulean_city_bike_enthusiast_theo",
		"Entities/NPCs/AceTrainerLila": "kanto_cerulean_city_ace_trainer_lila",
		"Entities/NPCs/AceTrainerBram": "kanto_cerulean_city_ace_trainer_bram",
		"Entities/NPCs/VeteranGarrick": "kanto_cerulean_city_veteran_garrick",
		"Entities/Pokemon/Growlithe": "kanto_cerulean_city_growlithe_1",
		"Entities/Pokemon/Dragonite": "kanto_cerulean_city_dragonite_1",
		"Entities/Pokemon/WaterPokemon/Gyarados": "kanto_cerulean_city_gyarados_1",
		"Entities/Pokemon/WaterPokemon/Goldeen": "kanto_cerulean_city_goldeen_1",
		"Entities/Pokemon/WaterPokemon/Poliwag": "kanto_cerulean_city_poliwag_1",
		"Entities/Pokemon/MountainPokemon/Geodude": "kanto_cerulean_city_mountain_geodude_1",
		"Entities/Pokemon/MountainPokemon/Nosepass": "kanto_cerulean_city_mountain_nosepass_1",
		"Entities/Pokemon/MountainPokemon/Roggenrola": "kanto_cerulean_city_mountain_roggenrola_1",
		"Entities/Pokemon/MountainPokemon/Larvitar": "kanto_cerulean_city_mountain_larvitar_1",
		"Entities/Pokemon/MountainPokemon/Rockruff": "kanto_cerulean_city_mountain_rockruff_1",
		"Entities/Pokemon/BattleDisplay/Onix": "kanto_cerulean_city_practice_onix_1",
		"Entities/Pokemon/BattleDisplay/Pikachu": "kanto_cerulean_city_practice_pikachu_1",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/house1.tscn": {
		"Entities/NPCs/OnixTrainer": "kanto_cerulean_city_house_1_onix_trainer",
		"Entities/Pokemon/Onix": "kanto_cerulean_city_house_1_onix_1",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/house2.tscn": {
		"Entities/NPCs/Resident": "kanto_cerulean_city_house_2_resident",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/house3.tscn": {
		"Entities/NPCs/ResidentElise": "kanto_cerulean_city_house_3_resident_elise",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn": {
		"Entities/NPCs/BikeShopOwner": "kanto_cerulean_city_bike_store_owner",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn": {
		"Entities/NPCs/SwimmerMarina": "kanto_cerulean_city_pokemon_center_swimmer_marina",
		"Entities/NPCs/CamperFinn": "kanto_cerulean_city_pokemon_center_camper_finn",
		"Entities/Pokemon/Psyduck": "kanto_cerulean_city_pokemon_center_psyduck_1",
		"Entities/Pokemon/Squirtle": "kanto_cerulean_city_pokemon_center_squirtle_1",
	},
	"res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn": {
		"Entities/NPCs/GymGuide": "kanto_cerulean_city_gym_guide",
		"Entities/NPCs/GymLeaderMisty": "kanto_alpha_gym_misty",
		"Entities/Pokemon/Staryu": "kanto_cerulean_city_gym_staryu_1",
		"Entities/Pokemon/Horsea": "kanto_cerulean_city_gym_horsea_1",
		"Entities/Pokemon/Shellder": "kanto_cerulean_city_gym_shellder_1",
		"Entities/Pokemon/Goldeen": "kanto_cerulean_city_gym_goldeen_1",
	},
}

const COLLISION_PATHS := {
	"cerulean_city.tscn": "Tiles/Collision",
	"house1.tscn": "BlueHouseTemplate/Collision",
	"house2.tscn": "BlueHouseTemplate/Collision",
	"house3.tscn": "BlueHouseTemplate/Collision",
	"bike_store.tscn": "Tiles/Collision",
	"pokemon_center.tscn": "Collision",
	"cerulean_gym.tscn": "Tiles/Collision",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for scene_path: String in POPULATION:
		_check_scene(scene_path, POPULATION[scene_path])
	quit(1 if failed else 0)


func _check_scene(scene_path: String, expected: Dictionary) -> void:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return
	var map := packed.instantiate()
	root.add_child(map)
	var collision_path := str(COLLISION_PATHS[scene_path.get_file()])
	var collision := map.get_node_or_null(collision_path) as TileMapLayer
	_check(collision != null, "%s exposes collision data" % scene_path.get_file())
	for node_path_value: Variant in expected:
		var node_path := str(node_path_value)
		var entity := map.get_node_or_null(node_path) as Node2D
		_check(entity != null, "%s places %s" % [scene_path.get_file(), node_path.get_file()])
		if entity == null:
			continue
		var expected_id := str(expected[node_path_value])
		var actual_id := str(entity.get("overworld_pokemon_id")) if "/Pokemon/" in node_path else str(entity.get("npc_id"))
		_check(actual_id == expected_id, "%s uses its canonical content ID" % node_path.get_file())
		if collision != null:
			var cell := collision.local_to_map(collision.to_local(entity.global_position))
			if not "/MountainPokemon/" in node_path:
				_check(collision.get_cell_source_id(cell) == -1, "%s stands on a walkable tile" % node_path.get_file())
	var misty := map.get_node_or_null("Entities/NPCs/GymLeaderMisty")
	if misty != null:
		_check(str(misty.get("trainer_id")) == "kanto_alpha_gym_misty", "Misty uses the registered Cerulean alpha battle")
		_check(misty.get("npc_profile") != null, "Misty has her Cascade Badge profile")
	var gym_attendant := map.get_node_or_null("Entities/NPCs/GymAttendant")
	if gym_attendant != null:
		_check(gym_attendant.position == Vector2(1584, 1360), "Gym attendant blocks the Gym doorway")
		_check(
			str(gym_attendant.get("portrait_id")) == "showdown_trialguide",
			"Gym attendant uses the matching Showdown guide portrait"
		)
		var story_hook := gym_attendant.get_node_or_null("GymClosedStoryHook")
		_check(story_hook != null, "Gym attendant owns the Gym-closed story hook")
		if story_hook != null:
			_check(
				str(story_hook.get("interaction_id")) == "kanto_cerulean_gym_closed"
					and str(story_hook.get("entity_id")) == "kanto_cerulean_city_gym_attendant",
				"Gym attendant reports the completed conversation to story progress"
			)
		_check(
			str(gym_attendant.get("visibility_hidden_quest_id")) == "help_bill"
				and str(gym_attendant.get("visibility_hidden_quest_step_id")).is_empty()
				and str(gym_attendant.get("visibility_hidden_quest_status")) == "completed",
			"Gym attendant leaves only after Bill is rescued"
		)
		_check(bool(gym_attendant.get("preload_quest_markers")), "Gym attendant preloads its story marker")
	var cave_agent := map.get_node_or_null("Entities/NPCs/CeruleanCaveAgent")
	if cave_agent != null:
		_check(cave_agent.position == Vector2(528, 208), "Investigation agent blocks the Cerulean Cave entrance")
		_check(
			str(cave_agent.get("guard_role")) == "transition_guard"
				and str(cave_agent.get("guarded_transition_id")) == "kanto_cerulean_city__to_cerulean_cave",
			"Investigation agent guards the Cerulean Cave transition"
		)
		_check(
			str(cave_agent.get("required_quest_id")) == "cerulean_cave_clearance"
				and str(cave_agent.get("required_quest_status")) == "completed",
			"Investigation agent leaves only after the future cave-clearance sidequest"
		)
		_check(not bool(cave_agent.get("requires_party_pokemon")), "Cave access is story-gated instead of party-gated")
		_check(
			bool(cave_agent.call("guards_world_position", Vector2(528, 176))),
			"Investigation agent blocks the cave transition while clearance is missing"
		)
	var veteran := map.get_node_or_null("Entities/NPCs/VeteranGarrick") as Node2D
	var dragonite := map.get_node_or_null("Entities/Pokemon/Dragonite") as Node2D
	if veteran != null and dragonite != null:
		_check(veteran.position == Vector2(1648, 1680), "Veteran Garrick fills Cerulean's southeast corner")
		_check(
			str(veteran.get("npc_definition_id")) == "trainer_class_veteran",
			"Veteran Garrick uses the veteran trainer presentation"
		)
		_check(str(dragonite.get("species_id")) == "dragonite", "Garrick's partner is Dragonite")
		_check(int(dragonite.get("level")) == 62, "Dragonite reflects Garrick's veteran status")
		_check(dragonite.position.distance_to(veteran.position) == 64.0, "Dragonite stays beside Garrick")
		_check(dragonite.get("npc_sprite_frames") != null, "Dragonite resolves its overworld follower sprite")
	if scene_path.ends_with("/pokemon_center.tscn"):
		_check(
			map.get_node_or_null("Entities/NPCs/PartnerMoveTutor") == null,
			"Cerulean Pokemon Center no longer places the partner Move Tutor"
		)
		var marina := map.get_node_or_null("Entities/NPCs/SwimmerMarina") as Node2D
		var finn := map.get_node_or_null("Entities/NPCs/CamperFinn") as Node2D
		var psyduck := map.get_node_or_null("Entities/Pokemon/Psyduck") as Node2D
		var squirtle := map.get_node_or_null("Entities/Pokemon/Squirtle") as Node2D
		if marina != null and psyduck != null:
			_check(str(marina.get("npc_definition_id")) == "trainer_class_swimmer_f", "Marina uses the swimmer presentation")
			_check(str(psyduck.get("species_id")) == "psyduck", "Marina's partner is Psyduck")
			_check(psyduck.position.distance_to(marina.position) == 64.0, "Psyduck stays beside Marina")
			_check(psyduck.get("npc_sprite_frames") != null, "Psyduck resolves its overworld follower sprite")
		if finn != null and squirtle != null:
			_check(str(finn.get("npc_definition_id")) == "trainer_class_camper", "Finn uses the camper presentation")
			_check(str(squirtle.get("species_id")) == "squirtle", "Finn's partner is Squirtle")
			_check(squirtle.position.distance_to(finn.position) == 64.0, "Squirtle stays beside Finn")
			_check(squirtle.get("npc_sprite_frames") != null, "Squirtle resolves its overworld follower sprite")
	map.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
