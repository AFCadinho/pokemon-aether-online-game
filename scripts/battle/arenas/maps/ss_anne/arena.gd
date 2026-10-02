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
	_add_deck_details(arena, ivory, navy, brass, red, wood, glass)
	_add_spectators(arena)
	return arena

func _add_spectators(arena: Node3D) -> void:
	var audience := group(arena, "DeckAudience")
	var models = preload("res://scripts/battle/arenas/shared/animated_spectator.gd").MODELS
	var positions := [Vector3(-8, 0, -20), Vector3(8, 0, -20), Vector3(-19.3, 0, -7), Vector3(19.3, 0, -7), Vector3(-7.5, 0, 23.5), Vector3(7.5, 0, 23.5)]
	for i in positions.size():
		var spectator := preload("res://scripts/battle/arenas/shared/animated_spectator.gd").new()
		spectator.name = "Passenger%d" % i
		spectator.position = positions[i]
		spectator.rotation.y = atan2(-spectator.position.x, -spectator.position.z)
		spectator.configure(models[i % models.size()], i * 1.37, 1.15, true)
		audience.add_child(spectator)

func _add_deck_details(arena: Node3D, ivory: Material, navy: Material, brass: Material, red: Material, wood: Material, glass: Material) -> void:
	# Low forecastle and nautical fittings give the sea-facing end its own identity.
	var bow := group(arena, "Forecastle")
	box(bow, ivory, Vector3(0, 0.2, 29), Vector3(28, 0.4, 6))
	box(bow, wood, Vector3(0, 0.42, 29), Vector3(28, 0.04, 6))
	for step in 3:
		box(bow, wood, Vector3(0, 0.07 * (step + 1), 25.2 + step * 0.3), Vector3(5, 0.14 * (step + 1), 0.3))
	for side in [-1, 1]:
		var bollard := group(bow, "MooringBollard", Vector3(side * 11, 0.44, 29))
		box(bollard, navy, Vector3(0, 0.07, 0), Vector3(1.3, 0.14, 0.8))
		for x in [-0.38, 0.38]:
			cylinder(bollard, brass, Vector3(x, 0.45, 0), 0.18, 0.75)
	var capstan := group(bow, "AnchorCapstan", Vector3(0, 0.44, 28))
	cylinder(capstan, navy, Vector3(0, 0.5, 0), 0.5, 1.0)
	cylinder(capstan, brass, Vector3(0, 1.02, 0), 0.7, 0.14)
	for yaw in [0.0, PI / 2]:
		box(capstan, wood, Vector3(0, 1.07, 0), Vector3(2.8, 0.1, 0.12)).rotation.y = yaw
	var mast := group(arena, "BowSignalMast", Vector3(0, 0.44, 31))
	cylinder(mast, ivory, Vector3(0, 4.4, 0), 0.11, 8.8, 0.06)
	box(mast, brass, Vector3(0, 7, 0), Vector3(6, 0.09, 0.09))
	for side in [-1, 1]:
		beam(mast, brass, Vector3(side * 3, 7, 0), Vector3(side * 5, 0, 0), 0.035)
		var flag_material: StandardMaterial3D = (red if side < 0 else navy).duplicate()
		flag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var flag := SurfaceTool.new()
		flag.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in [Vector3(side * 0.3, 6.4, 0), Vector3(side * 2.7, 5.6, 0.15), Vector3(side * 0.3, 4.8, 0)]:
			flag.add_vertex(vertex)
		flag.generate_normals()
		prop(mast, flag.commit(), flag_material, Vector3.ZERO)
	# Lamps frame the port/starboard views without enclosing the combat space.
	var lamps := group(arena, "PromenadeLamps")
	var glow := matte(Color("ffe4b1"), 0.5)
	for side in [-1, 1]:
		for z in [-11, 12]:
			var post := group(lamps, "DeckLantern", Vector3(side * 19.6, 0, z))
			cylinder(post, navy, Vector3(0, 1.55, 0), 0.065, 3.1)
			cylinder(post, glow, Vector3(0, 3.22, 0), 0.19, 0.38)
			cylinder(post, brass, Vector3(0, 3.47, 0), 0.27, 0.16, 0.05)
	# Portholes continue around the cabin sides for oblique camera views.
	var cabin := arena.get_node("ShipSuperstructure")
	for side in [-1, 1]:
		for z in [-3, 2]:
			var frame := cylinder(cabin, brass, Vector3(side * 14.6, 3.6, z), 0.7, 0.16)
			frame.rotation.z = PI / 2
			var pane := cylinder(cabin, glass, Vector3(side * 14.7, 3.6, z), 0.56, 0.1)
			pane.rotation.z = PI / 2
