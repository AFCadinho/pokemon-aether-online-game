extends SceneTree
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
const Pool = preload("res://scripts/battle/arenas/forest_environment_pool.gd")

class Stage:
	extends Control
	var viewport: SubViewport
	var world: Node3D
	var camera: Camera3D
	var actors := [null,null]
	var forest_lease := {}

func _initialize() -> void:
	_run.call_deferred()

func make_pass(parent: Node, pooled: bool) -> Dictionary:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	if pooled:
		vp.set_meta("pooled_forest_environment",true)
	parent.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	return {"viewport":vp,"world":world,"camera":camera,"base":[camera]}

func _run() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	var main := make_pass(stage,false)
	stage.viewport = main.viewport
	stage.world = main.world
	stage.camera = main.camera
	var response := Response.new()
	response.stage = stage
	stage.add_child(response)
	response.set_process(false)
	response._build()
	var light: SubViewport = response.viewport
	assert(light.get_parent()==stage.viewport)
	assert(light.own_world_3d)
	response._drop()
	await process_frame
	assert(not is_instance_valid(light))
	assert(is_instance_valid(stage.viewport))
	response.free()
	stage.free()

	# Pooled ownership remains with the world session across battle release.
	var pool := Pool.new()
	pool.ready_for_battle = true
	root.add_child(pool)
	pool.set_process(false)
	main = make_pass(pool,true)
	var auxiliary := make_pass(pool,true)
	pool.passes.assign([main,auxiliary])
	for turn in 2:
		stage = Stage.new()
		root.add_child(stage)
		stage.forest_lease = pool.acquire(stage)
		assert(not stage.forest_lease.is_empty())
		stage.viewport = main.viewport
		stage.world = main.world
		stage.camera = main.camera
		response = Response.new()
		response.stage = stage
		stage.add_child(response)
		response.set_process(false)
		response._build()
		assert(response.viewport==auxiliary.viewport)
		assert(response.viewport.get_parent()==main.viewport)
		response._drop()
		response.free()
		pool.release(stage)
		stage.free()
		await process_frame
		assert(is_instance_valid(auxiliary.viewport) and is_instance_valid(main.viewport))
		assert(main.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
		assert(auxiliary.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED)
	pool.free()
	print("BATTLE_MATERIAL_RESPONSE_ORDER_OK normal cleanup + two pooled leases")
	quit()
