extends "res://scripts/battle/arenas/shared/indoor_gym.gd"
## A quiet memorial chamber. All raised scenery stays outside the battle orbit.

func build() -> Node3D:
	var arena := Node3D.new()
	arena.name = "PokemonTowerArena"
	arena.set_meta("source_map", "kanto_lavender_town_pokemon_tower")
	arena.set_meta("surface_height", 0.0)
	var wall := surface(Color("352f47"), Color("211d2c"), 1, 1.7)
	var stone := surface(Color("514960"), Color("393245"), 1, 1.0)
	var trim := matte(Color("544960"))
	var dark := matte(Color("191622"))
	var bronze := matte(Color("685037"))
	var wax := matte(Color("ac9475"))
	var flame := matte(Color("e6ad62"), 0.8)
	var violet := matte(Color("5f508c"), 0.2)
	hall(arena, wall, trim, surface(Color("282233"), Color("1b1724"), 1, 3.0))
	box(arena, surface(Color("282335"), Color("1b1825"), 0, 2.2), Vector3(0, -0.34, 0), Vector3(52, 0.6, 62))
	var aisle := group(arena, "MemorialAisle")
	box(aisle, surface(Color("383043"), Color("241e2e"), 0, 1.4), Vector3(0, -0.015, 0), Vector3(15, 0.03, 59))
	for x in [-7.65, 7.65]:
		box(aisle, bronze, Vector3(x, 0.008, 0), Vector3(0.12, 0.016, 59))
	# Inlaid memorial medallion, flush enough for grounded Pokémon and effects.
	var seal := group(arena, "MemorialSeal")
	for radius in [4.8, 5.2]:
		ring(seal, trim, Vector3(0, 0.012, 0), radius, 0.055).scale.y = 0.12
	for i in 8:
		var angle := i * TAU / 8.0
		var inset := box(seal, bronze, Vector3(sin(angle) * 5, 0.014, cos(angle) * 5), Vector3(0.23, 0.012, 0.23))
		inset.rotation.y = angle + PI / 4
	var graves := group(arena, "MemorialRows")
	for side in [-1, 1]:
		for z in [-23, -16, -9, -2, 5, 12, 19, 26]:
			_grave(graves, Vector3(side * 22.7, 0, z), -side * PI / 2, stone, trim, dark, bronze)
		for x in [9, 14, 19]:
			_grave(graves, Vector3(side * x, 0, -26.5), 0, stone, trim, dark, bronze)
			_grave(graves, Vector3(side * x, 0, 27), PI, stone, trim, dark, bronze)
		for z in [-24, -12, 0, 12, 24]:
			var pier := group(arena, "MemorialPillar", Vector3(side * 24.6, 0, z))
			box(pier, trim, Vector3(0, 0.35, 0), Vector3(1.5, 0.7, 1.5))
			box(pier, stone, Vector3(0, 7.1, 0), Vector3(0.9, 13, 0.9))
			box(pier, trim, Vector3(0, 13.7, 0), Vector3(1.7, 0.5, 1.7))
			lamp(arena, Vector3(side * 25.1, 5.5, z + 3), -side * PI / 2, bronze, flame)
	var altar := group(arena, "RemembranceAltar", Vector3(0, 0, -27))
	box(altar, stone, Vector3(0, 0.3, 0), Vector3(8, 0.6, 5))
	box(altar, trim, Vector3(0, 0.75, -0.5), Vector3(6.5, 0.3, 3))
	box(altar, stone, Vector3(0, 1.8, -0.5), Vector3(4.5, 1.8, 1.8))
	box(altar, trim, Vector3(0, 2.8, -0.5), Vector3(5.2, 0.25, 2.2))
	for x in [-2.0, -1.2, 1.2, 2.0]:
		cylinder(altar, bronze, Vector3(x, 3.0, -0.5), 0.23, 0.12)
		cylinder(altar, wax, Vector3(x, 3.35, -0.5), 0.13, 0.65)
		cylinder(altar, flame, Vector3(x, 3.83, -0.5), 0.11, 0.3, 0.0)
	# Tall recessed arches, with a simple spectral rosette above the shrine.
	var shrine := group(arena, "ShrineWall", Vector3(0, 0, -30.1))
	for x in [-14, -7, 0, 7, 14]:
		box(shrine, dark, Vector3(x, 6.8, 0), Vector3(4.8, 7.5, 0.25))
		for side in [-1, 1]:
			box(shrine, trim, Vector3(x + side * 2.55, 6.5, 0.2), Vector3(0.35, 8, 0.4))
			beam(shrine, trim, Vector3(x + side * 2.55, 10.5, 0.2), Vector3(x, 13, 0.2), 0.36)
		for side in [-1, 1]:
			beam(shrine, violet, Vector3(x, 5, 0.25), Vector3(x + side * 1.35, 7, 0.25), 0.12)
			beam(shrine, violet, Vector3(x + side * 1.35, 7, 0.25), Vector3(x, 9, 0.25), 0.12)
	var rosette := ring(shrine, bronze, Vector3(0, 7, 0.3), 1.1, 0.13)
	rosette.rotation.x = PI / 2
	var entrance := group(arena, "TowerDoor", Vector3(0, 0, 30.1))
	box(entrance, trim, Vector3(0, 4, 0), Vector3(7, 8, 0.6))
	box(entrance, dark, Vector3(0, 3.7, -0.4), Vector3(5.8, 7.4, 0.3))
	box(entrance, bronze, Vector3(0, 3.7, -0.6), Vector3(0.12, 7.4, 0.12))
	return arena

func _grave(parent: Node3D, pos: Vector3, yaw: float, stone: Material, trim: Material, dark: Material, bronze: Material) -> void:
	var grave := group(parent, "Memorial", pos)
	grave.rotation.y = yaw
	box(grave, trim, Vector3(0, 0.12, 0.45), Vector3(2.8, 0.24, 3.4))
	box(grave, stone, Vector3(0, 1.2, -0.55), Vector3(1.9, 2, 0.55))
	var cap := cylinder(grave, stone, Vector3(0, 2.18, -0.55), 0.95, 0.55)
	cap.rotation.x = PI / 2
	box(grave, dark, Vector3(0, 1.25, -0.25), Vector3(1.2, 0.7, 0.04))
	for y in [1.1, 1.35]:
		box(grave, bronze, Vector3(0, y, -0.22), Vector3(0.75, 0.045, 0.025))
	box(grave, stone, Vector3(0, 0.3, 0.65), Vector3(1.8, 0.12, 1.7))
