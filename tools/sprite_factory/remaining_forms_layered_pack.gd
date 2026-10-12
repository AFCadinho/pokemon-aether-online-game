extends RefCounted
const Layered = preload("res://scripts/battle/battle_ui/material_layered_static.gd")
const Effect = preload("res://scripts/battle/battle_ui/material_effect.gd")

static func apply(actor: Node, records: Array) -> int:
	var used := {}
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(surface)
			for row: Dictionary in records:
				if source.resource_name != row.material: continue
				var old := mesh.get_active_material(surface) as ShaderMaterial
				assert(old != null and old.shader.code == Effect.STATIC_SHADER.code)
				var changed := ShaderMaterial.new()
				changed.shader = Shader.new()
				changed.shader.code = Layered.SHADER.code
				changed.resource_name = row.material
				changed.set_meta("pokeaether_layered_static", 1)
				for key: String in ["color_tex","mask_tex","displacement_tex","loop_seconds","height","intensity","alpha_cutoff","use_uv2","mask_start","mask_end","displacement_start","displacement_end"]:
					changed.set_shader_parameter(key, old.get_shader_parameter(key))
				for key: String in ["layer_1","layer_2","layer_3","layer_4","layer_scales"]:
					var v: Array = row[key]
					changed.set_shader_parameter(key,Vector4(v[0],v[1],v[2],v[3]))
				assert(Layered.valid(changed))
				mesh.set_surface_override_material(surface,changed)
				used[row.material]=true
	assert(used.size()==records.size())
	return used.size()
