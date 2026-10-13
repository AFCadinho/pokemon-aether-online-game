extends SceneTree
const Probe = preload("res://tests/android_gpu_isolation_check.gd")
const Cutout = preload("res://scripts/battle/arenas/shared/android_grass_cutout.gd")
const DrawOrder = preload("res://scripts/battle/arenas/shared/android_grass_draw_order.gd")
func _init() -> void:
	var fixture: Dictionary = JSON.parse_string('{"schema":1,"run_id":"0123456789abcdef0123456789abcdef","phase_seconds":15,"rounds":2}')
	assert(Probe.valid_fixture(fixture), "Host integer JSON parses as Godot float numbers")
	fixture.candidate = "grass_early_cutout"
	assert(Probe.valid_fixture(fixture), "Bounded candidate workload")
	fixture.candidate = "other"
	assert(not Probe.valid_fixture(fixture), "Reject unknown candidates")
	fixture.erase("candidate")
	for key in ["phase_seconds", "rounds"]:
		for bad in [null, true, "15", 15.5, 100]:
			var invalid := fixture.duplicate()
			invalid[key] = bad
			assert(not Probe.valid_fixture(invalid), "Reject malformed or unbounded workload")
	fixture.run_id = "../../other"
	assert(not Probe.valid_fixture(fixture), "Bound run identity")
	var source := "shader_type spatial;\nvarying vec2 world_xz;\nuniform sampler2D variation_noise;\nuniform sampler2D alpha_mask;\nuniform float variation_scale;\nuniform float alpha_threshold;\nvoid fragment() {\nALBEDO = vec3(texture(variation_noise, world_xz * variation_scale).r);\nALPHA = texture(alpha_mask, UV).a;\nALPHA_SCISSOR_THRESHOLD = alpha_threshold;\n}"
	var original := ShaderMaterial.new()
	original.shader = Shader.new()
	original.shader.code = source
	original.set_shader_parameter("alpha_threshold", 0.31)
	var candidate: ShaderMaterial = Cutout.material(original)
	assert(candidate != null and candidate != original and candidate.shader != original.shader, "Independent resources")
	assert(original.shader.code == source and candidate.get_shader_parameter("alpha_threshold") == original.get_shader_parameter("alpha_threshold"), "Original code and uniform values retained")
	assert(candidate.shader.code.find("discard;") < candidate.shader.code.find("textureGrad("), "Cutout precedes colour work")
	assert(candidate.shader.code.find("dFdx(") < candidate.shader.code.find("discard;"), "Gradients precede divergent discard")
	assert(Cutout.material(StandardMaterial3D.new()) == null and Cutout.shader_code("unexpected shader").is_empty(), "Unknown materials remain untouched")
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	batch.mesh = QuadMesh.new()
	batch.instance_count = 3
	batch.visible_instance_count = 2
	for index in 3:
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(0, 0, [10, 1, 0][index])))
		batch.set_instance_color(index, Color(index * 0.25, 0, 0, 1))
		batch.set_instance_custom_data(index, Color(0, index * 0.25, 0, 1))
	var ordered := DrawOrder.ordered(batch, Vector3.ZERO)
	assert(ordered.mesh == batch.mesh and ordered.visible_instance_count == 2, "Preserve mesh and visible population")
	assert(ordered.get_instance_transform(0) == batch.get_instance_transform(1) and ordered.get_instance_transform(1) == batch.get_instance_transform(0), "Near visible instances drawn first")
	assert(ordered.get_instance_color(0) == batch.get_instance_color(1) and ordered.get_instance_custom_data(0) == batch.get_instance_custom_data(1), "Reorder attributes with geometry")
	assert(batch.get_instance_transform(0).origin.z == 10 and ordered.get_instance_transform(2) == batch.get_instance_transform(2), "Original and hidden suffix unchanged")
	print("ANDROID_GPU_FIXTURE_PASS")
	quit()
