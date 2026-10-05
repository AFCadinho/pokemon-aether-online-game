extends "res://tests/battle_move_effects_3d_check.gd"
const Contact = preload("res://scripts/battle/battle_ui/contact_move_effect_3d.gd")
var seconds := 0.0
var points := {"source":Vector3(-2,1,0), "target":Vector3(2,1,0), "radius":0.8}
func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func(): get_tree().quit(1))
	_setup()
	var camera := Camera3D.new()
	stage.world.add_child(camera)
	camera.position = Vector3(0,3,6)
	camera.look_at(Vector3(0,1,0))
	for move in Contact.CONTACT_KEYS:
		for outcome in ["hit", "miss", "block"]:
			seconds = 0
			var effect := Contact.new()
			stage.world.add_child(effect)
			effect.view_camera = camera
			effect.start(move, {"frames":60.0, "impact_frame":27.0},
				{"show_impact":outcome=="hit", "result":outcome},
				func(): return seconds, func(): return points, func(): return true)
			effect.set_process(false)
			var seen := false
			for t in [0.0,0.2,0.35,0.44,0.45,0.49,0.55,0.64,0.8,0.99]:
				seconds = t
				effect._process(0)
				assert(effect.pieces.size() <= 16, "Bounded pooled contact geometry")
				for i in effect.cursor:
					var piece: MeshInstance3D = effect.pieces[i]
					assert(piece.transform.is_finite() and piece.visible)
					seen = true
					if i >= effect.sprite_keys.size(): continue
					if effect.sprite_keys[i].ends_with("_hit") or effect.sprite_keys[i] in ["bite_flash", "tackle_ring", "quick_ring"]:
						assert(outcome == "hit" and t >= effect.impact, "No contact flash on miss/block or before damage")
				if is_equal_approx(t,0.49):
					var frozen: float = effect.elapsed
					var count: int = effect.pieces.size()
					camera.position = Vector3(6,3,1)
					camera.look_at(Vector3(0,1,0))
					effect._process(0)
					assert(effect.elapsed == frozen and effect.pieces.size() == count)
					for piece: MeshInstance3D in effect.pieces:
						if piece.visible and piece.mesh is QuadMesh:
							assert(absf(piece.global_basis.z.normalized().dot(camera.global_basis.z.normalized())) > 0.999)
			assert(seen or outcome=="block")
			effect.cancel()
			assert(effect.done and not effect.visible)
			await get_tree().process_frame
		# Actual route and damage bridge; source effects do not own HP or 2D audio.
		await router.play_move_animation(move,"p1","p2",{"stop_at_impact":true,"show_impact":true})
		assert(router.has_3d_impact_damage("p2"))
		assert(stage.common_effects.size() == 1 and stage.common_effects[0].get_script() == Contact)
		assert(stage.common_effects[0].hit)
		await router.finish_3d_impact_damage("p2")
		await get_tree().process_frame
		assert(stage.common_effects.is_empty())
		router.cancel_render()
		await get_tree().process_frame
	await _check_approach()
	# Normal routing in all slots, guards and source positions are exercised by the base suite.
	router.release_threaded_resource_requests()
	router = null
	stage.queue_free()
	await get_tree().process_frame
	print("CONTACT_MOVES_3D_OK moves=4 outcomes=3 bounded_pool=true orbit_pause=true hit_gating=true impact_bridge=true")
	get_tree().quit()

func _check_approach() -> void:
	for slot in 4:
		var actor := "p%d" % (slot+1)
		var target_slot := (slot+1)%4
		var target := "p%d" % (target_slot+1)
		for move in Contact.CONTACT_KEYS:
			var origin: Vector3 = stage.actors[slot].position
			var destination: Vector3 = stage.actors[target_slot].position
			stage.start_move_action(actor,move)
			stage.start_move_dodge(actor,target,move)
			var effect: Node = stage.create_move_effect(move,actor,target,{"result":"miss"})
			effect.set_process(false)
			var aim: Vector3 = effect.anchors.call().target
			stage.players[slot].seek(effect.impact,true)
			stage.players[slot].speed_scale = 0
			stage._update_move_contacts()
			stage._update_move_dodges()
			effect._process(0)
			var position: Vector3 = stage.actors[slot].position
			assert(position.distance_to(origin) > 0.5, "Attacker approaches target")
			assert(position.distance_to(destination) < origin.distance_to(destination))
			assert(is_equal_approx(position.y,origin.y), "Approach preserves grounded height")
			assert(effect.anchors.call().target.is_equal_approx(aim), "No chasing the dodging target")
			assert(stage.dodge_offsets[target_slot].length() > 0.7)
			await get_tree().create_timer(0.03).timeout
			stage._update_move_contacts()
			assert(stage.actors[slot].position.is_equal_approx(position), "Pause freezes approach")
			stage.players[slot].seek(0.99,true)
			stage._update_move_contacts()
			assert(stage.actors[slot].position.is_equal_approx(origin), "Return finishes before clip ends")
			effect.cancel()
			assert(stage.move_contacts[slot].is_empty() and stage.contact_offsets[slot] == Vector3.ZERO)
			router.cancel_render()
			await get_tree().process_frame
	# Reset immediately while paused, including a visible Substitute and a replaced source.
	var doll := Doll.new()
	stage.world.add_child(doll)
	doll.position = stage.actors[0].position
	stage.substitute_models[0] = doll
	stage.actors[0].hide()
	stage.start_move_action("p1","Bite")
	var effect: Node = stage.create_move_effect("Bite","p1","p2",{"show_impact":true})
	effect.set_process(false)
	var home: Vector3 = doll.position
	stage.players[0].seek(effect.impact,true)
	stage._update_move_contacts()
	assert(doll.position.distance_to(home) > 0.5)
	effect.cancel()
	assert(doll.position.is_equal_approx(home))
	stage.substitute_models[0] = null
	doll.free()
	stage.actors[0].show()
	await get_tree().process_frame
	stage.start_move_action("p1","Tackle")
	effect = stage.create_move_effect("Tackle","p1","p2",{"show_impact":true})
	effect.set_process(false)
	stage.players[0].seek(effect.impact,true)
	stage._update_move_contacts()
	var previous: Node3D = stage.actors[0]
	stage.actors[0] = Node3D.new()
	stage.world.add_child(stage.actors[0])
	stage._update_move_contacts()
	assert(stage.actors[0].position == Vector3.ZERO, "Old motion cannot displace replacement")
	assert(stage.contact_offsets[0] == Vector3.ZERO)
	effect._process(0)
	assert(effect.cancelled)
	stage.actors[0].free()
	stage.actors[0] = previous
	router.cancel_render()
	await get_tree().process_frame
	for shutdown in [false,true]:
		stage.start_move_action("p1","Scratch")
		effect = stage.create_move_effect("Scratch","p1","p2",{"show_impact":true})
		effect.set_process(false)
		home = stage.actors[0].position
		stage.players[0].seek(effect.impact,true)
		stage._update_move_contacts()
		assert(stage.contact_offsets[0].length() > 0.5)
		stage.players[0].speed_scale = 0
		if shutdown: stage._set_active(false)
		else: router.cancel_render()
		assert(stage.actors[0].position.is_equal_approx(home))
		assert(stage.move_contacts[0].is_empty() and stage.contact_offsets[0] == Vector3.ZERO)
		stage.active = true
		await get_tree().process_frame
	print("CONTACT_APPROACH_OK moves=4 slots=4 grounded=true pause=true dodge=true return=true substitute=true replacement=true")
