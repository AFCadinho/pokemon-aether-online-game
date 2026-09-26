extends SceneTree

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2.5d"
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.size = Vector2(1500, 780)
	host.mount(battle)
	# Android skips the optional 3D presenter entirely. The single-battle HUD
	# must still follow each real sprite instead of using the edge fallback.
	battle.animation_router.model_presenter = null
	battle.player_sprite_box.set_single_pokemon_species("pikachu", "back")
	battle.enemy_sprite_box.set_single_pokemon_species("rattata", "front")
	await process_frame
	for child: Node in battle.get_children():
		if child.get_script() == load("res://scripts/battle/battle_ui/immersive_hud.gd"):
			child.call("_process", 1.0)
			break
	for index in 2:
		var box: Control = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		var hud: Control = battle.player_hud_panel if index == 0 else battle.enemy_hud_panel
		var global_bounds: Rect2 = box.get_single_sprite_hover_rect()
		assert(global_bounds.has_area(), "single battle sprite has visual bounds")
		var stage: Control = battle.battle_stage
		var sprite_center_x := (stage.get_global_transform().affine_inverse() * global_bounds.get_center()).x
		var hud_center_x := hud.position.x + hud.size.x * hud.scale.x * 0.5
		assert(absf(hud_center_x - sprite_center_x) < 25.0, "2D HP panel follows the sprite without a 3D presenter")
	host.release()
	host.queue_free()
	await process_frame
	print("battle_immersive_2d_hud_check: PASS")
	quit(0)
