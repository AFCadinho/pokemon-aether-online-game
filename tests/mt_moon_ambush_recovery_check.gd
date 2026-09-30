extends SceneTree

var failed := false


class FakeMiguel extends Node2D:
	var reset_count := 0

	func reset_after_ambush_failure() -> void:
		reset_count += 1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var controller: Node2D = (load("res://scripts/world/story/mt_moon_ambush_controller.gd") as GDScript).new()
	var origins: Array[Vector2] = []
	for actor_name: String in ["RocketLeft", "RocketRight", "RocketRear", "RocketUpperLeft", "RocketUpperRight"]:
		var rocket := AnimatedSprite2D.new()
		rocket.name = actor_name
		rocket.position = Vector2(origins.size() * 32, 32)
		origins.append(rocket.position)
		controller.add_child(rocket)
	var future_self := AnimatedSprite2D.new()
	future_self.name = "FutureSelf"
	for layer_name: String in ["BottomSprite", "ShoesSprite", "TopSprite", "EyesSprite", "FaceGearSprite"]:
		var layer := AnimatedSprite2D.new()
		layer.name = layer_name
		future_self.add_child(layer)
	controller.add_child(future_self)
	var miguel := FakeMiguel.new()
	miguel.name = "Miguel"
	controller.add_child(miguel)
	controller.set("miguel_path", NodePath("Miguel"))
	root.add_child(controller)
	var rockets: Array = controller.get("rockets")
	current_scene = controller
	var player := Node2D.new()
	controller.add_child(player)
	controller.call("set_story_player", player)
	_check(await controller.call("_attack_and_faint_follower"), "missing follower skips the cosmetic attack without failing the rescue")

	var future_starter: Variant = controller.call("_create_cutscene_pokemon", "garchomp", Vector2.ZERO, true)
	var rocket_partner: Variant = controller.call("_create_cutscene_pokemon", "zubat", Vector2.ZERO)
	_check(future_starter.shiny, "future self's evolved starter is shiny")
	_check(future_starter.npc_sprite_frames == FollowerSpriteService.get_sprite_frames("garchomp", true), "future starter draws the shiny overworld sprites")
	_check(not future_starter.visible, "shiny future starter stays hidden until the summon")
	_check(not rocket_partner.shiny, "Rocket partners keep their ordinary appearance")
	future_starter.queue_free()
	rocket_partner.queue_free()

	var follower := PokemonFollower.new()
	root.add_child(follower)
	follower.sprite.position = Vector2(0, 8)
	follower.sprite.rotation = 0.5
	follower.sprite.modulate = Color.GRAY
	follower.set_process(false)
	follower.visible = true
	controller.set("_fainted_follower", follower)
	controller.set("_follower_sprite_origin", Vector2(0, -16))
	controller.set("_follower_was_visible", false)
	controller.set("_follower_was_processing", true)
	controller.set("_dialogue_stage", 8)
	controller.set("_prepared", true)
	controller.set("_counterattack_played", true)
	controller.set("_starter_options", {"selectedSpeciesId": "gible"})
	var starter := Node2D.new()
	controller.add_child(starter)
	controller.set("_starter", starter)
	var pokemon := Node2D.new()
	controller.add_child(pokemon)
	var rocket_pokemon: Array[Node2D] = [pokemon]
	controller.set("_rocket_pokemon", rocket_pokemon)
	var fossil := Node2D.new()
	controller.add_child(fossil)
	fossil.visible = false
	controller.set("_other_fossil", fossil)
	controller.set("_other_fossil_was_visible", true)
	future_self.visible = true
	for rocket: Node in rockets:
		rocket.position += Vector2(0, 160)
		rocket.modulate.a = 0.0
		rocket.visible = true

	controller.call("abort_story_sequence")
	_check(controller.get("_dialogue_stage") == 0 and not controller.get("_prepared") and not controller.get("_counterattack_played"), "retry begins at the first ambush dialogue and animation")
	_check((controller.get("_starter_options") as Dictionary).is_empty(), "retry refreshes the starter after a checkpoint reset")
	for index: int in range(rockets.size()):
		var rocket: Node = rockets[index]
		_check(rocket.position == origins[index] and not rocket.visible and rocket.modulate.a == 1.0, "Rocket %d returns to its original formation" % index)
	_check(not future_self.visible, "failed attempt hides the future self")
	_check(miguel.reset_count == 1 and fossil.visible, "failed attempt restores Miguel and the other fossil")
	_check(follower.is_processing() and not follower.visible, "failed attempt restores the follower's process and visibility")
	_check(follower.sprite.position == Vector2(0, -16) and follower.sprite.rotation == 0.0 and follower.sprite.modulate == Color.WHITE, "follower recovers its original sprite position and appearance")
	await process_frame
	_check(not is_instance_valid(starter) and not is_instance_valid(pokemon), "failed attempt removes temporary Pokemon")
	controller.call("abort_story_sequence")
	_check((controller.get("_rocket_pokemon") as Array).is_empty(), "repeated cleanup is safe")
	follower.queue_free()
	controller.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
