extends SceneTree
const Effect = preload("res://scripts/battle/battle_ui/material_effect.gd")
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")

func _init() -> void:
	var material := ShaderMaterial.new()
	material.shader = Effect.FIRE_SHADER
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	material.set_shader_parameter("coverage_tex", texture)
	material.set_shader_parameter("noise_tex", texture)
	assert(Effect.valid(material))
	var actor := MeshInstance3D.new()
	actor.mesh = BoxMesh.new()
	actor.mesh.surface_set_material(0, material)
	assert(Response.supported_actor(actor))
	var copy: MeshInstance3D = actor.duplicate()
	var response := Response.new()
	var pairs := []
	response._pair(actor, copy, pairs)
	assert(actor.get_active_material(0) == material)
	var hidden: ShaderMaterial = copy.get_active_material(0)
	assert("discard" in hidden.shader.code)
	copy.free()
	actor.free()
	response.free()
	for key in ["coverage_tex", "noise_tex"]:
		var broken: ShaderMaterial = material.duplicate()
		broken.set_shader_parameter(key, null)
		assert(not Effect.valid(broken))
	for change in [["loop_seconds", 0.0], ["loop_seconds", NAN], ["review_time", 0.5], ["coverage_gain", -1.0], ["uv_transform", Vector4(0, 1, 0, 0)], ["fire_core", Vector3(NAN, 0, 0)]]:
		var broken: ShaderMaterial = material.duplicate()
		broken.set_shader_parameter(change[0], change[1])
		assert(not Effect.valid(broken))
	var unknown: ShaderMaterial = material.duplicate()
	unknown.shader = Shader.new()
	unknown.shader.code = Effect.FIRE_SHADER.code + "\n// Unreviewed revision"
	assert(not Effect.valid(unknown))
	assert(Effect.FIRE_SHADER.code == FileAccess.get_file_as_string("res://tools/sprite_factory/catalog_fire_preview.gdshader"))
	print("REVIEWED_FIRE_MATERIAL_OK exact_shader=true live_clock=true rejection_cases=9")
	quit()
