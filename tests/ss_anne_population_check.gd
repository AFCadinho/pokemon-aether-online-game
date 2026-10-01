extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var ids := {}
	var dialogue_count := 0
	var trainer_count := 0
	for floor_name in ["1f", "2f", "b1f", "3f"]:
		var path: String = "res://scenes/overworld/kanto/towns/ss_anne/ss_anne_" + floor_name + ".tscn"
		var map := (load(path) as PackedScene).instantiate()
		var added := 0
		for npc in map.get_node("Entities/NPCs").get_children():
			if not str(npc.name).begins_with("Population"):
				continue
			added += 1
			check(not ids.has(npc.npc_id), "Unique population NPC ID")
			ids[npc.npc_id] = true
			check(npc.npc_sprite_frames != null, "NPC has artwork")
			var catalog := root.get_node("TrainerPortraitCatalog")
			check(not catalog.resolve_portrait_id(npc.portrait_id, npc.npc_id, npc.npc_definition_id).is_empty(), "NPC has a matching dialogue/battle portrait")
			check(npc.position.x == floor(npc.position.x / 32.0) * 32.0 + 16.0 and npc.position.y == floor(npc.position.y / 32.0) * 32.0 + 16.0, "NPC stands on a tile center")
			var inside := false
			for region in map.get_node("FloorVisibilityMask").floor_regions.values():
				inside = inside or region.has_point(npc.position)
			check(inside, "NPC lies in a visible ship room")
			var ground := map.get_node("Visual/Ground") as TileMapLayer
			check(ground.get_cell_source_id(ground.local_to_map(npc.position)) != -1, "NPC stands on a mapped floor")
			for layer_name in ["Objects", "ObjectsTop"]:
				var furniture := map.get_node_or_null("Visual/" + layer_name) as TileMapLayer
				if furniture != null:
					check(furniture.get_cell_source_id(furniture.local_to_map(npc.position)) == -1, "NPC leaves furniture clear: " + npc.name)
			var collision := map.get_node_or_null("Tiles/Collision") as TileMapLayer
			if collision != null:
				check(collision.get_cell_source_id(collision.local_to_map(npc.position)) == -1, "NPC does not stand in painted collision: " + npc.name)
			for exit in map.get_node("Exits").get_children():
				check(not exit.contains_world_position(npc.position), "NPC does not block a transition")
			for spawn in map.get_node("Spawns").get_children():
				check(npc.position.distance_to(spawn.position) >= 64.0, "NPC leaves arrivals clear: " + npc.name)
			for other in map.get_node("Entities/NPCs").get_children():
				if npc != other:
					check(npc.position.distance_to(other.position) >= 64.0, "NPCs leave interaction space: " + npc.name)
			if npc.get_script().resource_path.ends_with("trainer_npc.gd"):
				trainer_count += 1
				check(npc.trainer_id == npc.npc_id, "Trainer ID matches server population ID")
				check(npc.sight_range_tiles == 0, "Additional battles are initiated by talking")
			else:
				dialogue_count += 1
		check(added > 0, "Every ship floor gains NPCs")
		map.free()
	check(dialogue_count == 8, "Eight additional dialogue NPCs")
	check(trainer_count == 6, "Six additional trainers")
	if not failed:
		print("SS_ANNE_POPULATION PASS: 8 dialogue NPCs, 6 optional trainers, all four floors and safe placement")
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
