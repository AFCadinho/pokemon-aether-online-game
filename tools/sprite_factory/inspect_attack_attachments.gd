extends SceneTree
## Read-only model inspection. Measurements are candidates, never runtime approval.
const Catalog = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
var output := "res://.tmp/attack-attachments/inspection"
var catalog_path := ""
var selected: Array[String] = []
var limit := 0
var world: Node3D

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in ["--catalog", "--output", "--species", "--limit"] and i + 1 >= args.size():
			printerr("Missing value for ", args[i])
			quit(1)
			return
		if args[i] == "--catalog": catalog_path = args[i+1]
		if args[i] == "--output": output = args[i+1]
		if args[i] == "--species": selected.assign(args[i+1].split(","))
		if args[i] == "--limit": limit = int(args[i+1])
	_run.call_deferred()

func _run() -> void:
	if not FileAccess.file_exists(catalog_path):
		printerr("Supply --catalog with an existing local runtime catalog")
		quit(1)
		return
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if entries is Dictionary: entries = entries.get("entries", [])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	world = Node3D.new()
	root.add_child(world)
	var completed := 0
	for entry: Dictionary in entries:
		var identity := Catalog.entry_key(entry)
		if identity.ends_with("@shiny"): continue
		if not selected.is_empty() and identity not in selected: continue
		var destination := output.path_join(identity + ".json")
		if FileAccess.file_exists(destination): continue
		var path := str(entry.runtime_path)
		var digest := FileAccess.get_sha256(path)
		var profile := Catalog.resolve(identity, digest)
		if profile.is_empty():
			printerr("Unapproved model: ", identity)
			quit(1)
			return
		var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if packed == null:
			printerr("Cannot load: ", identity)
			quit(1)
			return
		var actor := packed.instantiate() as Node3D
		world.add_child(actor)
		preload("res://scripts/battle/animations/reviewed_source_visibility.gd").apply(actor, identity, digest)
		var players := actor.find_children("*", "AnimationPlayer", true, false)
		var report := {"schema":1,"identity":identity,"runtime_sha256":digest,
			"review_status":"unreviewed","bones":[],"actions":{},"geometry":{}}
		for skeleton: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
			for bone in skeleton.get_bone_count():
				report.bones.append({"name":skeleton.get_bone_name(bone),"parent":skeleton.get_bone_parent(bone),"skeleton":str(actor.get_path_to(skeleton))})
		if not players.is_empty():
			var player: AnimationPlayer = players[0]
			player.stop()
			for action: StringName in player.get_animation_list():
				if "attack" in action or action == "idle":
					report.actions[action] = {"seconds":player.get_animation(action).length}
		_measure_geometry(actor, report)
		_enrich_report(actor, report)
		var file := FileAccess.open(destination, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t", true) + "\n")
		file.close()
		# Hold materials until render instances have detached; local-to-scene
		# material RIDs otherwise race MeshInstance teardown in offline probes.
		var materials: Array = []
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			materials.append(mesh.material_override)
			materials.append(mesh.material_overlay)
			if mesh.mesh != null:
				for surface in mesh.mesh.get_surface_count():
					materials.append(mesh.get_surface_override_material(surface))
					materials.append(mesh.mesh.surface_get_material(surface))
		actor.free()
		packed = null
		await process_frame
		materials.clear()
		completed += 1
		print("ATTACHMENT_INSPECT ",identity," bones=",report.bones.size()," actions=",report.actions.keys())
		if limit > 0 and completed >= limit: break
	print("ATTACHMENT_INSPECTION_COMPLETE count=",completed)
	quit()

func _enrich_report(_actor: Node3D, _report: Dictionary) -> void:
	pass

func _measure_geometry(actor: Node3D, report: Dictionary) -> void:
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null or not mesh.is_visible_in_tree(): continue
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton == null: continue
		var bindings := {}
		for bind in mesh.skin.get_bind_count():
			var name_value := str(mesh.skin.get_bind_name(bind))
			if name_value.is_empty(): name_value = skeleton.get_bone_name(mesh.skin.get_bind_bone(bind))
			bindings[bind] = name_value
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			if vertices.is_empty() or bones.is_empty(): continue
			var stride := bones.size() / vertices.size()
			for vertex in vertices.size():
				for influence in stride:
					if weights[vertex*stride+influence] < 0.5: continue
					var bind: int = bones[vertex*stride+influence]
					var bone_name: String = bindings.get(bind, "")
					if bone_name.is_empty(): continue
					var point: Vector3 = mesh.skin.get_bind_pose(bind) * vertices[vertex]
					var row: Dictionary = report.geometry.get(bone_name, {"count":0,"min":[point.x,point.y,point.z],"max":[point.x,point.y,point.z]})
					row.count += 1
					for axis in 3:
						row.min[axis] = minf(row.min[axis], point[axis])
						row.max[axis] = maxf(row.max[axis], point[axis])
					report.geometry[bone_name] = row
