extends SceneTree
const Layered = preload("res://scripts/battle/battle_ui/material_layered_static.gd")
const Effect = preload("res://scripts/battle/battle_ui/material_effect.gd")

func _initialize() -> void:
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = Layered.SHADER.code
	material.set_meta("pokeaether_layered_static", 1)
	for key: String in ["color_tex","mask_tex","displacement_tex"]:
		material.set_shader_parameter(key,ImageTexture.create_from_image(Image.create(2 if key=="color_tex" else 4,4,false,Image.FORMAT_RGBA8)))
	for key: String in ["layer_1","layer_2","layer_3","layer_4","layer_scales"]:
		material.set_shader_parameter(key,Vector4.ONE)
	for key: String in ["mask_start","mask_end","displacement_start","displacement_end"]:
		material.set_shader_parameter(key,Vector4(1,1,0,0))
	for key: String in ["height","alpha_cutoff"]: material.set_shader_parameter(key,0.0)
	for key: String in ["intensity","loop_seconds"]: material.set_shader_parameter(key,1.0)
	material.set_shader_parameter("use_uv2",false)
	assert(Layered.valid(material) and Effect.valid(material))
	# Distinct source resolutions are legal; missing maps and uncontrolled
	# shader changes are not. Never broaden the existing arbitrary-code gate.
	material.set_shader_parameter("layer_1",Vector4(NAN,1,1,1))
	assert(not Effect.valid(material))
	material.set_shader_parameter("layer_1",Vector4.ONE)
	material.set_shader_parameter("mask_end",Vector4(1,1,1,0))
	assert(not Effect.valid(material))
	material.set_shader_parameter("mask_end",Vector4(1,1,0,0))
	material.set_shader_parameter("height",1.0)
	assert(not Effect.valid(material))
	material.set_shader_parameter("height",0.0)
	material.set_shader_parameter("color_tex",null)
	assert(not Effect.valid(material))
	material.shader.code += "\n// changed shader"
	assert(not Effect.valid(material))
	print("LAYERED_STATIC_MATERIAL_OK independent_resolutions=true invalid_payloads_rejected=5")
	quit()
