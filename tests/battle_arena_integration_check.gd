extends SceneTree
const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_animations = true
	settings.battle_3d_catalog_path = OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	settings.battle_3d_forest_manifest = OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	assert(not settings.battle_3d_catalog_path.is_empty())
	var host := Node.new()
	root.add_child(host)
	current_scene = host
	var ids: Array = ["cave","sea","stadium"]
	if not settings.battle_3d_forest_manifest.is_empty():
		ids.append("forest")
	if not OS.get_environment("POKEAETHER_TEST_ARENAS").is_empty():
		ids = Array(OS.get_environment("POKEAETHER_TEST_ARENAS").split(","))
	for id in ids:
		for cycle in 2:
			settings.battle_3d_arena = "auto"
			var stage := Renderer.new()
			stage.environment_id = StringName({"forest":"grass","sea":"water","cave":"cave","stadium":"pvp_stadium"}[id])
			host.add_child(stage)
			stage.size = Vector2(1152,648)
			stage.setup()
			stage.set_combatant(0,"Dragonite")
			stage.set_combatant(1,"Roaring Moon")
			for frame in 2500:
				if stage.active:
					break
				await process_frame
			assert(stage.active and stage.arena_id == id,stage.arena_problem)
			await stage.await_prepared(true,30000)
			assert(not stage.preparation_failed)
			assert(stage.arena_root != null and stage.material_response.viewport != null)
			assert(stage.ground_offsets.size()==2)
			assert(await stage.recall("p1"))
			assert(await stage.send_out("p1"))
			var router = load("res://scripts/battle/battle_animation_router.gd").new()
			router.model_presenter = stage
			for move in ["Outrage", "Flamethrower"]:
				await router.play_attack_tween_for_actor("p1", move)
				assert(stage.current_actions[0] == stage.attack_action_for(move))
				await router.play_move_animation(move, "p1", "p2")
			assert(router.move_animation_configs.is_empty() and router.active_animation_nodes.is_empty())
			for action in ["physical_attack","special_attack","damage","faint_start"]:
				await stage.play_action("p2",action)
			stage.set_combatant(0,"Roaring Moon")
			for frame in 10:
				await process_frame
			assert(stage.identities[0]=="roaring-moon")
			stage.set_combatant(0,"Dragonite")
			stage.start_action("p2","reset")
			stage.set_actor_shown(1,true)
			for frame in 10:
				await process_frame
			if cycle==0 and DisplayServer.get_name()!="headless":
				var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
				DirAccess.make_dir_recursive_absolute(output)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join(id+"-client.png"))
			var main_view: WeakRef = weakref(stage.viewport)
			router.cancel_render()
			var light_view: WeakRef = weakref(stage.material_response.viewport)
			stage.queue_free()
			for frame in 5:
				await process_frame
			assert(main_view.get_ref()==null and light_view.get_ref()==null)
			print("ARENA_INTEGRATION_OK ",id," cycle=",cycle)
	host.queue_free()
	await process_frame
	quit()
