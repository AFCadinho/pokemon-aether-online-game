extends "res://tools/sprite_factory/control_render_probe.gd"
## Isolated interventions; never rewrites model files or changes admission.
func _run() -> void:
	output = OS.get_environment("DARKNESS_OUTPUT")
	assert(not output.is_empty() and not DirAccess.dir_exists_absolute(output))
	DirAccess.make_dir_recursive_absolute(output)
	var ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/sprite_factory/catalog_100_visual_triage_results.json"))
	for row: Dictionary in ledger.entries:
		if row.species not in ["garchomp", "cloyster", "forretress", "blissey", "azumarill", "dragonite"]:
			continue
		var path := ProjectSettings.globalize_path("res://../").path_join(row.runtime_path)
		assert(FileAccess.get_sha256(path) == row.runtime_sha256)
		var stage := ControlStage.new()
		root.add_child(stage)
		stage.setup()
		stage.set_process(false)
		stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stage.size = Vector2(512,512)
		stage.active = true
		stage._build_world()
		stage.viewport.size = Vector2i(512,512)
		stage.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var scene: PackedScene = load(path)
		var actor: Node3D = scene.instantiate()
		stage.world.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var box: AABB = await _sample(actor,player,"idle",0.0)
		actor.scale *= 2.8 / maxf(box.size.y,0.1)
		box = _bounds(actor)
		actor.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)
		stage.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		stage.camera.size = 4.8
		stage.camera.position = Vector3(3,2.5,8)
		stage.camera.look_at(Vector3(0,1.35,0))
		var values := []
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var mat: Material = mesh.get_active_material(surface)
				if mat is StandardMaterial3D:
					values.append({"material":mat.resource_name,"albedo":str(mat.albedo_color),"roughness":mat.roughness})
		stage.packed[row.species] = scene
		stage.identities[0] = row.species
		stage.actors[0] = actor
		var helper: Node = stage.material_response
		helper._process(0)
		helper._sync()
		await capture(stage,row.species+"-readable")
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var mat: Material = mesh.get_active_material(surface)
				if mat is ShaderMaterial:
					mat.set_shader_parameter("shadow_color_strength", 1.0)
		await capture(stage,row.species+"-baseline")
		var before: Image = stage.viewport.get_texture().get_image()
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var mat: Material = mesh.get_active_material(surface)
				if mat is ShaderMaterial:
					mat.set_shader_parameter("base_color",Color.WHITE)
		await capture(stage,row.species+"-white-factor")
		var after: Image = stage.viewport.get_texture().get_image()
		var original_shader: Shader = load("res://scripts/battle/battle_ui/material_response.gdshader")
		for mode in ["lit-endpoint", "shadow-endpoint", "unlit-endpoint"]:
			var shader := Shader.new()
			var amount_line := "float amount = (1.0 - smoothstep(0.5, 1.0, energy)) * clamp(shadow_color_strength, 0.0, 1.0);"
			assert(amount_line in original_shader.code)
			shader.code = original_shader.code.replace(amount_line, "float amount = %s;" % ("1.0" if mode == "shadow-endpoint" else "0.0"))
			if mode == "unlit-endpoint":
				shader.code = shader.code.replace("render_mode diffuse_burley,", "render_mode unshaded, diffuse_burley,")
			for mesh in actor.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					var mat: Material = mesh.get_active_material(surface)
					if mat is ShaderMaterial:
						mat.shader = shader
			await capture(stage,row.species+"-"+mode)
		assert(helper.viewport.get_texture().get_image().save_exr(output.path_join(row.species+"-irradiance.exr")) == OK)
		results.append({"species":row.species,"runtime_sha256":row.runtime_sha256,"materials":values,"white_factor_identical":before.get_data()==after.get_data()})
		stage.free()
		print("DARKNESS_PROBE ",row.species)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	quit()
