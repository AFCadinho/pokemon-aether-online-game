extends Node

const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.json")
const Timing = preload("res://scripts/battle/battle_3d_move_timing.gd")
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
# Compile the actual batch integration as part of this runtime check.
const Battle = preload("res://scripts/battle/battle.gd")

class SlowRouter extends BattleAnimationRouter:
	var delay := 0.0
	func _start_3d_audio(kind: String, key: String, plan: Dictionary = {}, begin_immediately := true) -> Node:
		if delay > 0:
			await model_presenter.get_tree().create_timer(delay).timeout
		return await super._start_3d_audio(kind, key, plan, begin_immediately)

class ActionPanel extends CurrentActionPanel:
	func set_message(_message: String) -> void:
		pass

class SpriteReactionRouter extends BattleAnimationRouter:
	var observe_damage: Callable
	func play_damage_tween_for_target(_target: String, _variant := "normal") -> void:
		observe_damage.call()

var stage: Node
var router: SlowRouter
var renderer: BattleEventRenderer
var hp_samples: Array = []
var move_done := false
var stats: Array = []
var attack_done := false

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
		"actor_position": stage.players[0].current_animation_position, "at": Time.get_ticks_msec()})

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
	if router.delay > 0:
		await get_tree().create_timer(router.delay * 0.5).timeout
		assert(stage.current_actions[0] == "idle", "Cold audio must prepare before native motion starts")
	var observed_audio: Node
	while not move_done:
		if not router.active_audio_nodes.is_empty():
			observed_audio = router.active_audio_nodes[0]
		await get_tree().process_frame
	assert(stage.players[0].is_playing(), "Move must release events at impact, before recovery ends")
	assert(is_equal_approx(stage.players[0].get_playing_speed(), 1.5))
	assert(stage.players[0].current_animation_position >= float(pilot.impact_frame) / 60.0)
	assert(is_instance_valid(observed_audio) and observed_audio.draining)
	assert(observed_audio.cursor == observed_audio.plan.cues.size(), "All reviewed cues must dispatch by impact")
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
	for action in ["idle", "sleep", "faint_start", "faint_loop"]:
		assert(ActionMap.presentation_speed(action) == 1.0)
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
	var audio: Node = router.active_audio_nodes[0]
	assert(audio.cursor == 1, "Startup cue precedes the impact cue")
	_set_replay_speed(0)
	var position: float = stage.players[0].current_animation_position
	await get_tree().create_timer(0.15).timeout
	assert(not move_done and is_equal_approx(stage.players[0].current_animation_position, position))
	assert(audio.cursor == 1, "Paused native motion must not dispatch the hit early")
	for sound: AudioStreamPlayer in audio.players.values():
		assert(sound.stream_paused and is_equal_approx(sound.pitch_scale, 1.0))
	_set_replay_speed(2)
	while not move_done:
		await get_tree().process_frame
	assert(audio.cursor == 2 and audio.draining and router.has_3d_impact_damage())
	assert(is_equal_approx(stage.players[0].get_playing_speed(), 3.0))
	await renderer.render_event({"type": "damage"}, {"damage_target_ident": "p2"})
	_set_replay_speed(1)
	router.cancel_render()
	await get_tree().process_frame

func _cold_attack() -> void:
	await router.play_attack_tween_for_actor("p1", "Thunderbolt")
	attack_done = true

func _cold_cancel_check() -> void:
	_actor(0, "pikachu")
	router.delay = 0.12
	attack_done = false
	_cold_attack()
	await get_tree().create_timer(0.03).timeout
	router.cancel_render()
	while not attack_done:
		await get_tree().process_frame
	assert(stage.current_actions[0] == "idle", "Cancelled preparation must not restart an attack")
	assert(router.active_audio_nodes.is_empty() and router.prepared_move_audio.is_empty())
	router.delay = 0

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

func _run() -> void:
	_selection_checks()
	SettingsManager.battle_animations = true
	stage = Stage.new()
	add_child(stage)
	stage.set_process(false)
	stage.active = true
	router = SlowRouter.new()
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
	router.delay = 0.12
	await _case("pikachu", "Thunderbolt")
	router.delay = 0
	await _case("pikachu", "Tackle")
	await _case("blastoise", "Ice Beam")
	await _clock_checks()
	await _cold_cancel_check()
	await _sprite_hp_check()
	# Cancellation must release an impact recovery and any playing audio tails.
	_actor(0, "pikachu")
	_actor(1, "pikachu")
	await router.play_attack_tween_for_actor("p1", "Thunderbolt")
	await router.play_move_animation("Thunderbolt", "p1", "p2", {"stop_at_impact": true})
	assert(router.has_3d_impact_damage())
	var tails: Array = router.active_audio_nodes.duplicate()
	router.cancel_render()
	assert(not router.has_3d_impact_damage() and router.active_audio_nodes.is_empty())
	for tail: Node in tails:
		for sound: AudioStreamPlayer in tail.players.values():
			assert(not sound.playing)
	router.release_threaded_resource_requests()
	renderer = null
	router = null
	stage.queue_free()
	panel.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_3D_IMPACT_PACING_OK ", JSON.stringify(stats))
	get_tree().quit()
