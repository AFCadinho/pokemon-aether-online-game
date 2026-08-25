extends SceneTree

const MOVE_CATALOG := preload("res://scripts/world/story/mt_moon_cinematic_move_catalog.gd")
const SUMMON_SCRIPT := preload("res://scripts/battle/animations/pokeball_summon_animation_player.gd")
const ATTACK_SCRIPT := preload("res://scripts/world/story/mt_moon_cinematic_attack.gd")

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var psychic_move: Dictionary = MOVE_CATALOG.for_types(["Psychic"])
	_expect(psychic_move.get("id") == "future-sight", "Psychic future starter uses Future Sight")
	_expect(psychic_move.get("type") == "psychic", "Psychic cinematic keeps its STAB type")

	var water_move: Dictionary = MOVE_CATALOG.for_types(["Water"])
	_expect(water_move.get("id") == "hydro-cannon", "Water future starter uses Hydro Cannon")
	_expect(water_move.get("type") == "water", "Water cinematic keeps its STAB type")

	var fallback_move: Dictionary = MOVE_CATALOG.for_types([])
	_expect(fallback_move.get("id") == "hyper-beam", "Missing type has a safe cinematic fallback")
	for type_id: String in MOVE_CATALOG.MOVES:
		var move_data := MOVE_CATALOG.MOVES[type_id] as Dictionary
		var sound_path := str(move_data.get("sound", ""))
		_expect(not sound_path.is_empty() and ResourceLoader.exists(sound_path), "%s cinematic move has an existing sound" % type_id)

	var summon_player := SUMMON_SCRIPT.new()
	_expect(summon_player.has_method("play_overworld_summon"), "Battle Poké Ball animation supports overworld summons")
	_expect(summon_player.sprite_render_scale == Vector2(4.0, 4.0), "Battle summon scale remains unchanged by default")
	var release_state := {"released": false}
	summon_player.pokemon_released.connect(func() -> void: release_state["released"] = true)
	get_root().add_child(summon_player)
	await summon_player.play_overworld_summon("poke-ball", Vector2(80, 180), Vector2(220, 120))
	_expect(bool(release_state.released), "Overworld Poké Ball animation reaches its release frame")
	summon_player.queue_free()
	var attack_effect := ATTACK_SCRIPT.new()
	get_root().add_child(attack_effect)
	await attack_effect.play(Vector2(40, 120), [Vector2(180, 80), Vector2(220, 140)], "psychic")
	await process_frame
	_expect(not is_instance_valid(attack_effect), "Cinematic attack effect completes and cleans itself up")

	var controller_source := _read_text("res://scripts/world/story/mt_moon_ambush_controller.gd")
	_expect("_summon_rocket_pokemon" in controller_source, "Ambush summons Team Rocket's Pokémon")
	_expect("await _attack_and_faint_follower()" in controller_source, "Team Rocket attacks the player's visible follower before the rescue")
	_expect("func set_story_player(player: Node2D)" in controller_source and "_resolve_player_follower(player)" in controller_source, "the ambush targets the player that actually entered the trigger")
	_expect("story.mt_moon.cutscene.follower_fainted" in controller_source, "the player begs their fainted follower to get up")
	_expect(
		'await _show_rocket_line(_text("story.mt_moon.cutscene.capture_threat"))' in controller_source,
		"Team Rocket threatens to take the player's Pokemon after the follower faints"
	)
	_expect(
		controller_source.find('story.mt_moon.cutscene.follower_fainted') < controller_source.find('story.mt_moon.cutscene.capture_threat'),
		"the player pleads with their follower before Team Rocket responds"
	)
	_expect("_show_rocket_attack_command(attacker_name)" in controller_source and "TrainerPortraitCatalog.get_texture(ROCKET_PORTRAIT_ID)" in controller_source, "the Rocket Grunt visibly orders the follower attack in dialogue")
	_expect("attack.top_level = true" in controller_source and '"poison"' in controller_source, "Zubat's bright attack renders in world coordinates")
	_expect('tween_property(attacker, "global_position", lunge_target' in controller_source, "Zubat visibly lunges at the follower")
	_expect("Color(1.0, 0.25, 0.35, 1.0)" in controller_source, "the follower visibly flashes when struck")
	_expect("_restore_follower()" in controller_source, "the cosmetic follower faint is safely restored after the cutscene")
	_expect("_open_rift" in controller_source, "Ambush opens the future-self rift")
	_expect("play_overworld_summon" in controller_source, "Ambush uses the shared Poké Ball animation")
	_expect("add_child(pokemon)\n\t# BaseNPC initialization can restore visibility" in controller_source, "cutscene Pokemon stay hidden after their NPC initialization")
	_expect("func _play_ball_summon" in controller_source and "pokemon.visible = false\n\t\tpokemon.modulate.a = 1.0" in controller_source, "each summon hides its Pokemon until the release signal")
	_expect("DIALOGUE_STAGE_FUTURE_VOICE" in controller_source, "the future-self voice is heard before the reveal")
	_expect("DIALOGUE_STAGE_ROCKET_REVEAL_CHALLENGE" in controller_source, "Team Rocket challenges the unseen voice before the reveal")
	_expect("current_stage == DIALOGUE_STAGE_ROCKET_REVEAL_CHALLENGE:\n\t\tawait _reveal_rescuer()" in controller_source, "the rescuer appears only after Team Rocket demands it")
	_expect("DIALOGUE_STAGE_ROCKET_BATTLE_CHALLENGE" in controller_source, "Team Rocket challenges the revealed rescuer before the attack")
	_expect("current_stage == DIALOGUE_STAGE_ROCKET_BATTLE_CHALLENGE:\n\t\tif not await _play_counterattack():" in controller_source, "Bring it on directly triggers the counterattack")
	_expect("DIALOGUE_STAGE_ROCKET_FLEE" in controller_source, "Rocket flight dialogue follows the counterattack")
	_expect("DIALOGUE_STAGE_PLAYER_QUESTION" in controller_source, "the player answers during the rescue dialogue")
	_expect("DIALOGUE_STAGE_PLAYER_DEFENSE := 7" in controller_source, "the player visibly responds between the rescuer's warning and lesson")
	_expect("DIALOGUE_STAGE_PLAYER_SURPRISE" in controller_source, "the player reacts after the rescuer disappears")
	_expect(
		'const PLAYER_DIALOGUE_STAGES: Array[int] = [\n\tDIALOGUE_STAGE_PLAYER_QUESTION,\n\tDIALOGUE_STAGE_PLAYER_DEFENSE,\n\tDIALOGUE_STAGE_PLAYER_PROMISE,\n\tDIALOGUE_STAGE_PLAYER_SURPRISE,\n]'
		in controller_source,
		"every player line shares one dialogue portrait policy"
	)
	_expect(
		"current_stage in ROCKET_DIALOGUE_STAGES or current_stage in PLAYER_DIALOGUE_STAGES" in controller_source,
		"every player dialogue stage enables its mugshot"
	)
	_expect("await _play_counterattack()" in controller_source and controller_source.find("await _play_counterattack()") < controller_source.find("await _flee_rockets()"), "the rescuer attacks before Team Rocket flees")
	_expect("_play_counterattack_sound(move)\n\tawait attack.play" in controller_source, "the future partner's move sound starts with its attack animation")
	_expect("audio_player.bus = SettingsManager.SFX_BUS" in controller_source, "the counterattack sound respects the SFX volume setting")
	_expect("await _wait_for_interact_release()" in controller_source, "dialogue input cannot skip the next story action")
	_expect('ROCKET_PORTRAIT_ID := "showdown_rainbowrocketgrunt"' in controller_source, "Team Rocket dialogue uses its Showdown portrait")
	_expect("TrainerHeadPortrait.new()" in controller_source and "PlayerSave.to_appearance_state()" in controller_source, "player dialogue renders the current overworld appearance")
	_expect("if stage in PLAYER_DIALOGUE_STAGES:\n\t\treturn await _player_mugshot()" in controller_source, "every player dialogue stage loads the current player mugshot")
	_expect("_player_portrait_renderer.render_scale = 1.25" in controller_source, "player dialogue shows a less tightly zoomed portrait")
	_expect("_player_portrait_renderer.head_only = false" in controller_source, "player dialogue includes the upper body and current clothing")
	_expect("dialogue_box.call(\"start_dialogue\", lines, resolved_speaker_name, portrait, show_portrait)" in controller_source, "each cinematic speaker controls its own portrait")
	_expect("_face_rockets_inward()\n\tawait _flee_miguel()\n\tawait _summon_rocket_pokemon()" in controller_source, "Miguel flees as Team Rocket closes in and before their Pokemon appear")
	_expect("await _show_miguel_takes_other_fossil()\n\t_face_story_player_down()\n\tvar entrance_tween" in controller_source, "the player faces down before Team Rocket appears")
	_expect('player.call("face_world_position", player_feet + Vector2.DOWN)' in controller_source, "the ambushed player uses the downward idle pose")
	_expect(
		'const ROCKET_FACING_ANIMATIONS: Array[StringName] = [\n\t&"idle_right",\n\t&"idle_left",\n\t&"idle_up",\n\t&"idle_down",\n\t&"idle_down",\n]'
		in controller_source,
		"the ambush formation keeps both upper Grunts facing down"
	)
	_expect("counterattack cannot start without the future starter" in controller_source, "a missing starter stops the sequence instead of silently skipping the attack")
	_expect("_future_self_spawn_global_position = player.global_position + Vector2(fossil_side * 32.0, -16)" in controller_source, "the layered rescuer aligns visually beside the player")
	_expect("_configure_future_self_appearance()" in controller_source and '"Mysterious_Mask"' in controller_source, "the rescuer is built from the player's model and Mysterious Outfit")
	_expect("_set_future_self_animation(animation_name)" in controller_source, "every Future Self clothing layer follows the facing direction")
	_expect('FUTURE_SELF_MUGSHOT := preload("res://assets/sprites/mugshots/future_self_mugshot.png")' in controller_source, "the revealed future self has a dedicated Mysterious Outfit mugshot")
	_expect("DIALOGUE_STAGE_FUTURE_VOICE" not in controller_source.get_slice("const REVEALED_FUTURE_SELF_DIALOGUE_STAGES", 1).get_slice("]", 0), "the unseen future voice does not reveal its portrait")
	_expect("if stage in REVEALED_FUTURE_SELF_DIALOGUE_STAGES:\n\t\treturn FUTURE_SELF_MUGSHOT" in controller_source, "future-self dialogue uses the mugshot only after the reveal")
	_expect("future_self.global_position + Vector2(0, 48)" in controller_source, "the future starter clears its Trainer's larger temporary sprite")
	_expect("await _flee_rockets()\n\t\t_face_future_self_and_player()" in controller_source, "Team Rocket disappears before the player-facing conversation")
	_expect("current_stage == DIALOGUE_STAGE_FAREWELL:\n\t\tawait _dismiss_rescuer()" in controller_source, "the rescuer disappears before the final player reaction")
	_expect("player.call(\"face_world_position\", future_self.global_position)" in controller_source, "the player faces the rescuer for their conversation")
	var miguel_source := _read_text("res://scripts/world/npcs/mt_moon_miguel_npc.gd")
	_expect("func flee_after_ambush()" in miguel_source, "Miguel can visibly flee after the rescue")
	_expect("await _show_panic_dialogue()\n\t_has_fled_ambush = true" in miguel_source, "Miguel panics before running from Team Rocket")
	_expect("if _has_fled_ambush and final_step_active:\n\t\tvisible = false" in miguel_source, "story updates cannot snap a fleeing Miguel back into view")
	_expect("_set_idle_frame(Vector2.DOWN)" in miguel_source, "Miguel returns to idle after his run animation")
	_expect("AFTER_AMBUSH_DIALOGUE_ID" in miguel_source and "FINAL_STEP_ID" in miguel_source, "Miguel apologizes when encountered after the ambush")
	var basement_source := _read_text("res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn")
	_expect('name="RocketUpperLeft"' in basement_source, "a Team Rocket Grunt surrounds the player from upper left")
	_expect('name="RocketUpperRight"' in basement_source, "a Team Rocket Grunt surrounds the player from upper right")
	var scene := load("res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn") as PackedScene
	_expect(scene != null, "Mt. Moon B2F loads with the expanded cinematic")

	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog := _load_json("res://localization/%s.json" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.go"), "%s has the summon caption" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.use_move"), "%s has the attack command" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.player_speaker"), "%s has the player speaker fallback" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.follower_fainted"), "%s has the follower faint plea" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.follower_attack"), "%s has the follower attack command" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.capture_threat"), "%s has the Rocket capture threat" % locale)

	quit(1 if failed else 0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
