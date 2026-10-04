extends Node
# Developer-only pacing probe: real renderer/router/presenter clocks, synthetic actors.
# Excludes model loading, skeletal geometry, arena rendering, networking and AI.
# Uses a fixed 0.4 s trainer callout; the game uses 0.4–0.62 s when shown.
# Run the companion scene through slot-env. Output remains in ignored .tmp.
const Model = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.json")
class ProbePanel extends CurrentActionPanel:
	func set_message(_message: String) -> void:
		pass
var presenter: Node
var router: BattleAnimationRouter
var renderer: BattleEventRenderer
var panel: ProbePanel
var output: Array = []
var hp_marks: Array = []
func _ready() -> void:
	_run.call_deferred()
func _command(_command: Dictionary) -> Dictionary:
	return {"shown": true, "minimum_read_seconds": .4}
func _hp(_ident: String, _event: Dictionary, previous: bool) -> void:
	hp_marks.append({"previous":previous,"at_ms":Time.get_ticks_msec()})
func _actor(index: int, species: String) -> void:
	if is_instance_valid(presenter.actors[index]):
		presenter.actors[index].free()
	var actor := Node3D.new()
	presenter.add_child(actor)
	var player := AnimationPlayer.new()
	actor.add_child(player)
	var library := AnimationLibrary.new()
	var profile: Dictionary = Registry.data.profiles[species]
	for action: String in profile.action_timing:
		var spec: Dictionary = profile.action_timing[action]
		var animation := Animation.new()
		animation.length = float(spec.frames)/60.0
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath(".:rotation:y"))
		animation.track_insert_key(track,0.0,0.0)
		animation.track_insert_key(track,animation.length,0.1)
		library.add_animation(action,animation)
	player.add_animation_library("",library)
	presenter.actors[index] = actor
	presenter.players[index] = player
	presenter.identities[index] = species
	presenter.combatants[index] = {"species":species,"shiny":false}
	presenter.entries[species] = profile
	presenter.current_actions[index] = "idle"
	presenter.resting[index] = true
	presenter.lifecycle[index] = "idle"
func _sample(species: String, target: String, move: String) -> void:
	_actor(0,species)
	_actor(1,target)
	var audio: Node = await router._start_3d_audio("move",move.to_lower().replace(" ",""))
	router._release_3d_audio(audio)
	hp_marks.clear()
	var started := Time.get_ticks_msec()
	await renderer.render_event({"type":"move"},{"battle_message":"used " + move,
		"attack_actor_ident":"p1","move_animation_name":move,"move_animation_actor_ident":"p1","move_animation_target_ident":"p2"})
	var move_finished := Time.get_ticks_msec()
	await renderer.render_event({"type":"damage"},{"battle_message":"lost HP","damage_target_ident":"p2"})
	output.append({"species":species,"target":target,"move":move,"animations":get_tree().root.get_node("SettingsManager").battle_animations,
		"move_event_ms":move_finished-started,"damage_event_ms":Time.get_ticks_msec()-move_finished,"total_ms":Time.get_ticks_msec()-started,
		"hp_marks":hp_marks.duplicate(true)})
func _run() -> void:
	get_tree().root.get_node("SettingsManager").battle_animations = true
	presenter = Model.new()
	get_tree().root.add_child(presenter)
	presenter.set_process(false)
	presenter.active = true
	panel = ProbePanel.new()
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	var label := Label.new()
	label.name = "CurrentActionLabel"
	margin.add_child(label)
	panel.add_child(margin)
	get_tree().root.add_child(panel)
	router = BattleAnimationRouter.new()
	router.model_presenter = presenter
	router.animation_parent = presenter
	renderer = BattleEventRenderer.new()
	renderer.setup(null,null,panel,router,BattleMessageTiming.new(),presenter,_hp,Callable(),_command)
	await _sample("pikachu","charizard","Thunderbolt")
	await _sample("dragonite","pikachu","Flamethrower")
	await _sample("garchomp","pikachu","Earthquake")
	await _sample("blastoise","pikachu","Ice Beam")
	var started := Time.get_ticks_msec()
	await renderer.render_event({"type":"statChange"},{"battle_message":"Attack rose!","stat_change_target_ident":"p1","stat_change_amount":1,"effect_animation_key":"stat_up"})
	output.append({"effect":"stat_up","elapsed_ms":Time.get_ticks_msec()-started})
	get_tree().root.get_node("SettingsManager").battle_animations = false
	await _sample("pikachu","charizard","Thunderbolt")
	router.cancel_render()
	presenter.free()
	panel.free()
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp/battle-pacing-investigation"))
	var file := FileAccess.open("res://.tmp/battle-pacing-investigation/runtime.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	print("PACING_PROBE ",JSON.stringify(output))
	get_tree().quit()
