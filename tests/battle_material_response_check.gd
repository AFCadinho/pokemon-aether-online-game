extends SceneTree
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")

func _init() -> void:
	var material := StandardMaterial3D.new()
	assert(not Response.valid_material(material))
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	material.set_meta(Response.META, {"schema": 1, "endpoint_0": texture, "endpoint_1": texture, "specular": 0.46})
	assert(Response.valid_material(material))
	material.set_meta(Response.META, {"schema": 1, "endpoint_0": texture, "endpoint_1": texture, "specular": NAN})
	assert(not Response.valid_material(material))
	material.set_meta(Response.META, {"schema": 2, "endpoint_0": texture, "endpoint_1": texture, "specular": 0.46})
	assert(not Response.valid_material(material))
	material.set_meta(Response.META, {"schema": 1, "specular": 0.46})
	assert(not Response.valid_material(material))
	assert(not Response.valid_material(ShaderMaterial.new()))
	var world := Node3D.new()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	world.add_child(environment)
	Response.apply_neutral_lighting(world)
	assert(environment.environment.ambient_light_color == Color.WHITE)
	assert(is_equal_approx(environment.environment.ambient_light_energy, 0.14))
	var lights := 0
	var shadows := 0
	for child in world.get_children():
		if child is DirectionalLight3D:
			lights += 1
			shadows += int(child.shadow_enabled)
	assert(lights == 3 and shadows == 1)
	world.free()
	print("battle_material_response_check: PASS")
	quit()
