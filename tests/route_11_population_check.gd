extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var map := (load("res://scenes/overworld/kanto/routes/kanto_route_11.tscn") as PackedScene).instantiate()
	check(map.encounter_area_id == "kanto_route_11", "Route 11 uses its server encounter table")
	check(is_equal_approx(map.grass_encounter_chance, 0.21), "Grass fallback chance is configured")
	var grass := map.get_node("Tiles/TallGrass") as TileMapLayer
	var visual_grass := map.get_node("Visual/Grass") as TileMapLayer
	check(not grass.visible and not grass.get_used_cells().is_empty(), "Hidden gameplay grass exists")
	for cell in grass.get_used_cells():
		check(visual_grass.get_cell_source_id(cell) != -1, "Every encounter tile has visible tall grass")
		for layer_name in ["TreeBottom", "TreeTop", "Objects", "ObjectsTop", "Doors", "GroundDetail"]:
			check(map.get_node("Visual/" + layer_name).get_cell_source_id(cell) == -1, "Scenery is excluded from encounters")
	check(grass.get_cell_source_id(Vector2i(14, 4)) == -1, "Cliff tiles in the Grass visual layer are not encounter tiles")
	for cell in visual_grass.get_used_cells():
		var source := visual_grass.tile_set.get_source(visual_grass.get_cell_source_id(cell)) as TileSetAtlasSource
		if source.get_tile_animation_frames_count(visual_grass.get_cell_atlas_coords(cell)) <= 1:
			continue
		var has_scenery := false
		for layer_name in ["TreeBottom", "TreeTop", "Objects", "ObjectsTop", "Doors", "GroundDetail"]:
			has_scenery = has_scenery or map.get_node("Visual/" + layer_name).get_cell_source_id(cell) != -1
		if not has_scenery:
			check(grass.get_cell_source_id(cell) != -1, "Visible walkable grass triggers encounters")
	var trainers := map.get_node("Entities/NPCs").get_children()
	check(trainers.size() == 10, "All ten FRLG trainers exist")
	var ids := {}
	for trainer in trainers:
		check(trainer.get_script().resource_path.ends_with("trainer_npc.gd"), "NPC supports trainer battles")
		check(not ids.has(trainer.trainer_id), "Trainer IDs are unique")
		ids[trainer.trainer_id] = true
		check(trainer.trainer_id.begins_with("kanto_route_11_"), "Trainer ID matches Route 11")
		check(trainer.npc_sprite_frames != null, "Trainer has overworld artwork")
		var cell := visual_grass.local_to_map(trainer.position)
		for layer_name in ["TreeBottom", "TreeTop", "Objects", "ObjectsTop", "Doors", "GroundDetail"]:
			check(map.get_node("Visual/" + layer_name).get_cell_source_id(cell) == -1, "Trainer stands clear of scenery: " + trainer.name)
		for step in range(1, trainer.sight_range_tiles + 1):
			var ahead := cell + Vector2i(trainer.facing_direction) * step
			for layer_name in ["TreeBottom", "TreeTop", "Objects", "ObjectsTop", "Doors", "GroundDetail"]:
				check(map.get_node("Visual/" + layer_name).get_cell_source_id(ahead) == -1, "Trainer sight stays clear of scenery: " + trainer.name)
		for spawn in map.get_node("Spawns").get_children():
			check(trainer.position.distance_to(spawn.position) >= 96.0, "Trainer does not block a spawn")
	check(map.get_node("Exits").get_child_count() == 3, "Existing exits remain")
	map.free()
	if not failed: print("PASS Route 11: encounters, grass coverage, ten trainers and safe placement")
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
