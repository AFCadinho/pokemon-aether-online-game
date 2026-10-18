extends "res://scripts/battle/arenas/shared/indoor_gym.gd"
## Team Rocket's underground operations room, built independently in both passes.

func build() -> Node3D:
	var arena := Node3D.new()
	arena.name = "RocketHideoutArena"
	arena.set_meta("source_map", "kanto_rocket_hideout_b1f")
	arena.set_meta("surface_height", 0.0)
	var wall := surface(Color("59616b"), Color("303840"), 1, 2.5)
	var steel := matte(Color("7a8792"))
	var dark := matte(Color("222a33"))
	var red := matte(Color("b92d42"))
	var red_glow := matte(Color("f23e55"), 0.65)
	var screen := matte(Color("69c3ce"), 0.7)
	var white := matte(Color("d6e5e6"), 0.7)
	var yellow := matte(Color("c6a459"))
	hall(arena, wall, dark, surface(Color("38414c"), Color("252b32"), 0, 4.0))
	box(arena, surface(Color("747e87"), Color("424b55"), 0, 2.5), Vector3(0, -0.34, 0), Vector3(52, 0.6, 62))
	var floor := group(arena, "OperationsFloor")
	box(floor, surface(Color("8d969d"), Color("56616a"), 0, 2.5), Vector3(0, -0.02, 0), Vector3(30, 0.04, 38))
	for side in [-1, 1]:
		box(floor, red, Vector3(side * 15.2, 0.008, 0), Vector3(0.18, 0.016, 45))
		# Conduit runs and warning bands sit against the outer walls.
		for y in [3.8, 4.5]:
			beam(arena, steel, Vector3(side * 25.1, y, -29), Vector3(side * 25.1, y, 29), 0.25)
		for z in [-24, -12, 0, 12, 24]:
			box(arena, dark, Vector3(side * 25.1, 8, z), Vector3(0.6, 16, 0.9))
			box(arena, white, Vector3(side * 24.7, 10, z), Vector3(0.12, 0.25, 3.8))
			box(arena, red, Vector3(side * 25.35, 2.5, z), Vector3(0.1, 0.55, 10.5))
	var machines := group(arena, "ServerBanks")
	for side in [-1, 1]:
		for z in [-19, -12, -5]:
			var rack := group(machines, "ServerRack", Vector3(side * 23.5, 0, z))
			rack.rotation.y = -side * PI / 2
			box(rack, dark, Vector3(0, 2.7, 0), Vector3(3.8, 5.4, 1.8))
			box(rack, steel, Vector3(0, 5.45, 0), Vector3(4, 0.15, 2))
			for y in [0.8, 1.9, 3.0, 4.1]:
				box(rack, wall, Vector3(0, y, 0.94), Vector3(3.3, 0.85, 0.12))
				box(rack, screen, Vector3(-0.9, y, 1.02), Vector3(0.55, 0.18, 0.04))
				box(rack, red_glow, Vector3(1.2, y, 1.02), Vector3(0.12, 0.12, 0.04))
				for x in [-0.1, 0.25, 0.6]:
					box(rack, dark, Vector3(x, y, 1.02), Vector3(0.1, 0.5, 0.04))
	var storage := group(arena, "CargoStacks")
	for side in [-1, 1]:
		for z in [9, 17, 25]:
			_crate(storage, Vector3(side * 23.1, 0, z), steel, dark, yellow)
			if z != 17:
				_crate(storage, Vector3(side * 23.1, 2.6, z), steel, dark, yellow)
	var command := group(arena, "CommandConsole", Vector3(0, 0, -27))
	box(command, dark, Vector3(0, 1.2, 0), Vector3(12, 2.4, 3))
	box(command, steel, Vector3(0, 2.45, 0), Vector3(12.3, 0.18, 3.2))
	for x in [-4, 0, 4]:
		box(command, dark, Vector3(x, 3.35, -0.65), Vector3(3.1, 1.7, 0.3))
		box(command, screen, Vector3(x, 3.35, -0.46), Vector3(2.75, 1.35, 0.05))
		for i in 3:
			box(command, dark, Vector3(x - 0.6, 3.0 + i * 0.3, -0.42), Vector3(1.2 + i * 0.25, 0.07, 0.025))
		box(command, dark, Vector3(x, 2.56, 0.65), Vector3(2.5, 0.06, 0.65))
	# Mesh-built R insignia: no external font, decal, pack or texture dependency.
	var emblem_root := group(arena, "RocketInsignia", Vector3(0, 6.5, -30.1))
	emblem_root.scale = Vector3.ONE * 0.6
	box(emblem_root, dark, Vector3.ZERO, Vector3(9.5, 8, 0.35))
	box(emblem_root, red_glow, Vector3(-1.6, 0, 0.25), Vector3(1, 6, 0.2))
	box(emblem_root, red_glow, Vector3(0, 2.5, 0.25), Vector3(3.4, 1, 0.2))
	box(emblem_root, red_glow, Vector3(1.7, 1.3, 0.25), Vector3(1, 2.6, 0.2))
	box(emblem_root, red_glow, Vector3(0, 0.1, 0.25), Vector3(3.4, 0.9, 0.2))
	beam(emblem_root, red_glow, Vector3(-0.1, -0.3, 0.25), Vector3(2.2, -2.9, 0.25), 0.95)
	for x in [-17, 17]:
		var vent := group(arena, "Ventilation", Vector3(x, 7, -30.1))
		box(vent, dark, Vector3.ZERO, Vector3(7, 5, 0.5))
		for y in range(-2, 3):
			box(vent, steel, Vector3(0, y * 0.75, 0.35), Vector3(6.5, 0.18, 0.3))
	var lift := group(arena, "SecurityLift", Vector3(0, 0, 30.1))
	box(lift, dark, Vector3(0, 4.3, 0), Vector3(9, 8.6, 0.6))
	for side in [-1, 1]:
		box(lift, steel, Vector3(side * 1.85, 3.8, -0.4), Vector3(3.6, 7.6, 0.3))
		box(lift, red, Vector3(side * 1.85, 3, -0.6), Vector3(3.6, 0.65, 0.08))
	box(lift, red_glow, Vector3(0, 8, -0.4), Vector3(4, 0.25, 0.12))
	for x in range(-5, 6):
		var stripe := box(lift, yellow if x % 2 == 0 else dark, Vector3(x * 0.7, 0.015, -1.3), Vector3(0.7, 0.03, 0.8))
		stripe.rotation.y = -0.3
	return arena

func _crate(parent: Node3D, pos: Vector3, steel: Material, dark: Material, yellow: Material) -> void:
	var crate := group(parent, "CargoCrate", pos)
	box(crate, steel, Vector3(0, 1.3, 0), Vector3(3.2, 2.6, 3.2))
	for x in [-1.5, 1.5]:
		box(crate, dark, Vector3(x, 1.3, 0), Vector3(0.18, 2.7, 3.3))
	for z in [-1.5, 1.5]:
		box(crate, dark, Vector3(0, 1.3, z), Vector3(3.3, 2.7, 0.18))
		box(crate, yellow, Vector3(0, 1.5, z * 1.07), Vector3(1.2, 0.5, 0.04))
