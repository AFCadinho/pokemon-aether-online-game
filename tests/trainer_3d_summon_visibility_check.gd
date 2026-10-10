extends SceneTree

# Keep the real trainer setup, presenter and Pokeball choreography. Only the
# server lead response and model assets are replaced with offline fixtures.

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_catalog_path = ""
	settings._manual_model_catalog_this_session = true
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var save := root.get_node("PlayerSave")
	var previous_party: Array = save.party.duplicate()
	var player := Pokemon.new("Dragonite", 5)
	player.current_hp = maxi(player.max_hp, 1)
	save.party.assign([player])
	for layout in ["classic", "immersive"]:
		settings.battle_ui_layout = layout
		for preview in [false, true]:
			await _check_intro(player, preview)
	await _check_rejected_entry_reset(player)
	save.party.assign(previous_party)
	# Shared audio tails can outlive the battle's visual animations.
	await create_timer(1.0).timeout
	print("trainer_3d_summon_visibility_check: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)

func _battle() -> Variant:
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	battle.set_script(load("res://tests/fixtures/trainer_3d_summon_probe.gd"))
	root.add_child(battle)
	var stage: Node = battle.animation_router.model_presenter
	stage.loaded_path = ""
	stage.catalog_problem = ""
	stage.playback_speed = 8.0
	return battle

func _check_intro(player: Pokemon, preview: bool) -> void:
	print("CASE layout=", root.get_node("SettingsManager").battle_ui_layout, " preview=", preview)
	var battle: Variant = _battle()
	var stage: Node = battle.animation_router.model_presenter
	battle.prepare_pending_entry(&"route_1", battle.BattleType.TRAINER)
	battle.lead_response = _response(preview, true)
	_seed_model(stage, "arcanine")
	battle.run_setup(player, _response(preview, false))
	await process_frame
	await process_frame
	_check(battle.waiting_for_leads, "setup waits for the authoritative lead response")
	if not preview:
		_check(stage.active and stage.identities[1] == "arcanine", "the provisional first NPC slot has a ready 3D model")
		_check(not stage.actors[1].visible, "the provisional NPC Pokemon stays hidden during pending entry")
	# Opaque-host warmup must restore the actual pending-summon visibility.
	await stage.await_prepared(true)
	await process_frame
	_check(_hidden(stage, 0) and _hidden(stage, 1), "model warmup leaves both unsummoned actors hidden")

	var commands: Array[String] = []
	battle.command_started.connect(func(player_id: String):
		commands.append(player_id)
		_check(stage.identities[0] == "dragonite" and stage.identities[1] == "pikachu", "summons use the resolved leads, including NPC slot two")
		_check(_hidden(stage, 1), "the opponent stays hidden before its own summon")
		_check(_hidden(stage, 0) if player_id == "p1" else not _hidden(stage, 0), "only previously summoned actors are visible during command callouts")
	)
	var throws: Array[String] = []
	var released := [false, false]
	var premature_visibility := [false, false]
	var monitor := func():
		for index in 2:
			premature_visibility[index] = premature_visibility[index] or (not released[index] and not _hidden(stage, index))
	process_frame.connect(monitor)
	stage.ball_cue.connect(func(ident: String, cue: String):
		if cue == "cry":
			released[0 if ident == "p1" else 1] = true
		if cue != "summon_throw":
			return
		throws.append(ident)
		_check(_hidden(stage, 0 if ident == "p1" else 1), "a throwing ball has not revealed its actor")
		if ident == "p1":
			_check(_hidden(stage, 1), "the opponent stays hidden during the player's summon")
	)
	_seed_model(stage, "dragonite")
	_seed_model(stage, "pikachu")
	battle.choose_leads.emit()
	var deadline := Time.get_ticks_msec() + 10000
	while not battle.setup_finished and Time.get_ticks_msec() < deadline:
		await process_frame
	process_frame.disconnect(monitor)
	_check(premature_visibility == [false, false], "neither lead is visible in any frame before its own ball release")
	_check(battle.setup_finished and battle.battle_actions_ready, "the intro completes and unlocks battle actions")
	_check(commands == ["p1", "p2"] and throws == ["p1", "p2"], "both lead summons run through the real 3D route")
	_check(not _hidden(stage, 0) and not _hidden(stage, 1), "both leads remain visible after their summons")
	battle._update_active_sprites("settings_sprite_refresh")
	await process_frame
	await process_frame
	_check(not _hidden(stage, 0) and not _hidden(stage, 1), "ordinary post-intro refreshes keep both leads visible")
	# A later battle switch must still reveal its replacement normally.
	await battle._play_switch_recall("poke-ball", battle.enemy_sprite_box, "front")
	battle._set_single_pokemon_species_with_pvp_warning(battle.enemy_sprite_box, "Arcanine", "front", false, "switch_event")
	_seed_model(stage, "arcanine")
	await battle._play_switch_release("poke-ball", "", battle.enemy_sprite_box, "front")
	_check(stage.identities[1] == "arcanine" and not _hidden(stage, 1), "a later switch is not held by the opening summon")
	battle.queue_free()
	await process_frame
	await process_frame

func _check_rejected_entry_reset(player: Pokemon) -> void:
	var battle: Variant = _battle()
	var stage: Node = battle.animation_router.model_presenter
	_seed_model(stage, "arcanine")
	battle.run_setup(player, _response(false, false))
	await process_frame
	await process_frame
	battle.choose_leads.emit()
	await process_frame
	_check(battle.setup_finished, "rejected lead selection ends setup")
	# Wild entry and trainer resume share this reset and do not play lead summons.
	battle._prepare_battle_setup(battle.BattleType.WILD, player, null)
	battle._set_single_pokemon_species_with_pvp_warning(battle.player_sprite_box, "Dragonite", "back", false, "initial_setup")
	battle._set_single_pokemon_species_with_pvp_warning(battle.enemy_sprite_box, "Arcanine", "front", false, "initial_setup")
	_seed_model(stage, "dragonite")
	_seed_model(stage, "arcanine")
	await process_frame
	await process_frame
	_check(not _hidden(stage, 0) and not _hidden(stage, 1), "a new setup clears any unfinished trainer summon hold")
	battle.queue_free()
	await process_frame
	await process_frame

func _response(preview: bool, selected: bool) -> Dictionary:
	var player := _pokemon("p1", "Dragonite", 1, selected)
	var first := _pokemon("p2", "Arcanine", 1, false)
	var second := _pokemon("p2", "Pikachu", 2, selected)
	return {
		"success": true, "battleId": "offline-summon-visibility",
		"battleOptions": {"teamPreview": preview},
		"trainerTeam": [first, second],
		"requests": {
			"p1": {"side": {"pokemon": [player]}},
			"p2": {"side": {"pokemon": [first, second]}},
		},
	}

func _pokemon(side: String, species: String, slot: int, active: bool) -> Dictionary:
	return {"ident": side + ": " + species, "species": species, "details": species + ", L5",
		"level": 5, "condition": "20/20", "hp": 20, "maxHp": 20, "metadataSlot": slot, "active": active}

func _seed_model(stage: Node, key: String) -> void:
	var actor := MeshInstance3D.new()
	actor.mesh = SphereMesh.new()
	var player := AnimationPlayer.new()
	actor.add_child(player)
	player.owner = actor
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 1.0
	clip.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("idle", clip)
	player.add_animation_library("", library)
	var packed := PackedScene.new()
	assert(packed.pack(actor) == OK)
	actor.free()
	stage.packed[key] = packed
	stage.entries[key] = {"action_timing": {"idle": {"frames": 60.0, "speed": 1.0, "loop": true}}}
	stage.placements[key] = {"scale": 1.0, "yaw_degrees": 0.0, "lift": 0.0, "hover_height": 0.0, "calibrated": false}

func _hidden(stage: Node, index: int) -> bool:
	return not is_instance_valid(stage.actors[index]) or not stage.actors[index].visible

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
