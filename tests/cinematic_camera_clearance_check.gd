extends Node
const Clearance = preload("res://scripts/battle/battle_ui/cinematic_camera_clearance.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var grass := Node3D.new()
	grass.name = "SharedForestGrass"
	arena.add_child(grass)
	var blades := MeshInstance3D.new()
	blades.mesh = BoxMesh.new()
	blades.mesh.size = Vector3(8, 2, 4)
	blades.position = Vector3(0, 1, 6)
	grass.add_child(blades)
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.mesh.size = Vector3(2, 3, 1)
	wall.position = Vector3(0, 1.5, 4)
	arena.add_child(wall)
	var floor := MeshInstance3D.new()
	floor.mesh = BoxMesh.new()
	floor.mesh.size = Vector3(100, 0.1, 100)
	floor.position.y = -0.1
	arena.add_child(floor)
	var camera := Camera3D.new()
	add_child(camera)
	var focus := Vector3(0, 1, 0)
	camera.position = Vector3(0, 1.5, 8)
	camera.look_at(focus)
	var authored := camera.transform
	var overview := Transform3D(authored.basis, Vector3(0, 10, 12))
	var guard := Clearance.new()
	guard.prepare(arena)
	assert(guard.grass.size() == 1 and guard.props.size() == 1, "Only upright visible scenery is indexed")
	guard.apply(camera, focus, overview, 1.0)
	assert(camera.position.y > authored.origin.y)
	for box: AABB in guard.props:
		assert(not box.intersects_segment(camera.position, focus), "Lifted shot clears the prop's complete sightline")
	var near_end := camera.position.lerp(focus, minf(0.6, 3.0 / camera.position.distance_to(focus)))
	assert(not guard.grass[0].intersects_segment(camera.position, near_end), "Foreground grass does not cross the lens ray")
	assert(((-camera.basis.z).normalized()).dot((focus - camera.position).normalized()) > 0.9999, "Shot keeps its focus")
	assert(blades.visible and wall.visible and floor.visible, "Arena visibility is never changed")
	assert(camera.fov == 75.0, "Clearance does not change lens FOV")
	camera.transform = authored
	guard.apply(camera, focus, overview, 0.0)
	assert(camera.transform.is_equal_approx(authored), "Disabled/recovered shots stay untouched")
	# A clear shot retains the original composition exactly.
	camera.position = Vector3(6, 3, 8)
	camera.look_at(Vector3(6, 2, 0))
	var clear_shot := camera.transform
	guard.apply(camera, Vector3(6, 2, 0), overview, 1.0)
	assert(camera.transform.is_equal_approx(clear_shot))
	# Tall enclosing props fall back to the prepared overview, never clamp
	# to a height that still leaves scenery in front of the action.
	guard.props = [AABB(Vector3(-1, 0, 2), Vector3(2, 30, 1))]
	guard.grass.clear()
	camera.transform = authored
	guard.apply(camera, focus, overview, 1.0)
	assert(camera.transform.is_equal_approx(overview))
	# Overhead roofs can overlap the whole court in XZ while leaving the view clear.
	guard.props = [AABB(Vector3(-20,19,-20),Vector3(40,1,40))]
	camera.transform = authored
	guard.apply(camera,focus,overview,1.)
	assert(camera.transform.is_equal_approx(authored),"A roof above the ray preserves the authored shot")
	# Batched walls/beams must retain their gaps instead of becoming one solid box.
	var structural := Node3D.new()
	add_child(structural)
	var boxes := MultiMeshInstance3D.new()
	boxes.multimesh = MultiMesh.new()
	boxes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	boxes.multimesh.mesh = BoxMesh.new()
	boxes.multimesh.mesh.size = Vector3(2,3,1)
	boxes.multimesh.instance_count = 3
	boxes.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(-4,1.5,4)))
	boxes.multimesh.set_instance_transform(1,Transform3D(Basis.IDENTITY,Vector3(4,1.5,4)))
	boxes.multimesh.set_instance_transform(2,Transform3D(Basis.IDENTITY,Vector3(0,15,4)))
	structural.add_child(boxes)
	var structural_guard := Clearance.new()
	structural_guard.prepare(structural)
	assert(structural_guard.prop_batches.size()==1 and structural_guard.props.is_empty())
	if DisplayServer.get_name()=="headless":
		# The dummy rendering server does not retain MultiMesh transforms. Native
		# runs below exercise collection; headless runs check the same sightlines.
		var expected: Array[AABB] = [AABB(Vector3(-5.4,-.4,3.1),Vector3(2.8,3.8,1.8)),AABB(Vector3(2.6,-.4,3.1),Vector3(2.8,3.8,1.8)),AABB(Vector3(-1.4,13.1,3.1),Vector3(2.8,3.8,1.8))]
		structural_guard.prop_batches = [{"bounds":AABB(Vector3(-5.4,-.4,3.1),Vector3(10.8,17.3,1.8)),"boxes":expected}]
	camera.transform = authored
	structural_guard.apply(camera,focus,overview,1.)
	assert(camera.transform.is_equal_approx(authored),"Open space between batched props stays open")
	camera.position = Vector3(-4,1.5,8)
	camera.look_at(Vector3(-4,1,0))
	structural_guard.apply(camera,Vector3(-4,1,0),overview,1.)
	assert(camera.position.y>1.5,"Individual batched walls still protect the view")
	structural.queue_free()
	if DisplayServer.get_name() != "headless":
		var batches := MultiMeshInstance3D.new()
		batches.multimesh = MultiMesh.new()
		batches.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batches.multimesh.mesh = blades.mesh
		batches.multimesh.instance_count = 1
		batches.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(0, 1, 6)))
		grass.add_child(batches)
		blades.hide()
		wall.hide()
		await RenderingServer.frame_post_draw
		var batch_guard := Clearance.new()
		batch_guard.prepare(arena)
		assert(batch_guard.grass.size() == 1 and batch_guard.props.is_empty(), "Real MultiMesh grass bounds are indexed by the native renderer")
		camera.transform = authored
		batch_guard.apply(camera, focus, overview, 1.0)
		assert(camera.position.y > authored.origin.y, "Batched grass receives the same lens clearance")
		print("CINEMATIC_CLEARANCE_NATIVE_MULTIMESH_PASS")
	# A new pooled arena gets a fresh index; the former arena is unmodified.
	var empty := Node3D.new()
	add_child(empty)
	guard.prepare(empty)
	assert(guard.grass.is_empty() and guard.props.is_empty() and guard.prop_batches.is_empty())
	arena.queue_free()
	empty.queue_free()
	camera.queue_free()
	await get_tree().process_frame
	print("CINEMATIC_CLEARANCE_PASS grass=true props=true focus=true unchanged_clear_shots=true recovery=true overview_fallback=true pooled_arenas=true")
	get_tree().quit()
