extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var service := FileAccess.get_file_as_string("res://scripts/services/rock_smash_service.gd")
	var obstacle := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/daily_smashable_rock.gd"
	)
	var field_moves := FileAccess.get_file_as_string("res://scripts/services/field_move_service.gd")
	var mentor := FileAccess.get_file_as_string(
		"res://scripts/world/kanto/towns/pewter_city/karate_master_kenji.gd"
	)
	var pewter := FileAccess.get_file_as_string(
		"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
	)
	var mt_moon_scenes: Array[String] = [
		FileAccess.get_file_as_string("res://scenes/overworld/kanto/caves/mt_moon/1f.tscn"),
		FileAccess.get_file_as_string("res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn"),
		FileAccess.get_file_as_string("res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn"),
	]
	var route_scenes := {
		"kanto_route_3": FileAccess.get_file_as_string(
			"res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
		),
		"kanto_route_4": FileAccess.get_file_as_string(
			"res://scenes/overworld/kanto/routes/kanto_route_4.tscn"
		),
	}

	_check("RockSmashService=" in project, "Rock Smash state is registered as an autoload")
	_check(
		'const ROCK_SMASH_ENDPOINT := "/game/rock-smash"' in service
		and 'const SMASH_ENDPOINT := "/game/rock-smash/smash"' in service,
		"Rock Smash state and rewards use server endpoints"
	)
	_check(
		"sync_player_position_for_world_action" in obstacle
		and "await RockSmashService.smash_rock" in obstacle
		and "await clear_obstacle()" in obstacle
		and "if request_pending:" in obstacle,
		"A rock survives its server state update and only animates after authorization"
	)
	var field_move_obstacle := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/field_move_obstacle.gd"
	)
	_check(
		'call_deferred("queue_free")' in field_move_obstacle,
		"Cleared rocks defer deletion until the interaction unlocks overworld movement"
	)
	_check(
		'"rock-smash":' not in field_moves,
		"Rock Smash remains outside the Gen I Kanto Gym Badge gates"
	)
	_check(
		'const QUEST_ID := "learn_rock_smash"' in mentor
		and 'const OFFER_PREREQUISITE_QUEST_ID := "learn_at_trainer_school"' in mentor
		and "await PlayerGameStateService.refresh_story()" in mentor
		and "claim_npc_item_reward" in mentor,
		"Kenji refreshes the pre-Brock lesson offer and claims its rewards authoritatively"
	)
	_check(
		'portrait_id = "showdown_blackbelt_gen6"' in pewter,
		"Kenji uses the Showdown Black Belt mugshot"
	)
	_check(
		'uid="uid://bgt5h7r4aixq5" path="res://assets/npcs/classes/black_belt_frames.tres" id="31_black_belt"' in pewter
		and 'uid="uid://bgt5h7r4aixq5"' in FileAccess.get_file_as_string(
			"res://assets/npcs/classes/black_belt_frames.tres"
		),
		"Kenji's overworld frames and Pewter City share a valid stable resource UID"
	)

	var rock_ids: Array[String] = [
		"kanto_pewter_city_training_rock_north",
		"kanto_pewter_city_training_rock_east",
		"kanto_pewter_city_training_rock_south",
		"kanto_pewter_city_training_rock_west",
	]
	for rock_id: String in rock_ids:
		_check(pewter.count(rock_id) == 1, "Pewter places fixed rock %s once" % rock_id)
	_check(
		"position = Vector2(592, 176)" in pewter
		and "position = Vector2(528, 144)" in pewter
		and "position = Vector2(656, 144)" in pewter
		and "position = Vector2(656, 208)" in pewter
		and "position = Vector2(528, 208)" in pewter,
		"Kenji and all four lesson rocks retain their reviewed positions"
	)
	var mt_moon_rock_ids: Array[String] = [
		"kanto_mt_moon_1f_rock_west",
		"kanto_mt_moon_1f_rock_central",
		"kanto_mt_moon_1f_rock_east",
		"kanto_mt_moon_b1f_rock_west",
		"kanto_mt_moon_b1f_rock_east",
		"kanto_mt_moon_b1f_rock_south",
		"kanto_mt_moon_b2f_rock_north",
		"kanto_mt_moon_b2f_rock_central",
		"kanto_mt_moon_b2f_rock_south",
	]
	var combined_mt_moon := "\n".join(mt_moon_scenes)
	for rock_id: String in mt_moon_rock_ids:
		_check(combined_mt_moon.count(rock_id) == 1, "Mt. Moon places daily rock %s once" % rock_id)
	_check(
		combined_mt_moon.count("daily_smashable_rock.tscn") == 3
		and combined_mt_moon.count("rock_visual_style = 1") == 9
		and 'rock_id = "kanto_mt_moon_b2f_rock_south"\nrock_variant = 3' in combined_mt_moon
		and "smashable_rock.tscn" not in combined_mt_moon.replace("daily_smashable_rock.tscn", ""),
		"Mt. Moon uses nine daily cave rocks with a distinct master rock variant"
	)
	var expected_route_rocks := {
		"kanto_route_3": {
			"kanto_route_3_rock_west": "position = Vector2(400, 1008)",
			"kanto_route_3_rock_central_west": "position = Vector2(720, 1040)",
			"kanto_route_3_rock_central_east": "position = Vector2(464, 1168)",
			"kanto_route_3_rock_east": "position = Vector2(2704, 752)",
		},
		"kanto_route_4": {
			"kanto_route_4_rock_west": "position = Vector2(176, 1040)",
			"kanto_route_4_rock_central_west": "position = Vector2(944, 592)",
			"kanto_route_4_rock_central_east": "position = Vector2(2256, 560)",
			"kanto_route_4_rock_east": "position = Vector2(2608, 784)",
		},
	}
	for map_id: String in expected_route_rocks:
		var route_source: String = route_scenes[map_id]
		var route_rocks: Dictionary = expected_route_rocks[map_id]
		_check(
			route_source.count("daily_smashable_rock.tscn") == 1
			and route_source.count("rock_visual_style = 2") == 4,
			"%s uses four daily route rocks" % map_id
		)
		for rock_id: String in route_rocks:
			var position_text: String = route_rocks[rock_id]
			_check(
				route_source.count(rock_id) == 1 and position_text in route_source,
				"%s places %s on its reviewed walkable cell" % [map_id, rock_id]
			)
	_check(
		"ROUTE," in obstacle and 'display_name = "Route Rock"' in obstacle,
		"Outdoor rocks use the natural rock sheet with route-specific interaction text"
	)

	var rock_scene := load("res://scenes/world/interactables/daily_smashable_rock.tscn") as PackedScene
	_check(rock_scene != null, "Daily smashable rock scene loads")
	var pewter_scene := load(
		"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
	) as PackedScene
	_check(pewter_scene != null, "Pewter City still loads with Kenji and the four rocks")
	for floor_path: String in [
		"res://scenes/overworld/kanto/caves/mt_moon/1f.tscn",
		"res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn",
		"res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn",
	]:
		_check(load(floor_path) is PackedScene, "%s loads with daily cave rocks" % floor_path)
	for route_path: String in [
		"res://scenes/overworld/kanto/routes/kanto_route_3.tscn",
		"res://scenes/overworld/kanto/routes/kanto_route_4.tscn",
	]:
		_check(load(route_path) is PackedScene, "%s loads with four daily route rocks" % route_path)
	var sheet := load(
		"res://assets/world/field_move_obstacles/object_rock_training_pewter.png"
	) as Texture2D
	_check(
		sheet != null and sheet.get_width() == 128 and sheet.get_height() == 128,
		"Pewter training rocks use the 4-by-4 32px animation sheet"
	)
	var cave_sheet := load(
		"res://assets/world/field_move_obstacles/object_rock.png"
	) as Texture2D
	_check(
		cave_sheet != null and cave_sheet.get_width() == 128 and cave_sheet.get_height() == 128,
		"Mt. Moon rocks retain the natural 4-by-4 cave animation sheet"
	)

	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		_check(parsed is Dictionary, "Rock Smash localization parses for %s" % locale)
		if parsed is Dictionary:
			_check(
				(parsed as Dictionary).has("story.kanto.learn_rock_smash.title")
				and (parsed as Dictionary).has("ui.skills.rock_smash.rocks.reset")
				and (parsed as Dictionary).has("ui.skills.rock_smash.location.mt_moon_b2f")
				and (parsed as Dictionary).has("ui.skills.rock_smash.location.route_3")
				and (parsed as Dictionary).has("ui.skills.rock_smash.location.route_4")
				and (parsed as Dictionary).has("ui.skills.rock_smash.rock.route_central_east")
				and (parsed as Dictionary).has("backend.error.rock_smash_too_far"),
				"Rock Smash quest, cave and route rocks, daily reset, and errors are translated for %s" % locale
			)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
