extends Node
const Elemental = preload("res://scripts/battle/battle_ui/elemental_move_effect_3d.gd")
var seconds := 0.0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var samples := 0
	for floor_y in [-3.0, 0.04, 4.5]:
		for heights in [Vector2(.12,.18), Vector2(1.8,.35), Vector2(.35,1.8), Vector2(2.5,3.0)]:
			for reverse in [false,true]:
				for outcome in ["hit","miss","block"]:
					var source := Vector3(-3,floor_y+heights.x,-2)
					var target := Vector3(3,floor_y+heights.y,2)
					if reverse:
						source.x *= -1
						target.x *= -1
					var anchors := {"source":source,"target":target,"radius":.5,
						"actor_ground":Vector3(source.x,floor_y,source.z),
						"target_ground":Vector3(target.x,floor_y,target.z)}
					var effect := Elemental.new()
					add_child(effect)
					seconds = 0
					effect.start("darkpulse",{"frames":180,"launch_frame":45,"impact_frame":105},
						{"show_impact":outcome=="hit","result":outcome},
						func(): return seconds, func(): return anchors, func(): return true)
					effect.set_process(false)
					for step in 180:
						seconds = step/60.0
						effect._process(0)
						assert(effect.origin.is_equal_approx(source) and effect.aim.is_equal_approx(target), "Keep anatomical source and target")
						assert(effect.impact_drawn==(outcome=="hit" and seconds>=effect.impact))
						for i in effect.cursor:
							var piece: MeshInstance3D = effect.pieces[i]
							# Include the full shader displacement, not just CPU mesh vertices.
							var bounds := piece.mesh.get_aabb().grow(.055)
							for corner in 8:
								var point := piece.transform * bounds.get_endpoint(corner)
								assert(point.y >= floor_y-.0001,"Dark Pulse clips floor: y=%f floor=%f time=%f heights=%s" % [point.y,floor_y,seconds,heights])
						if seconds>=effect.launch and seconds<effect.impact:
							assert(effect.pieces[0].position.is_equal_approx(source.lerp(target,effect.flight)), "Flight stays aimed at the target")
							assert(effect.pieces[0].basis.x.length()>=.219,"Floor clearance must preserve lateral width")
						var transforms: Array[Transform3D] = []
						for i in effect.cursor: transforms.append(effect.pieces[i].transform)
						effect._process(1)
						for i in effect.cursor: assert(transforms[i].is_equal_approx(effect.pieces[i].transform),"Paused native clock holds geometry")
						samples += 1
					# A dodging target cannot drag the already launched effect.
					anchors.target += Vector3(1,0,1)
					seconds = 2.999
					effect._process(0)
					assert(effect.aim.is_equal_approx(target))
					effect.cancel()
					await get_tree().process_frame
	print("DARK_PULSE_CLEARANCE_OK samples=",samples," floors=3 height_pairs=4 directions=2 outcomes=3 shader_bounds=true anchors=true pause=true")
	get_tree().quit()
