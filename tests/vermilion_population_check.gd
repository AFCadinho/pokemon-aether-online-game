extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load("res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn") as PackedScene).instantiate()
	root.add_child(city)
	var collision := city.get_node("Tiles/Collision") as TileMapLayer
	var occupied: Dictionary = {}
	var npcs := city.get_node("Entities/NPCs")
	var pokemon := city.get_node("Entities/Pokemon")
	_check(npcs.get_child_count() == 12 and npcs.get_node("TransitKeeperNPC").local_destination_id == "kanto_vermilion_city" and npcs.has_node("GuildRegistrarNPC"), "ten dialogue residents, the city Transit Keeper and Guild Registrar")
	_check(pokemon.get_child_count() == 6, "six ambient Pokemon")
	for group: Node in [npcs, pokemon]:
		for actor: Node2D in group.get_children():
			var cell := collision.local_to_map(collision.to_local(actor.global_position))
			_check(not occupied.has(cell), "%s has its own tile" % actor.name)
			occupied[cell] = actor.name
			_check_clear(city, collision, cell, str(actor.name))
			if group == npcs:
				var rear := cell - Vector2i(actor.facing_direction)
				_check_clear(city, collision, rear, "%s pickpocket approach" % actor.name)
				_check(actor.npc_sprite_frames != null, "%s has character sprites" % actor.name)
				_check(actor.npc_id.begins_with("kanto_vermilion_city_"), "%s uses city metadata" % actor.name)
			else:
				_check(FollowerSpriteService.get_sprite_frames(actor.species_id, false) != null, "%s follower sprite resolves" % actor.name)
				if actor.movement_behavior != "idle":
					var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
					for offset in [-1, 1]:
						_check_clear(city, collision, cell + axis * offset, "%s patrol" % actor.name)
	for npc: Node2D in npcs.get_children():
		var rear := collision.local_to_map(npc.position) - Vector2i(npc.facing_direction)
		_check(not occupied.has(rear), "%s rear approach is unoccupied" % npc.name)
	for exit_node: Node2D in city.get_node("Exits").get_children():
		for group: Node in [npcs, pokemon]:
			for actor: Node2D in group.get_children():
				_check(not exit_node.contains_world_position(actor.global_position), "%s leaves %s clear" % [actor.name, exit_node.name])
	city.queue_free()
	await process_frame
	print("VERMILION_POPULATION ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check_clear(city: Node, collision: TileMapLayer, cell: Vector2i, label: String) -> void:
	_check(collision.get_cell_source_id(cell) == -1, label + " is walkable")
	_check(not city.is_water_tile_for_actor(Vector2(cell * 32 + Vector2i(16, 16)), null), label + " is dry")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + label)
