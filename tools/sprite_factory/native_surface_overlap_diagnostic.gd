extends "res://tools/sprite_factory/native_resource_compression_check.gd"
## CPU ray evidence for coincident posed surfaces; diagnostic only, not a visual gate.
func _run() -> void:
	sink.tree=self
	OS.add_logger(sink)
	var path: String=OS.get_environment("NATIVE_OVERLAP_SOURCE")
	var expected: String=OS.get_environment("NATIVE_OVERLAP_SOURCE_SHA256")
	assert(not expected.is_empty() and FileAccess.get_sha256(path)==expected)
	var pixels: Array=JSON.parse_string(OS.get_environment("NATIVE_OVERLAP_PIXELS"))
	assert(not pixels.is_empty())
	var a: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var b: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var actors: Array=[a.instantiate(),b.instantiate()]
	var stage:=make_stage()
	for actor: Node3D in actors:
		stage.world.add_child(actor)
		pose(actor,"idle",0)
	var box:=bounds(actors[0])
	stage.camera.position=box.get_center()+Vector3(0,.1,1).normalized()*maxf(box.size.length(),.1)*2
	stage.camera.look_at(box.get_center())
	stage.camera.far=1000
	for actor: Node3D in actors:pose(actor,OS.get_environment("NATIVE_OVERLAP_ACTION"),float(OS.get_environment("NATIVE_OVERLAP_FRACTION")))
	await process_frame
	await RenderingServer.frame_post_draw
	var output:=[]
	for actor: Node3D in actors:
		var actor_data:=[]
		for coordinates in pixels:
			var pixel:=Vector2(coordinates[0],coordinates[1])
			var hits:=[]
			var ray_origin:=stage.camera.project_ray_origin(pixel)
			var ray_dir:=stage.camera.project_ray_normal(pixel)
			for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
				var posed: Mesh=mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin!=null else mesh.mesh
				var local_origin:=mesh.global_transform.affine_inverse()*ray_origin
				var local_dir:=mesh.global_transform.basis.inverse()*ray_dir
				for s in posed.get_surface_count():
					var arrays:=posed.surface_get_arrays(s)
					var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
					var indexes: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
					var count: int=vertices.size() if indexes.is_empty() else indexes.size()
					for offset in range(0,count,3):
						var i0: int=offset if indexes.is_empty() else indexes[offset]
						var i1: int=offset+1 if indexes.is_empty() else indexes[offset+1]
						var i2: int=offset+2 if indexes.is_empty() else indexes[offset+2]
						var point: Variant=Geometry3D.ray_intersects_triangle(local_origin,local_dir,vertices[i0],vertices[i1],vertices[i2])
						if point==null:continue
						var mat: Material=mesh.get_active_material(s)
						hits.append({"distance":ray_origin.distance_to(mesh.global_transform*point),"mesh":str(actor.get_path_to(mesh)),"surface":s,"triangle":offset/3,"material":mat.resource_name,"geometry_rid":mesh.mesh.get_rid().get_id(),"material_rid":mat.get_rid().get_id()})
			hits.sort_custom(func(x,y):return x.distance<y.distance)
			actor_data.append({"pixel":str(pixel),"hits":hits.slice(0,12)})
		output.append(actor_data)
	report["diagnostic_only"]=true
	report["source_sha256"]=expected
	report["action"]=OS.get_environment("NATIVE_OVERLAP_ACTION")
	report["fraction"]=OS.get_environment("NATIVE_OVERLAP_FRACTION")
	report["ray_hits"]=output
	report.complete=sink.errors.is_empty()
	save_report()
	stage.queue_free()
	for i in 3:await process_frame
	quit()
