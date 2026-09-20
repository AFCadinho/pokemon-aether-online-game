extends SceneTree

const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
var runs := 0
var after_memory: Array[int] = []
var evidence := []
var action_frames: Array[float] = []
var sampling := false
var sample_tick := 0

func _sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if sampling and sample_tick > 0:
		action_frames.append((now - sample_tick) / 1000.0)
	sample_tick = now

func _init() -> void:
	process_frame.connect(_sample_frame)
	_run.call_deferred()

func _run() -> void:
	var settings = root.get_node("SettingsManager")
	var old_mode: String = settings.battle_presentation_mode
	var old_path: String = settings.battle_3d_catalog_path
	var old_camera: bool = settings.battle_3d_camera_motion
	var old_arena: String = settings.battle_3d_arena
	var old_layout: String = settings.battle_ui_layout
	settings.battle_ui_layout = OS.get_environment("POKEAETHER_TEST_UI_LAYOUT") if not OS.get_environment("POKEAETHER_TEST_UI_LAYOUT").is_empty() else "classic"
	var old_forest: String = settings.battle_3d_forest_manifest
	if not OS.get_environment("POKEAETHER_TEST_ARENA").is_empty():
		settings.battle_3d_arena = OS.get_environment("POKEAETHER_TEST_ARENA")
		settings.battle_3d_forest_manifest = OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	var round_evidence := {}
	settings.battle_3d_camera_motion = false
	settings.battle_presentation_mode = "2.5d"
	assert(Renderer.supported("Dragonite", false, false, false))
	for args in [["Eevee", false, false, false], ["Dragonite", true, false, false], ["Dragonite", false, true, false], ["Dragonite", false, false, true]]:
		assert(not Renderer.supported.callv(args))
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	var screen_host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(screen_host)
	if current_scene == null:
		current_scene = screen_host
	screen_host.mount(battle)
	await process_frame
	var stage = battle.battle_stage.get_node("ExperimentalBattle3D")
	assert(stage.packed.is_empty() and stage.viewport == null and not stage.active)
	settings.battle_presentation_mode = "3d"
	var report := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	settings.battle_3d_catalog_path = ""
	stage.set_combatant(0, "Dragonite")
	stage.set_combatant(1, "Roaring Moon")
	for frame in 4:
		await process_frame
	assert(not stage.active and stage.reason.contains("No 3D catalog selected"))
	assert(stage.mode_label.text.contains("No 3D catalog selected"))
	if not report.is_empty():
		OS.set_environment("POKEAETHER_3D_STAGE_REPORT", report)
	settings.battle_3d_catalog_path = "user://missing-battle-model-report.json"
	await process_frame
	await process_frame
	assert(not stage.active and stage.packed.is_empty())
	assert(stage.reason.contains("catalog not found"))
	if not report.is_empty():
		settings.battle_3d_catalog_path = report
		battle.player_sprite_box.set_single_pokemon_species("Dragonite", "back", false)
		battle.enemy_sprite_box.set_single_pokemon_species("Roaring Moon", "front", false)
		stage.set_combatant(0, "Dragonite")
		stage.set_combatant(1, "Roaring Moon")
		var waits := 0
		var loading_frames: Array[float] = []
		while not stage.active and waits < 2000:
			var before := Time.get_ticks_usec()
			await process_frame
			loading_frames.append((Time.get_ticks_usec() - before) / 1000.0)
			waits += 1
		for frame in 10:
			var before := Time.get_ticks_usec()
			await process_frame
			loading_frames.append((Time.get_ticks_usec() - before) / 1000.0)
		loading_frames.sort()
		print("3D_LOAD_FRAME_MS max=", loading_frames[-1], " p95=", loading_frames[int(loading_frames.size()*0.95)])
		round_evidence.load_max_ms = loading_frames[-1]
		round_evidence.load_p95_ms = loading_frames[int(loading_frames.size()*0.95)]
		assert(stage.active and stage.packed.size() == 2)
		if not OS.get_environment("POKEAETHER_TEST_ARENA").is_empty():
			var expected := preload("res://scripts/battle/arenas/arena_catalog.gd").resolve(settings.battle_3d_arena, battle.active_battle_environment_id)
			assert(stage.arena_id == expected,stage.arena_problem)
		if stage.entries.dragonite.get("material_response_schema", 0) == 1:
			for entry in stage.entries.values():
				assert(ResourceLoader.get_dependencies(entry.runtime_path).is_empty(), "Prepared response must be self-contained")
			var response = stage.material_response
			assert(response.viewport != null and response.sync_count > 0)
			assert(response.viewport.use_hdr_2d)
			assert(response.viewport.size == stage.viewport.size)
			assert(response.viewport.msaa_3d == stage.viewport.msaa_3d)
			assert(response.copies[0] != null and response.copies[1] != null)
			for list in response.pairs:
				for pair in list:
					if pair[0] is MeshInstance3D:
						for surface in pair[0].mesh.get_surface_count():
							assert(pair[0].get_active_material(surface).shader == response.RESPONSE)
			print("BATTLE_3D_MATERIAL_RESPONSE_OK")
		print("3D_IMPORT_MS ", stage.import_times_ms)
		assert(stage.pending_entries.is_empty())
		assert(stage.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR)
		assert(stage.render_surface.texture == stage.viewport.get_texture())
		var original_scale: Vector2 = stage.scale
		var anchor_before: Vector2 = stage.get_global_transform().affine_inverse() * stage._anchor(true, 0)
		for factor in [0.75, 1.37, 1.0]:
			stage.scale = original_scale * factor
			stage._sync_render_size()
			var screen: Transform2D = stage.get_screen_transform()
			var expected := Vector2i(ceili(stage.size.x * screen.x.length()), ceili(stage.size.y * screen.y.length()))
			assert(stage.viewport.size == expected)
			var anchor_after: Vector2 = stage.get_global_transform().affine_inverse() * stage._anchor(true, 0)
			assert(anchor_before.distance_to(anchor_after) < 1.0, "Raster resizing shifted a HUD/effect anchor")
		stage.scale = original_scale
		stage._sync_render_size()
		print("3D_NATIVE_RASTER ", stage.viewport.size, " logical=", stage.size)
		var camera_home := preload("res://scripts/battle/arenas/arena_catalog.gd").camera_home(stage.arena_id)
		assert(stage.camera.position.is_equal_approx(camera_home))
		settings.battle_3d_camera_motion = true
		stage._update_camera(2.0)
		assert(not stage.camera.position.is_equal_approx(camera_home))
		settings.battle_3d_camera_motion = false
		stage._update_camera(0.0)
		assert(stage.camera.position.is_equal_approx(camera_home))
		stage.set_combatant(1, "")
		await process_frame
		await process_frame
		assert(stage.active and stage.actors[1] == null)
		stage.set_combatant(1, "Roaring Moon")
		await process_frame
		await process_frame
		assert(stage.active and stage.actors[1] != null)
		assert(battle.player_sprite_box.single_sprite.self_modulate.a == 0)
		assert(battle.player_sprite_box.presentation_anchor.is_valid())
		# No hidden-sprite frames, visibility, scale or playback may drive 3D.
		var old_frames: SpriteFrames = battle.player_sprite_box.single_sprite.sprite_frames
		battle.player_sprite_box.single_sprite.stop()
		battle.player_sprite_box.single_sprite.sprite_frames = null
		battle.player_sprite_box.single_sprite.visible = false
		await process_frame
		await process_frame
		assert(stage.actors[0].visible)
		assert(battle.player_sprite_box.get_single_animation_visual_rect_in_node(battle.battle_stage).has_area())
		stage.set_actor_shown(0, false)
		assert(await stage.send_out("p1"))
		assert(stage.lifecycle[0] == "idle" and stage.actor_shown[0])
		assert(await stage.recall("p1"))
		assert(stage.lifecycle[0] == "hidden" and not stage.actor_shown[0])
		stage.send_out("p1")
		assert(stage.lifecycle[0] == "send_out")
		stage.cancel_actions()
		await process_frame
		assert(stage.lifecycle[0] == "idle" and stage.actor_scale[0] == 1.0)
		var old_ball_player: Node = battle.pokeball_summon_animation_player
		battle.pokeball_summon_animation_player = null
		await battle._play_lead_summon("poke-ball", "Dragonite", null, "back")
		await battle._play_switch_recall("poke-ball", null, "back")
		assert(stage.lifecycle[0] == "hidden")
		await battle._play_switch_release("poke-ball", "Dragonite", null, "back")
		assert(stage.lifecycle[0] == "idle")
		battle.pokeball_summon_animation_player = old_ball_player
		stage.recall("p1")
		stage.set_combatant(0, "Dragonite", false, true)
		await process_frame
		assert(stage.lifecycle[0] == "idle" and stage.actor_shown[0])
		battle.animation_router.play_attack_tween_for_actor("p1: Dragonite", "Dragon Claw")
		assert(stage.players[0].current_animation == "physical_attack")
		stage.players[0].advance(100.0)
		await process_frame
		await process_frame
		battle.animation_router.play_attack_tween_for_actor("p1: Dragonite", "Dragon Pulse")
		await process_frame
		assert(stage.players[0].current_animation == "special_attack")
		assert(battle.player_sprite_box.single_sprite.sprite_frames == null)
		battle.player_sprite_box.single_sprite.sprite_frames = old_frames
		battle.player_sprite_box.single_sprite.visible = true
		settings.battle_3d_camera_motion = true
		var held_phase: float = stage.camera_phase
		stage._update_camera(2.0)
		assert(stage.camera_phase == held_phase)
		settings.battle_3d_camera_motion = false
		battle.animation_router.playback_speed = 4.0
		await process_frame
		await process_frame
		assert(stage.players[0].speed_scale == 4.0)
		battle.animation_router.playback_speed = 1.0
		battle.animation_router.play_damage_tween_for_target("p2: Roaring Moon")
		assert(stage.players[1].current_animation == "damage")
		stage.set_sleeping(0, true)
		stage.cancel_actions()
		assert(stage.players[0].current_animation == "sleep")
		# Cancellation must not let an old faint clear a current Pokémon.
		battle.animation_router.play_faint_tween_for_target("p1: Dragonite")
		assert(stage.players[0].current_animation == "faint_start")
		battle.animation_router.cancel_render()
		await process_frame
		await process_frame
		assert(battle.player_sprite_box.current_single_species == "Dragonite")
		# The 3D lifecycle completes independently of the hidden sprite.
		battle.animation_router.play_faint_tween_for_target("p2: Roaring Moon")
		assert(battle.enemy_sprite_box.current_single_species == "Roaring Moon")
		stage.players[1].advance(100.0)
		for frame in 3:
			await process_frame
		assert(stage.lifecycle[1] == "fainted" and not stage.actor_shown[1])
		assert(battle.enemy_sprite_box.current_single_species == "Roaring Moon")
		stage.set_actor_shown(1, true)
		stage.cancel_actions()
		for frame in 3:
			await process_frame
		stage.set_combatant(1, "Roaring Moon", true)
		await process_frame
		await process_frame
		assert(not stage.active and battle.player_sprite_box.single_sprite.self_modulate.a == 1)
		stage.set_combatant(1, "Roaring Moon", false)
		await process_frame
		await process_frame
		assert(stage.active)
		assert(battle.player_sprite_box.get_single_sprite_hover_rect().has_area())
		battle.enemy_sprite_box.substitute_active = true
		await process_frame
		await process_frame
		assert(not stage.active)
		battle.enemy_sprite_box.substitute_active = false
		stage.set_sleeping(0, false)
		await process_frame
		await process_frame
		# Drive an actual recorded response through the client's existing renderer.
		var p1 := {"ident": "p1a: Dragonite", "details": "Dragonite, L100", "species": "Dragonite", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
		var p2 := {"ident": "p2a: Roaring Moon", "details": "Roaring Moon, L100", "species": "Roaring Moon", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
		p1.pokemonKey = "acceptance-p1-dragonite"
		p2.pokemonKey = "acceptance-p2-moon"
		var first := {"success": true, "battleId": "3d-fixture", "replayKind": "wild", "formatId": "gen9nationaldex", "players": {"p1": {"name": "Player"}, "p2": {"name": "Wild"}},
			"ownTeam": [{"species": "Dragonite", "level": 100}], "trainerTeam": [{"species": "Roaring Moon", "level": 100}],
			"requests": {"p1": {"side": {"pokemon": [p1]}}, "p2": {"side": {"pokemon": [p2]}}},
			"state": {"turn": 1, "ended": false}, "events": [{"type": "turn", "turn": 1, "eventSeq": 0}]}
		var bench := {"ident": "p1: Roaring Moon", "details": "Roaring Moon, L100", "species": "Roaring Moon", "condition": "100/100", "hp": 100, "maxHp": 100, "active": false}
		bench.pokemonKey = "acceptance-p1-moon"
		first.ownTeam = [p1.duplicate(true), bench.duplicate(true)]
		first.requests.p1.side.pokemon.append(bench.duplicate(true))
		var second := first.duplicate(true)
		second.requests.p2.side.pokemon[0].hp = 82
		second.requests.p2.side.pokemon[0].condition = "82/100"
		second.events = [{"type": "move", "actor": "p1a: Dragonite", "target": "p2a: Roaring Moon", "move": "Dragon Pulse", "eventSeq": 1},
			{"type": "damage", "target": "p2a: Roaring Moon", "condition": "82/100", "eventSeq": 2}]
		var physical := second.duplicate(true)
		physical.events = [{"type": "move", "actor": "p1a: Dragonite", "target": "p2a: Roaring Moon", "move": "Dragon Claw", "eventSeq": 3}]
		var switched := physical.duplicate(true)
		switched.requests.p1.side.pokemon[0].active = false
		switched.requests.p1.side.pokemon[1].active = true
		switched.requests.p1.side.pokemon[1].ident = "p1a: Roaring Moon"
		switched.ownTeam[0].active = false
		switched.ownTeam[1].active = true
		switched.ownTeam[1].ident = "p1a: Roaring Moon"
		switched.events = [{"type": "switch", "pokemon": "p1a: Roaring Moon", "playerId": "p1", "details": "Roaring Moon, L100", "condition": "100/100", "eventSeq": 4}]
		switched.events[0].toRef = {"species": "Roaring Moon", "displaySpecies": "Roaring Moon", "ident": "p1a: Roaring Moon", "pokemonKey": "acceptance-p1-moon"}
		switched.events[0].species = "Roaring Moon"
		var returned := physical.duplicate(true)
		returned.events = [{"type": "switch", "pokemon": "p1a: Dragonite", "playerId": "p1", "details": "Dragonite, L100", "condition": "100/100", "eventSeq": 5}]
		returned.events[0].toRef = {"species": "Dragonite", "displaySpecies": "Dragonite", "ident": "p1a: Dragonite", "pokemonKey": "acceptance-p1-dragonite"}
		returned.events[0].species = "Dragonite"
		var fainted := returned.duplicate(true)
		fainted.requests.p2.side.pokemon[0].hp = 0
		fainted.requests.p2.side.pokemon[0].condition = "0 fnt"
		fainted.events = [{"type": "faint", "target": "p2a: Roaring Moon", "condition": "0 fnt", "eventSeq": 6}]
		var terminal := fainted.duplicate(true)
		terminal.state = {"turn": 2, "ended": true, "winner": "Player"}
		terminal.events = [{"type": "win", "winner": "Player", "eventSeq": 7}]
		var setup_started := Time.get_ticks_usec()
		assert(battle.setup_battle_replay({"schemaVersion": 1, "frames": [first, second, physical, switched, returned, fainted, terminal]}))
		round_evidence.replay_setup_ms = (Time.get_ticks_usec() - setup_started) / 1000.0
		assert(battle.vs_panel_container.player_1_portrait.appearance_state.is_empty(), "Wild battles must not build hidden player portraits")
		battle.replay_paused = false
		action_frames.clear()
		sample_tick = Time.get_ticks_usec()
		sampling = true
		await battle.play_replay_frame(battle.replay_controls.timeline, 1)
		assert(battle.battle_state.get_active_player_pokemon("p2").hp == 82)
		await process_frame
		assert(stage.active)
		await battle.play_replay_frame(battle.replay_controls.timeline, 2)
		await battle.play_replay_frame(battle.replay_controls.timeline, 3)
		await process_frame
		await process_frame
		assert(stage.identities[0] == "roaring-moon")
		await battle.play_replay_frame(battle.replay_controls.timeline, 4)
		await process_frame
		await process_frame
		assert(stage.identities[0] == "dragonite")
		_check_response_sync(stage)
		assert(battle.battle_state.get_active_player_pokemon("p1").species == "Dragonite")
		var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			sampling = false # Explicit screenshot GPU readback is not gameplay work.
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("client-3d.png"))
			sample_tick = Time.get_ticks_usec()
			sampling = true
		await battle.play_replay_frame(battle.replay_controls.timeline, 5)
		await battle.play_replay_frame(battle.replay_controls.timeline, 6)
		await battle.stop_battle_replay()
		sampling = false
		action_frames.sort()
		round_evidence.actions_max_ms = action_frames[-1]
		round_evidence.actions_p95_ms = action_frames[int(action_frames.size()*0.95)]
		print("3D_ACTION_FRAME_MS max=", round_evidence.actions_max_ms, " p95=", round_evidence.actions_p95_ms)
		if runs == 0:
			# A new battle-scene host can use the presenter with no sprite boxes.
			var standalone := Renderer.new()
			root.add_child(standalone)
			standalone.setup()
			standalone.set_combatant(0, "Dragonite")
			standalone.set_combatant(1, "Roaring Moon")
			for frame in 2000:
				if standalone.active:
					break
				await process_frame
			assert(standalone.active and standalone.boxes.is_empty())
			assert(await standalone.send_out("p1"))
			assert(await standalone.recall("p1"))
			standalone.queue_free()
			await process_frame
			await process_frame
		settings.battle_presentation_mode = "2.5d"
		var old_viewport: WeakRef = weakref(stage.viewport)
		await process_frame
		await process_frame
		assert(not stage.active and stage.packed.is_empty())
		assert(stage.viewport == null and old_viewport.get_ref() == null)
		assert(stage.material_response.viewport == null and stage.material_response.pairs == [[], []])
		assert(stage.actors == [null, null] and stage.pending_entries.is_empty())
		assert(not battle.player_sprite_box.presentation_anchor.is_valid())
		assert(battle.player_sprite_box.single_sprite.self_modulate.a == 1)
		# Cancel a fresh in-flight request, then let the detached drain finish.
		stage._load_catalog(report)
		stage._import_next_model()
		assert(not stage.loading_path.is_empty())
		stage._process(0.0)
		assert(stage.loading_path.is_empty() and stage.pending_entries.is_empty())
		for frame in 30:
			await process_frame
		assert(stage.packed.is_empty() and stage.viewport == null)
	settings.battle_presentation_mode = old_mode
	settings.battle_3d_catalog_path = old_path
	settings.battle_3d_camera_motion = old_camera
	settings.battle_3d_arena = old_arena
	settings.battle_ui_layout = old_layout
	settings.battle_3d_forest_manifest = old_forest
	screen_host.release()
	screen_host.queue_free()
	await process_frame
	await process_frame
	print("BATTLE_3D_PRESENTATION_OK")
	after_memory.append(OS.get_static_memory_usage())
	round_evidence.static_bytes = OS.get_static_memory_usage()
	round_evidence.video_bytes = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	evidence.append(round_evidence)
	print("3D_AFTER_BATTLE_MEMORY ", after_memory)
	runs += 1
	if runs < 3 and not report.is_empty():
		_run.call_deferred()
		return
	if after_memory.size() == 3:
		assert(after_memory[2] - after_memory[1] < 1024 * 1024, "Repeated battle retained more than 1 MiB static memory")
	var evidence_path := OS.get_environment("POKEAETHER_3D_ACCEPTANCE_REPORT")
	if not evidence_path.is_empty():
		var file := FileAccess.open(evidence_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(evidence, "\t"))
		file.close()
	var budget := OS.get_environment("POKEAETHER_3D_ACCEPTANCE_MAX_FRAME_MS").to_float()
	if budget > 0 and DisplayServer.get_name() != "headless":
		for item: Dictionary in evidence:
			assert(item.load_max_ms < budget and item.actions_max_ms < budget and item.replay_setup_ms < budget, "Desktop frame budget exceeded; see acceptance report")
	quit()

func _check_response_sync(stage: Control) -> void:
	var response = stage.material_response
	if response.viewport == null:
		return
	response._sync()
	assert(response.camera.transform.is_equal_approx(stage.camera.transform))
	for list in response.pairs:
		for pair in list:
			if pair[0] is Node3D:
				assert(pair[0].transform.is_equal_approx(pair[1].transform))
				assert(pair[0].visible == pair[1].visible)
			if pair[0] is Skeleton3D:
				for bone in pair[0].get_bone_count():
					assert(pair[0].get_bone_pose(bone).is_equal_approx(pair[1].get_bone_pose(bone)))
			if pair[0] is MeshInstance3D:
				for shape in pair[0].get_blend_shape_count():
					assert(is_equal_approx(pair[0].get_blend_shape_value(shape), pair[1].get_blend_shape_value(shape)))
