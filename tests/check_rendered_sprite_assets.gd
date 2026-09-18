extends SceneTree
## Run with the local V1 preview catalog containing Dragonite and Rattata.
const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(Assets._catalog_key("Roaring Moon", false) == "roaring-moon:normal")
	assert(Assets._catalog_key(" Roaring_Moon ", true) == "roaring-moon:shiny")
	assert(Assets._catalog_key("Rattata-Alola", false) == "rattata-alola:normal")
	assert(Assets.load_frames("rattata-alola", "front", false) == null)
	assert(Assets.load_frames("rattata", "front", true) == null)
	assert(Assets.load_frames("pikachu", "front", false) == null)
	for species: String in ["dragonite", "rattata"]:
		for side: String in ["front", "back"]:
			var frames := Assets.load_frames(species, side, false)
			assert(frames != null)
			assert(frames.get_frame_count("idle") == (91 if species == "dragonite" else 27))
			assert(not frames.has_animation("damage"))
			assert(Assets.ensure_action_loaded(frames, "damage"))
			assert(Assets.ensure_action_loaded(frames, "faint_loop"))
			assert(frames.get_animation_loop("faint_loop"))
			assert(Assets.ensure_action_loaded(frames, "sleep") == (species == "dragonite"))
			# A rejected or damaged action cannot partially create an animation.
			var actions: Dictionary = frames.get_meta("rendered_actions")
			var backup: Dictionary = actions["physical_attack"].duplicate(true)
			actions["physical_attack"]["status"] = "rejected"
			assert(not Assets.ensure_action_loaded(frames, "physical_attack"))
			actions["physical_attack"] = backup.duplicate(true)
			actions["physical_attack"]["pages"][0]["sha256"] = "bad"
			assert(not Assets.ensure_action_loaded(frames, "physical_attack"))
			assert(not frames.has_animation("physical_attack"))
			actions["physical_attack"] = backup
			assert(Assets.ensure_action_loaded(frames, "physical_attack"))
	var box = load("res://scenes/battle/sprite_box.tscn").instantiate()
	root.add_child(box)
	box.set_single_pokemon_species("rattata", "back", false)
	assert(box.single_sprite.sprite_frames.has_meta("rendered_asset"))
	box.set_dratini_poc_sleeping(true)
	assert(box.single_sprite.animation == &"idle")
	box.play_attack_tween(Vector2.ZERO, "Tackle")
	assert(box.single_sprite.animation == &"physical_attack")
	await create_timer(1.0).timeout
	box.playback_speed = 20.0
	await box.play_faint_tween()
	assert(box.single_sprite.animation == &"faint_loop")
	assert(box.single_sprite.visible)
	box.queue_free()
	await process_frame
	var stage := Control.new()
	root.add_child(stage)
	var player = load("res://scenes/battle/sprite_box.tscn").instantiate()
	var opponent = load("res://scenes/battle/sprite_box.tscn").instantiate()
	stage.add_child(player)
	stage.add_child(opponent)
	player.set_single_pokemon_species("dragonite", "back", false)
	opponent.set_single_pokemon_species("rattata", "front", false)
	var router = load("res://scripts/battle/battle_animation_router.gd").new()
	router.setup(player, opponent, stage)
	await router.play_attack_tween_for_actor("p1a: Dragonite", "Tackle")
	assert(player.single_sprite.animation == &"physical_attack")
	await router.play_move_animation("Tackle", "p1a: Dragonite", "p2a: Rattata")
	await router.play_attack_tween_for_actor("p2a: Rattata", "Hydro Pump")
	assert(opponent.single_sprite.animation == &"special_attack")
	await router.play_move_animation("Hydro Pump", "p2a: Rattata", "p1a: Dragonite")
	await router.play_damage_tween_for_target("p1a: Dragonite")
	assert(player.single_sprite.animation == &"idle")
	player.set_dratini_poc_sleeping(true)
	assert(player.single_sprite.animation == &"sleep")
	player.set_dratini_poc_sleeping(false)
	# Ordinary species still use the original asset resolver.
	opponent.set_single_pokemon_species("pikachu", "front", false)
	assert(not opponent.single_sprite.sprite_frames.has_meta("rendered_asset"))
	stage.queue_free()
	await process_frame
	# Preview data cannot enter the ordinary approved path.
	var preview := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG")
	OS.set_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG", "")
	OS.set_environment("POKEAETHER_RENDERED_CATALOG", preview)
	assert(Assets.load_frames("rattata", "front", false) == null)
	print("Rendered sprite factory resolver / routing / fallback checks PASS")
	quit()
