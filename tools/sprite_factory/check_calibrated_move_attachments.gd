extends SceneTree
## Check every calibrated part against real normal/shiny clips. Does not certify visuals.
const Attachments = preload("res://scripts/battle/battle_ui/move_attachments_3d.gd")
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const Pose = preload("res://tools/sprite_factory/attack_attachment_pose.gd")
var catalog_path := ""
var output := "res://.tmp/attack-attachments/calibrated-check.json"
var errors: Array[String] = []
var profile_sha256 := ""
var selected: Array[String] = []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in ["--catalog", "--output", "--species"] and i + 1 >= args.size():
			printerr("Missing value for ", args[i])
			quit(1)
			return
		if args[i] == "--catalog": catalog_path = args[i+1]
		if args[i] == "--output": output = args[i+1]
		if args[i] == "--species": selected.assign(args[i+1].split(","))
	_run.call_deferred()

func _run() -> void:
	profile_sha256 = FileAccess.get_sha256("res://data/battle_move_attachments_3d.json")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if raw is Dictionary: raw = raw.get("entries", [])
	if not raw is Array:
		printerr("Supply --catalog with the complete approved local runtime catalog")
		quit(1)
		return
	var entries := {}
	for entry: Dictionary in raw: entries[Catalog.entry_key(entry)] = entry
	var world := Node3D.new()
	root.add_child(world)
	var checks := {}
	for species: String in selected:
		if not Attachments.CALIBRATED.data.profiles.has(species): errors.append("Missing requested calibration: " + species)
	for species: String in Attachments.CALIBRATED.data.profiles:
		if not selected.is_empty() and species not in selected: continue
		var normal := {}
		for identity: String in [species,species+"@shiny"]:
			if not entries.has(identity):
				errors.append("Missing catalog model: "+identity)
				continue
			var entry: Dictionary = entries[identity]
			var digest := FileAccess.get_sha256(str(entry.runtime_path))
			if Catalog.resolve(identity,digest).is_empty():
				errors.append("Unapproved scene: "+identity)
				continue
			if identity == species:
				var calibration: Dictionary = Attachments.CALIBRATED.data.profiles[species]
				var reviews: Array = calibration.get("part_reviews", {}).values()
				if calibration.has("review"): reviews.append(calibration.review)
				var revision_matches := not reviews.is_empty()
				for review: Dictionary in reviews:
					if digest != review.get("normal_runtime_sha256", ""): revision_matches = false
				if not revision_matches:
					errors.append("Calibration revision differs: "+identity)
					continue
			var packed := ResourceLoader.load(str(entry.runtime_path),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
			if packed == null:
				errors.append("Cannot load scene: "+identity)
				continue
			var actor := packed.instantiate() as Node3D
			world.add_child(actor)
			var players := actor.find_children("*","AnimationPlayer",true,false)
			if players.size() != 1:
				errors.append("Ambiguous player: "+identity)
				actor.free()
				continue
			var player: AnimationPlayer = players[0]
			preload("res://scripts/battle/animations/reviewed_source_visibility.gd").apply(actor,identity,digest)
			preload("res://scripts/battle/animations/gliscor_flight.gd").apply(player,identity,digest)
			preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(player,identity,digest)
			preload("res://scripts/battle/animations/charmander_breath.gd").apply(player,identity,digest)
			var available_actions := {}
			for action: String in player.get_animation_list(): available_actions[action] = {}
			for move: String in Attachments.CALIBRATED.data.profiles[species].get("move_actions", {}):
				if Attachments.action_for(identity,move,available_actions).is_empty():
					errors.append("Unavailable move action: "+identity+":"+move)
			var poses := {}
			for action: String in player.get_animation_list():
				if action != "idle" and not "attack" in action: continue
				for frame in 21:
					Pose.sample(player, action, player.get_animation(action).length*float(frame)/20.0)
					for rig: Skeleton3D in actor.find_children("*","Skeleton3D",true,false): rig.force_update_all_bone_transforms()
					for part: String in Attachments.configured_parts(identity):
						# An action-only emitter has no binding in other native clips.
						if Attachments.definitions_for(identity,part,action).is_empty(): continue
						var result := Attachments.sample_part(actor,identity,part,world,action)
						var key := "%s:%d:%s" % [action,frame,part]
						if result.is_empty():
							errors.append("Unbound attachment: "+identity+":"+key)
							continue
						var points := []
						for point: Vector3 in result.sources:
							if not point.is_finite(): errors.append("Non-finite point: "+identity+":"+key)
							points.append([point.x,point.y,point.z])
						poses[key] = points
			if identity == species:
				normal = poses
			else:
				if normal.keys() != poses.keys(): errors.append("Shiny action coverage differs: "+species)
				for key: String in normal:
					if not poses.has(key) or poses[key].size() != normal[key].size():
						errors.append("Shiny emitter count differs: "+species+":"+key)
						continue
					for source in normal[key].size():
						for axis in 3:
							if absf(normal[key][source][axis]-poses[key][source][axis]) > 0.001:
								errors.append("Shiny attachment pose differs: "+species+":"+key)
			checks[identity] = {"runtime_sha256":digest,"sample_count":poses.size(),"pose_sha256":JSON.stringify(poses).sha256_text()}
			# Keep GPU resources alive until mesh instances have been removed.
			var render_resources := _retain_render_resources(actor)
			actor.free()
			await process_frame
			packed = null
			render_resources.clear()
		print("CALIBRATED_ATTACHMENT_CHECK ",species)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		printerr("Cannot write ", output)
		quit(1)
		return
	file.store_string(JSON.stringify({"schema":1,"models":checks,"errors":errors,
		"visual_verification":false,"samples_per_action":21,
		"profile_count": Attachments.CALIBRATED.data.profiles.size(),
		"requested_species":selected, "checked_profile_count":checks.size()/2,
		"profile_sha256": profile_sha256},"\t",true)+"\n")
	file.close()
	for error: String in errors: printerr(error)
	print("CALIBRATED_ATTACHMENTS_CHECKED models=",checks.size()," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)

func _retain_render_resources(actor: Node3D) -> Array[Resource]:
	var resources: Array[Resource] = []
	for instance: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if instance.mesh != null:
			resources.append(instance.mesh)
			for surface in instance.mesh.get_surface_count():
				var material := instance.get_active_material(surface)
				if material != null: resources.append(material)
		if instance.material_overlay != null: resources.append(instance.material_overlay)
	return resources
