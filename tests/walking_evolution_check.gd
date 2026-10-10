extends SceneTree
const Factory := preload("res://scripts/data/pokemon_factory.gd")
const VIEW_PATH := "res://scripts/ui/evolution_conditions_view.gd"
var failures := 0
class Actor extends Node:
	var surf_activity_active := false
	var land_mount_activity_active := false
	var story_path_movement_active := false
class World extends Node:
	var is_in_battle := false
	var player: Node

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(15).timeout.connect(func() -> void: quit(1))
	for autoload: Node in root.get_children():
		autoload.set_process(false)
	root.get_node("GatewayApiConfig").cached_url = "http://127.0.0.1:1"
	root.get_node("ThievingService").set_process(false)
	root.get_node("RockSmashService").set_process(false)
	root.get_node("WalkingEvolutionService").set_process(false)
	var auth := root.get_node("AuthService")
	var save := root.get_node("PlayerSave")
	var localization := root.get_node("LocalizationManager")
	auth.session_token = "walking-fixture"
	auth.current_user = {"id": 1}
	var pokemon := Factory.create_pokemon_from_backend_payload({"ownedPokemonId": 77, "speciesId": "pawmo", "species": "Pawmo",
		"level": 20, "canEvolve": true, "evolutionWalkSteps": 0, "evolutionWalkRequiredSteps": 1000})
	save.party.assign([pokemon])
	var actor := Actor.new()
	var world := World.new()
	world.player = actor
	root.add_child(world)
	world.add_child(actor)
	world.add_to_group("world")
	var service = load("res://tests/support/walking_evolution_transport.gd").new()
	root.add_child(service)
	service.set_process(false)
	_check(service.can_count(pokemon), "lead walking counts without enabling Repel or follower visibility")
	for property: String in ["surf_activity_active", "land_mount_activity_active", "story_path_movement_active"]:
		actor.set(property, true)
		service.record_steps(8)
		_check(service.total_steps == 0, "%s does not add evolution steps" % property)
		actor.set(property, false)
	world.is_in_battle = true
	service.record_steps(8)
	_check(service.total_steps == 0, "battle activity does not add evolution steps")
	world.is_in_battle = false
	service.record_steps(2)
	service.hold_next = true
	service._sync_usage()
	service.record_steps(3)
	service.release_reply.emit()
	await process_frame
	_check(service.requests[0].totalSteps == 0 and service.total_steps == 5,
		"walking handshake sends zero while retaining steps completed during its response")
	await service.flush()
	_check(pokemon.evolution_walk_steps == 5 and service.synced_steps == 5, "flush saves all completed steps once")
	service.record_steps(2)
	service.fail_next = true
	var failure: Dictionary = await service.flush()
	_check(not failure.success and service.total_steps == 7 and service.synced_steps == 5,
		"network failure preserves pending walking progress")
	await service.flush()
	_check(pokemon.evolution_walk_steps == 7 and service.server_steps == 7, "retry does not count confirmed steps again")
	var other := Factory.create_pokemon_from_backend_payload({"ownedPokemonId": 88, "species": "Rellor", "level": 20,
		"canEvolve": true, "evolutionWalkRequiredSteps": 1000})
	save.party.assign([pokemon, other])
	_check(not service.can_count(other), "a Pokemon in another party slot gets no walking credit")
	service.record_steps(1)
	service.hold_next = true
	service._sync_usage()
	auth.session_token = "next-account-session"
	service.reset()
	save.party.assign([other])
	service.release_reply.emit()
	await process_frame
	_check(other.evolution_walk_steps == 0, "late previous-session response cannot credit the new party")
	service.server_steps = 995
	other.evolution_walk_steps = 995
	service.record_steps(5)
	var completed: Array = []
	service.walking_completed.connect(func(id: int) -> void: completed.append(id))
	await service.flush()
	await service.flush()
	_check(other.evolution_walk_steps == 1000 and completed == [88], "walking completion is announced once")
	_check(not service.can_count(other), "a complete walking requirement stops further counting")
	var view = load(VIEW_PATH).new()
	root.add_child(view)
	view.render({"walkSteps": 640, "isLead": true, "evolutions": [{"speciesId": "pawmot", "name": "Pawmot",
		"gameplaySupported": true, "conditionsMet": false, "rule": {"min_walk_steps": 1000}}]})
	var bar := view.find_child("WalkingProgress", true, false) as ProgressBar
	_check(bar != null and bar.value == 640 and bar.max_value == 1000, "conditions popup displays personal walking progress")
	view.render({"walkSteps": 1000, "isLead": false, "evolutions": [{"speciesId": "pawmot", "name": "Pawmot",
		"gameplaySupported": true, "conditionsMet": false, "rule": {"min_walk_steps": 1000}}]})
	_check(_has_label(view, localization.text("ui.evolution_conditions.walk_complete")), "completed walking still explains the next level-up")
	view.render({"evolutions": [{"speciesId": "escavalier", "name": "Escavalier", "gameplaySupported": false}]})
	_check(_has_label(view, localization.text("ui.evolution_conditions.unsupported")), "unsupported evolution methods have an honest explanation")
	view.free()
	service.free()
	world.free()
	save.party.assign([])
	pokemon = null
	other = null
	auth.clear_session()
	await process_frame
	await process_frame
	quit(failures)

func _has_label(node: Node, text: String) -> bool:
	if node is Label and node.text == text:
		return true
	for child: Node in node.get_children():
		if _has_label(child, text):
			return true
	return false

func _check(ok: bool, text: String) -> void:
	if ok:
		print("PASS ", text)
	else:
		failures += 1
		push_error(text)
