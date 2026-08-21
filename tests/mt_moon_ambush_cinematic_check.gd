extends SceneTree

const MOVE_CATALOG := preload("res://scripts/world/story/mt_moon_cinematic_move_catalog.gd")
const SUMMON_SCRIPT := preload("res://scripts/battle/animations/pokeball_summon_animation_player.gd")
const ATTACK_SCRIPT := preload("res://scripts/world/story/mt_moon_cinematic_attack.gd")

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var psychic_move: Dictionary = MOVE_CATALOG.for_types(["Psychic"])
	_expect(psychic_move.get("id") == "future-sight", "Psychic future starter uses Future Sight")
	_expect(psychic_move.get("type") == "psychic", "Psychic cinematic keeps its STAB type")

	var water_move: Dictionary = MOVE_CATALOG.for_types(["Water"])
	_expect(water_move.get("id") == "hydro-cannon", "Water future starter uses Hydro Cannon")
	_expect(water_move.get("type") == "water", "Water cinematic keeps its STAB type")

	var fallback_move: Dictionary = MOVE_CATALOG.for_types([])
	_expect(fallback_move.get("id") == "hyper-beam", "Missing type has a safe cinematic fallback")

	var summon_player := SUMMON_SCRIPT.new()
	_expect(summon_player.has_method("play_overworld_summon"), "Battle Poké Ball animation supports overworld summons")
	_expect(summon_player.sprite_render_scale == Vector2(4.0, 4.0), "Battle summon scale remains unchanged by default")
	var release_state := {"released": false}
	summon_player.pokemon_released.connect(func() -> void: release_state["released"] = true)
	get_root().add_child(summon_player)
	await summon_player.play_overworld_summon("poke-ball", Vector2(80, 180), Vector2(220, 120))
	_expect(bool(release_state.released), "Overworld Poké Ball animation reaches its release frame")
	summon_player.queue_free()
	var attack_effect := ATTACK_SCRIPT.new()
	get_root().add_child(attack_effect)
	await attack_effect.play(Vector2(40, 120), [Vector2(180, 80), Vector2(220, 140)], "psychic")
	await process_frame
	_expect(not is_instance_valid(attack_effect), "Cinematic attack effect completes and cleans itself up")

	var controller_source := _read_text("res://scripts/world/story/mt_moon_ambush_controller.gd")
	_expect("_summon_rocket_pokemon" in controller_source, "Ambush summons Team Rocket's Pokémon")
	_expect("_open_rift" in controller_source, "Ambush opens the future-self rift")
	_expect("play_overworld_summon" in controller_source, "Ambush uses the shared Poké Ball animation")
	var scene := load("res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn") as PackedScene
	_expect(scene != null, "Mt. Moon B2F loads with the expanded cinematic")

	for locale: String in ["en", "nl", "pt_BR"]:
		var catalog := _load_json("res://localization/%s.json" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.go"), "%s has the summon caption" % locale)
		_expect(catalog.has("story.mt_moon.cutscene.used_move"), "%s has the attack caption" % locale)

	quit(1 if failed else 0)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
