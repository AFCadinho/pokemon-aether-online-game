extends SceneTree
const Pack = preload("res://tools/sprite_factory/material_response_pack.gd")
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")

func actor() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.resource_name = "fixture"
	node.mesh.surface_set_material(0, material)
	return node

func _init() -> void:
	var directory := ProjectSettings.globalize_path("user://batch-response-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("map.png")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	assert(image.save_png(path) == OK)
	var hash := FileAccess.get_sha256(path)
	var manifest := {"schema":1, "glb_sha256":"fixture", "maps":[{"material":"fixture", "interpolation":"EASE",
		"ramp":[[0.5,[1.0,1.0,1.0,1.0]],[1.0,[0.0,0.0,0.0,1.0]]],
		"0":path,"1":path,"0_sha256":hash,"1_sha256":hash}],
		"inputs":[{"material":"fixture","inputs":{"IOR":{"value":1.45,"links":[]},"SpecularMaskMap":{"value":0.5,"links":[]}}}]}
	var pack := Pack.new()
	var node := actor()
	assert(pack.apply(node,manifest,"fixture"),pack.failure)
	assert(node.get_meta(Response.META)==1 and Response.supported_actor(node))
	var saved := PackedScene.new()
	assert(saved.pack(node)==OK)
	var scene_path := directory.path_join("model.scn")
	assert(ResourceSaver.save(saved,scene_path,ResourceSaver.FLAG_COMPRESS)==OK)
	node.free()
	var restored = load(scene_path).instantiate()
	assert(restored.get_meta(Response.META)==1 and Response.supported_actor(restored))
	restored.free()
	for kind in ["glb","endpoint","ramp","duplicate","missing","specular","duplicate_input","missing_material","linked"]:
		var bad := manifest.duplicate(true)
		match kind:
			"glb": bad.glb_sha256="other"
			"endpoint": bad.maps[0]["0_sha256"]="a".repeat(64)
			"ramp": bad.maps[0].interpolation="LINEAR"
			"duplicate": bad.maps.append(bad.maps[0].duplicate(true))
			"missing": bad.erase("inputs")
			"specular": bad.inputs[0].inputs.IOR.value=-1
			"duplicate_input": bad.inputs.append(bad.inputs[0].duplicate(true))
			"missing_material": bad.inputs[0].erase("material")
			"linked": bad.inputs[0].inputs.IOR.links=["unsupported"]
		node=actor()
		assert(not pack.apply(node,bad,"fixture"),kind)
		node.free()
	for file in [scene_path,path]: DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(directory)
	print("BATCH_MATERIAL_RESPONSE_OK")
	quit()
