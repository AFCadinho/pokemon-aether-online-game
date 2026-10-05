extends SceneTree
## Render the actual 2.5D presenter against a static background using approved art.
class Platform extends Control:
	var hazards := Control.new()
	var player_screens := Control.new()
	var enemy_screens := Control.new()
	func _init():
		for node in [hazards,player_screens,enemy_screens]:
			add_child(node)
			node.hide()
func _init():
	_run.call_deferred()
func _run():
	var args := OS.get_cmdline_user_args()
	assert(args.size()==2, "CATALOG OUTPUT_DIRECTORY")
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode="2.5d"
	settings.battle_3d_catalog_path=ProjectSettings.globalize_path(args[0])
	settings._manual_model_catalog_this_session=true
	var host := Control.new()
	root.add_child(host)
	host.size=Vector2(1000,650)
	var bg := TextureRect.new()
	bg.texture=load("res://assets/background/battle/environments/grass_animated_fallback.jpg")
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size=host.size
	host.add_child(bg)
	var platforms := []
	for index in 2:
		var platform := Platform.new()
		host.add_child(platform)
		var image := TextureRect.new()
		image.name="PlatformImage"
		image.size=Vector2(400,200)
		platform.add_child(image)
		platform.position=host.size*(Vector2(.24,.83) if index==0 else Vector2(.75,.65))-Vector2(200,130)
		platforms.append(platform)
	var stage = load("res://scripts/battle/battle_ui/experimental_battle_3d.gd").new()
	host.add_child(stage)
	stage.setup([],platforms)
	for pair in [["azumarill","rattata"],["dragonite","rattata"],["wailord","steelix-mega"]]:
		stage.set_combatant(0,pair[0])
		stage.set_combatant(1,pair[1])
		await stage.await_prepared(true,30000)
		assert(stage.active and not stage.preparation_failed,stage.reason)
		stage.mode_label.hide()
		for frame in 5: await process_frame
		# Populate older model envelopes through the same HUD/effect path.
		for i in 2: stage._visual_rect(i)
		for frame in 3: await process_frame
		stage.set_process(false)
		stage.mode_label.hide()
		for i in 2:
			stage.players[i].pause()
			stage.players[i].seek(0,true)
		for mode in ["after","before"]:
			if mode=="before": stage.camera.size=10.0
			for i in 2:
				var height: float=stage.actors[i].position.y
				stage.actors[i].position=stage._position(i)
				stage.actors[i].position.y=height
			for frame in 2: await process_frame
			RenderingServer.force_draw(false)
			var image := root.get_texture().get_image()
			image.get_region(Rect2i(0,0,1000,650)).save_png(args[1].path_join(pair[0]+"-"+mode+".png"))
			print("HYBRID_REVIEW ",pair," ",mode," camera=",stage.camera.size," rect0=",stage._visual_rect(0)," rect1=",stage._visual_rect(1))
		stage.set_process(true)
	host.free()
	quit()
