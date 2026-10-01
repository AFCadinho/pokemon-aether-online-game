extends "res://scripts/battle/arenas/shared/indoor_gym.gd"
## S.S. Anne's promenade deck. All scenery stays outside the combat/camera space.
func build() -> Node3D:
	var arena := Node3D.new()
	arena.name = "SSAnneArena"
	arena.set_meta("source_maps", ["kanto_ss_anne_b1f", "kanto_ss_anne_1f", "kanto_ss_anne_2f", "kanto_ss_anne_3f"])
	arena.set_meta("surface_height", 0.0)
	var ivory := matte(Color("e9e6d8"))
	var navy := matte(Color("243d56"))
	var brass := matte(Color("bd9651"))
	var red := matte(Color("ba493b"))
	var glass := matte(Color("316d84"))
	var wood := surface(Color("b88a59"), Color("795638"), 2, 1.3)
	var ocean := ShaderMaterial.new()
	ocean.shader = preload("res://scripts/battle/arenas/maps/ss_anne/ocean.gdshader")
	box(group(arena, "Ocean"), ocean, Vector3(0, -3.7, 0), Vector3(1600, 0.1, 1600))
	var deck := group(arena, "PromenadeDeck")
	box(deck, navy, Vector3(0, -1.9, 0), Vector3(42, 3, 64))
	box(deck, ivory, Vector3(0, -0.45, 0), Vector3(42.5, 0.4, 64.5))
	box(deck, wood, Vector3(0, -0.15, 0), Vector3(42, 0.3, 64))
	var court := group(arena, "BattleCourt")
	for x in [-8, 8]:
		box(court, ivory, Vector3(x, 0.012, 0), Vector3(0.08, 0.02, 13))
	for z in [-6.5, 6.5]:
		box(court, ivory, Vector3(0, 0.012, z), Vector3(16, 0.02, 0.08))
	emblem(court, ivory, Vector3(0, 0.025, 0), 1.6)
	var rails := group(arena, "SafetyRails")
	for side in [-1, 1]:
		for z in range(-30, 33, 3):
			cylinder(rails, ivory, Vector3(side * 20.4, 0.75, z), 0.065, 1.5)
		for y in [0.45, 0.9, 1.45]:
			box(rails, ivory, Vector3(side * 20.4, y, 0), Vector3(0.09, 0.09, 64))
		for z in [-32, 32]:
			for y in [0.45, 0.9, 1.45]:
				box(rails, ivory, Vector3(0, y, z), Vector3(41, 0.09, 0.09))
		for z in [-15, 3, 21]:
			var buoy := group(arena, "LifeBuoy", Vector3(side * 20.25, 1.1, z))
			var hoop := ring(buoy, red, Vector3.ZERO, 0.48, 0.12)
			hoop.rotation.z = PI / 2
			for y in [-0.48, 0.48]:
				box(buoy, ivory, Vector3(0, y, 0), Vector3(0.25, 0.22, 0.22))
		for z in [-19, 15, 25]:
			var bench := group(arena, "DeckBench", Vector3(side * 16.8, 0, z))
			bench.rotation.y = side * PI / 2
			box(bench, wood, Vector3(0, 0.65, 0), Vector3(3.4, 0.15, 1.0))
			box(bench, wood, Vector3(0, 1.1, -0.45), Vector3(3.4, 0.7, 0.12))
			for x in [-1.35, 1.35]:
				box(bench, ivory, Vector3(x, 0.35, 0), Vector3(0.12, 0.7, 0.85))
	# White superstructure, portholes and a red funnel establish the ocean liner.
	var cabin := group(arena, "ShipSuperstructure", Vector3(0, 0, -28))
	box(cabin, ivory, Vector3(0, 3.1, 0), Vector3(29, 6.2, 12))
	box(cabin, navy, Vector3(0, 0.5, 6.03), Vector3(29, 0.65, 0.12))
	box(cabin, ivory, Vector3(0, 6.35, 0), Vector3(30, 0.3, 13))
	for x in [-11, -7, 7, 11]:
		var frame := cylinder(cabin, brass, Vector3(x, 3.6, 6.1), 0.8, 0.18)
		frame.rotation.x = PI / 2
		var pane := cylinder(cabin, glass, Vector3(x, 3.6, 6.22), 0.65, 0.08)
		pane.rotation.x = PI / 2
	box(cabin, navy, Vector3(0, 1.7, 6.1), Vector3(2.4, 3.4, 0.2))
	box(cabin, brass, Vector3(0, 1.7, 6.23), Vector3(0.05, 3.2, 0.04))
	var sign := Label3D.new()
	sign.name = "ShipName"
	sign.text = "S.S. ANNE"
	sign.font_size = 80
	sign.pixel_size = 0.018
	sign.modulate = Color("243d56")
	sign.outline_size = 0
	sign.position = Vector3(0, 4.9, 6.2)
	cabin.add_child(sign)
	cylinder(cabin, red, Vector3(0, 9.2, -1), 2.3, 5.4)
	cylinder(cabin, navy, Vector3(0, 11.5, -1), 2.35, 0.9)
	for x in [-10, 10]:
		cylinder(cabin, ivory, Vector3(x, 7.3, -1), 0.42, 2.0)
		var vent := cylinder(cabin, brass, Vector3(x, 8.2, -0.6), 0.6, 1.1)
		vent.rotation.x = PI / 2
	var glow := matte(Color("ffe0a0"), 0.6)
	for x in [-13, 13]:
		lamp(cabin, Vector3(x, 4.8, 6.2), 0, brass, glow)
	_add_spectators(arena)
	return arena

func _sphere(parent: Node3D, material: Material, pos: Vector3, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return prop(parent, mesh, material, pos)

func _add_spectators(arena: Node3D) -> void:
	var audience := group(arena, "DeckAudience")
	var shirts := [Color("f0e9da"), Color("ca6456"), Color("568e9a"), Color("e0ad58"), Color("f0e9da"), Color("7970a0")]
	var skins := [Color("c68f67"), Color("e9b991"), Color("986342")]
	var navy := matte(Color("263c55"))
	var shoes := matte(Color("34313a"))
	var hair := matte(Color("4d3529"))
	var white := matte(Color("f0e9da"))
	for i in 6:
		var spectator := preload("res://scripts/battle/arenas/maps/ss_anne/spectator.gd").new()
		spectator.name = "Sailor%d" % i if i in [0, 4] else "Passenger%d" % i
		spectator.position = Vector3((-1.0 if i < 3 else 1.0) * (6.5 + (i % 3) * 1.8), 0, -19.8 - (i % 2) * 0.45)
		spectator.rotation.y = atan2(-spectator.position.x, -spectator.position.z)
		spectator.phase = i * 1.37
		audience.add_child(spectator)
		var skin := matte(skins[i % skins.size()])
		var shirt := matte(shirts[i])
		for side in [-1, 1]:
			cylinder(spectator, navy, Vector3(side * 0.15, 0.46, 0), 0.11, 0.72)
			box(spectator, shoes, Vector3(side * 0.15, 0.075, 0.07), Vector3(0.23, 0.15, 0.36))
		cylinder(spectator, shirt, Vector3(0, 1.16, 0), 0.27, 0.76, 0.32)
		cylinder(spectator, skin, Vector3(0, 1.66, 0), 0.095, 0.19)
		_sphere(spectator, skin, Vector3(0, 1.92, 0), 0.23)
		if i in [0, 4]:
			cylinder(spectator, navy, Vector3(0, 2.08, 0), 0.24, 0.07)
			cylinder(spectator, white, Vector3(0, 2.16, 0), 0.255, 0.13)
			box(spectator, navy, Vector3(0, 1.45, 0.3), Vector3(0.16, 0.27, 0.035))
		else:
			_sphere(spectator, hair, Vector3(0, 2.035, -0.035), 0.205).scale.y = 0.7
		for side in [-1, 1]:
			box(spectator, shoes, Vector3(side * 0.075, 1.94, 0.21), Vector3(0.035, 0.04, 0.025))
			var arm := group(spectator, "LeftArm" if side < 0 else "RightArm", Vector3(side * 0.34, 1.5, 0))
			cylinder(arm, shirt, Vector3(0, -0.2, 0), 0.095, 0.38)
			cylinder(arm, skin, Vector3(0, -0.45, 0), 0.075, 0.2)
			_sphere(arm, skin, Vector3(0, -0.6, 0), 0.095)
			if side < 0:
				spectator.left_arm = arm
			else:
				spectator.right_arm = arm
