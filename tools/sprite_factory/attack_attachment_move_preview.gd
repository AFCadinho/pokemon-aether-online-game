extends SceneTree
## Offline render of the real stage action selection, anchors and move effects.
## Uses approved local models; does not connect to a battle server.
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pose = preload("res://tools/sprite_factory/attack_attachment_pose.gd")
var catalog_path := ""
var output := "res://.tmp/attack-attachments/move-previews"
var species := "snivy"
var move := "Vine Whip"
var camera_yaw := 0.0
var camera_scale := 1.0
var requested_fractions: Array[float] = []
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var stage: Control

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in ["--catalog", "--output", "--species", "--move", "--camera-yaw", "--camera-scale", "--fractions"] and i + 1 >= args.size():
			printerr("Missing argument: ", args[i]); quit(1); return
		if args[i] == "--catalog": catalog_path = args[i+1]
		if args[i] == "--output": output = args[i+1]
		if args[i] == "--species": species = args[i+1]
		if args[i] == "--move": move = args[i+1]
		if args[i] == "--camera-yaw": camera_yaw = deg_to_rad(float(args[i+1]))
		if args[i] == "--camera-scale": camera_scale = float(args[i+1])
		if args[i] == "--fractions":
			for value: String in args[i+1].split(",", true):
				if not value.is_valid_float() or not is_finite(float(value)) or float(value) < 0 or float(value) > 1:
					printerr("Invalid pose fraction: ", value); quit(1); return
				requested_fractions.append(float(value))
			if requested_fractions.size() > 8:
				printerr("At most eight pose fractions are supported"); quit(1); return
	if not is_finite(camera_scale) or camera_scale <= 0 or not is_finite(camera_yaw):
		printerr("Invalid camera settings"); quit(1); return
	_run.call_deferred()

func _run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	var entries: Array = raw.entries if raw is Dictionary else raw
	var model := {}
	for entry: Dictionary in entries:
		if Catalog.entry_key(entry) == species: model = entry; break
	assert(not model.is_empty(), "Requested local model is missing")
	assert(FileAccess.get_sha256(model.runtime_path) == model.runtime_sha256)
	var profile := Catalog.resolve(species, model.runtime_sha256)
	assert(not profile.is_empty(), "Requested model revision is not approved")
	viewport = SubViewport.new()
	viewport.size = Vector2i(720,540)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = Node3D.new(); viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263449")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .7
	world.add_child(environment)
	var light := DirectionalLight3D.new(); world.add_child(light)
	light.rotation_degrees = Vector3(-30,-30,0)
	camera = Camera3D.new(); world.add_child(camera); camera.fov = 40
	stage = Stage.new(); root.add_child(stage); stage.set_process(false)
	stage.active = true; stage.world = world; stage.camera = camera
	stage.entries[species] = profile
	stage.visual_bounds[species] = profile.get("bounds", {})
	var packed := ResourceLoader.load(model.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	for slot in 2:
		var actor := packed.instantiate() as Node3D; world.add_child(actor)
		preload("res://scripts/battle/battle_ui/material_surface_order.gd").apply(actor)
		preload("res://scripts/battle/animations/reviewed_source_visibility.gd").apply(actor,species,model.runtime_sha256)
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		preload("res://scripts/battle/animations/gliscor_flight.gd").apply(player,species,model.runtime_sha256)
		preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(player,species,model.runtime_sha256)
		preload("res://scripts/battle/animations/charmander_breath.gd").apply(player,species,model.runtime_sha256)
		actor.scale = Vector3.ONE * float(profile.grounding.scale)
		actor.position = stage._position(slot) + Vector3.UP*float(profile.grounding.get("lift",0))
		var direction: Vector3 = stage._position(1-slot) - stage._position(slot)
		actor.rotation.y = atan2(direction.x,direction.z) + deg_to_rad(float(profile.grounding.get("yaw_degrees",0)))
		stage.actors[slot] = actor; stage.players[slot] = player
		stage.identities[slot] = species
		stage.combatants[slot] = {"species":species.trim_suffix("@shiny"),"shiny":species.ends_with("@shiny")}
		stage.actor_shown[slot] = true; stage.lifecycle[slot] = "idle"
		Pose.sample(player, "idle", player.get_animation("idle").length*.45)
	var requested: String = stage.attack_action_for(move,"p1")
	var mapped: Dictionary = Stage.ActionMap.resolve(requested,stage.players[0].get_animation_list(),profile.action_timing)
	assert(not mapped.is_empty(), "Requested move has no native action")
	var action: String = mapped.action
	stage.current_actions[0] = action
	Pose.sample(stage.players[0], action, 0.0)
	var effect: Node = stage.create_move_effect(move,"p1","p2",{"show_impact":true})
	assert(effect != null, "Move effect is unavailable")
	effect.set_process(false)
	var timing: Dictionary = stage.move_timing(move,"p1")
	var fractions := [.2,.45,.65]
	# Include the active lash/beam interval even when authored timing differs.
	fractions.append(lerpf(float(timing.get("launch_frame",0)),float(timing.impact_frame),.9)/float(timing.frames))
	if not requested_fractions.is_empty(): fractions = requested_fractions.duplicate()
	fractions.sort()
	var sheet := Image.create(720*2,540*fractions.size(),false,Image.FORMAT_RGB8)
	var label := Label.new(); label.position = Vector2(8,8); label.add_theme_font_size_override("font_size",18); viewport.add_child(label)
	var records := []
	for row in fractions.size():
		var fraction: float = fractions[row]
		Pose.sample(stage.players[0], action, stage.players[0].get_animation(action).length*fraction)
		for rig: Skeleton3D in stage.actors[0].find_children("*","Skeleton3D",true,false): rig.force_update_all_bone_transforms()
		stage._update_move_contacts()
		for frame in 2: await process_frame
		for column in 2:
			var points: Dictionary = stage._move_anchors("p1","p2",move)
			var center: Vector3 = points.source
			var height := maxf(float(stage._effect_bounds(0).height),.65)
			var direction := Vector3(.9,.35,1.6) if column == 0 else Vector3(-.4,.35,1.8)
			camera.position = center + direction.rotated(Vector3.UP, camera_yaw)*height*1.7*camera_scale
			camera.look_at(center)
			effect._process(0)
			label.text = "%s | %s | %s %.3f | %s" % [species,move,action,fraction,points.attachment_part]
			await process_frame; await RenderingServer.frame_post_draw
			sheet.blit_rect(viewport.get_texture().get_image(),Rect2i(0,0,720,540),Vector2i(column*720,row*540))
			records.append({"fraction":fraction,"view":column,"part":points.attachment_part,"bones":points.attachment_bones,"sources":points.sources.size(),"pieces":effect.cursor,
				"source_position":[points.source.x,points.source.y,points.source.z],"target_position":[points.target.x,points.target.y,points.target.z],"contact_yaw":stage.contact_yaws[0]})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var filename := species+"-"+Stage.MoveEffect.move_key(move)
	assert(sheet.save_png(output.path_join(filename+".png")) == OK)
	var file := FileAccess.open(output.path_join(filename+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"species":species,"move":move,"action":action,"timing":timing,"pose_sampling":"forward_from_start_v1","runtime_sha256":model.runtime_sha256,"attachment_data_sha256":FileAccess.get_sha256("res://data/battle_move_attachments_3d.json"),"scope":"offline actual stage anchors, native action, contact approach and move VFX; plain review lighting","captures":records},"\t")+"\n")
	file.close()
	effect.cancel(); await process_frame
	stage.world = null; stage.camera = null; stage.free()
	print("ATTACHMENT_MOVE_PREVIEW ",filename)
	quit()
