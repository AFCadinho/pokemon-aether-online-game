extends SceneTree
## Three local real-battle passes of the 14 paired candidates, without image readback.
const Cache = preload("res://scripts/battle/battle_ui/model_resource_cache.gd")
const Candidate = preload("res://tests/phase5_candidate_stage.gd")
const NAMES := ["charmeleon", "dunsparce", "flaaffy", "houndoom", "houndour", "igglybuff", "mareep", "persian", "phanpy", "skiploom", "slowking", "stantler", "teddiursa", "ursaring"]

var frame_samples: Array[float] = []
var frame_stalls: Array[Dictionary] = []
var frame_tick := 0
var sample := false
var context := ""
var stage: Control
var battle: Control
var host: Control


func _init() -> void:
	process_frame.connect(_sample_frame)
	_run.call_deferred()


func _sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if sample and frame_tick > 0:
		var elapsed := (now - frame_tick) / 1000.0
		frame_samples.append(elapsed)
		if elapsed > 50.0:
			frame_stalls.append({"ms": elapsed, "context": context,
				"covered": host.get_node("Cover").visible})
	frame_tick = now


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _ready_pair(species: String, left_shiny: bool, right_shiny: bool) -> void:
	context = "load " + species
	stage.set_combatant(0, species, left_shiny, true)
	stage.set_combatant(1, species, right_shiny, true)
	var identities := [species + ("@shiny" if left_shiny else ""), species + ("@shiny" if right_shiny else "")]
	var deadline := Time.get_ticks_msec() + 30000
	while not stage.active or stage.identities != identities or stage._models_pending():
		assert(Time.get_ticks_msec() < deadline, stage.reason)
		await process_frame
	await _frames(3)
	assert(stage.failed_models.is_empty() and stage.packed.size() <= 2)
	assert(Cache.items.size() <= Cache.MAX_ENTRIES and Cache.source_bytes <= Cache.MAX_SOURCE_BYTES)
	for identity in identities:
		assert(stage.placements[identity].calibrated and not stage.motion_clips[identity].is_empty())
	battle.player_hud_panel.set_pokemon_data(species.capitalize(), 100, 100, 100)
	battle.enemy_hud_panel.set_pokemon_data(species.capitalize(), 100, 100, 100)
	await create_timer(0.2).timeout
	assert(not battle.player_hud_panel.get_global_rect().intersects(stage._visual_rect(0)))
	assert(not battle.enemy_hud_panel.get_global_rect().intersects(stage._visual_rect(1)))


func _run() -> void:
	var catalog := OS.get_environment("POKEAETHER_BATCH01_RUNTIME_CATALOG")
	var output := OS.get_environment("POKEAETHER_BATCH01_STRESS_OUTPUT")
	var names: Array[String] = []
	var requested := OS.get_environment("POKEAETHER_BATCH01_STRESS_NAMES")
	if requested.is_empty():
		for name: String in NAMES:
			names.append(name)
	else:
		for name: String in requested.split(",", false):
			assert(not name.is_empty() and name == name.strip_edges() and name not in names)
			names.append(name)
	assert(not names.is_empty())
	assert(catalog.is_absolute_path() and output.is_absolute_path())
	var settings := root.get_node("SettingsManager")
	settings.battle_3d_catalog_path = catalog
	settings.battle_3d_camera_motion = false
	settings.battle_ui_layout = "immersive"
	root.size = Vector2i(1280, 720)
	Cache.clear()
	var report := {"schema": 1, "runtime_approved": false, "release_approved": false,
		"screenshots_enabled": false, "catalog_sha256": FileAccess.get_sha256(catalog), "rounds": []}
	report["species"] = names
	for cycle in 3:
		settings.battle_presentation_mode = "3d"
		settings.battle_3d_arena = "stadium" if cycle == 1 else "classic"
		host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
		battle = load("res://scenes/battle/battle.tscn").instantiate()
		root.add_child(host)
		host.mount(battle)
		var old_stage = battle.animation_router.model_presenter
		var position: int = old_stage.get_index()
		old_stage.free()
		stage = Candidate.new()
		stage.use_runtime_registry = true
		stage.name = "ExperimentalBattle3D"
		battle.battle_stage.add_child(stage)
		battle.battle_stage.move_child(stage, position)
		stage.setup([battle.player_sprite_box, battle.enemy_sprite_box],
			[battle.player_battle_platform, battle.enemy_battle_platform])
		battle.animation_router.model_presenter = stage
		var round_data := {"arena": settings.battle_3d_arena, "pairs": 0, "faint_replacements": 0}
		frame_samples.clear()
		frame_stalls.clear()
		frame_tick = Time.get_ticks_usec()
		sample = true
		for species in names:
			await _ready_pair(species, false, true)
			context = "action " + species
			assert(stage.actors[0] != stage.actors[1] and stage.players[0] != stage.players[1])
			stage.start_action("p2", "special_attack")
			assert(stage.current_actions[1] == "special_attack")
			stage.cancel_actions()
			stage.play_action("p2", "faint_start")
			stage.players[1].advance(100.0)
			await _frames(4)
			assert(stage.lifecycle[1] == "fainted" and stage.current_actions[1] == "faint_loop")
			stage.set_combatant(1, species, true, true)
			await _frames(4)
			assert(stage.lifecycle[1] == "idle")
			await _ready_pair(species, true, false)
			round_data.pairs += 1
			round_data.faint_replacements += 1
		round_data.retained_source_bytes = Cache.source_bytes
		sample = false
		frame_samples.sort()
		round_data.frame_p95_ms = frame_samples[int(frame_samples.size() * 0.95)]
		round_data.frame_max_ms = frame_samples[-1]
		round_data.frame_samples = frame_samples.size()
		round_data.stalls_over_50ms = frame_stalls.duplicate(true)
		round_data.load_spans = stage.load_spans.duplicate(true)
		var actor_ref: WeakRef = weakref(stage.actors[0])
		var viewport_ref: WeakRef = weakref(stage.viewport)
		host.release()
		host.queue_free()
		await _frames(5)
		assert(actor_ref.get_ref() == null and viewport_ref.get_ref() == null)
		round_data.static_bytes = OS.get_static_memory_usage()
		report.rounds.append(round_data)
		print("BATCH01_STRESS_ROUND ", cycle, " pairs=", round_data.pairs, " p95=", round_data.frame_p95_ms)
	Cache.clear()
	assert(Cache.items.is_empty() and Cache.source_bytes == 0)
	report.complete = true
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("BATCH01_STRESS_OK")
	quit()
