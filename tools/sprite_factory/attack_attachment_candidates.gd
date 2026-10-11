extends "res://tools/sprite_factory/inspect_attack_attachments.gd"
## Geometry-derived proposals. Every row remains pending visual review.

func _init() -> void:
	output = "res://.tmp/attack-attachments/candidates"
	super._init()

func _definition(bone: String, point := Vector3.ZERO, weight := 1.0) -> Dictionary:
	return {"bone":bone,"offset":[point.x,point.y,point.z],"weight":weight}

func _enrich_report(actor: Node3D, report: Dictionary) -> void:
	var names: Array[String] = []
	for bone: Dictionary in report.bones: names.append(bone.name)
	var parts := {}
	var reasons := {}
	for part: String in {"mouth":"EffMouth01","body":"EffCenter01","hand":"EffHand01","left_hand":"EffHand02","foot":"EffFoot01","tail":"EffTail01"}:
		var bone: String = {"mouth":"EffMouth01","body":"EffCenter01","hand":"EffHand01","left_hand":"EffHand02","foot":"EffFoot01","tail":"EffTail01"}[part]
		if bone in names:
			parts[part] = [[_definition(bone)]]
			reasons[part] = "native_effect_bone"
	if not parts.has("mouth"):
		var head := ""
		var jaw := ""
		for bone: String in ["upper_jaw", "upper_jaw_01", "head", "Head", "head_01", "face", "head_a", "waist"]:
			if bone in names:
				head = bone
				break
		for bone: String in ["lower_jaw_02", "lower_jaw", "jaw", "lower_jaw_01", "jaw_01", "jaw_02", "root_jaw", "Jaw", "mouth", "jaw_a", "lower_jaw_a"]:
			if bone in names and report.geometry.has(bone):
				jaw = bone
				break
		if not head.is_empty() and not jaw.is_empty():
			var lip := _jaw_lip(actor, head, jaw)
			if not lip.is_empty():
				parts.mouth = [[_definition(head, lip.head, 0.5), _definition(jaw, lip.jaw, 0.5)]]
				reasons.mouth = "bind_geometry_lip_midpoint_requires_review"
	for part: String in {"hand":"right_hand","left_hand":"left_hand","foot":"right_foot","left_foot":"left_foot"}:
		if parts.has(part): continue
		var bone: String = {"hand":"right_hand","left_hand":"left_hand","foot":"right_foot","left_foot":"left_foot"}[part]
		if not report.geometry.has(bone): continue
		var geometry: Dictionary = report.geometry[bone]
		var point := Vector3.ZERO
		for axis in 3: point[axis] = (float(geometry.min[axis])+float(geometry.max[axis]))*0.5
		parts[part] = [[_definition(bone, point)]]
		reasons[part] = "weighted_surface_center_requires_review"
	report["candidate_parts"] = parts
	report["candidate_reasons"] = reasons

func _jaw_lip(actor: Node3D, head: String, jaw: String) -> Dictionary:
	var jaw_samples: Array[Dictionary] = []
	var head_samples: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.skin == null: continue
		var skeleton := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skeleton == null: continue
		var head_bind := -1
		var jaw_bind := -1
		for bind in mesh.skin.get_bind_count():
			var bone := str(mesh.skin.get_bind_name(bind))
			if bone.is_empty(): bone = skeleton.get_bone_name(mesh.skin.get_bind_bone(bind))
			if bone == head: head_bind = bind
			if bone == jaw: jaw_bind = bind
		if head_bind < 0 or jaw_bind < 0: continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty(): continue
			var stride := bones.size()/vertices.size()
			for vertex in vertices.size():
				for influence in stride:
					var bind: int = bones[vertex*stride+influence]
					if bind not in [jaw_bind,head_bind] or weights[vertex*stride+influence] < 0.5: continue
					var sample := {"head":mesh.skin.get_bind_pose(head_bind)*vertices[vertex],"jaw":mesh.skin.get_bind_pose(jaw_bind)*vertices[vertex],"model":actor.to_local(mesh.to_global(vertices[vertex]))}
					if bind==jaw_bind: jaw_samples.append(sample)
					else: head_samples.append(sample)
	if jaw_samples.is_empty(): return {}
	# Source jaw joints extend along local X, with lateral Y. Infer which
	# side of Z contains the upper head; imported mesh/world axes can differ.
	jaw_samples.sort_custom(func(a,b): return a.jaw.x > b.jaw.x)
	var front := float(jaw_samples[0].jaw.x)
	var back := float(jaw_samples[-1].jaw.x)
	var lower := Vector3.ZERO
	var lower_in_head := Vector3.ZERO
	var count := 0
	for sample: Dictionary in jaw_samples:
		if sample.jaw.x < lerpf(back,front,0.92): break
		lower += sample.jaw
		lower_in_head += sample.head
		count += 1
	lower /= count
	lower_in_head /= count
	# Some rigs skin the upper lip entirely to facial child bones. The jaw
	# tip still gives the reviewer a visible starting point; it is not approval.
	if head_samples.is_empty(): return {"head":lower_in_head,"jaw":lower}
	var head_center := Vector3.ZERO
	var width := 0.0
	var height := 0.0
	for sample: Dictionary in head_samples:
		head_center += sample.jaw
		width = maxf(width,absf(sample.jaw.y-lower.y))
		height = maxf(height,absf(sample.jaw.z-lower.z))
	head_center /= head_samples.size()
	var up := 1.0 if head_center.z >= lower.z else -1.0
	var upper_candidates: Array[Dictionary] = []
	for sample: Dictionary in head_samples:
		if absf(sample.jaw.y-lower.y)>width*0.25: continue
		if sample.jaw.x < front-(front-back)*0.2: continue
		if (sample.jaw.z-lower.z)*up < -height*0.03: continue
		upper_candidates.append(sample)
	if upper_candidates.is_empty(): return {"head":lower_in_head,"jaw":lower}
	upper_candidates.sort_custom(func(a,b): return a.jaw.z*up < b.jaw.z*up)
	var top := float(upper_candidates[0].jaw.z)*up
	var upper := Vector3.ZERO
	count = 0
	for sample: Dictionary in upper_candidates:
		if sample.jaw.z*up > top+height*0.035: break
		upper += sample.head
		count += 1
	return {"head":upper/count,"jaw":lower}
