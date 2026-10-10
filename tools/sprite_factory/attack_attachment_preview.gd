extends SceneTree
## Captures every requested model's actual attack poses with candidate markers.
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pose = preload("res://tools/sprite_factory/attack_attachment_pose.gd")
var catalog_path := ""
var candidates := "res://.tmp/attack-attachments/candidates"
var output := "res://.tmp/attack-attachments/previews"
var selected: Array[String] = []
var selected_part := "mouth"
var native_only := false
var camera_scale := 1.0
var camera_yaw := 0.0
var camera_elevation := 0.0
var emitter_index := 0
var pose_fractions: Array[float] = [0.2, 0.45, 0.65, 0.45]
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
const PART_COLORS := {"mouth":Color.MAGENTA,"hand":Color.CYAN,"left_hand":Color.DODGER_BLUE,
	"foot":Color.YELLOW,"left_foot":Color.ORANGE,"body":Color.WHITE,"tail":Color.RED}

func _transform(value: Transform3D) -> Array:
	return [value.basis.x.x,value.basis.x.y,value.basis.x.z,
		value.basis.y.x,value.basis.y.y,value.basis.y.z,
		value.basis.z.x,value.basis.z.y,value.basis.z.z,
		value.origin.x,value.origin.y,value.origin.z]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in ["--catalog", "--candidates", "--output", "--species", "--part", "--camera-scale", "--camera-yaw", "--camera-elevation", "--emitter", "--fractions"] and i + 1 >= args.size():
			printerr("Missing value for ", args[i])
			quit(1)
			return
		if args[i] == "--catalog": catalog_path = args[i+1]
		if args[i] == "--candidates": candidates = args[i+1]
		if args[i] == "--output": output = args[i+1]
		if args[i] == "--species": selected.assign(args[i+1].split(","))
		if args[i] == "--part": selected_part = args[i+1]
		if args[i] == "--native-only": native_only = true
		if args[i] == "--camera-scale": camera_scale = float(args[i+1])
		if args[i] == "--camera-yaw": camera_yaw = deg_to_rad(float(args[i+1]))
		if args[i] == "--camera-elevation": camera_elevation = float(args[i+1])
		if args[i] == "--emitter": emitter_index = int(args[i+1])
		if args[i] == "--fractions":
			var values := args[i+1].split(",")
			if values.size() != 4:
				printerr("Supply four fractions: three primary views and one side view")
				quit(1); return
			for column in 4:
				if not values[column].is_valid_float() or not is_finite(float(values[column])) or float(values[column]) < 0.0 or float(values[column]) > 1.0:
					printerr("Pose fractions must be finite numbers from zero to one")
					quit(1); return
				pose_fractions[column] = float(values[column])
	if camera_scale <= 0.0 or not is_finite(camera_scale) or emitter_index < 0:
		printerr("Camera scale must be positive and emitter index nonnegative")
		quit(1)
		return
	_run.call_deferred()

func _point(actor: Node3D, source: Array) -> Vector3:
	var result := Vector3.ZERO
	var total := 0.0
	for definition: Dictionary in source:
		for rig: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
			var bone := rig.find_bone(definition.bone)
			if bone < 0: continue
			var offset: Array = definition.offset
			var weight := float(definition.get("weight",1.0))
			result += rig.to_global(rig.get_bone_global_pose(bone)*Vector3(offset[0],offset[1],offset[2]))*weight
			total += weight
			break
	return result/maxf(total,0.00001)

func _visible(actor: Node3D, source: Array) -> bool:
	if source.is_empty(): return false
	if not source[0].has("visible_mesh"): return true
	var mesh := actor.get_node_or_null(NodePath(str(source[0].visible_mesh))) as MeshInstance3D
	return mesh != null and mesh.is_visible_in_tree()

func _marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	# Draw after source-model transparent mouth and bubble surfaces as well.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 127
	marker.material_override = material
	world.add_child(marker)
	return marker

func _posed_bounds(actor: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point := mesh.global_transform*vertex
				box = box.expand(point) if found else AABB(point,Vector3.ZERO)
				found = true
	return box

func _run() -> void:
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if entries is Dictionary: entries = entries.entries
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport = SubViewport.new()
	viewport.size = Vector2i(420,360)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263449")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-30,-30,0)
	light.light_energy = 1.1
	camera = Camera3D.new()
	world.add_child(camera)
	camera.fov = 35
	var marker := _marker(Color.MAGENTA)
	var label := Label.new()
	label.position = Vector2(6,5)
	label.add_theme_font_size_override("font_size",17)
	viewport.add_child(label)
	for entry: Dictionary in entries:
		var identity := Catalog.entry_key(entry)
		if identity.ends_with("@shiny") or (not selected.is_empty() and identity not in selected): continue
		if FileAccess.file_exists(output.path_join(identity+".png")): continue
		var path := candidates.path_join(identity+".json")
		if not FileAccess.file_exists(path): continue
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var sources := {}
		if selected_part == "all":
			for part: String in report.candidate_parts:
				if native_only and report.candidate_reasons.get(part, "") != "native_effect_bone": continue
				sources[part] = report.candidate_parts[part]
			if sources.is_empty(): continue
		else:
			if not report.candidate_parts.has(selected_part): continue
			if native_only and report.candidate_reasons.get(selected_part, "") != "native_effect_bone": continue
			sources[selected_part] = report.candidate_parts[selected_part]
		var packed := ResourceLoader.load(str(entry.runtime_path),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var actor := packed.instantiate() as Node3D
		world.add_child(actor)
		preload("res://scripts/battle/battle_ui/material_surface_order.gd").apply(actor)
		var profile := Catalog.resolve(identity,str(entry.runtime_sha256))
		actor.rotation.y = deg_to_rad(float(profile.get("grounding",{}).get("yaw_degrees",0)))
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		preload("res://scripts/battle/animations/reviewed_source_visibility.gd").apply(actor,identity,str(entry.runtime_sha256))
		preload("res://scripts/battle/animations/gliscor_flight.gd").apply(player,identity,str(entry.runtime_sha256))
		preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(player,identity,str(entry.runtime_sha256))
		preload("res://scripts/battle/animations/charmander_breath.gd").apply(player,identity,str(entry.runtime_sha256))
		var actions: Array[String] = []
		for action: String in player.get_animation_list():
			if action == "idle" or "attack" in action: actions.append(action)
		var sheet := Image.create(420*4,360*actions.size(),false,Image.FORMAT_RGB8)
		if selected_part != "all" and emitter_index >= sources[selected_part].size():
			printerr("Missing emitter ", emitter_index, " for ", identity, ":", selected_part)
			quit(1)
			return
		var source: Array = [] if selected_part == "all" else sources[selected_part][emitter_index]
		var overview_markers := []
		if selected_part == "all":
			marker.hide()
		var captures := []
		for row in actions.size():
			var action := actions[row]
			var action_sources: Dictionary = sources.duplicate()
			for part: String in report.get("candidate_actions", {}).get(action, {}):
				if action_sources.has(part):
					action_sources[part] = report.candidate_actions[action][part]
			if selected_part != "all":
				if emitter_index >= action_sources[selected_part].size():
					printerr("Missing emitter ", emitter_index, " for ", identity, ":", selected_part, ":", action)
					quit(1)
					return
				source = action_sources[selected_part][emitter_index]
			else:
				for item: Dictionary in overview_markers: item.marker.free()
				overview_markers.clear()
				for part: String in action_sources:
					for group: Array in action_sources[part]:
						overview_markers.append({"source":group,"marker":_marker(PART_COLORS.get(part,Color.WHITE))})
			for column in 4:
				var fraction: float = pose_fractions[column]
				Pose.sample(player, action, player.get_animation(action).length*fraction)
				for rig: Skeleton3D in actor.find_children("*","Skeleton3D",true,false): rig.force_update_all_bone_transforms()
				for frame in 2: await process_frame
				if selected_part != "all":
					var active_sources := []
					for group: Array in action_sources[selected_part]:
						if _visible(actor, group): active_sources.append(group)
					assert(emitter_index < active_sources.size(), "Requested emitter is not visible in this pose")
					source = active_sources[emitter_index]
				marker.position = _point(actor,source)
				var geometry: Dictionary = report.geometry.get("head",{})
				var size := maxf(float(profile.get("bounds",{}).get("idle",{}).get("size",[0.6,1,1])[0])*0.65,0.08)
				if not geometry.is_empty():
					size = maxf(float(geometry.max[1])-float(geometry.min[1]),0.15)
				marker.scale = Vector3.ONE*size*0.025*camera_scale
				var direction := Vector3(0.8,0.25,1.9) if column < 3 else Vector3(1.9,0.15,0.3)
				direction.y += camera_elevation
				direction = direction.rotated(Vector3.UP,camera_yaw)*camera_scale
				var target := marker.position
				if selected_part == "all":
					await RenderingServer.frame_post_draw
					var box := _posed_bounds(actor)
					target = box.get_center()
					size = maxf(box.size.length()*0.95,0.01)
					for item: Dictionary in overview_markers:
						item.marker.visible = _visible(actor, item.source)
						item.marker.position = _point(actor,item.source)
						item.marker.scale = Vector3.ONE*size*0.012
				camera.position = target + direction*size
				camera.look_at(target)
				label.text = "%s | %s %.2f%s" % [identity,action,fraction," side" if column == 3 else ""]
				await process_frame
				await RenderingServer.frame_post_draw
				var shot := viewport.get_texture().get_image()
				sheet.blit_rect(shot,Rect2i(0,0,420,360),Vector2i(column*420,row*360))
				var bones := {}
				for rig: Skeleton3D in actor.find_children("*","Skeleton3D",true,false):
					for bone in rig.get_bone_count():
						bones[rig.get_bone_name(bone)] = _transform(rig.global_transform*rig.get_bone_global_pose(bone))
				captures.append({"action":action,"fraction":fraction,"column":column,"row":row,
					"camera":_transform(camera.global_transform),"fov":camera.fov,"bones":bones,"parts":action_sources,"meshes":Pose.meshes(actor)})
		assert(sheet.save_png(output.path_join(identity+".png"))==OK)
		var file := FileAccess.open(output.path_join(identity+".json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"identity":identity,"runtime_sha256":entry.runtime_sha256,
			"width":420,"height":360,"parts":sources,"captures":captures,"pose_sampling":"forward_from_start_v1"},"\t")+"\n")
		file.close()
		for item: Dictionary in overview_markers: item.marker.free()
		actor.free()
		packed = null
		await process_frame
		print("ATTACHMENT_PREVIEW ",identity," poses=",actions.size()*4)
	quit()
