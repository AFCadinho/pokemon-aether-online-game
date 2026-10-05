extends Node
const SourceEffect = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
const LegacyEffect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const ApprovedPilot = preload("res://tests/ember_sv_effect_pilot.gd")
var seconds := 0.0
var camera: Camera3D
var anchors := {"source":Vector3(-2,1,0), "target":Vector3(2,1,0), "radius":0.8}
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	get_tree().create_timer(20.0).timeout.connect(func(): get_tree().quit(1))
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,3,6)
	camera.look_at(Vector3(0,1,0))
	var source_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-source="): source_dir = arg.trim_prefix("--legacy-source=")
	var manifest: Dictionary = {}
	if not source_dir.is_empty(): manifest = JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join("manifest.json")))
	for move in ["ember", "watergun"]:
		for outcome in ["hit", "miss", "block"]:
			seconds = 0
			var effect := SourceEffect.new()
			add_child(effect)
			effect.view_camera = camera
			var options := {"show_impact":outcome == "hit", "result":"miss" if outcome == "miss" else ""}
			effect.start(move, {"frames":60.0, "impact_frame":27.0}, options, func(): return seconds, func(): return anchors, func(): return true)
			effect.set_process(false)
			if not manifest.is_empty(): effect.presentation_scale = 1.0 # Compare the historical recipe before the size review.
			var old: Node3D
			var approved: Node3D
			if move == "ember" and not manifest.is_empty():
				old = LegacyEffect.new()
				add_child(old)
				old.view_camera = camera
				old.start(move, {"frames":60.0, "impact_frame":27.0}, options, func(): return seconds, func(): return anchors, func(): return true)
				old.set_process(false)
				# Keep the approved visual recipe; misses now aim straight while the target dodges.
				old.miss = false
				approved = ApprovedPilot.new()
				add_child(approved)
				approved.configure(old, source_dir, manifest)
				approved.set_process(false)
			for time in [0.2, 0.32, 0.44, 0.48, 0.58, 0.7]:
				seconds = time
				effect._process(0)
				assert(effect.pieces.size() < 32)
				for i in effect.pieces.size():
					if not effect.pieces[i].visible or i >= effect.sprite_keys.size(): continue
					if effect.sprite_keys[i] in ["ember_hit", "ember_sparks", "water_splash"]: assert(outcome == "hit")
				if approved != null:
					old._process(0)
					approved._process(0)
					assert(effect.cursor == approved.cursor, "Approved Ember sprite count changed")
					for i in effect.cursor:
						assert(effect.pieces[i].transform.is_equal_approx(approved.sprites[i].transform), "Approved Ember placement changed outcome=%s time=%f i=%d got=%s want=%s" % [outcome, time, i, effect.pieces[i].transform, approved.sprites[i].transform])
						var actual: ShaderMaterial = effect.pieces[i].material_override
						var expected: ShaderMaterial = approved.sprites[i].material_override
						for parameter in ["frame_index", "opacity", "frames"]:
							assert(is_equal_approx(actual.get_shader_parameter(parameter), expected.get_shader_parameter(parameter)))
						var tint: Vector3 = actual.get_shader_parameter("tint")
						assert(tint.is_equal_approx(expected.get_shader_parameter("tint")))
			effect.cancel()
			if old != null: old.cancel()
			await get_tree().process_frame
			await get_tree().process_frame
	print("SOURCE_MOVE_EFFECTS_3D_OK moves=2 outcomes=3 bounded_geometry=true approved_ember_parity=", not manifest.is_empty())
	get_tree().quit()
