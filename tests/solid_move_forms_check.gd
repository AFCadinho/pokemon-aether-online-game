extends "res://tests/battle_move_effects_3d_check.gd"
var seconds := 0.0

func _run() -> void:
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(1))
	_setup()
	for move in ["Hyper Beam", "Pyro Ball", "Hurricane", "Draco Meteor"]:
		for outcome in ["hit", "miss", "block"]:
			for reverse in [false, true]:
				seconds = 0
				var actor := "p2" if reverse else "p1"
				var target := "p1" if reverse else "p2"
				stage.start_move_action(actor, move)
				var effect: Node = stage.create_move_effect(move, actor, target, {"show_impact":outcome == "hit", "result":outcome})
				var points: Dictionary = effect.anchors.call()
				effect.anchors = func(): return points
				effect.clock = func(): return seconds
				effect.set_process(false)
				var max_billboards := 0
				var impact_seen := false
				for frame in range(1, 60):
					seconds = effect.duration * frame / 60.0
					effect._process(0)
					assert(effect.cursor <= 40, move + " bounded continuous geometry")
					var snapshot: Array[Transform3D] = []
					var materials: Array = []
					var billboards := 0
					for j in effect.cursor:
						var piece: MeshInstance3D = effect.pieces[j]
						assert(piece.transform.is_finite())
						snapshot.append(piece.transform)
						if piece.mesh is QuadMesh: billboards += 1
						if piece.material_override is ShaderMaterial:
							var mat: ShaderMaterial = piece.material_override
							assert(not "TIME" in mat.shader.code, "Pause-safe shader clock")
							materials.append([mat, mat.get_shader_parameter("seconds")])
					max_billboards = maxi(max_billboards, billboards)
					if move != "Draco Meteor" and effect.impact_drawn:
						assert(outcome == "hit" and seconds >= effect.impact)
						impact_seen = true
					effect._process(0)
					assert(effect.cursor == snapshot.size())
					for j in effect.cursor: assert(effect.pieces[j].transform.is_equal_approx(snapshot[j]), "Frozen native clock")
					for entry in materials: assert(entry[0].get_shader_parameter("seconds") == entry[1])
				assert(max_billboards <= (5 if move == "Draco Meteor" else 2), move + " no detached sprite clouds")
				if move != "Draco Meteor": assert(impact_seen == (outcome == "hit"))
				seconds = effect.duration
				effect._process(0)
				assert(effect.done)
				await get_tree().process_frame
	router.cancel_render()
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("SOLID_MOVE_FORMS_OK moves=4 directions=2 outcomes=3 native_clock=true bounded_geometry=true reduced_billboards=true impact_timing=true cleanup=true")
	get_tree().quit()
