extends SceneTree
const Effect = preload("res://scripts/battle/battle_ui/move_effect_3d.gd")
const Fire = preload("res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd")
const Contact = preload("res://scripts/battle/battle_ui/contact_move_effect_3d.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for key in Effect.KEYS:
		assert(Effect.PRESENTATION_SCALES.has(key))
		assert(Effect.PRESENTATION_SCALES[key]>=1.2 and Effect.PRESENTATION_SCALES[key]<=2.5)
	# Widening a beam must not multiply its world-space endpoint distance.
	var effect := Effect.new()
	root.add_child(effect)
	effect.set_process(false)
	effect.presentation_scale = 2.5
	effect.tube.height = 1.0
	for segment in [[Vector3(-3,1,0),Vector3(4,2,1)], [Vector3(1,4,0),Vector3(1,0,0)]]:
		effect.cursor = 0
		effect._line(segment[0],segment[1],.1,null)
		var node: MeshInstance3D = effect.pieces[0]
		assert(node.position.is_equal_approx((segment[0]+segment[1])*.5))
		assert(is_equal_approx(node.basis.y.length(),segment[0].distance_to(segment[1])+.065))
		assert(is_equal_approx(node.basis.x.length(),.25) and is_equal_approx(node.basis.z.length(),.25))
	effect.free()
	# A volumetric flame cone has the same endpoint constraint as a line beam.
	var fire := Fire.new()
	root.add_child(fire)
	fire.set_process(false)
	fire.presentation_scale = 1.7
	fire._fire_core(Vector3(0,1,0),Vector3(5,1,0),1.0)
	assert(is_equal_approx(fire.pieces[0].basis.y.length(),5))
	assert(is_equal_approx(fire.pieces[0].basis.x.length(),.374))
	fire.free()
	# Bite/claw patterns expand as a group, never by fattening each tooth twice.
	var contact := Contact.new()
	root.add_child(contact)
	contact.set_process(false)
	contact.presentation_scale = 1.3
	contact.anchors = func(): return {"radius":.8}
	contact.key = "scratch"
	contact.elapsed = 0
	contact._draw_source_move(Vector3.ZERO,Vector3.ONE,Vector3.RIGHT,Vector3.UP)
	assert(is_equal_approx(contact.target_radius,1.04))
	assert(is_equal_approx(contact._geometry_scale(),1.0))
	contact.free()
	print("MOVE_SCALE_3D_OK moves=23 beam_endpoints=true cone_endpoints=true contact_spacing=true")
	quit()
