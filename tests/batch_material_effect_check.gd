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
	var lit := manifest.duplicate(true)
	lit.records[0].profile = "scvi_standard_displacement_review_v1"
	node = actor()
	var surface: StandardMaterial3D = node.get_active_material(0)
	surface.metallic = 0.8
	surface.roughness = 0.35
	surface.emission_enabled = true
	surface.emission = Color(0.2, 0.4, 0.6)
	assert(pack.apply(node, lit, "fixture"), pack.failure)
	var lit_material: ShaderMaterial = node.get_active_material(0)
	assert(Effect.valid(lit_material) and Response.supported_actor(node))
	assert(is_equal_approx(lit_material.get_shader_parameter("surface_metallic"), 0.8))
	assert(is_equal_approx(lit_material.get_shader_parameter("surface_roughness"), 0.35))
	assert(lit_material.get_shader_parameter("emission_color") == surface.emission)
	var lit_scene := PackedScene.new()
	assert(lit_scene.pack(node) == OK)
	var lit_path := directory.path_join("lit.scn")
	assert(ResourceSaver.save(lit_scene, lit_path, ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceLoader.get_dependencies(lit_path).is_empty())
	node.free()
	var lit_restored: MeshInstance3D = load(lit_path).instantiate()
	assert(Effect.valid(lit_restored.get_active_material(0)))
	lit_restored.free()
	var source_static := manifest.duplicate(true)
	var smoke := manifest.duplicate(true)
	smoke.records[0].profile = "scvi_nondirectional_layered_displacement_v1"
	smoke.records[0].use_uv2 = true
	smoke.records[0].authored_reconstruction = "outward_rim_smoke_v1"
	node = actor()
	assert(pack.apply(node, smoke, "fixture"), pack.failure)
	assert(Effect.valid(node.get_active_material(0)))
	assert(node.get_active_material(0).shader.code == Effect.RIM_SMOKE_SHADER.code)
	node.free()
	for kind in ["unknown", "unlit", "sampled", "static"]:
		var bad_smoke := smoke.duplicate(true)
		match kind:
			"unknown": bad_smoke.records[0].authored_reconstruction = "guessed"
			"unlit": bad_smoke.records[0].profile = "scvi_unlit_layered_displacement_v1"
			"sampled": bad_smoke.records[0].uv_samples = {}
			"static": bad_smoke.records[0].static_source_material = true
		node = actor()
		assert(not pack.apply(node, bad_smoke, "fixture"), kind)
		node.free()
	source_static.records[0].static_source_material = true
	source_static.records[0].tracks = {"UVScaleOffset": [[2,2],[1,1],[0,0],[0,0]],
		"UVScaleOffset3": [[1,1],[1,1],[0,0],[0,0]]}
	node = actor()
	assert(pack.apply(node, source_static, "fixture"), pack.failure)
	assert(Effect.valid(node.get_active_material(0)))
	assert(node.get_active_material(0).shader.code == Effect.STATIC_SHADER.code)
	saved = PackedScene.new()
	assert(saved.pack(node) == OK)
	assert(ResourceSaver.save(saved, scene_path, ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceLoader.get_dependencies(scene_path).is_empty())
	node.free()
	restored = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE).instantiate()
	assert(Effect.valid(restored.get_active_material(0)))
	restored.free()
	for kind in ["animated", "sampled", "false"]:
		var invalid_static := source_static.duplicate(true)
		match kind:
			"animated": invalid_static.records[0].tracks.UVScaleOffset[2] = [0,1]
			"sampled": invalid_static.records[0].uv_samples = {}
			"false": invalid_static.records[0].static_source_material = false
		node = actor()
		assert(not pack.apply(node, invalid_static, "fixture"), kind)
		node.free()
	var sampled := manifest.duplicate(true)
	sampled.records[0].profile = "scvi_unlit_layered_displacement_uv2_v1"
	sampled.records[0].use_uv2 = true
	sampled.records[0].uv_samples = {"UVScaleOffset": [[1,1,0,0],[1,1,0.75,0],[1,1,-1,0]],
		"UVScaleOffset3": [[1,1,0,0],[1,1,0.25,0.5],[1,1,2,2]]}
	node = actor()
	assert(pack.apply(node, sampled, "fixture"), pack.failure)
	assert(Effect.valid(node.get_active_material(0)))
	assert(node.get_active_material(0).get_shader_parameter("uv_samples").get_image().get_pixel(1, 0).b == 0.75)
	saved = PackedScene.new()
	assert(saved.pack(node) == OK)
	assert(ResourceSaver.save(saved, scene_path, ResourceSaver.FLAG_COMPRESS) == OK)
	assert(ResourceLoader.get_dependencies(scene_path).is_empty())
	node.free()
	restored = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_REPLACE).instantiate()
	assert(Effect.valid(restored.get_active_material(0)))
	restored.free()
	for kind in ["length", "nan", "endpoint", "scale"]:
		var invalid := sampled.duplicate(true)
		match kind:
			"length": invalid.records[0].uv_samples.UVScaleOffset.pop_back()
			"nan": invalid.records[0].uv_samples.UVScaleOffset[1][2] = NAN
			"endpoint": invalid.records[0].uv_samples.UVScaleOffset[2][2] = 0
			"scale": invalid.records[0].uv_samples.UVScaleOffset[1][0] = 2
		node = actor()
		assert(not pack.apply(node, invalid, "fixture"), kind)
		node.free()
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
