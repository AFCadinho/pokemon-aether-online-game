extends "res://tests/battle_dialogue_preview.gd"
## --moves --capture-extensions [--representatives] [--caster=Dragonite]
const Extensions = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
var sample_seconds := 0.0
func _start() -> void:
	left_species="Dragonite"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--caster="):left_species=arg.trim_prefix("--caster=")
	root.get_node("SettingsManager").battle_3d_camera_motion=true
	await super._start()
	root.title="PokeAether — 901 native 3D moves"
	if "--capture-extensions" in OS.get_cmdline_user_args():await _capture_extensions()

func _capture_extensions() -> void:
	var renderer: Node=battle.animation_router.model_presenter
	assert(renderer.active,renderer.reason)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var representatives := "--representatives" in OS.get_cmdline_user_args()
	var selected: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--extension-moves="):selected=argument.trim_prefix("--extension-moves=").split(",")
	var seen := {}
	var captures := 0
	var moves := 0
	battle.animation_router.playback_speed=0.
	for key: String in Extensions.EXTENSIONS.data.moves:
		if not selected.is_empty() and key not in selected:continue
		var recipe: Dictionary=Extensions.get_recipe(key)
		if selected.is_empty() and representatives and seen.has(recipe.motif) and key not in ["fireblast","hydropump","aurasphere","gigatonhammer","fly","dig","surf","trickroom","sunnyday","snowscape","spikyshield","prismaticlaser","triattack","maxknuckle","maxrockfall","maxgeyser"]:continue
		seen[recipe.motif]=true
		moves+=1
		for reverse in [false,true] if representatives else [false]:
			var actor := "p2" if reverse else "p1"
			var target := "p1" if reverse else "p2"
			renderer.start_move_action(actor,key)
			var effect: Node=renderer.create_move_effect(key,actor,target,{"show_impact":bool(recipe.damaging)})
			assert(is_instance_valid(effect),key)
			effect.clock=func():return sample_seconds
			var samples: Array=[effect.launch*.75,lerpf(effect.launch,effect.impact,.82),lerpf(effect.impact,effect.duration,.18)] if representatives else [lerpf(effect.launch,effect.impact,.82)]
			for i in samples.size():
				sample_seconds=float(samples[i])
				var slot: int=renderer.actor_index(actor)
				renderer.players[slot].seek(sample_seconds,true)
				renderer.players[slot].advance(0.)
				renderer._update_move_contacts()
				effect._process(0.)
				renderer._update_camera(0.)
				await process_frame
				toolbar.get_parent().hide()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%s-%d.png" % [key,reverse,i]))
				toolbar.get_parent().show()
				captures+=1
			effect.cancel()
			sample_seconds=0.
			await process_frame
			renderer._action("idle",renderer.actor_index(actor))
			assert(renderer.common_effects.is_empty() and renderer.move_camera.effect==null and renderer.move_atmosphere.effect==null,key)
		if moves%25==0:print("EXTENSION_PREVIEW_PROGRESS moves=",moves," captures=",captures)
	print("EXTENSION_PREVIEW_OK moves=",moves," captures=",captures," motifs=",seen.size()," real_models=true")
	host.release()
	host.queue_free()
	await process_frame
	quit()
