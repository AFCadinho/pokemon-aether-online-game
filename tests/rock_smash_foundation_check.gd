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

	_check("RockSmashService=" in project, "Rock Smash state is registered as an autoload")
	_check(
		'const ROCK_SMASH_ENDPOINT := "/game/rock-smash"' in service
		and 'const SMASH_ENDPOINT := "/game/rock-smash/smash"' in service,
		"Rock Smash state and rewards use server endpoints"
	)
	_check(
		"sync_player_position_for_world_action" in obstacle
		and "await RockSmashService.smash_rock" in obstacle
		and "await clear_obstacle()" in obstacle,
		"A rock only breaks after its position and server reward are authorized"
	)
	var field_move_obstacle := FileAccess.get_file_as_string(
		"res://scripts/world/interactables/field_move_obstacle.gd"
	)
	_check(
		'call_deferred("queue_free")' in field_move_obstacle,
		"Cleared rocks defer deletion until the interaction unlocks overworld movement"
	)
	_check(
		"badge" not in field_moves.to_lower(),
		"Generic field-move use does not require a Gym Badge"
	)
	_check(
		'const QUEST_ID := "learn_rock_smash"' in mentor
		and 'const OFFER_PREREQUISITE_QUEST_ID := "learn_at_trainer_school"' in mentor
		and "claim_npc_item_reward" in mentor,
		"Kenji offers the pre-Brock lesson and claims its rewards authoritatively"
	)
	_check(
		'portrait_id = "showdown_blackbelt_gen6"' in pewter,
		"Kenji uses the Showdown Black Belt mugshot"
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

	var rock_scene := load("res://scenes/world/interactables/daily_smashable_rock.tscn") as PackedScene
	_check(rock_scene != null, "Daily smashable rock scene loads")
	var pewter_scene := load(
		"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
	) as PackedScene
	_check(pewter_scene != null, "Pewter City still loads with Kenji and the four rocks")
	var sheet := load(
		"res://assets/world/field_move_obstacles/object_rock_training_pewter.png"
	) as Texture2D
	_check(
		sheet != null and sheet.get_width() == 128 and sheet.get_height() == 128,
		"Pewter training rocks use the 4-by-4 32px animation sheet"
	)

	for locale: String in ["en", "nl", "pt_BR"]:
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		_check(parsed is Dictionary, "Rock Smash localization parses for %s" % locale)
		if parsed is Dictionary:
			_check(
				(parsed as Dictionary).has("story.kanto.learn_rock_smash.title")
				and (parsed as Dictionary).has("ui.skills.rock_smash.rocks.reset")
				and (parsed as Dictionary).has("backend.error.rock_smash_too_far"),
				"Rock Smash quest, daily reset, and backend errors are translated for %s" % locale
			)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
