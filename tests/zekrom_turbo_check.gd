extends "res://tests/primal_kyogre_surf_check.gd"


func _run() -> void:
	_check_jet_polygon_geometry()
	var actor := _new_local()
	actor.set("surf_activity_active", false)
	var remote: Node2D = load("res://scripts/world/remote_player_avatar.gd").new()
	root.add_child(remote)
	remote.set_process(false)
	for id: String in ["zekrom", "zekrom_shiny", "lapras", "rayquaza", "zekrom"]:
		actor.set("active_mount_id", id)
		actor.call("refresh_appearance")
		actor.call("_sync_mount_visual")
		remote.call("apply_state", {"userId": 1, "gender": "male", "appearance": Appearance.get_default_appearance("male"), "position": {"x": 0, "y": 0}, "movement": {"isMoving": false, "activityStyle": "ride", "mountId": id}})
		var expected := id.begins_with("zekrom")
		for avatar: Node2D in [actor, remote]:
			var effect: Node2D = avatar.get("mount_turbo_effect")
			_check(effect != null and effect.enabled == expected, "switching enables turbo only on Zekrom")
			if not expected:
				_check(not effect.visible and not effect.jet.visible and not effect.sparks.emitting and not effect.is_processing(), "switching fully clears turbo")
				continue
			var feet: Vector2 = actor.call("get_feet_position")
			var collision: Vector2 = actor.get_node("DetectionShape").position
			var interaction: Vector2 = actor.call("get_interaction_position")
			_check(effect.get_parent() == avatar.get_node("Look/MountForegroundSprite") and effect.z_index == 0, "tail lights share mount foreground depth")
			_check(effect.sparks is CPUParticles2D and effect.sparks.amount <= 12, "spark budget is bounded")
			for direction: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
				avatar.set("last_direction", direction)
				avatar.call("_sync_mount_animation", true, direction)
				var mount: AnimatedSprite2D = avatar.get_node("Look/MountSprite")
				mount.pause()
				effect.set_process(false)
				effect.advance(0.2)
				_check(effect.active and effect.energy == 1.0 and effect.sparks.emitting, "moving powers the turbine")
				_check(effect.jet.axis == -direction and effect.sparks.direction == -direction, "exhaust points opposite movement")
				var jet_parent := avatar.get_node("Look/MountSprite" if direction == Vector2.DOWN else "Look/MountForegroundSprite")
				_check(effect.jet.get_parent() == jet_parent and effect.jet.show_behind_parent == (direction == Vector2.DOWN) and effect.jet.z_index == 0, "front view occludes the exhaust; visible angles connect to the nozzle at actor world depth")
				var origin: Vector2 = effect.jet.position
				for phase in range(4):
					mount.frame = phase
					avatar.call("_on_mount_frame_changed")
					_check(effect.jet.position == origin + Vector2(0, 2 * (phase % 2)), "nozzle follows authored two-pixel bob")
				_check(actor.call("get_feet_position") == feet and actor.get_node("DetectionShape").position == collision and actor.call("get_interaction_position") == interaction, "turbo changes no gameplay anchors")
				avatar.call("_sync_mount_animation", false, direction)
				_check(not effect.active and not effect.sparks.emitting, "stopping immediately ends emission")
				effect.advance(0.2)
				_check(not effect.visible and not effect.jet.visible and not effect.is_processing(), "residual glow ends quickly while stationary")
	actor.set("active_mount_id", "")
	actor.call("_sync_mount_visual")
	_check(not actor.get("mount_turbo_effect").jet.visible, "dismount removes the whole effect")
	actor.free()
	remote.free()
	var preview: Node2D = load("res://scripts/ui/mount_rider_preview.gd").new()
	root.add_child(preview)
	preview.call("configure", "zekrom", Appearance.get_default_appearance("male"), "left", true)
	_check(preview.get("mount_turbo_effect").active, "animated Store preview includes turbo")
	preview.call("configure", "zekrom", Appearance.get_default_appearance("male"), "left", false)
	preview.get("mount_turbo_effect").advance(0.2)
	_check(not preview.get("mount_turbo_effect").visible, "Store Animation Off clears turbo")
	preview.free()
	await process_frame
	print("Zekrom turbo checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_jet_polygon_geometry() -> void:
	var effect_script := load("res://scripts/world/mount_turbo_effect.gd")
	var jet: Node2D = effect_script.Jet.new()
	for energy: float in [0.0, 0.00000001]:
		jet.set("energy", energy)
		_check((jet.call("_jet_shape") as PackedVector2Array).is_empty(), "zero-energy jet submits no degenerate polygon")
	var energies: Array[float] = [0.00001, 0.0001, 0.001]
	for step in range(1, 101):
		energies.append(step / 100.0)
	var count := 0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		jet.set("axis", direction)
		for tick in range(32):
			jet.set("clock", tick / 16.0)
			for energy: float in energies:
				jet.set("energy", energy)
				var shape := jet.call("_jet_shape") as PackedVector2Array
				for width: float in [1.45, 1.0, 0.63, 0.24]:
					var polygon := jet.call("_polygon_points", shape, width) as PackedVector2Array
					var triangles := Geometry2D.triangulate_polygon(polygon)
					if triangles.is_empty():
						_check(false, "jet triangulates direction=%s tick=%d energy=%f width=%f" % [direction, tick, energy, width])
						jet.free()
						return
					var area := 0.0
					for i in range(0, triangles.size(), 3):
						var a := polygon[triangles[i]]
						var b := polygon[triangles[i + 1]]
						var c := polygon[triangles[i + 2]]
						area += absf((b - a).cross(c - a)) * 0.5
					if area <= 0.0:
						_check(false, "jet has a drawable area throughout its energy ramp")
						jet.free()
						return
					count += 1
	_check(count == 52736, "all four jet layers triangulate across directions, pulse phases and ignition/fade energies")
	jet.free()
