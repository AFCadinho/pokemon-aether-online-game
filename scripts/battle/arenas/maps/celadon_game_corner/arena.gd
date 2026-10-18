extends "res://scripts/battle/arenas/shared/indoor_gym.gd"
## A subdued casino lounge; cabinets and stools sit outside the camera orbit.

func build() -> Node3D:
	var arena := Node3D.new()
	arena.name = "CeladonGameCornerArena"
	arena.set_meta("source_map", "kanto_celadon_game_corner")
	arena.set_meta("surface_height", 0.0)
	var plum := matte(Color("302335"))
	var wine := matte(Color("4b293c"))
	var dark := matte(Color("191b28"))
	var gold := matte(Color("80633d"))
	var wood := surface(Color("3e2a33"), Color("251c24"), 2, 2.5)
	var cream := matte(Color("a29378"))
	var amber := matte(Color("bd8a44"), 0.35)
	var pink := matte(Color("974867"), 0.25)
	var teal := matte(Color("387784"), 0.3)
	hall(arena, plum, gold, matte(Color("221c2c")))
	box(arena, wood, Vector3(0, -0.34, 0), Vector3(52, 0.6, 62))
	var rug := group(arena, "CasinoCarpet")
	box(rug, _stone(Color("392432"), true), Vector3(0, -0.02, 0), Vector3(30, 0.04, 40))
	for x in [-14.6, 14.6]:
		box(rug, gold, Vector3(x, 0.008, 0), Vector3(0.1, 0.016, 39))
	for z in [-19.5, 19.5]:
		box(rug, gold, Vector3(0, 0.008, z), Vector3(29.3, 0.016, 0.1))
	for x in [-11, 11]:
		for z in [-14, -7, 0, 7, 14]:
			var inset := box(rug, plum, Vector3(x, 0.008, z), Vector3(0.8, 0.016, 0.8))
			inset.rotation.y = PI / 4
	var machines := group(arena, "SlotMachines")
	for side in [-1, 1]:
		for z in [-18, -6, 6, 18]:
			_cabinet(machines, Vector3(side * 23.5, 0, z), -side * PI / 2, wine, dark, gold, cream, teal, amber)
		for x in [10, 16, 22]:
			_cabinet(machines, Vector3(side * x, 0, -27), 0, wine, dark, gold, cream, pink, amber)
		for z in [-24, -12, 0, 12, 24]:
			var panel := group(arena, "WallPanel", Vector3(side * 25.25, 0, z))
			panel.rotation.y = -side * PI / 2
			box(panel, wood, Vector3(0, 2, 0), Vector3(9, 4, 0.2))
			box(panel, wine, Vector3(0, 7, 0), Vector3(4, 4, 0.2))
			_diamond(panel, gold, Vector3(0, 7, 0.2), 1.2)
			lamp(arena, Vector3(side * 25.1, 5.7, z + 3.5), -side * PI / 2, gold, amber)
	var counter := group(arena, "TokenCounter", Vector3(0, 0, -28))
	box(counter, wood, Vector3(0, 1.35, 0), Vector3(12, 2.7, 3.2))
	box(counter, gold, Vector3(0, 2.75, 0), Vector3(12.4, 0.18, 3.6))
	for x in [-4, 0, 4]:
		box(counter, wine, Vector3(x, 1.35, 1.65), Vector3(3.4, 1.8, 0.08))
		_diamond(counter, gold, Vector3(x, 1.35, 1.73), 0.55)
	for x in [-3, 3]:
		box(counter, dark, Vector3(x, 3.1, 0), Vector3(1.1, 0.6, 0.9))
		box(counter, teal, Vector3(x, 3.15, 0.47), Vector3(0.75, 0.25, 0.03))
	# Three illuminated diamonds echo the casino frontage without a bright wall.
	var sign := group(arena, "GameCornerMarquee", Vector3(0, 5.7, -30.1))
	box(sign, dark, Vector3.ZERO, Vector3(10, 3.7, 0.35))
	for i in 3:
		_diamond(sign, [pink, amber, teal][i], Vector3((i - 1) * 3, 0, 0.25), 1.1)
	for y in [-1.8, 1.8]:
		box(sign, gold, Vector3(0, y, 0.2), Vector3(10.2, 0.12, 0.12))
	var entrance := group(arena, "CasinoEntrance", Vector3(0, 0, 30.1))
	box(entrance, gold, Vector3(0, 3.5, 0), Vector3(8, 7, 0.5))
	box(entrance, dark, Vector3(0, 3.2, -0.35), Vector3(7.2, 6.4, 0.3))
	box(entrance, gold, Vector3(0, 3.2, -0.55), Vector3(0.1, 6.4, 0.1))
	for side in [-1, 1]:
		var sofa := group(arena, "LoungeSeat", Vector3(side * 15, 0, 27.5))
		box(sofa, dark, Vector3(0, 0.4, 0), Vector3(8, 0.8, 3))
		box(sofa, wine, Vector3(0, 1, 0), Vector3(8, 0.5, 3))
		box(sofa, wine, Vector3(0, 1.8, 1.2), Vector3(8, 1.8, 0.6))
		for x in [-3.7, 3.7]:
			box(sofa, wine, Vector3(x, 1.5, 0), Vector3(0.6, 1.2, 3))
	return arena

func _diamond(parent: Node3D, material: Material, pos: Vector3, radius: float) -> void:
	for side in [-1, 1]:
		beam(parent, material, pos + Vector3(0, radius, 0), pos + Vector3(side * radius * 0.7, 0, 0), 0.1)
		beam(parent, material, pos + Vector3(side * radius * 0.7, 0, 0), pos - Vector3(0, radius, 0), 0.1)

func _cabinet(parent: Node3D, pos: Vector3, yaw: float, body: Material, dark: Material, gold: Material, reel: Material, screen: Material, glow: Material) -> void:
	var machine := group(parent, "SlotCabinet", pos)
	machine.rotation.y = yaw
	box(machine, dark, Vector3(0, 0.25, 0), Vector3(3, 0.5, 2.2))
	box(machine, body, Vector3(0, 2.2, 0), Vector3(2.8, 3.9, 1.9))
	box(machine, gold, Vector3(0, 4.35, 0), Vector3(3, 0.4, 2))
	box(machine, screen, Vector3(0, 3.9, 1), Vector3(2.35, 0.4, 0.08))
	box(machine, dark, Vector3(0, 2.8, 1), Vector3(2.45, 1.45, 0.1))
	for x in [-0.75, 0, 0.75]:
		box(machine, reel, Vector3(x, 2.8, 1.07), Vector3(0.65, 1.05, 0.05))
		box(machine, body, Vector3(x, 3.02, 1.11), Vector3(0.4, 0.1, 0.025))
		beam(machine, body, Vector3(x + 0.18, 3.02, 1.11), Vector3(x - 0.1, 2.55, 1.11), 0.1)
	box(machine, gold, Vector3(0, 1.8, 1.1), Vector3(2.8, 0.16, 0.75))
	box(machine, glow, Vector3(0.75, 1.9, 1.25), Vector3(0.3, 0.1, 0.2))
	box(machine, dark, Vector3(-0.4, 1.9, 1.25), Vector3(0.55, 0.1, 0.2))
	box(machine, dark, Vector3(0, 0.8, 1), Vector3(1.3, 0.35, 0.12))
	var stool := group(machine, "Stool", Vector3(0, 0, 2.6))
	cylinder(stool, dark, Vector3(0, 0.1, 0), 0.7, 0.2)
	cylinder(stool, gold, Vector3(0, 0.65, 0), 0.14, 1.1)
	cylinder(stool, body, Vector3(0, 1.25, 0), 0.72, 0.3)
