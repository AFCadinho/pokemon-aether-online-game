extends Node3D
## Twelve independent actors share the presenter's verified resources, never battle slots.
const ActionMap = preload("res://scripts/battle/animations/model_action_map.gd")
const SurfaceOrder = preload("res://scripts/battle/battle_ui/material_surface_order.gd")
const SourceVisibility = preload("res://scripts/battle/animations/reviewed_source_visibility.gd")
var slots: Array[Dictionary] = []

func build(stage: Node, teams: Array) -> void:
	set_meta("battle_field_visual", true)
	var origin: Vector3 = stage._position(0).lerp(stage._position(1), 0.5)
	var view: Vector3 = stage._default_camera_home() - stage.camera_target_for_preview()
	view.y = 0.0
	view = view.normalized()
	var right := Vector3(view.z, 0, -view.x)
	for side in 2:
		var sign_value := 1.0 if side == 0 else -1.0
		for index: int in teams[side].size():
			var identity: String = teams[side][index]
			var actor: Node3D = stage.packed[identity].instantiate()
			add_child(actor)
			var player: AnimationPlayer = stage._find_player(actor)
			var placement: Dictionary = stage.placements[identity]
			SurfaceOrder.apply(actor)
			var digest := str(stage.entries[identity].get("_verified_runtime_hash", ""))
			SourceVisibility.apply(actor, identity, digest)
			preload("res://scripts/battle/animations/gliscor_flight.gd").apply(player, identity, digest)
			preload("res://scripts/battle/animations/mega_garchomp_standing.gd").apply(player, identity, digest)
			preload("res://scripts/battle/animations/charmander_breath.gd").apply(player, identity, digest)
			if preload("res://scripts/battle/battle_ui/android_actor_exposure.gd").supported() and preload("res://scripts/battle/arenas/arena_catalog.gd").uses_outdoor_lighting(stage.arena_id):
				preload("res://scripts/battle/battle_ui/android_actor_exposure.gd").apply(actor)
			var mapped := ActionMap.resolve("idle", player.get_animation_list(), stage.entries[identity].action_timing)
			if not mapped.is_empty():
				var clip := player.get_animation(mapped.clip)
				clip.length = mapped.duration
				clip.loop_mode = Animation.LOOP_LINEAR
				player.play(mapped.clip, -1, mapped.speed)
				player.advance(0.0)
			var bounds := _bounds(actor)
			var authored_scale := float(placement.scale)
			var dimensions := bounds.size * authored_scale
			var shrink := minf(1.0, 1.65 / maxf(maxf(dimensions.x, dimensions.z), maxf(dimensions.y, 0.01)))
			actor.scale = Vector3.ONE * authored_scale * shrink
			actor.rotation.y = atan2(-view.x * sign_value, -view.z * sign_value) + deg_to_rad(float(placement.yaw_degrees))
			# Stagger the rows so the rear three cannot hide behind the front three.
			var row := index / 3
			var column := (index % 3) - 1.0 + (-0.25 if row == 0 else 0.25)
			var point: Vector3 = origin + view * sign_value * (2.7 + row * 1.8) + right * (column * 2.6 - sign_value * 1.4)
			point.y += (float(placement.lift) + float(placement.get("hover_height", 0.0))) * shrink
			actor.position = point
			slots.append({"actor": actor, "player": player, "identity": identity, "side": side, "index": index})

func _bounds(actor: Node3D) -> AABB:
	var result := AABB()
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	if actor is MeshInstance3D: meshes.append(actor)
	for mesh in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var box: AABB = (actor.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		result = result.merge(box) if result.has_volume() else box
	return result

func animate(speed: float) -> void:
	for slot in slots:
		slot.player.speed_scale = maxf(speed, 0.0)

func cancel() -> void:
	hide()
	for slot in slots:
		slot.player.stop()
	slots.clear()
	queue_free()
