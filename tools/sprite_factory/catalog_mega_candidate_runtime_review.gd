extends "res://tools/sprite_factory/catalog_dlc_runtime_review.gd"
## Give native metal/ice surfaces the same neutral reflection sky as Mega battle review.
var reflections_ready := false

func _review(entry: Dictionary, output: String) -> Dictionary:
	if not reflections_ready:
		for node in world.get_children():
			if node is WorldEnvironment:
				var sky := Sky.new()
				var material := ProceduralSkyMaterial.new()
				material.sky_top_color = Color(.45, .55, .7)
				material.sky_horizon_color = Color(.8, .85, .9)
				material.ground_bottom_color = Color(.25, .3, .35)
				material.ground_horizon_color = Color(.8, .85, .9)
				sky.sky_material = material
				node.environment.sky = sky
				node.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
				reflections_ready = true
	return await super._review(entry, output)
