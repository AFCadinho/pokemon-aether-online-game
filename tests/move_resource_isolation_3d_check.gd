extends Node
## Concurrent casts must never share clocks, fades, geometry transforms or owners.
const Source = preload("res://scripts/battle/battle_ui/source_move_effect_3d.gd")
const Fire = preload("res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd")
const Draco = preload("res://scripts/battle/battle_ui/draco_meteor_effect_3d.gd")
const Extended = preload("res://scripts/battle/battle_ui/extended_move_effect_3d.gd")
const Batch = preload("res://scripts/battle/battle_ui/batch_four_move_effect_3d.gd")
const Rocks = preload("res://scripts/battle/battle_ui/rock_slide_forms_3d.gd")
const Ground = preload("res://scripts/battle/battle_ui/rock_ground_forms_3d.gd")
const Volume = preload("res://scripts/battle/battle_ui/move_volume_forms_3d.gd")

func _ready() -> void:
	_run.call_deferred()

func _cast(script: Script, move: String, clock: Dictionary) -> Node:
	var effect: Node3D = script.new()
	add_child(effect)
	var points := {"source": Vector3(-2, 1.5, 0), "target": Vector3(2, 1, 0), "radius": 0.6,
		"actor_center": Vector3(-2, 1, 0), "actor_ground": Vector3(-2, 0.04, 0), "target_ground": Vector3(2, 0.04, 0)}
	effect.start(move, {"frames": 192.0, "launch_frame": 42.0, "impact_frame": 123.0},
		{"show_impact": true}, func(): return clock.seconds, func(): return points, func(): return true)
	effect.set_process(false)
	return effect

func _snapshot(effect: Node) -> Array:
	var result := []
	for piece: MeshInstance3D in effect.pieces:
		var mat: Material = piece.material_override
		var values := {}
		if mat is ShaderMaterial:
			for property: Dictionary in mat.get_property_list():
				if str(property.name).begins_with("shader_parameter/"):
					values[property.name] = mat.get(property.name)
		elif mat is StandardMaterial3D:
			values.albedo = mat.albedo_color
		result.append([piece.transform, piece.visible, values])
	return result

func _run() -> void:
	get_tree().create_timer(30).timeout.connect(func(): get_tree().quit(1))
	var tail := Volume.swept_mesh(false)
	var funnel := Volume.swept_mesh(true)
	assert(tail != funnel and tail.get_surface_count() == 1 and funnel.get_surface_count() == 1)
	for i in 4:
		assert(Volume.swept_mesh(false) == tail and Volume.swept_mesh(true) == funnel)
	var original := Rocks.new()
	var other := Rocks.new()
	assert(original.boulder == other.boulder and original.stone != other.stone and original.dust != other.dust)
	assert(original.stone.shader == other.stone.shader)
	var stone_code: String = original.stone.shader.code
	var ground := Ground.new()
	assert(ground.rocks.stone.shader != original.stone.shader)
	assert(original.stone.shader.code == stone_code and ground.rocks.stone.shader.code.contains("uniform vec3 tone"))
	var source_program: Shader = preload("res://scripts/battle/battle_ui/source_move_sprite.gdshader")
	var source_code := source_program.code
	for pair in [[Source, "watergun"], [Fire, "flamethrower"], [Draco, "dracometeor"], [Extended, "rockslide"], [Batch, "moonblast"]]:
		var clock_a := {"seconds": 0.0}
		var clock_b := {"seconds": 0.0}
		var a := _cast(pair[0], pair[1], clock_a)
		var b := _cast(pair[0], pair[1], clock_b)
		for times in [Vector2(0.95, 0.85), Vector2(2.1, 1.8), Vector2(2.7, 2.4)]:
			clock_a.seconds = times.x
			a._process(0.0)
			var before := _snapshot(a)
			clock_b.seconds = times.y
			b._process(0.0)
			assert(a.cursor > 0 and b.cursor > 0, "%s no geometry at %s" % [pair[1], times])
			assert(_snapshot(a) == before, str(pair[1]) + ": another cast changed transforms/material parameters")
			var owned := {}
			for piece: MeshInstance3D in a.pieces: owned[piece.material_override] = true
			for piece: MeshInstance3D in b.pieces:
				assert(not owned.has(piece.material_override), "Mutable material shared between casts")
		if pair[1] != "rockslide": assert(a.sprite_shader == b.sprite_shader)
		var reference: WeakRef = weakref(a)
		a.cancel()
		a = null
		await get_tree().process_frame
		assert(reference.get_ref() == null, "Shared resources retained a cancelled effect")
		clock_b.seconds = 2.5
		b._process(0.0)
		assert(not b.done and b.cursor > 0, str(pair[1]) + ": cancelling another cast invalidated this effect")
		b.cancel()
		await get_tree().process_frame
	assert(source_program.code == source_code and not source_program.code.contains("moon_disc"), "Moon crop mutated the shared source shader")
	assert(get_child_count() == 0, "Effect nodes survived teardown")
	print("MOVE_RESOURCE_ISOLATION_OK concurrent=5 materials_independent=true bounded_shared_meshes=3 shader_variants_isolated=true cancellation=true")
	get_tree().quit()
