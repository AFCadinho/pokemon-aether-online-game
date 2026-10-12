extends "res://tests/coop_3d_faint_persistence_check.gd"
## Real singles/doubles routes, plus a delayed offline download and recall clock.

class DelayedStage:
	extends "res://scripts/battle/battle_ui/experimental_battle_3d.gd"
	var downloads := 0
	var provide_model: Callable
	var optional_import_frames := 0
	func _models_pending() -> bool:
		return optional_import_frames > 0 or super._models_pending()
	func _import_next_model() -> void:
		if optional_import_frames > 0:
			optional_import_frames -= 1
		else:
			super._import_next_model()
	func _ensure_downloaded_models(_preserve_actors := false, _preview_generation := -1) -> void:
		downloads += 1
		for frame in 5: await get_tree().process_frame
		provide_model.call()

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
		for side: String in ["p1", "p2"]:
			await _check_single_switch(side)
	var service: Node = root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	service.activity = {"activityId": "wild_route_1", "status": "active"}
	settings.battle_ui_layout = "immersive"
	for controller: String in ["p1", "p2", "p3", "p4"]:
		await _check_double_switch(controller)
	service.reset()
	await _check_cold_preparation()
	await _check_recall_tail()
	print("battle_3d_switch_transition_check: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)

func _watch_switch(stage: Node, side: String, incoming: String) -> Dictionary:
	var index: int = stage.actor_index(side)
	var state := {"recalling": false, "hidden_frame": -1, "throw_frame": -1, "released": false, "cues": []}
	var monitor := func():
		if not state.recalling: return
		if not stage.actor_shown[index] and state.hidden_frame < 0:
			state.hidden_frame = Engine.get_process_frames()
		if stage.identities[index] == incoming and not state.released:
			_check(not stage.actors[index].visible, "replacement stays hidden before ball release")
	var cue_listener := func(controller: String, cue: String):
		if controller != side: return
		state.cues.append(cue)
		if state.cues.size() == 1:
			state.recalling = true
			_check(stage.packed.has(incoming), "incoming model is prepared before recall begins")
		if cue == "summon_throw": state.throw_frame = Engine.get_process_frames()
		if cue == "cry": state.released = true
	process_frame.connect(monitor)
	stage.ball_cue.connect(cue_listener)
	state.monitor = monitor
	state.listener = cue_listener
	return state

func _finish_watch(stage: Node, state: Dictionary) -> void:
	process_frame.disconnect(state.monitor)
	stage.ball_cue.disconnect(state.listener)
	_check(state.cues == ["summon_release", "summon_throw", "summon_release", "cry"], "exactly one recall and summon")
	_check(state.hidden_frame >= 0 and state.throw_frame - state.hidden_frame <= 2,
		"summon starts within two frames of absorption, without a closing/loading pause")

func _check_single_switch(side: String) -> void:
	var battle: Variant = _battle()
	battle.battle_type = battle.BattleType.TRAINER
	battle.training_ai_battle = true
	battle.battle_state.load_from_api_response(_battle_response(), false)
	var stage: Node = battle.animation_router.model_presenter
	for species: String in ["dragonite", "pikachu"]: _seed_faint_model(stage, species, true)
	battle._update_active_sprites()
	for frame in 4: await process_frame
	_seed_faint_model(stage, "arcanine", true)
	var state := _watch_switch(stage, side, "arcanine")
	var ident: String = battle.battle_state.get_active_player_pokemon(side).ident
	await battle._render_battle_events([{
		"type": "switch", "player": side, "fromIdent": ident,
		"pokemon": side + ": Arcanine", "species": "Arcanine",
		"details": "Arcanine, L5", "condition": "20/20", "hp": 20, "maxHp": 20, "metadataSlot": 2,
	}], false, "offline_smooth_switch", true)
	_finish_watch(stage, state)
	_check(stage.handles(side) and stage.lifecycle[stage.actor_index(side)] == "idle", "single switch completes in 3D")
	battle.queue_free()
	await process_frame
	await process_frame

func _check_double_switch(controller: String) -> void:
	var battle: Variant = _coop_fixture()
	var panel: Node = battle.coop_presenter
	var stage: Node = battle.animation_router.model_presenter
	var snapshot := _snapshot()
	panel._latest = snapshot
	panel._apply_positions(snapshot)
	for frame in 6: await process_frame
	var incoming := "arcanine" if controller in ["p1", "p3"] else "dragonite"
	var state := _watch_switch(stage, controller, incoming)
	await panel._animate_event({"kind": "switch", "actor": controller, "details": incoming.capitalize() + ", L5"})
	_finish_watch(stage, state)
	_check(stage.handles(controller) and stage.lifecycle[stage.actor_index(controller)] == "idle", "double switch completes in 3D")
	battle.queue_free()
	await process_frame
	await process_frame

func _check_cold_preparation() -> void:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	root.add_child(host)
	var stage := DelayedStage.new()
	host.add_child(stage)
	stage.setup()
	stage.loaded_path = ""
	stage.catalog_problem = ""
	for species: String in ["dragonite", "pikachu"]: _seed_faint_model(stage, species, true)
	stage.set_combatant(0, "Dragonite")
	stage.set_combatant(1, "Pikachu")
	for frame in 6: await process_frame
	var outgoing: Node = stage.actors[0]
	stage.provide_model = func(): _seed_faint_model(stage, "arcanine", true)
	stage.stage_switch_model("p1", "Arcanine")
	for frame in 3:
		await process_frame
		_check(stage.actors[0] == outgoing and outgoing.visible, "cold preparation keeps outgoing model on field")
	await stage.await_switch_model("p1")
	_check(stage.downloads == 1 and stage.packed.has("arcanine"), "cold incoming model is downloaded once")
	await stage.recall("p1")
	stage.set_combatant(0, "Arcanine")
	stage.set_actor_shown(0, false)
	stage.optional_import_frames = 8
	await stage.await_switch_actor("p1")
	_check(stage.handles("p1") and stage.downloads == 1, "replacement readiness does not recheck bundles")
	_check(stage.optional_import_frames > 0, "optional future forms do not delay the prepared replacement")
	await stage.send_out("p1")
	stage.stage_switch_model("p1", "Definitely Missing Species")
	await stage.await_switch_model("p1")
	_check(stage.staged_switch_species[0] == "" and stage.handles("p1"), "unsupported input does not disturb the actor")
	stage.provide_model = func(): _seed_faint_model(stage, "toxapex@shiny", true)
	stage.stage_switch_model("p1", "Toxapex", true)
	_check(stage.staged_switch_species[0] == "toxapex@shiny" and stage.switch_preparing[0], "staging preserves the public shiny variant")
	stage.cancel_actions()
	for frame in 7: await process_frame
	_check(stage.staged_switch_species[0] == "" and not stage.switch_preparing[0], "cancellation releases staged demand")
	_check(stage.identities[0] == "arcanine" and stage.actors[0].visible, "late preparation never swaps a cancelled actor")
	host.queue_free()
	await process_frame
	await process_frame

func _check_recall_tail() -> void:
	var effect: Node3D = load("res://scripts/battle/battle_ui/pokeball_effect_3d.gd").new()
	root.add_child(effect)
	var absorbed := [-1]
	effect.build(Vector3.ZERO, Vector3.UP, Vector3.ZERO, "poke-ball", func(): return 10000.0,
		func(amount: float, _offset: Vector3):
			if amount == 0.0: absorbed[0] = Engine.get_process_frames())
	_check(await effect.recall(), "native recall completes")
	_check(absorbed[0] == Engine.get_process_frames(), "ball closing adds no frames after full absorption")
	effect.queue_free()
	await process_frame
