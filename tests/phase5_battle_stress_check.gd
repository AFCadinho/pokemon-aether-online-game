extends SceneTree
## Real battle UI + candidate presenter; no server, sessions or player saves.
const Candidate = preload("res://tests/phase5_candidate_stage.gd")
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const TEAM_A := ["pikachu", "arcanine", "lucario", "snorlax", "articuno", "pikachu"]
const TEAM_B := ["dragonite", "roaring-moon", "snorlax", "lucario", "arcanine", "dragonite"]
var evidence := {"complete": false, "runtime_approved": false, "rounds": [], "shiny": "not certified; normal-only candidates, fallback checked"}
var output: String
var stage: Control
var battle: Control
var screen_host: Control
var frame_samples: Array[float] = []
var frame_tick := 0
var sample_frames := false
var sample_context := ""
var frame_stalls: Array[Dictionary] = []
var replay_setup_ms := 0.0
var capture_images := true

func _sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if sample_frames and frame_tick > 0:
		var elapsed := (now - frame_tick) / 1000.0
		frame_samples.append(elapsed)
		if elapsed > 50.0:
			frame_stalls.append({"ms": elapsed, "context": sample_context,
				"frame": Engine.get_process_frames(), "pipelines": stage._blocking_pipelines(),
				"covered": screen_host.get_node("Cover").visible})
	frame_tick = now

func _init() -> void:
	process_frame.connect(_sample_frame)
	_run.call_deferred()

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _ready_pair(left: String, right: String, force := false, left_shiny := false, right_shiny := false) -> float:
	sample_context = "load " + left + " / " + right
	var start := Time.get_ticks_usec()
	stage.set_combatant(0, left, left_shiny, force)
	stage.set_combatant(1, right, right_shiny, force)
	var keys := [left + ("@shiny" if left_shiny else ""), right + ("@shiny" if right_shiny else "")]
	var deadline := Time.get_ticks_msec() + 20000
	while not stage.active or stage.identities != keys or stage._models_pending():
		assert(Time.get_ticks_msec() < deadline, stage.reason)
		await process_frame
	await _frames(3)
	assert(stage.packed.size() <= 2 and Cache.items.size() <= Cache.MAX_ENTRIES)
	assert(Cache.source_bytes <= Cache.MAX_SOURCE_BYTES and stage.failed_models.is_empty())
	for species in keys:
		assert(stage.placements[species].calibrated)
		assert(not stage.motion_clips[species].is_empty())
	battle.player_hud_panel.set_pokemon_data(left.capitalize(), 100, 100, 100)
	battle.enemy_hud_panel.set_pokemon_data(right.capitalize(), 100, 100, 100)
	return (Time.get_ticks_usec() - start) / 1000.0

func _faint_and_replace(species: String, shiny := false) -> void:
	stage.play_action("p1", "faint_start")
	assert(stage.current_actions[0] == "faint_start")
	stage.players[0].advance(100.0)
	await _frames(4)
	assert(stage.lifecycle[0] == "fainted" and stage.current_actions[0] == "faint_loop")
	stage.players[0].advance(100.0)
	await _frames(3)
	assert(stage.actors[0].visible and stage.actor_shown[0] and stage.players[0].is_playing())
	assert(stage.current_actions[1] == "idle", "Duplicate on opposite side inherited faint")
	stage.set_combatant(0, species, shiny, true)
	await _frames(3)
	assert(stage.lifecycle[0] == "idle" and stage.current_actions[0] == "idle")
	# An old asynchronous faint must not complete against a replacement.
	stage.play_action("p1", "faint_start")
	stage.set_combatant(0, species, shiny, true)
	await _frames(4)
	assert(stage.lifecycle[0] == "idle" and stage.current_actions[0] == "idle")

func _check_hud() -> void:
	# Let the real immersive HUD settle, then compare in global UI coordinates.
	await create_timer(0.6).timeout
	for index in 2:
		var hud: Control = battle.player_hud_panel if index == 0 else battle.enemy_hud_panel
		assert(stage._visual_rect(index).has_area())
		assert(not hud.get_global_rect().intersects(stage._visual_rect(index)), "HUD overlaps model envelope")
	assert(not battle.player_hud_panel.get_global_rect().intersects(battle.enemy_hud_panel.get_global_rect()))

func _pokemon(species: String, side: String, slot: int) -> Dictionary:
	var name := species.replace("-", " ").capitalize()
	return {"species": name, "ident": side + ("a: " if slot == 0 else ": ") + name,
		"details": name + ", L100", "condition": "100/100", "hp": 100, "maxHp": 100,
		"active": slot == 0, "pokemonKey": side + "-slot-" + str(slot), "level": 100}

func _switch_frame(previous: Dictionary, from_slot: int, to_slot: int, sequence: int) -> Dictionary:
	var frame := previous.duplicate(true)
	for party in [frame.ownTeam, frame.requests.p1.side.pokemon]:
		party[from_slot].active = false
		party[to_slot].active = true
		party[to_slot].ident = "p1a: " + party[to_slot].species
	var mon: Dictionary = frame.requests.p1.side.pokemon[to_slot]
	frame.events = [{"type": "switch", "playerId": "p1", "pokemon": mon.ident,
		"species": mon.species, "details": mon.details, "condition": mon.condition,
		"eventSeq": sequence, "toRef": {"species": mon.species, "displaySpecies": mon.species,
			"ident": mon.ident, "pokemonKey": mon.pokemonKey}}]
	return frame

func _replay_check() -> void:
	sample_context = "replay setup"
	var own := []
	var enemy := []
	for slot in 6:
		own.append(_pokemon(TEAM_A[slot], "p1", slot))
		enemy.append(_pokemon(TEAM_B[slot], "p2", slot))
	var first := {"success": true, "battleId": "offline-phase5", "replayKind": "wild",
		"formatId": "gen9nationaldex", "players": {"p1": {"name": "Review"}, "p2": {"name": "Control"}},
		"ownTeam": own, "trainerTeam": enemy,
		"requests": {"p1": {"side": {"pokemon": own.duplicate(true)}}, "p2": {"side": {"pokemon": enemy.duplicate(true)}}},
		"state": {"turn": 1, "ended": false}, "events": [{"type": "turn", "turn": 1, "eventSeq": 0}]}
	var attack := first.duplicate(true)
	attack.requests.p2.side.pokemon[0].hp = 75
	attack.requests.p2.side.pokemon[0].condition = "75/100"
	attack.events = [{"type": "move", "actor": "p1a: Pikachu", "target": "p2a: Dragonite", "move": "Thunderbolt", "eventSeq": 1},
		{"type": "damage", "target": "p2a: Dragonite", "condition": "75/100", "eventSeq": 2}]
	var duplicate := _switch_frame(attack, 0, 5, 3)
	var faint := duplicate.duplicate(true)
	faint.requests.p1.side.pokemon[5].hp = 0
	faint.requests.p1.side.pokemon[5].condition = "0 fnt"
	faint.events = [{"type": "faint", "target": "p1a: Pikachu", "condition": "0 fnt", "eventSeq": 4}]
	var replacement := _switch_frame(faint, 5, 1, 5)
	var terminal := replacement.duplicate(true)
	terminal.state = {"turn": 2, "ended": true, "winner": "Control"}
	terminal.events = [{"type": "win", "winner": "Control", "eventSeq": 6}]
	var setup_started := Time.get_ticks_usec()
	assert(battle.setup_battle_replay({"schemaVersion": 1, "frames": [first, attack, duplicate, faint, replacement, terminal]}))
	replay_setup_ms = (Time.get_ticks_usec() - setup_started) / 1000.0
	# Setup and the first event used to run in the same frame, mislabelling
	# the entire UI reconstruction as a first-move stall. Keep both measured.
	await _frames(3)
	battle.replay_paused = false
	for frame in range(1, 6):
		sample_context = "replay frame " + str(frame)
		await battle.play_replay_frame(battle.replay_controls.timeline, frame)
		var expected := "arcanine" if frame >= 4 else "pikachu"
		var deadline := Time.get_ticks_msec() + 20000
		while not stage.active or stage.identities != [expected, "dragonite"]:
			assert(Time.get_ticks_msec() < deadline, stage.reason)
			await process_frame
		await _frames(3)
		if frame == 1:
			assert(battle.battle_state.get_active_player_pokemon("p2").hp == 75)
		if frame == 2:
			assert(battle.battle_state.get_active_player_pokemon("p1").pokemonKey == "p1-slot-5")
		if frame == 3:
			assert(stage.lifecycle[0] == "fainted" and stage.current_actions[0] == "faint_loop" and stage.actors[0].visible)
		if frame == 4:
			assert(stage.lifecycle[0] == "idle" and stage.actor_shown[0])
	await battle.stop_battle_replay()
	print("PHASE5_REPLAY_DUPLICATE_REPLACEMENT_OK")

func _run() -> void:
	capture_images = OS.get_environment("POKEAETHER_PHASE5_CAPTURE") != "0"
	evidence["screenshots_enabled"] = capture_images
	var report := OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")
	output = OS.get_environment("POKEAETHER_PHASE5_STRESS_OUTPUT")
	assert(report.is_absolute_path() and output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(report))
	var runtime_registry := OS.get_environment("POKEAETHER_PHASE5_PRODUCTION") == "1"
	evidence["production_registry"] = runtime_registry
	for entry: Dictionary in catalog:
		entry.species = Renderer.ReviewedModels.entry_key(entry)
	var variants: Array = catalog.filter(func(e): return str(e.species).ends_with("@shiny"))
	assert(catalog.size() == 7 or (catalog.size() == 14 and variants.size() == 7))
	for entry: Dictionary in catalog:
		assert((runtime_registry or entry.get("_review_only", false)) and FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2.5d"
	settings.battle_ui_layout = "immersive"
	settings.battle_3d_catalog_path = report
	settings.battle_3d_camera_motion = false
	root.size = Vector2i(1280, 720)
	# Admission is explicit: held species remain unsupported, including shiny.
	var production := Renderer.new()
	for species in ["gastly", "abra", "onix"]:
		assert(not production._catalog_species_allowed(species))
		assert(not production._supports_combatant(species, false, false, false))
	assert(production._supports_combatant("dragonite", true, false, false))
	assert(production._supports_combatant("pikachu", false, false, false))
	production.free()
	Cache.clear()
	for cycle in 3:
		settings.battle_presentation_mode = "2.5d" if cycle == 0 else "3d"
		settings.battle_3d_arena = "classic" if cycle != 1 else "stadium"
		var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		screen_host = host
		battle = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(host)
		host.mount(battle)
		# Replace only the presenter, keeping the real router, HUD and controls.
		var old_stage = battle.animation_router.model_presenter
		var position: int = old_stage.get_index()
		old_stage.free()
		stage = Candidate.new()
		stage.use_runtime_registry = runtime_registry
		stage.name = "ExperimentalBattle3D" # Keep the real host's preparation fence.
		battle.battle_stage.add_child(stage)
		battle.battle_stage.move_child(stage, position)
		stage.setup([battle.player_sprite_box, battle.enemy_sprite_box], [battle.player_battle_platform, battle.enemy_battle_platform])
		battle.animation_router.model_presenter = stage
		settings.battle_presentation_mode = "3d"
		var party := []
		for species in TEAM_A:
			party.append({"species": species, "hp": 100, "max_hp": 100})
		battle.player_party_grid.set_party(party)
		var round_data := {"arena": settings.battle_3d_arena, "switch_ms": [], "duplicate_checks": 0, "faint_replacements": 0}
		var first_id := 0
		var first_key := ""
		frame_samples.clear()
		frame_stalls.clear()
		frame_tick = Time.get_ticks_usec()
		sample_frames = true
		for turn in 12:
			var left: String = TEAM_A[turn % 6]
			var right: String = TEAM_B[(turn + cycle) % 6]
			var previous = weakref(stage.actors[0]) if stage.actors[0] != null else null
			var previous_species: String = stage.identities[0]
			round_data.switch_ms.append(await _ready_pair(left, right, true))
			sample_context = "actions " + left + " / " + right
			if previous != null and previous_species != left:
				assert(previous.get_ref() == null, "Retired actor leaked")
			if turn == 0:
				first_id = stage.packed[left].get_instance_id()
				first_key = stage.validated_entries[left]._resource_cache_key
			if turn == 4:
				assert(Cache.fetch(first_key) == null, "Real LRU eviction did not occur")
			if turn == 5:
				assert(stage.packed[left].get_instance_id() != first_id, "Evicted scene was not reloaded")
			stage.start_action("p1", "physical_attack")
			assert(stage.current_actions[0] == "physical_attack")
			stage.players[0].advance(100)
			await _frames(3)
			assert(stage.current_actions[0] == "idle")
			assert(await stage.recall("p1"))
			assert(await stage.send_out("p1"))
			if turn < 6:
				await _check_hud()
			if capture_images and turn == 4 and DisplayServer.get_name() != "headless":
				sample_frames = false
				RenderingServer.force_draw(false)
				assert(root.get_texture().get_image().save_png(output.path_join("battle-%d.png" % cycle)) == OK)
				frame_tick = Time.get_ticks_usec()
				sample_frames = true
		# Every eligible species is checked as two independent simultaneous actors.
		for entry: Dictionary in catalog.filter(func(e): return not str(e.species).ends_with("@shiny")):
			await _ready_pair(entry.species, entry.species, true)
			sample_context = "duplicate faint " + str(entry.species)
			assert(stage.actors[0] != stage.actors[1] and stage.players[0] != stage.players[1])
			assert(stage.packed.size() == 1)
			await _faint_and_replace(entry.species)
			round_data.duplicate_checks += 1
			round_data.faint_replacements += 1
		round_data["variant_checks"] = 0
		for entry: Dictionary in variants:
			var species: String = str(entry.species).trim_suffix("@shiny")
			await _ready_pair(species, species, true, false, true)
			var normal_id: int = stage.packed[species].get_instance_id()
			var shiny_id: int = stage.packed[entry.species].get_instance_id()
			assert(normal_id != shiny_id)
			assert(stage.validated_entries[species]._resource_cache_key != stage.validated_entries[entry.species]._resource_cache_key)
			await _ready_pair(species, species, true, true, false)
			assert(stage.packed[species].get_instance_id() == normal_id and stage.packed[entry.species].get_instance_id() == shiny_id)
			assert(stage.handles("p1") and stage.handles("p2"))
			await _faint_and_replace(species, true)
			await _check_hud()
			if capture_images and cycle == 0 and DisplayServer.get_name() != "headless":
				sample_frames = false
				RenderingServer.force_draw(false)
				assert(root.get_texture().get_image().save_png(output.path_join(species + "-variants.png")) == OK)
				frame_tick = Time.get_ticks_usec()
				sample_frames = true
			var evictors: Array = ["pikachu", "arcanine", "lucario"].filter(func(name): return name != species)
			var shiny_key: String = stage.validated_entries[entry.species]._resource_cache_key
			await _ready_pair(evictors[0], evictors[1], true)
			assert(Cache.fetch(shiny_key) == null)
			await _ready_pair(species, species, true, false, true)
			assert(stage.packed[species].get_instance_id() != normal_id)
			assert(stage.packed[entry.species].get_instance_id() != shiny_id)
			round_data.variant_checks += 1
		stage.set_combatant(1, "gastly" if not variants.is_empty() else "pikachu", true)
		await _frames(4)
		assert(not stage.active, "Unreviewed shiny must fall back")
		await _ready_pair("pikachu", "dragonite", true)
		round_data.cache_hits = stage.model_cache_hits
		round_data.retained_source_bytes = Cache.source_bytes
		await _replay_check()
		round_data["replay_duplicate_faint_replacement"] = true
		round_data["replay_setup_ms"] = replay_setup_ms
		sample_frames = false
		frame_samples.sort()
		round_data["frame_max_ms"] = frame_samples[-1]
		round_data["frame_p95_ms"] = frame_samples[int(frame_samples.size() * 0.95)]
		round_data["frame_samples"] = frame_samples.size()
		round_data["stalls_over_50ms"] = frame_stalls.duplicate(true)
		round_data["actor_build_ms"] = stage.actor_build_ms
		round_data["arena_build_ms"] = stage.arena_build_ms
		round_data["load_spans"] = stage.load_spans.duplicate(true)
		round_data["model_validation_ms"] = stage.model_validation_ms
		var actor_ref: WeakRef = weakref(stage.actors[0])
		var viewport_ref: WeakRef = weakref(stage.viewport)
		host.release()
		host.queue_free()
		await _frames(5)
		assert(actor_ref.get_ref() == null and viewport_ref.get_ref() == null)
		round_data.static_bytes = OS.get_static_memory_usage()
		evidence.rounds.append(round_data)
		print("PHASE5_STRESS_ROUND ", cycle, " ", round_data)
	# Explicit test cleanup after all three battles; capacity was never increased.
	Cache.clear()
	assert(Cache.items.is_empty() and Cache.source_bytes == 0)
	evidence.complete = true
	if not variants.is_empty():
		evidence.shiny = "seven paired variants, bidirectional switches, separate cache keys, faint/replacement, repeated across three battles"
	evidence["phase5c_complete"] = false
	evidence["remaining"] = ["Separate closing review of this report, visual source review and performance evidence"]
	evidence["catalog_sha256"] = FileAccess.get_sha256(report)
	evidence["scope"] = "real immersive UI, presenter and recorded battle events; normal candidates, no live server"
	assert(evidence.rounds[2].static_bytes - evidence.rounds[1].static_bytes < 1048576, "Repeated battle static retention exceeded 1 MiB")
	var file := FileAccess.open(output.path_join("stress.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	print("PHASE5_BATTLE_STRESS_OK")
	quit()
