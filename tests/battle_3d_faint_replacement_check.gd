extends "res://tests/trainer_3d_summon_visibility_check.gd"
## Real event/render and forced-switch paths, with small offline model clips.

func _run() -> void:
	await process_frame
	root.size = Vector2i(1920, 1080)
	var settings: Node = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_catalog_path = ""
	settings._manual_model_catalog_this_session = true
	settings.battle_animations = true
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	for layout: String in ["classic", "immersive"]:
		settings.battle_ui_layout = layout
		for animations: bool in [true, false]:
			settings.battle_animations = animations
			for side: String in ["p1", "p2"]:
				for loop_pose: bool in [true, false]:
					await _check_faint_replacement(side, loop_pose)
	print("battle_3d_faint_replacement_check: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)

func _check_faint_replacement(side: String, loop_pose: bool) -> void:
	var battle: Variant = _battle()
	battle.battle_type = battle.BattleType.TRAINER
	battle.training_ai_battle = true
	battle.battle_state.load_from_api_response(_battle_response(), false)
	var stage: Node = battle.animation_router.model_presenter
	for species: String in ["dragonite", "pikachu", "arcanine"]:
		_seed_faint_model(stage, species, loop_pose)
	battle._update_active_sprites()
	var index := 0 if side == "p1" else 1
	# Retain the offline replacement as staged model demand instead of relying
	# on the production downloader/shared resource cache for this fixture.
	stage.staged_mega_species[index] = "arcanine"
	for frame in 4: await process_frame
	var actor: Node3D = stage.actors[index]
	var ident: String = battle.battle_state.get_active_player_pokemon(side).ident
	var faint := {"type": "faint", "target": ident, "condition": "0 fnt", "hp": 0, "maxHp": 20}
	# A canonical 0-HP snapshot can arrive before the ordered faint animation.
	battle.battle_state.apply_event_conditions([faint])
	battle._update_active_sprites("snapshot_reconciliation")
	await process_frame
	_check(stage.handles(side) and stage.actors[index] == actor,
		"0-HP reconciliation retains the existing model for its native faint")
	await battle._render_battle_events([faint], false, "offline_faint", true)
	battle._refresh_force_switch_transition_presentation()
	battle._update_active_sprites("settings_sprite_refresh")
	for frame in 4: await process_frame
	_check(stage.handles(side) and stage.actors[index] == actor and actor.visible,
		"the same fainted model stays visible while choosing a replacement")
	_check(stage.lifecycle[index] == "fainted", "the real event router completes the native faint")
	if stage.handles(side):
		_check(absf(actor.rotation.z - PI * 0.5) < 0.01, "the fainted model keeps its lying pose")
		_check(stage.current_actions[index] == ("faint_loop" if loop_pose else "faint_start"),
			"both looping and final-frame faint poses are retained")
	var box: Node = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
	_check(box.single_sprite.self_modulate.a == 0.0 and box.active_tween == null,
		"faint never starts the 2D sprite tween or exposes its sprite")
	var cues: Array[String] = []
	var actor_id := actor.get_instance_id()
	stage.ball_cue.connect(func(controller: String, cue: String):
		if controller != side: return
		cues.append(cue)
		if cues.size() == 1:
			_check(stage.actors[index].get_instance_id() == actor_id and absf(stage.actors[index].rotation.z - PI * 0.5) < 0.01,
				"the return animation recalls the original lying model")
	)
	await battle._render_battle_events([{
		"type": "switch", "player": side, "fromIdent": ident,
		"pokemon": side + ": Arcanine", "species": "Arcanine",
		"details": "Arcanine, L5", "condition": "20/20", "hp": 20, "maxHp": 20,
		"metadataSlot": 2,
	}], false, "offline_replacement", true)
	for frame in 3: await process_frame
	_check(cues == ["summon_release", "summon_throw", "summon_release", "cry"],
		"one native return precedes one native throw/release for the replacement")
	_check(stage.identities[index] == "arcanine" and stage.lifecycle[index] == "idle" and stage.actors[index].visible,
		"the replacement ends upright and visible")
	_check(box.single_sprite.self_modulate.a == 0.0, "the whole replacement stays in 3D")
	# The ordinary 2D layout still clears an empty field slot.
	root.get_node("SettingsManager").battle_presentation_mode = "2d"
	battle.battle_state.apply_event_conditions([{"type": "faint", "target": side + ": Arcanine", "condition": "0 fnt"}])
	battle._update_active_sprites()
	_check(stage.combatants[index].species == "" and box.current_single_species == "", "2D still clears fainted sprites")
	root.get_node("SettingsManager").battle_presentation_mode = "3d"
	battle.queue_free()
	await process_frame
	await process_frame

func _battle_response() -> Dictionary:
	var requests := {}
	for side: String in ["p1", "p2"]:
		requests[side] = {"side": {"pokemon": [
			_pokemon(side, "Dragonite" if side == "p1" else "Pikachu", 1, true),
			_pokemon(side, "Arcanine", 2, false),
		]}}
	return {"success": true, "battleId": "offline-faint-replacement", "requests": requests}

func _seed_faint_model(stage: Node, key: String, loop_pose: bool) -> void:
	var actor := MeshInstance3D.new()
	actor.mesh = CapsuleMesh.new()
	var player := AnimationPlayer.new()
	actor.add_child(player)
	player.owner = actor
	var library := AnimationLibrary.new()
	var timing := {}
	for action: String in ["idle", "faint_start", "faint_loop"]:
		if action == "faint_loop" and not loop_pose: continue
		var clip := Animation.new()
		clip.length = 0.12
		clip.loop_mode = Animation.LOOP_NONE if action == "faint_start" else Animation.LOOP_LINEAR
		var track := clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track, NodePath(".:rotation:z"))
		clip.track_insert_key(track, 0.0, PI * 0.5 if action == "faint_loop" else 0.0)
		clip.track_insert_key(track, clip.length, 0.0 if action == "idle" else PI * 0.5)
		library.add_animation(action, clip)
		timing[action] = {"frames": 7.2, "speed": 1.0, "loop": action != "faint_start"}
	player.add_animation_library("", library)
	var packed := PackedScene.new()
	assert(packed.pack(actor) == OK)
	actor.free()
	stage.packed[key] = packed
	stage.entries[key] = {"action_timing": timing}
	stage.placements[key] = {"scale": 1.0, "yaw_degrees": 0.0, "lift": 0.5, "hover_height": 0.0, "calibrated": false}
