extends SceneTree
## Offline visual fixture: real controls, no battle requests submitted.
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var settings = root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "stadium"
	settings.battle_3d_catalog_path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle)
	battle._show_local_player_trainer()
	battle.enemy_trainer_sprite.show_player({"gender":"female","skin_tone":"#f8d0b8"},Vector2.LEFT)
	battle.vs_panel_container.set_names("Admin","Rival")
	var renderer = battle.animation_router.model_presenter
	renderer.set_combatant(0,"Dragonite")
	renderer.set_combatant(1,"Roaring Moon")
	await renderer.await_prepared(true,30000)
	renderer.set_actor_shown(0,true)
	renderer.set_actor_shown(1,true)
	var party := []
	for species in ["Dragonite","Typhlosion","Scizor","Arcanine","Charizard","Roaring Moon"]:
		party.append({"species":species,"hp":100,"max_hp":100,"active":species=="Dragonite"})
	battle.player_party_grid.set_party(party)
	battle.get_node("%PlayerStagePartyGrid").set_party(party)
	var parent: Control = battle.player_party_grid
	while parent != battle:
		parent.show()
		parent = parent.get_parent() as Control
	battle.moves_grid.set_moves([
		{"move":"Outrage","type":"dragon","pp":8,"maxpp":10},
		{"move":"Earthquake","type":"ground","pp":9,"maxpp":10},
		{"move":"Fire Punch","type":"fire","pp":15,"maxpp":15},
		{"move":"Dragon Dance","type":"dragon","pp":19,"maxpp":20}])
	battle.moves_grid.show()
	battle.get_node("%UtilityActions").show()
	battle.current_action_panel.set_message("Choose a move")
	battle.get_node("%MechanicsPanel").show()
	battle.get_node("%ZMove").show()
	battle.get_node("%MegaEvolutionIcon").hide()
	for frame in 90:
		await process_frame
	host.get_node("Cover").hide()
	assert(battle._show_trainer_command_text("p1","Dragonite, use Outrage!",10.0))
	assert(battle._show_trainer_command_text("p2","Roaring Moon, attack!",10.0))
	for frame in 15:
		await process_frame
	assert(battle.battle_stage.get_node("TrainerPortrait0").visible)
	assert(battle.battle_stage.get_node("TrainerPortrait1").visible)
	assert(not renderer.mode_label.visible)
	assert(not battle.battle_log_toggle_button.visible and not battle.calc_log_button.visible)
	var moves: Rect2 = battle.moves_grid.get_global_rect()
	assert(not moves.intersects(battle.player_party_grid.get_global_rect()),str("moves=",moves," party=",battle.player_party_grid.get_global_rect()," dock=",battle.get_node("%ActionsDock").get_global_rect()))
	assert(not moves.intersects(battle.current_action_panel.get_global_rect()))
	assert(battle.get_node("%PlayerStagePartyRail").visible)
	var chat_space := Rect2(Vector2(0,battle.size.y - 160),Vector2(battle.size.x * 0.23,160))
	var inverse: Transform2D = battle.get_global_transform().affine_inverse()
	assert(not chat_space.intersects(inverse * battle.player_party_grid.get_global_rect()))
	assert(not chat_space.intersects(inverse * battle.current_action_panel.get_global_rect()))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("combat.png"))
	host.release()
	host.queue_free()
	await process_frame
	print("IMMERSIVE_COMBAT_LAYOUT_OK")
	quit()
