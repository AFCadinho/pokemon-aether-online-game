extends "res://tests/battle_dialogue_preview.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
const Effect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
var sample_seconds := 0.0

func _start() -> void:
	await super._start()
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var renderer: Node = battle.animation_router.model_presenter
	assert(renderer.active,renderer.reason)
	battle.animation_router.playback_speed = 0
	toolbar.get_parent().hide()
	var selected := OS.get_environment("POKEAETHER_TEST_MOVES").split(",",false)
	var catalogue: Array = Effect.KEYS + Recipes.all_recipes().keys()
	var moves: Array = Array(selected) if not selected.is_empty() else catalogue
	var exhaustive := "--catalogue" in OS.get_cmdline_user_args()
	var count := 0
	for move in moves:
		for reverse in ([catalogue.find(move)%2==1] if exhaustive else [false,true]):
			var actor := "p2" if reverse else "p1"
			var target := "p1" if reverse else "p2"
			for outcome in (["hit"] if exhaustive else ["hit","miss","block"]):
				renderer.start_move_action(actor,move)
				var effect: Node = renderer.create_move_effect(move,actor,target,{"show_impact":outcome=="hit","result":outcome})
				assert(is_instance_valid(effect),move)
				effect.clock = func(): return sample_seconds
				var samples := [effect.launch*.8,lerpf(effect.launch,effect.impact,.65),lerpf(effect.impact,effect.duration,.2)]
				for phase in samples.size():
					sample_seconds=samples[phase]
					var slot: int=renderer.actor_index(actor)
					renderer.players[slot].seek(sample_seconds,true)
					renderer.players[slot].advance(0)
					renderer._update_move_contacts()
					effect._process(0)
					renderer._update_camera(0)
					await process_frame
					await RenderingServer.frame_post_draw
					assert(root.get_texture().get_image().save_png(output.path_join("%s-%s-%s-%d.png" % [move,reverse,outcome,phase]))==OK)
				effect.cancel()
				sample_seconds=0
				await process_frame
				renderer._action("idle",renderer.actor_index(actor))
				assert(renderer.common_effects.is_empty() and renderer.move_camera.effect==null and renderer.move_atmosphere.effect==null,move)
		count+=1
		if count%25==0: print("CATALOGUE_PREVIEW_PROGRESS ",count,"/",moves.size())
	print("REMAINING_PREVIEW_OK moves=",moves.size()," catalogue=",exhaustive," phases=3")
	host.release()
	host.queue_free()
	host=null
	await process_frame
	quit()
