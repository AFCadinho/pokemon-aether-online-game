extends SceneTree
const Effect = preload("res://scripts/battle/battle_ui/pokeball_effect_3d.gd")
const Doll = preload("res://scripts/battle/battle_ui/substitute_model_3d.gd")
var world: Node3D
var effect: Node3D
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1000,700)
	world = Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3.2,2.0,4.5)
	camera.look_at(Vector3(0,0.65,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.6
	camera.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("273c49")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-40,-25,0)
	var doll := Doll.new()
	world.add_child(doll)
	doll.build(1.8,func(): return 1.0)
	doll.position.x = -0.7
	effect = Effect.new()
	world.add_child(effect)
	effect.build(Vector3(-2,1,0),Vector3(0.7,0.8,0),Vector3(0.7,0,0),"poke-ball",func(): return 1.0,func(_a: float,_p: Vector3): pass)
	effect.ball.position = Vector3(0.7,0.6,0)
	effect.ball.scale = Vector3.ONE * 2.5
	effect._open(0.0)
	await _shot("closed")
	effect._open(1.0)
	await _shot("open")
	effect.queue_free()
	effect = Effect.new()
	world.add_child(effect)
	var point: Vector3 = doll.position
	var height: float = doll.idle_scale
	effect.build(Vector3(1.3,0.7,0),point+Vector3.UP*height*0.5,point,"poke-ball",func(): return 1.0,func(a: float,p: Vector3):
		doll.visible = a > 0.001
		doll.scale = Vector3.ONE*maxf(a,0.001)
		doll.position = point+p
	)
	_preview_capture()
	await create_timer(0.44).timeout
	await _shot("absorb")
	await create_timer(0.5).timeout
	await _shot("shake")
	while not capture_done: await process_frame
	await _shot("breakout")
	effect.queue_free()
	quit()
var capture_done := false
func _preview_capture() -> void:
	await effect.capture(3,false)
	capture_done = true
func _shot(key: String) -> void:
	for i in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/battle-props-"+key+".png")
