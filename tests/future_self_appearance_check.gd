extends SceneTree

const Appearance := preload("res://scripts/services/character_appearance_service.gd")
const FutureAppearance := preload("res://scripts/world/story/future_self_appearance.gd")


var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var save := root.get_node("PlayerSave")
	var original: Dictionary = save.to_appearance_state()
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	_check(battle_source.contains('trainer_sprite.show_player(appearance_value as Dictionary, facing_direction)'), "NPC battle presentation uses the layered trainer renderer")
	var progress := root.get_node("TrainerProgressService")
	var original_progress_script: Script = progress.get_script()
	# Compile the service fixture after autoload registration, as in runtime.
	var progress_fixture := GDScript.new()
	progress_fixture.source_code = "extends \"res://scripts/services/trainer_progress_service.gd\"\nvar fixture_completed := false\nfunc get_progress(_trainer_id: String) -> Dictionary:\n\treturn {\"success\": true, \"progress\": {\"state\": \"completed\" if fixture_completed else \"first_encounter\"}}\n"
	_check(progress_fixture.reload() == OK, "progress fixture compiles")
	progress.set_script(progress_fixture)
	for gender: String in ["male", "female"]:
		progress.fixture_completed = false
		save.apply_appearance_state({
			"gender": gender,
			"body": Appearance.resolve_body_model_id("", gender),
			"skin_tone": "#b87860", "eye_color": "#3090d0",
			"hair": Appearance.get_default_part_id("hair", gender),
		})
		var npc: Node = load("res://scenes/npcs/rock_tunnel_future_self_npc.tscn").instantiate()
		root.add_child(npc)
		await process_frame
		var frames: SpriteFrames = npc.npc_sprite_frames
		_check(frames != null, "%s Future Self has composed frames" % gender)
		for direction: String in ["up", "down", "left", "right"]:
			_check(frames.has_animation("idle_" + direction), "%s idle %s exists" % [gender, direction])
			_check(frames.get_frame_count("walk_" + direction) == 4, "%s walk %s has four frames" % [gender, direction])
		var metadata: Dictionary = npc.build_battle_trainer_metadata({})
		_check(not metadata.has("_battle_sprite_id"), "%s battle avoids a catalog trainer fallback" % gender)
		_check(not metadata.has("_battle_sprite_frames"), "%s battle avoids the overworld sprite" % gender)
		_check(npc.display_name == "Mysterious Trainer", "%s name keeps the identity concealed" % gender)
		var trainer: BattleTrainerSprite = load("res://scenes/battle/battle_trainer_sprite.tscn").instantiate()
		root.add_child(trainer)
		trainer.show_player(metadata["_battle_appearance"], Vector2.LEFT)
		_check(trainer.player_battle_art.visible and not trainer.npc_sprite.visible, "%s battle renders layered trainer art" % gender)
		for layer: Dictionary in trainer.player_layer_metadata:
			if layer["category"] in ["top", "bottom", "shoes", "facegear"]:
				_check(str(layer["part_id"]).begins_with("Mysterious_") and not layer["fallback"], "%s %s uses authored Mysterious trainer art" % [gender, layer["category"]])
		trainer.queue_free()
		_check(metadata.get("_battle_mugshot") == npc.mugshot, "%s battle shares dialogue portrait" % gender)
		var mt_moon: Node = load("res://scripts/world/story/mt_moon_ambush_controller.gd").new()
		var reference: Texture2D = mt_moon._future_self_mugshot()
		_check(npc.mugshot != null and npc.mugshot.get_image().get_data() == reference.get_image().get_data(), "%s portrait matches Mt. Moon" % gender)
		var bare_body := Appearance.get_skin_tinted_body_frames(
			save.appearance_body_id, gender, Appearance.BODY_MOVEMENT_DEFAULT, save.appearance_skin_tone
		)
		_check(frames.get_frame_texture("idle_down", 0).get_image().get_data() != Appearance._get_texture_image(bare_body.get_frame_texture("idle_down", 0)).get_data(), "%s outfit is rendered over the body" % gender)
		# A persisted completion must not hide him while his farewell is open.
		npc.visible = true
		npc.trainer_progress_state = npc.STATE_FIRST_ENCOUNTER
		npc.finish_trainer_battle(npc.trainer_id, gender == "male")
		progress.fixture_completed = true
		npc.apply_battle_victory_progress(npc.trainer_id, {"state": "completed"})
		await npc._load_trainer_progress()
		_check(npc.trainer_progress_state == npc.STATE_COMPLETED, "%s completion refresh is loaded during the farewell" % gender)
		await create_timer(0.55).timeout
		_check(npc.visible and npc.modulate.a == 1.0, "%s stays visible throughout the farewell" % gender)
		await npc.finish_story_battle_presentation(npc.trainer_id)
		_check(not npc.visible, "%s disappears after the farewell" % gender)
		_check(not npc.blocks_world_position(npc.get_feet_position()), "%s vanished visitor no longer blocks the entrance" % gender)
		_check(not npc._can_start_manual_interaction() and not npc._can_auto_challenge(), "%s vanished visitor cannot trigger a second encounter" % gender)
		await npc.interact_with_player(null)
		npc._apply_story_visibility(true)
		_check(not npc.visible and not npc.blocks_world_position(npc.get_feet_position()), "%s story refresh cannot restore an invisible blocker" % gender)
		var reloaded: Node = load("res://scenes/npcs/rock_tunnel_future_self_npc.tscn").instantiate()
		root.add_child(reloaded)
		await process_frame
		_check(not reloaded.visible, "%s completed encounter stays absent on map reload" % gender)
		_check(not reloaded.blocks_world_position(reloaded.get_feet_position()), "%s completed encounter leaves its old tile passable on reload" % gender)
		reloaded.queue_free()
		progress.fixture_completed = false
		await npc._load_trainer_progress()
		_check(npc.visible and npc.modulate.a == 1.0, "%s progress reset restores the visitor" % gender)
		mt_moon.free()
		npc.queue_free()
		await process_frame
	progress.fixture_completed = false
	var map: Node = load("res://scenes/overworld/kanto/caves/rock_tunnel/1f.tscn").instantiate()
	root.add_child(map)
	await process_frame
	var state := root.get_node("GameState")
	var original_map: Node = state.current_map
	state.current_map = map
	var visitor := map.get_node("Entities/NPCs/FutureSelf")
	var visitor_count := 0
	for trainer: Node in map.get_node("Entities/NPCs").get_children():
		if str(trainer.get("trainer_id")) == "kanto_rock_tunnel_future_self":
			visitor_count += 1
	_check(visitor_count == 1, "Rock Tunnel has one masked visitor")
	var player := Node2D.new()
	map.add_child(player)
	for exit: Node2D in map.get_node("Exits").get_children():
		player.global_position = exit.get_node("CollisionShape2D").global_position
		_check(visitor._position_for_mandatory_battle(player), "%s has a safe nearby visitor position" % exit.name)
		_check(visitor.global_position.distance_to(player.global_position) <= 96.0, "%s keeps the visitor in view" % exit.name)
		_check(visitor._can_story_npc_move_to(visitor.get_feet_position()), "%s visitor avoids collision and other NPCs" % exit.name)
	state.current_map = original_map
	map.queue_free()
	await process_frame
	progress.set_script(original_progress_script)
	save.apply_appearance_state(original)
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
