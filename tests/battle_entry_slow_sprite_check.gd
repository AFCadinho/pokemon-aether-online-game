extends SceneTree

# The exported diagnostic serves this sprite with a six-second metadata delay.
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2d"
	var service := root.get_node("WebPokemonSpriteService")
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(load("res://scripts/world/world.gd"))
	world.set_process(false)
	var started := Time.get_ticks_msec()
	await world._prefetch_web_battle_sprites({"wildPokemon": {"species": "Pikachu"}})
	_check(Time.get_ticks_msec() - started < 500, "Encounter prefetch must return before the delayed download finishes")
	await process_frame
	await process_frame
	_check(not service._in_flight.is_empty(), "Slow sprite download is genuinely pending")
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	host.request_reveal()
	await host.wait_until_revealed()
	_check(not service._in_flight.is_empty(), "Battle becomes visible while its sprite is still downloading")
	_check(host.content.modulate.a == 1.0, "The battle shell is fully revealed")
	var deadline := Time.get_ticks_msec() + 20000
	while not service._in_flight.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	var loaded: Dictionary = service.get_cached_frames("Pikachu", "front", false, "animated")
	_check(loaded.get("frames") != null, "The background sprite download eventually reaches the cache")
	host.release()
	host.queue_free()
	world.set_script(null)
	world.queue_free()
	await process_frame
	if not failed:
		print("battle_entry_slow_sprite_check: PASS")
	quit(1 if failed else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
