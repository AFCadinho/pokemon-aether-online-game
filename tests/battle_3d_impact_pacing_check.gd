extends Node

const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.json")
const Timing = preload("res://scripts/battle/battle_3d_move_timing.gd")
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
# Compile the actual batch integration as part of this runtime check.
const Battle = preload("res://scripts/battle/battle.gd")

class RecordingRouter extends BattleAnimationRouter:
	var effects: Array = []
	var beats: Array = []
	func play_effect_animation(key: String, target: String = "", reveal: Callable = Callable()) -> void:
		beats.append("effect_start")
		await super.play_effect_animation(key,target,reveal)
		beats.append("effect_end")
	func play_attack_tween_for_actor(actor: String, move: String = "") -> void:
		beats.append("attack")
		await super.play_attack_tween_for_actor(actor,move)
	func play_damage_tween_for_target(target: String, variant: String = "normal") -> void:
		beats.append("damage")
		await super.play_damage_tween_for_target(target,variant)
	var damage_sounds: Array = []
	func _start_3d_audio(kind: String, key: String, plan: Dictionary = {}, begin_immediately := true) -> Node:
		assert(kind == "effect" or (kind == "move" and model_presenter.can_present_move(key)),
			"Move audio requires an available native move effect")
		var audio := await super._start_3d_audio(kind, key, plan, begin_immediately)
		assert(is_instance_valid(audio) and not audio.streams.is_empty(), "Shared effect sounds remain available")
		if kind == "effect": effects.append(key)
		return audio
	func _play_one_shot_sound(path: String) -> void:
		damage_sounds.append(path)
		super._play_one_shot_sound(path)

class ActionPanel extends CurrentActionPanel:
	func set_message(_message: String) -> void:
		pass

class SpriteReactionRouter extends BattleAnimationRouter:
	var observe_damage: Callable
	func play_damage_tween_for_target(_target: String, _variant := "normal") -> void:
		observe_damage.call()

var stage: Node
var router: RecordingRouter
var renderer: BattleEventRenderer
var hp_samples: Array = []
var move_done := false
var stats: Array = []
var attack_done := false
var faint_done := false
var faint_stats: Array = []

func _ready() -> void:
	_run.call_deferred()

func _actor(index: int, species: String) -> void:
	if is_instance_valid(stage.actors[index]):
		stage.actors[index].free()
	var actor := Node3D.new()
	stage.add_child(actor)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var library := AnimationLibrary.new()
	var profile: Dictionary = Registry.data.profiles[species]
	for action: String in profile.action_timing:
		var animation := Animation.new()
		animation.length = float(profile.action_timing[action].frames) / 60.0
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(".:rotation:y"))
		animation.track_insert_key(track, 0.0, 0.0)
		animation.track_insert_key(track, animation.length, 0.1)
		library.add_animation(action, animation)
	player.add_animation_library("", library)
	stage.actors[index] = actor
	stage.players[index] = player
	stage.identities[index] = species
	stage.combatants[index] = {"species": species, "shiny": false}
	stage.entries[species] = profile
	stage.current_actions[index] = "idle"
	stage.resting[index] = true
	stage.lifecycle[index] = "idle"

func _hp(_ident: String, _event: Dictionary, previous: bool) -> void:
	hp_samples.append({"previous": previous, "actor_playing": stage.players[0].is_playing(),
		"actor_position": stage.players[0].current_animation_position if not stage.players[0].current_animation.is_empty() else 0.0,
		"at": Time.get_ticks_msec()})

func _move(move: String, bridge := true) -> void:
	await renderer.render_event({"type": "move"}, {"attack_actor_ident": "p1", "move_animation_name": move,
		"move_animation_actor_ident": "p1", "move_animation_target_ident": "p2",
		"battle_message": "Used " + move, "3d_impact_bridge": bridge})
	move_done = true

func _case(species: String, move: String) -> void:
	_actor(0, species)
	_actor(1, "pikachu")
	move_done = false
	hp_samples.clear()
	var pilot: Dictionary = stage.move_timing(move, "p1")
	assert(not pilot.is_empty())
	var started := Time.get_ticks_msec()
	_move(move)
	assert(stage.current_actions[0] == pilot.action, "Native motion starts without move-audio preparation")
	while not move_done:
		assert(router.active_audio_nodes.is_empty())
		await get_tree().process_frame
	assert(stage.players[0].is_playing(), "Move must release events at impact, before recovery ends")
	# Pikachu's two-second native clip now uses the supported-VFX 1.25s cap.
	assert(is_equal_approx(stage.players[0].get_playing_speed(), 1.6 if move == "Thunderbolt" else ((407.5/60.0)/1.25 if move == "Ice Beam" else 1.5)))
	assert(stage.players[0].current_animation_position >= float(pilot.impact_frame) / 60.0)
	assert(router.active_audio_nodes.is_empty(), "Pilot sounds are also silent without move VFX")
	assert(not router.has_3d_impact_damage("p1") and router.has_3d_impact_damage("p2"))
	var impact_ms := Time.get_ticks_msec() - started
	# Neutral/effectiveness metadata stays ordered but must not delay the hit.
	await renderer.render_event({"type": "effectiveness"}, {"battle_message": "Super effective!"})
	await renderer.render_event({"type": "damage"}, {"damage_target_ident": "p2", "battle_message": "Lost HP"})
	assert(hp_samples.size() == 2 and hp_samples[0].previous and not hp_samples[1].previous)
	assert(hp_samples[1].actor_playing, "HP changes at impact while attacker recovers")
	assert(hp_samples[1].at - hp_samples[0].at < 20, "HP must not wait for the damage clip to finish")
	assert(not stage.players[0].is_playing() and not stage.players[1].is_playing(), "Next action must wait for both recoveries")
	assert(not router.has_3d_impact_damage())
	assert(router.damage_sounds[-1] == router.TAKE_DAMAGE_SOUND_PATH)
	stats.append({"species": species, "move": move, "impact_ms": impact_ms, "pair_ms": Time.get_ticks_msec() - started})
	router.cancel_render()
	await get_tree().process_frame

func _selection_checks() -> void:
	var move := {"type": "move", "actor": "p1", "target": "p2", "move": "Thunderbolt"}
	var hit := {"type": "damage", "target": "p2"}
	assert(Timing.damage_index([move, hit], 0) == 1)
	assert(Timing.damage_index([move, {"type": "criticalHit"}, {"type": "effectiveness"}, hit], 0) == 3)
	for boundary in ["miss", "fail", "immune", "status", "pokemonEffect", "heal", "switch", "drag", "turn"]:
		assert(Timing.damage_index([move, {"type": boundary}, hit], 0) == -1, boundary)
	assert(Timing.damage_index([move, hit, hit], 0) == -1, "Multi-hit uses the complete ordered route")
	assert(Timing.damage_index([move, {"type": "damage", "target": "p1"}], 0) == -1)
	assert(Timing.damage_index([move, {"type": "damage", "target": "p2", "source": "brn"}], 0) == -1)
	assert(Timing.damage_index([move, {"type": "move"}, hit], 0) == -1)
	var profile: Dictionary = Registry.data.profiles.pikachu.action_timing
	var pilot: Dictionary = Timing.profile("pikachu@shiny", "Thunderbolt", "special_attack", profile)
	assert(not pilot.is_empty())
	assert(Timing.profile("dragonite", "Thunderbolt", "special_attack", profile).is_empty())
	assert(Timing.profile("pikachu", "Thunderbolt", "physical_attack", profile).is_empty())
	var catalog = preload("res://scripts/battle/animations/battle_audio_catalog.gd").new()
	var source: Dictionary = catalog.get_plan("move", "thunderbolt")
	var original := source.duplicate(true)
	var native: Dictionary = Timing.audio_plan(source, pilot)
	assert(source == original and native.native_clock and native.cues.size() == 2)
	assert(native.cues[0].event.name == "PRSFX- Thunderbolt2.wav" and native.cues[0].at_seconds == 20.0 / 60.0)
	assert(native.cues[1].event.name == "PRSFX- Thunderbolt1.wav" and native.cues[1].at_seconds == 48.0 / 60.0)
	source.cues.append({"at_seconds": 1, "event": {"name": "unreviewed"}})
	assert(Timing.audio_plan(source, pilot) == source, "A new sound must not be silently discarded")
	for action in ["idle", "sleep", "faint_loop"]:
		assert(ActionMap.presentation_speed(action) == 1.0)
	assert(ActionMap.presentation_speed("faint_start") == 2.0)
	# Apply the policy to every reviewed clip while retaining the registry's
	# full frame span and loop policy. Effective duration includes native speed.
	for species: String in Registry.data.profiles:
		var timing: Dictionary = Registry.data.profiles[species].action_timing
		var available := PackedStringArray(timing.keys())
		var faint: Dictionary = ActionMap.resolve("faint_start", available, timing)
		if faint.is_empty():
			continue
		var native_seconds: float = faint.duration / faint.speed
		var speed := ActionMap.presentation_speed("faint_start", native_seconds)
		assert(speed >= 2.0 and native_seconds / speed <= ActionMap.FAINT_MAX_SECONDS + 0.000001, species)
		assert(not faint.loop, "Reviewed faint-start clips must complete before their resting pose")
	var faster_native := ActionMap.resolve("faint_start", PackedStringArray(["faint_start"]), {
		"faint_start": {"frames": 480.0, "speed": 2.0, "loop": false}})
	var faster_seconds: float = faster_native.duration / faster_native.speed
	assert(is_equal_approx(faster_seconds / ActionMap.presentation_speed("faint_start", faster_seconds), 1.25))
	for action in ["physical_attack", "physical_attack_2", "special_attack", "damage"]:
		assert(ActionMap.presentation_speed(action) == 1.5)

func _set_replay_speed(speed: float) -> void:
	router.playback_speed = speed
	renderer.playback_speed = speed
	# The isolated stage disables its scene/catalog process. Mirror its usual
	# per-frame player speed update without loading a world or models.
	for player: AnimationPlayer in stage.players:
		if is_instance_valid(player):
			player.speed_scale = stage.playback_speed

func _clock_checks() -> void:
	_actor(0, "pikachu")
	_actor(1, "pikachu")
	move_done = false
	_move("Thunderbolt")
	while stage.players[0].current_animation_position < 0.38:
		await get_tree().process_frame
	_set_replay_speed(0)
	var position: float = stage.players[0].current_animation_position
	await get_tree().create_timer(0.15).timeout
	assert(not move_done and is_equal_approx(stage.players[0].current_animation_position, position))
	assert(router.active_audio_nodes.is_empty())
	_set_replay_speed(2)
	while not move_done:
		await get_tree().process_frame
	assert(router.active_audio_nodes.is_empty() and router.has_3d_impact_damage())
	assert(is_equal_approx(stage.players[0].get_playing_speed(), 3.2))
	await renderer.render_event({"type": "damage"}, {"damage_target_ident": "p2"})
	_set_replay_speed(1)
	router.cancel_render()
	await get_tree().process_frame

func _next_attack() -> void:
	await router.play_attack_tween_for_actor("p1", "Outrage")
	attack_done = true

func _recovery_cancel_check() -> void:
	_actor(0, "pikachu")
	_actor(1, "pikachu")
	await router.play_move_animation("Thunderbolt", "p1", "p2", {"stop_at_impact": true})
	attack_done = false
	_next_attack()
	assert(not attack_done, "Next attack must wait for pending recovery")
	await get_tree().create_timer(0.03).timeout
	router.cancel_render()
	while not attack_done:
		await get_tree().process_frame
	assert(stage.current_actions[0] == "idle", "Cancelled recovery must not restart an attack")
	assert(router.active_audio_nodes.is_empty() and router.prepared_moves.is_empty())

func _unreviewed_move_check() -> void:
	_actor(0, "garchomp")
	_actor(1, "pikachu")
	move_done = false
	assert(stage.move_timing("Dragon Tail", "p1").is_empty())
	_move("Dragon Tail", false)
	assert(stage.current_actions[0] == "physical_attack")
	while not move_done:
		assert(router.active_audio_nodes.is_empty())
		await get_tree().process_frame
	assert(not stage.players[0].is_playing() and not router.has_3d_impact_damage())
	assert(not router.audio_catalog.catalogs.has("move"), "Unreviewed source clocks must not prolong native attacks")

func _shared_effect_checks() -> void:
	await router.play_damage_tween_for_target("p2", "super_effective")
	assert(router.damage_sounds[-1] == router.SUPER_EFFECTIVE_DAMAGE_SOUND_PATH)
	await router.play_heal_presentation_for_target("p2", "health_up")
	await router.play_stat_change_presentation_for_target("p2", 1)
	await router.play_stat_change_presentation_for_target("p2", -1)
	assert(router.effects == ["health_up", "stat_up", "stat_down"])
	# Shared samples may outlive their short native event without serial waits.
	while not router.active_audio_nodes.is_empty():
		await get_tree().process_frame
	assert(router.active_audio_nodes.is_empty() and not router.audio_catalog.catalogs.has("move"))

func _sprite_hp_check() -> void:
	var sprite_router := SpriteReactionRouter.new()
	hp_samples.clear()
	sprite_router.observe_damage = func():
		assert(hp_samples.size() == 1 and hp_samples[0].previous, "2D keeps its HP-after-reaction boundary")
	renderer.animation_router = sprite_router
	await renderer.render_event({"type": "damage"}, {"damage_target_ident": "p2"}, true)
	assert(hp_samples.size() == 2 and not hp_samples[1].previous)
	renderer.animation_router = router
	sprite_router.observe_damage = Callable()

func _faint() -> void:
	await renderer.render_event({"type": "faint"}, {"faint_target_ident": "p1", "battle_message": "Fainted"})
	faint_done = true

func _faint_case(species: String, with_loop := true) -> void:
	_actor(0, species)
	if not with_loop:
		stage.players[0].get_animation_library("").remove_animation("faint_loop")
	hp_samples.clear()
	faint_done = false
	var native_seconds: float = stage.players[0].get_animation("faint_start").length
	var spec: Dictionary = Registry.data.profiles[species].action_timing.faint_start
	native_seconds /= float(spec.speed)
	var speed := ActionMap.presentation_speed("faint_start", native_seconds)
	var started := Time.get_ticks_msec()
	_faint()
	assert(hp_samples.size() == 1 and not hp_samples[0].previous, "Final HP precedes the faint motion")
	assert(stage.current_actions[0] == "faint_start" and stage.lifecycle[0] != "fainted")
	assert(is_equal_approx(stage.players[0].get_playing_speed(), float(spec.speed) * speed))
	while not faint_done:
		assert(stage.actors[0].visible, "The next event must await the visible faint movement")
		await get_tree().process_frame
	assert(stage.lifecycle[0] == "fainted" and stage.actors[0].visible)
	if with_loop:
		assert(stage.current_actions[0] == "faint_loop" and stage.players[0].is_playing())
		assert(stage.players[0].get_playing_speed() == float(Registry.data.profiles[species].action_timing.faint_loop.speed))
	else:
		assert(stage.current_actions[0] == "faint_start" and not stage.players[0].is_playing())
	# HP/HUD refreshes cannot revive the completed model into idle.
	stage.start_action("p1", "idle")
	assert(stage.lifecycle[0] == "fainted" and stage.current_actions[0] in ["faint_start", "faint_loop"])
	faint_stats.append({"species": species, "native_seconds": native_seconds,
		"motion_seconds": native_seconds / speed, "event_ms": Time.get_ticks_msec() - started, "loop": with_loop})

func _faint_pause_cancel_check() -> void:
	_actor(0, "pikachu")
	faint_done = false
	_faint()
	await get_tree().process_frame
	_set_replay_speed(0)
	var position: float = stage.players[0].current_animation_position
	await get_tree().create_timer(0.15).timeout
	assert(not faint_done and is_equal_approx(stage.players[0].current_animation_position, position))
	_set_replay_speed(2)
	assert(stage.players[0].get_playing_speed() == 4.0)
	while not faint_done:
		await get_tree().process_frame
	assert(stage.lifecycle[0] == "fainted" and stage.players[0].get_playing_speed() == 2.0)
	_set_replay_speed(1)
	_actor(0, "pikachu")
	faint_done = false
	_faint()
	await get_tree().process_frame
	renderer.cancel_render()
	while not faint_done:
		await get_tree().process_frame
	assert(stage.lifecycle[0] != "fainted" and stage.current_actions[0] == "idle", "Cancelled faint must not install a stale faint pose")

func _run() -> void:
	_selection_checks()
	SettingsManager.battle_animations = true
	stage = Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.active = true
	router = RecordingRouter.new()
	router.model_presenter = stage
	router.animation_parent = stage
	var panel := ActionPanel.new()
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	var label := Label.new()
	label.name = "CurrentActionLabel"
	margin.add_child(label)
	panel.add_child(margin)
	add_child(panel)
	renderer = BattleEventRenderer.new()
	renderer.setup(null, null, panel, router, BattleMessageTiming.new(), stage, _hp)
	await _case("pikachu", "Thunderbolt")
	await _case("pikachu", "Tackle")
	await _case("blastoise", "Ice Beam")
	await _clock_checks()
	await _recovery_cancel_check()
	await _unreviewed_move_check()
	await _shared_effect_checks()
	await _gem_order_check()
	await _sprite_hp_check()
	await _faint_case("pikachu")
	await _faint_case("blastoise")
	await _faint_case("volbeat")
	await _faint_case("pikachu", false)
	await _faint_pause_cancel_check()
	# Cancellation must release an impact recovery without any move sound nodes.
	_actor(0, "pikachu")
	_actor(1, "pikachu")
	await router.play_attack_tween_for_actor("p1", "Thunderbolt")
	await router.play_move_animation("Thunderbolt", "p1", "p2", {"stop_at_impact": true})
	assert(router.has_3d_impact_damage())
	router.cancel_render()
	assert(not router.has_3d_impact_damage() and router.active_audio_nodes.is_empty() and router.prepared_moves.is_empty())
	router.release_threaded_resource_requests()
	renderer = null
	router = null
	stage.queue_free()
	panel.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_3D_IMPACT_PACING_OK ", JSON.stringify(stats))
	print("BATTLE_3D_FAINT_PACING_OK ", JSON.stringify(faint_stats))
	get_tree().quit()


func _gem_order_check() -> void:
	_actor(0,"pikachu")
	_actor(1,"pikachu")
	stage.world = Node3D.new()
	stage.add_child(stage.world)
	var presenter := BattleEventPresentation.new()
	presenter.setup(BattleEventTextFormatter.new(),BattleHpEventHelper.new(),func(ident: String, _prefix: bool): return ident,func(ident: String): return ident)
	for spec in [["Ground Gem","Earthquake"],["Electric Gem","Thunderbolt"]]:
		var source := [
			{"type":"move","actor":"p1","target":"p2","move":spec[1]},
			{"type":"item","target":"p1","item":spec[0],"state":"end","source":"gem"},
			{"type":"damage","target":"p2","previousCondition":"100/100","condition":"70/100","damagePercent":30.0},
		]
		var ordered: Array = Battle.BATTLE_GEM_EVENT_ORDER.before_moves(source)
		router.beats.clear()
		presenter.reset()
		for index in ordered.size():
			var event: Dictionary = ordered[index]
			var presentation: Dictionary = presenter.build(event)
			for key in ["pre_log_message","log_message","battle_message"]: presentation[key] = ""
			presentation.add_blank_after = false
			if event.type == "move":
				assert(router.beats == ["effect_start","effect_end"],"Gem visual and sound finish before attacking")
				presentation["3d_impact_bridge"] = Timing.damage_index(ordered,index) >= 0
			await renderer.render_event(event,presentation,true)
		assert(router.beats == ["effect_start","effect_end","attack","damage"],str(router.beats))
		assert(router.effects[-1] == "use_item" and not router.has_3d_impact_damage())
	stage.world.queue_free()
	stage.world = null
	print("GEM_BEFORE_ATTACK_OK ground_and_electric=true")
