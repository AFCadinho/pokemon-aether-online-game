extends "res://tests/battle_move_effects_3d_check.gd"
var seconds := 0.0

func _run() -> void:
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(1))
	_setup()
	for move in ["Hyper Beam", "Solar Beam", "Electro Shot", "Flash Cannon", "Ice Beam"]:
		for emission_scale in [0.12, 1.0, 2.0]:
			for reverse in [false, true]:
				seconds = 0
				var effect: Node
				if move == "Ice Beam": effect = Stage.IceBeamMoveEffect.new()
				elif move == "Flash Cannon": effect = Stage.BatchFourMoveEffect.new()
				else: effect = Stage.StagedMoveEffect.new()
				stage.world.add_child(effect)
				var direction := -1.0 if reverse else 1.0
				var sources := [Vector3(-3 * direction, 3, 4.75), Vector3(-3 * direction, 3, 5.25)]
				var aim := Vector3(3 * direction, 3.4, 5)
				var points := {"source":sources[0], "sources":sources, "target":aim, "radius":0.6}
				effect.start(move, {"frames":60, "launch_frame":12, "impact_frame":42, "emission_end_frame":54, "emission_scale":emission_scale},
					{"show_impact":false}, func(): return seconds, func(): return points, func(): return true)
				effect.set_process(false)
				var previous_tip := 0.0
				for progress in [0.10, 0.55, 1.0]:
					seconds = lerpf(effect.launch, effect.impact, progress)
					effect._process(0)
					var count := 0
					var maximum_tip := 0.0
					for i in effect.cursor:
						var piece: MeshInstance3D = effect.pieces[i]
						if piece.mesh not in effect.beam_meshes.values(): continue
						count += 1
						var base: Vector3 = piece.position - piece.basis.y * 0.5
						var end: Vector3 = piece.position + piece.basis.y * 0.5
						var source: Vector3 = sources[0] if base.distance_to(sources[0]) < 0.001 else sources[1]
						assert(base.distance_to(source) < 0.001, "Beam begins exactly at its outlet")
						assert(end.distance_to(source.lerp(aim, progress)) < 0.001, "Beam length does not overshoot its tip")
						var throat: float = piece.mesh.bottom_radius * piece.basis.x.length()
						var tip: float = piece.mesh.top_radius * piece.basis.x.length()
						assert(tip > throat, "Beam widens toward its target")
						assert(throat < 0.10 * emission_scale, "Mouth and cannon outlets remain narrow")
						maximum_tip = maxf(maximum_tip, tip)
					assert(count >= sources.size(), "Both emitters render their own tapered beam")
					assert(maximum_tip > previous_tip, "The first short tip is smaller than the later distant tip")
					previous_tip = maximum_tip
				seconds = 0.92
				effect._process(0)
				for i in effect.cursor: assert(effect.pieces[i].mesh not in effect.beam_meshes.values(), "Emission ends before recovery")
				effect.cancel()
				await get_tree().process_frame
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("TAPERED_BEAMS_OK moves=5 directions=2 emitters=2 scales=3 narrow_outlet=true expanding_tip=true exact_endpoints=true emission_end=true")
	get_tree().quit()
