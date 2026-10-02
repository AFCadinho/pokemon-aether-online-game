extends "res://tools/sprite_factory/catalog_batch_battle_review.gd"
## Fixed neutral reflection lighting for reproducible metal/crystal comparison.
## Full 60 Hz / independent 120 Hz measurements remain inherited unchanged.
var lighting_ready := false
var source_measurements: Dictionary = {}

func _validate_motion(entry: Dictionary, model: Node3D, player: AnimationPlayer, measured: Dictionary) -> Dictionary:
	# Floor sampling uses CPU-skinned vertices, not pixels. Exclude mesh draw
	# layers during the full-clock measurement, while keeping every node visible
	# for _bounds(). Restore the original layers before all rendered pose shots.
	# Bone/skin updates, sample frequency and clearance checks stay unchanged.
	var layers: Dictionary = {}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		layers[mesh] = mesh.layers
		mesh.layers = 0
	var sampled: Dictionary = await super._validate_motion(entry, model, player, measured)
	for mesh: MeshInstance3D in layers:
		mesh.layers = layers[mesh]
	return sampled

func _measure(entry: Dictionary, model: Node3D, player: AnimationPlayer) -> Dictionary:
	var baseline := OS.get_environment("POKEAETHER_MEGA_MEASUREMENT_BASELINE")
	if baseline.is_empty() or entry.species == "dragonite":
		return await super._measure(entry, model, player)
	if source_measurements.is_empty():
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baseline))
		assert(report.complete and report.sample_hz == 60)
		var source := OS.get_environment("POKEAETHER_PHASE5_REVIEW").path_join("catalog.json")
		assert(report.catalog_sha256 == FileAccess.get_sha256(source))
		assert(report.runtime_catalog_sha256 == FileAccess.get_sha256(OS.get_environment("POKEAETHER_PHASE5_RUNTIME_REPORT")))
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
		for row: Dictionary in report.entries:
			if row.has("clips"):
				assert(not source_measurements.has(row.species))
				source_measurements[row.species] = row
		assert(source_measurements.size() == catalog.entries.size() - 1)
		for candidate: Dictionary in catalog.entries:
			if candidate.species != "dragonite":
				assert(source_measurements.has(candidate.species))
				assert(source_measurements[candidate.species].glb_sha256 == candidate.glb_sha256)
	# Uniformly scale the already-measured 60 Hz data. The inherited validator
	# still samples every actual SCN at 120 Hz, including idle, independently.
	var original: Dictionary = source_measurements[entry.species]
	assert(original.glb_sha256 == entry.glb_sha256)
	var factor := float(readability[entry.species])
	var measured: Dictionary = original.duplicate(true)
	measured.erase("shots")
	measured.scale = float(original.scale) * factor
	model.scale = Vector3.ONE * float(measured.scale)
	measured.candidate_lift = maxf(0, .025 - float(original.clips.idle.minimum_y) * factor)
	for name: String in measured.clips:
		var clip: Dictionary = measured.clips[name]
		assert(player.has_animation(name) and is_equal_approx(player.get_animation(name).length, clip.duration))
		clip.minimum_y *= factor
		clip.maximum_minimum_y *= factor
		for i in clip.minimum_y_samples.size():
			clip.minimum_y_samples[i] *= factor
		for i in 3:
			clip.envelope_min[i] *= factor
			clip.envelope_size[i] *= factor
		clip.clearance_with_idle_lift = clip.minimum_y + measured.candidate_lift
	measured["measurement_origin"] = "analytically_scaled_pinned_60hz_baseline; independent native 120hz samples below"
	measured["baseline_sha256"] = FileAccess.get_sha256(baseline)
	return measured

func _render_frame() -> void:
	if not lighting_ready and is_instance_valid(world):
		for node in world.get_children():
			if node is WorldEnvironment:
				node.environment.ambient_light_color = Color(.65, .7, .8)
				var sky := Sky.new()
				var material := ProceduralSkyMaterial.new()
				material.sky_top_color = Color(.45, .55, .7)
				material.sky_horizon_color = Color(.8, .85, .9)
				material.ground_bottom_color = Color(.25, .3, .35)
				material.ground_horizon_color = Color(.8, .85, .9)
				sky.sky_material = material
				node.environment.sky = sky
				node.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
				lighting_ready = true
	await super._render_frame()
