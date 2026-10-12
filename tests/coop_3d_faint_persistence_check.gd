extends "res://tests/battle_3d_faint_replacement_check.gd"
## Exercise the actual four-slot presenter, events, snapshots and reconnects.

func _run() -> void:
	await process_frame
	root.size = Vector2i(1920, 1080)
	var settings: Node = root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_catalog_path = ""
	settings._manual_model_catalog_this_session = true
	OS.unset_environment("POKEAETHER_3D_STAGE_REPORT")
	OS.unset_environment("POKEAETHER_MODEL_CATALOG")
	var service: Node = root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	service.activity = {"activityId": "wild_route_1", "status": "active"}
	for participant: String in ["p1", "p3"]:
		for animations: bool in [true, false]:
			settings.battle_animations = animations
			for loop_pose: bool in [true, false]:
				await _check_wild_faints(participant, loop_pose)
	await _check_reconnect_and_capture()
	service.reset()
	print("coop_3d_faint_persistence_check: ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)

func _coop_fixture(loop_pose := true) -> Variant:
	var battle: Variant = _battle()
	assert(battle.setup_coop_battle())
	var model: Node = battle.animation_router.model_presenter
	for species: String in ["dragonite", "pikachu", "arcanine"]:
		_seed_faint_model(model, species, loop_pose)
	return battle

func _snapshot(participant := "p1") -> Dictionary:
	return {"participant": participant, "turn": 1, "opponentPartySize": 2,
		"positions": [
			{"controller": "p1", "details": "Dragonite, L5", "hpPercent": 100},
			{"controller": "p3", "details": "Dragonite, L5", "hpPercent": 100},
			{"controller": "p2", "details": "Pikachu, L5", "hpPercent": 100},
			{"controller": "p4", "details": "Arcanine, L5", "hpPercent": 100}],
		"ownTeam": [{"species": "Dragonite", "hp": 20, "maxHp": 20, "active": true}],
		"events": []}

func _check_wild_faints(participant: String, loop_pose: bool) -> void:
	var battle: Variant = _coop_fixture(loop_pose)
	var panel: Node = battle.coop_presenter
	var model: Node = battle.animation_router.model_presenter
	var snapshot := _snapshot(participant)
	panel._latest = snapshot
	panel._apply_positions(snapshot)
	for frame in 6: await process_frame
	_check(model.active and model.handles("p2") and model.handles("p4"), "all four models are ready")
	var first_actor: WeakRef = weakref(model.actors[1])
	var second_actor: WeakRef = weakref(model.actors[3])
	var ball_cues: Array[String] = []
	model.ball_cue.connect(func(_controller: String, cue: String): ball_cues.append(cue))
	await panel._animate_event({"kind": "faint", "actor": "p2"})
	snapshot.positions[2].fainted = true
	snapshot.positions[2].hpPercent = 0
	panel._apply_positions(snapshot)
	for frame in 4: await process_frame
	_check_lying(model, "p2", first_actor.get_ref())
	_check(model.handles("p4") and model.actors[3].visible and model.lifecycle[3] == "idle",
		"the surviving wild Pokémon keeps its standing model")
	_check(not panel._native_sprite("p2").visible, "the fainted 2D sprite stays hidden")
	# A subsequent turn/snapshot must not revive or erase the first faint.
	snapshot.turn = 2
	snapshot.positions[3].hpPercent = 65
	panel._apply_positions(snapshot)
	for frame in 4: await process_frame
	_check_lying(model, "p2", first_actor.get_ref())
	await panel._animate_event({"kind": "faint", "actor": "p4"})
	snapshot.positions[3].fainted = true
	snapshot.positions[3].hpPercent = 0
	snapshot.ended = true
	panel._apply_positions(snapshot)
	for frame in 4: await process_frame
	_check_lying(model, "p2", first_actor.get_ref())
	_check_lying(model, "p4", second_actor.get_ref())
	_check(ball_cues.is_empty(), "wild faints never recall or summon either wild Pokémon")
	battle.queue_free()
	await process_frame
	await process_frame
	_check(first_actor.get_ref() == null and second_actor.get_ref() == null, "closing the battle releases both fainted models")

func _check_reconnect_and_capture() -> void:
	var battle: Variant = _coop_fixture()
	var panel: Node = battle.coop_presenter
	var model: Node = battle.animation_router.model_presenter
	var snapshot := _snapshot()
	snapshot.positions[2].fainted = true
	snapshot.positions[2].hpPercent = 0
	panel._latest = snapshot
	panel._apply_positions(snapshot) # No faint event or actor yet: reconnect.
	for frame in 8: await process_frame
	_check_lying(model, "p2", model.actors[1])
	# Captures also use a 0-HP/fainted server slot, but must stay off the field.
	snapshot.events = [{"kind": "coopcapture", "target": "p2", "caught": true}]
	panel._apply_positions(snapshot)
	for frame in 4: await process_frame
	_check(model.combatants[1].species == "" and not model.handles("p2"), "caught Pokémon never appear as fainted models on reconnect")
	# A Trainer's replacement may have the same species as the fainted actor.
	snapshot.positions[0].fainted = true
	snapshot.positions[0].hpPercent = 0
	panel._apply_positions(snapshot)
	for frame in 4: await process_frame
	_check_lying(model, "p1", model.actors[0])
	root.get_node("SettingsManager").battle_animations = true
	await panel._animate_event({"kind": "switch", "actor": "p1", "details": "Dragonite, L5"})
	await panel._prepare_model_roster()
	_check(model.lifecycle[0] == "idle" and absf(model.actors[0].rotation.z) < 0.01,
		"a same-species Trainer replacement never inherits the old faint snapshot")
	# An accepted capture must also remain hidden when a later sparse snapshot
	# no longer includes that capture event.
	root.get_node("SettingsManager").battle_animations = false
	await panel._animate_event({"kind": "coopcapture", "actor": "p3", "target": "p4", "caught": true})
	snapshot.events = []
	snapshot.positions[3].fainted = true
	snapshot.positions[3].hpPercent = 0
	panel._apply_positions(snapshot)
	for frame in 4: await process_frame
	_check(model.combatants[3].species == "" and not model.handles("p4"), "an accepted capture stays hidden across sparse snapshots")
	root.get_node("SettingsManager").battle_presentation_mode = "2d"
	snapshot.events = []
	panel._apply_positions(snapshot)
	_check(not panel._native_sprite("p2").visible, "2D keeps its existing fainted-sprite visibility")
	battle.queue_free()
	await process_frame
	await process_frame

func _check_lying(model: Node, controller: String, expected: Object) -> void:
	_check(model.handles(controller), "fainted " + controller + " retains its 3D model")
	if not model.handles(controller): return
	var index: int = model.actor_index(controller)
	_check(model.actors[index] == expected and model.actors[index].visible and model.lifecycle[index] == "fainted",
		"fainted " + controller + " remains visible in the same slot")
	_check(absf(model.actors[index].rotation.z - PI * 0.5) < 0.01, "fainted " + controller + " holds the lying pose")
