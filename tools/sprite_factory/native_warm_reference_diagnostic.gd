extends "res://tools/sprite_factory/native_paired_reference_check.gd"
## Isolation probes run AFTER an unchanged strict comparison has failed.
## They never qualify modified lighting, hidden geometry or relaxed tolerances.

func pipelines() -> Array:
	return [Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
		Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)]

func diagnostic_pair(stage: Stage,actors: Array,action: String,fraction: float,label: String) -> void:
	var a:=await shot(stage,actors,0,action,fraction)
	var b:=await shot(stage,actors,1,action,fraction)
	var evidence:=difference(a,b)
	evidence.merge({"probe":label,"pixel_exact":a.bytes==b.bytes,
		"sha_a":Components.sha(a.bytes),"sha_b":Components.sha(b.bytes)})
	report.diagnostics.append(evidence)
	assert(a.image.save_png(directory.path_join(label+"-a.png"))==OK)
	assert(b.image.save_png(directory.path_join(label+"-b.png"))==OK)

func failure_diagnostics(stage: Stage,actors: Array,action: String,fraction: float) -> void:
	report["diagnostic_only"] = true
	report["diagnostics"] = []
	report["pipeline_before"] = pipelines()
	for frame in 180:await process_frame
	await diagnostic_pair(stage,actors,action,fraction,"settled")
	report["pipeline_after_wait"] = pipelines()
	# Exact mesh names are explicitly provided, never guessed or hidden in a gate.
	for mesh_name in OS.get_environment("NATIVE_DIAGNOSTIC_MESHES").split(",",false):
		var meshes:=[]
		for actor in actors:
			var mesh:=actor.find_child(mesh_name,true,false) as MeshInstance3D
			assert(mesh!=null and mesh.visible,"Expected visible diagnostic mesh: "+mesh_name)
			meshes.append(mesh)
			mesh.visible=false
		await diagnostic_pair(stage,actors,action,fraction,"without-"+mesh_name)
		for mesh in meshes:mesh.visible=true
	await diagnostic_pair(stage,actors,action,fraction,"restored-meshes")
	var shadows: Dictionary={}
	for light in stage.world.get_children():
		if light is DirectionalLight3D:
			shadows[light]=light.shadow_enabled
			light.shadow_enabled=false
	await diagnostic_pair(stage,actors,action,fraction,"no-shadow")
	var normals: Dictionary={}
	for actor in actors:
		for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var mat: Material=mesh.get_active_material(surface)
				if mat is StandardMaterial3D and not normals.has(mat):
					normals[mat]=mat.normal_enabled
					mat.normal_enabled=false
	await diagnostic_pair(stage,actors,action,fraction,"no-shadow-no-normal")
	for mat in normals:mat.normal_enabled=normals[mat]
	for light in shadows:light.shadow_enabled=shadows[light]
	# The caller still saves an incomplete report and exits 2 for the strict failure.
