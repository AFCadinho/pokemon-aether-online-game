extends SceneTree
const Pack = preload("res://tools/sprite_factory/material_effect_pack.gd")
const Effect = preload("res://scripts/battle/battle_ui/material_effect.gd")
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")

func actor() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.resource_name = "fixture"
	node.mesh.surface_set_material(0, material)
	return node

func _init() -> void:
	var directory := ProjectSettings.globalize_path("user://batch-effect-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("map.png")
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	assert(image.save_png(path) == OK)
	var texture := {"path": path, "sha256": FileAccess.get_sha256(path)}
	var manifest := {"schema": 1, "glb_sha256": "fixture", "records": [{
		"material": "fixture", "profile": "scvi_unlit_layered_displacement_v1",
		"loop_seconds": 2.0, "height": 0.05, "intensity": 1.0, "alpha_cutoff": 0.0,
		"use_uv2": false, "color": texture, "LayerMaskMap": texture, "DisplacementMap": texture,
		"tracks": {"UVScaleOffset": [[1,1],[1,1],[0,-1],[0,0]],
			"UVScaleOffset3": [[1,1],[1,1],[0,2],[0,2]]}}]}
	var pack := Pack.new()
	var node := actor()
	assert(pack.apply(node, manifest, "fixture"), pack.failure)
	assert(Effect.valid(node.get_active_material(0)) and Response.supported_actor(node))
	var saved := PackedScene.new()
	assert(saved.pack(node) == OK)
	var scene_path := directory.path_join("model.scn")
	assert(ResourceSaver.save(saved, scene_path, ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceLoader.get_dependencies(scene_path).is_empty())
	node.free()
	var restored: MeshInstance3D = load(scene_path).instantiate()
	assert(Effect.valid(restored.get_active_material(0)))
	var copy: MeshInstance3D = load(scene_path).instantiate()
	var response := Response.new()
	var pairs := []
	var original := restored.get_active_material(0)
	response._pair(restored, copy, pairs)
	assert(restored.get_active_material(0) == original)
	var hidden := copy.get_active_material(0)
	assert("discard" in hidden.shader.code)
	assert(pairs.size() == 1)
	response.free()
	copy.free()
	restored.free()
	for kind in ["glb", "texture", "duplicate", "profile", "uv_set", "nan", "zero_loop", "tracks", "endpoint", "cycle", "scale", "material"]:
		var bad := manifest.duplicate(true)
		match kind:
			"glb": bad.glb_sha256 = "other"
			"texture": bad.records[0].color.sha256 = "a".repeat(64)
			"duplicate": bad.records.append(bad.records[0].duplicate(true))
			"profile": bad.records[0].profile = "guessed"
			"uv_set": bad.records[0].use_uv2 = true
			"nan": bad.records[0].height = NAN
			"zero_loop": bad.records[0].loop_seconds = 0
			"tracks": bad.records[0].erase("tracks")
			"endpoint": bad.records[0].tracks.UVScaleOffset[0] = [1]
			"cycle": bad.records[0].tracks.UVScaleOffset[2] = [0,0.5]
			"scale": bad.records[0].tracks.UVScaleOffset[0] = [1,2]
			"material": bad.records[0].material = "missing"
		node = actor()
		assert(not pack.apply(node, bad, "fixture"), kind)
		node.free()
	for file in [scene_path, path]: DirAccess.remove_absolute(file)
	DirAccess.remove_absolute(directory)
	print("BATCH_MATERIAL_EFFECT_OK")
	quit()
