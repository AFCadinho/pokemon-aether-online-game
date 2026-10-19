extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var island := (load('res://scenes/overworld/kanto/towns/cinnabar_island/cinnabar_island.tscn') as PackedScene).instantiate()
	var collision := island.get_node('Tiles/Collision') as TileMapLayer
	var water := island.get_node('Tiles/Water') as TileMapLayer
	var reserved := {}
	var speeds := {}
	var waits := {}
	var actors: Array[Node] = []
	actors.append_array(island.get_node('Entities/NPCs').get_children())
	actors.append_array(island.get_node('Entities/Pokemon').get_children())
	_check(actors.size() == 13, 'six residents, the Transit Keeper and six Pokemon')
	var doorway := island.get_node('Exits/ToPokecenter')
	for actor in actors:
		var cell := collision.local_to_map(actor.position)
		var axis := Vector2i.RIGHT if actor.movement_behavior == 'pace_horizontal' else Vector2i.DOWN
		var radius: int = 0 if actor.movement_behavior == 'idle' else actor.movement_tiles
		_check(actor.natural_ambient_movement, '%s uses independent pacing' % actor.name)
		if radius > 0:
			speeds[actor.movement_speed_pixels] = true
			waits[actor.movement_wait_seconds] = true
			_check(actor.movement_wait_jitter_seconds > 0, '%s varies its pauses' % actor.name)
		for offset in range(-radius, radius+1):
			var lane := cell + axis*offset
			_check(collision.get_cell_source_id(lane) == -1, '%s open patrol cell %s' % [actor.name, lane])
			_check(water.get_cell_source_id(lane) == -1, '%s stays on land at %s' % [actor.name, lane])
			_check(not reserved.has(lane), '%s has a separate lane at %s' % [actor.name,lane])
			_check(not doorway.contains_world_position(Vector2(lane*32)+Vector2(16,16)), 'doorway remains free')
			reserved[lane] = actor.name
		if actor.get("species_id") != null:
			_check(FollowerSpriteService.get_sprite_frames(actor.species_id, false) != null, '%s follower art exists' % actor.name)
		else:
			_check(actor.npc_sprite_frames != null, '%s NPC art exists' % actor.name)
	_check(speeds.size() >= 6 and waits.size() >= 6, 'varied authored speeds and pauses')
	# The entire Center approach stays free of resident patrols.
	for y in range(47, 53):
		_check(not reserved.has(Vector2i(33,y)), 'Center approach is clear at row %d' % y)
	island.free()
	print('CINNABAR_POPULATION ', 'FAIL' if failed else 'PASS')
	quit(1 if failed else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
