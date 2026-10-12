extends SceneTree
## Preserve every preview resource except per-instance material ownership.
const Audit = preload("model_texture_audit.gd")
var materials := {}
var visited := {}

func visit(value: Variant) -> void:
	if value is Resource:
		var id: int = value.get_instance_id()
		if visited.has(id): return
		visited[id] = true
		if value is Material:
			materials[value] = value.resource_local_to_scene
		for name: String in Audit.storage_properties(value): visit(value.get(name))
	elif value is Array:
		for item in value: visit(item)
	elif value is Dictionary:
		for item in value.values(): visit(item)

func actor_materials(actor: Node) -> String:
	var values := []
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count(): values.append(mesh.get_active_material(surface))
	return Audit.signature(values)

func check_isolation(scene: PackedScene, entry: Dictionary) -> int:
	var a := scene.instantiate()
	var b := scene.instantiate()
	root.add_child(a)
	root.add_child(b)
	var pa: AnimationPlayer = a.find_children("*","AnimationPlayer",true,false)[0]
	var pb: AnimationPlayer = b.find_children("*","AnimationPlayer",true,false)[0]
	pb.play("idle"); pb.pause(); pb.seek(0,true)
	var before := actor_materials(b)
	var samples := 0
	for action: String in entry.animations:
		pa.play(action); pa.pause()
		for fraction in [0.0,0.25,0.5,0.75,1.0]:
			pa.seek(pa.get_animation(action).length*fraction,true)
			assert(actor_materials(b)==before,"Animation leaked into another Zygarde")
			samples += 1
	a.free(); b.free()
	return samples

class ErrorSink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING:
			printerr("ZYGARDE_PREPARE_ABORT ",code," ",rationale)
			tree.call_deferred("quit",2)
var error_sink := ErrorSink.new()
func _initialize() -> void:
	error_sink.tree = self
	OS.add_logger(error_sink)
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size()==2)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var folder: String = args[1]
	assert(not DirAccess.dir_exists_absolute(folder))
	DirAccess.make_dir_recursive_absolute(folder)
	var rows := []
	for entry: Dictionary in source.entries:
		assert(FileAccess.get_sha256(entry.runtime_path)==entry.runtime_sha256)
		var scene := ResourceLoader.load(entry.runtime_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(scene != null and ResourceLoader.get_dependencies(entry.runtime_path).is_empty())
		materials.clear(); visited.clear(); visit(scene)
		for material: Material in materials: material.resource_local_to_scene = false
		var signature := Audit.signature(scene)
		for material: Material in materials:
			material.resource_local_to_scene = true
		var path := folder.path_join(entry.species+".scn")
		assert(ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS)==OK)
		var cold := ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var checks := check_isolation(cold,entry)
		materials.clear(); visited.clear(); visit(cold)
		for material: Material in materials:
			assert(material.resource_local_to_scene)
			material.resource_local_to_scene = false
		assert(Audit.signature(cold)==signature,"Changes beyond per-instance material ownership")
		var row := entry.duplicate(true)
		row["preview_runtime_path"] = entry.runtime_path
		row["preview_runtime_sha256"] = entry.runtime_sha256
		row["runtime_path"] = path
		row["runtime_sha256"] = FileAccess.get_sha256(path)
		row["material_isolation_samples"] = checks
		row["declared_changes_only"] = true
		row["declared_changes"] = ["per_instance_material_ownership"]
		row["action_timing"] = {}
		for action: String in row.animations:
			var clip: Dictionary = row.animations[action]
			row.action_timing[action] = {"frames":clip.duration*60,"speed":1,"loop":clip.loop}
		rows.append(row)
	var file := FileAccess.open(folder.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")); file.close()
	print("ZYGARDE_BATTLE_PREPARED pairs=1 isolation_samples=70 declared_changes_only=true")
	quit()
