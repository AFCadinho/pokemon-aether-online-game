extends "res://tests/battle_move_effects_3d_check.gd"
const Recipes = preload("res://scripts/battle/battle_ui/move_recipe_3d.gd")
func _run() -> void:
	get_tree().create_timer(60).timeout.connect(func():get_tree().quit(1))
	_setup()
	var moves: Array = Effect.KEYS.duplicate()
	moves.append_array(Recipes.DATA.data.moves.keys())
	assert(moves.size()==194)
	for frames in [60.0,120.0,407.5]:
		for action in ["physical_attack","special_attack"]:stage.entries.fixture.action_timing[action].frames=frames
		for move: String in moves:
			stage.start_move_action("p1",move)
			var timing: Dictionary = stage.move_timing(move,"p1")
			var wall_seconds: float = timing.frames/60/stage.players[0].get_playing_speed()
			assert(is_equal_approx(wall_seconds,Effect.presentation_seconds(move)),move)
			stage.start_move_dodge("p1","p2",move)
			stage.players[0].seek(timing.impact_frame/60,true)
			stage._update_move_dodges()
			assert(stage.dodge_offsets[1].length()>=stage.move_dodges[1].displacement.length()*.98,"Dodge must hold through the actual impact: "+move)
			stage._clear_move_dodge(1)
		stage.start_move_action("p1","unimplemented move")
		assert(stage.players[0].current_animation_length/stage.players[0].get_playing_speed()<=Effect.MODEL_ONLY_MAX_SECONDS+.001)
		assert(stage.create_move_effect("unimplemented move","p1","p2",{})==null)
	# Self-targeting field screens must not fall into the generic self-shield route.
	for move in ["Aurora Veil","Light Screen","Reflect","Protect"]:
		stage.start_move_action("p1",move)
		var screen: Node = stage.create_move_effect(move,"p1","",{})
		stage.players[0].seek(stage.players[0].current_animation_length*.45,true)
		screen._process(0)
		var panel := false
		for i in screen.cursor:panel = panel or screen.pieces[i].mesh is BoxMesh
		assert(panel,"Missing vertical screen: "+move)
		screen.cancel()
		await get_tree().process_frame
	# Fractional atlas indices are shared by all source-textured renderers.
	var effect: Node = Stage.SourceMoveEffect.new()
	stage.world.add_child(effect)
	var points := {"source":Vector3.ZERO,"target":Vector3(3,1,0),"radius":.6}
	effect.start("ember",{"frames":60,"impact_frame":30},{},func():return .2,func():return points,func():return true)
	effect.cursor=0
	effect._source_sprite(Vector3.ZERO,1,"ember_core",.42,1,Basis.IDENTITY)
	assert(is_equal_approx(float(effect.sprite_materials[0].get_shader_parameter("frame_index")),1.26))
	effect.cancel()
	router.cancel_render()
	router.release_threaded_resource_requests()
	router=null
	stage.queue_free()
	await get_tree().process_frame
	print("PRESENTATION_REVIEW_OK moves=194 native_clip_lengths=3 late_dodge=true model_only_fast=true atlas_blend=true")
	get_tree().quit()
