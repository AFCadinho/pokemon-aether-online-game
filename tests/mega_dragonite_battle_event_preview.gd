extends SceneTree
## Offline local model review. Requires a temporary candidate registry in this slot.
## No server request, player save, or selected release model is written.

var battle: Control
var stage: Control
var saw_effect := false
var saw_appeal := false
var swapped_early := false
var hud_visible_during_effect := false
var reveal_time := -1.0
var frame_dir := ""
var captured: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _sample() -> void:
	if not is_instance_valid(stage):
		return
	var effect = stage.mega_effects[0]
	if is_instance_valid(effect):
		saw_effect = true
		if battle.player_hud_panel.visible:
			hud_visible_during_effect = true
		if not effect.revealed and stage.combatants[0].species != "dragonite":
			swapped_early = true
		if effect.revealed and reveal_time < 0:
			reveal_time = effect.elapsed
		if not frame_dir.is_empty() and DisplayServer.get_name() != "headless":
			for sample in [0.8, 1.45, 1.8, 2.2, 3.0, 4.0]:
				var label := str(sample)
				if effect.elapsed >= sample and label not in captured:
					captured.append(label)
					_capture.call_deferred(label)
	if stage.current_actions[0] == "mega_appeal":
		saw_appeal = true

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(battle):
		root.get_texture().get_image().save_png(frame_dir.path_join("mega-" + label + ".png"))

func _run() -> void:
	var catalog := OS.get_environment("POKEAETHER_MEGA_BATTLE_CATALOG")
	assert(catalog.is_absolute_path() and FileAccess.file_exists(catalog))
	var shiny := OS.get_environment("POKEAETHER_MEGA_BATTLE_SHINY") == "1"
	frame_dir = OS.get_environment("POKEAETHER_MEGA_BATTLE_FRAMES_DIR")
	if not frame_dir.is_empty():
		assert(frame_dir.is_absolute_path())
		DirAccess.make_dir_recursive_absolute(frame_dir)
	var settings = root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "classic"
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = catalog
	settings.battle_animations = true
	root.size = Vector2i(1280, 720)
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle)
	battle.battle_state.load_from_api_response({
		"battleId": "offline-mega-dragonite-review",
		"requests": {
			"p1": {"active": [{"canMegaEvo": true, "canMegaEvoSpecies": "Dragonite-Mega"}], "side": {"pokemon": [
				{"ident": "p1a: Dragonite", "species": "Dragonite", "details": "Dragonite, L100", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true, "pokemonKey": "p1-slot-0", "level": 100, "shiny": shiny}
			]}},
			"p2": {"active": [{}], "side": {"pokemon": [
				{"ident": "p2a: Dragonite", "species": "Dragonite", "details": "Dragonite, L100", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true, "pokemonKey": "p2-slot-0", "level": 100}
			]}},
		},
	}, false)
	battle.player_sprite_box.set_single_pokemon_species("Dragonite", "back", shiny)
	battle.enemy_sprite_box.set_single_pokemon_species("Dragonite", "front")
	battle.player_hud_panel.set_pokemon_data("Dragonite", 100, 100, 100)
	battle.enemy_hud_panel.set_pokemon_data("Dragonite", 100, 100, 100)
	stage = battle.animation_router.model_presenter
	stage.set_combatant(0, "Dragonite", shiny)
	stage.set_combatant(1, "Dragonite")
	await stage.await_prepared(true, 30000)
	assert(stage.active and stage.identities == ["dragonite@shiny" if shiny else "dragonite", "dragonite"], stage.reason)
	host.get_node("Cover").hide()
	process_frame.connect(_sample)
	await battle._render_battle_events([{
		"type": "mega", "target": "p1a: Dragonite", "species": "Dragonite-Mega"
	}], false, "offline_mega_review", true)
	process_frame.disconnect(_sample)
	assert(saw_effect and not swapped_early, "Mega form switched before reveal")
	assert(not hud_visible_during_effect and battle.player_hud_panel.visible, "Mega HUD obscured the pose or was not restored")
	assert(reveal_time >= 1.35 and reveal_time < 1.5, "Unexpected reveal timing: %s" % reveal_time)
	assert(saw_appeal, "Native Mega appeal did not play")
	assert(stage.active and stage.identities[0] == ("dragonite-mega@shiny" if shiny else "dragonite-mega"), stage.reason)
	assert(battle.battle_state.get_active_pokemon_species("p1") == "Dragonite-Mega")
	print("MEGA_DRAGONITE_BATTLE_EVENT_OK reveal=", reveal_time, " active=", stage.identities,
		" action=", stage.current_actions[0], " actor_y=", stage.actors[0].position.y)
	var output := OS.get_environment("POKEAETHER_MEGA_BATTLE_SCREENSHOT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output) == OK)
	stage.play_action("p1", "sleep")
	for frame in 3:
		await process_frame
	var eye_mesh := stage.actors[0].get_node("pm0149_51_00/Skeleton3D/pm0149_51_00_eye_mesh") as MeshInstance3D
	assert(stage.current_actions[0] == "sleep" and not eye_mesh.visible, "Corrected sleep eyes were lost")
	var sleep_output := OS.get_environment("POKEAETHER_MEGA_BATTLE_SLEEP_SCREENSHOT")
	if not sleep_output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(sleep_output) == OK)
	host.release()
	host.queue_free()
	await process_frame
	quit()
