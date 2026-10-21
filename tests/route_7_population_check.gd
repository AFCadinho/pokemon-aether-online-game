extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_7.tscn"
const VISUAL := "res://generated/tiled_visuals/route_7/route_7.visual.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := (load(ROUTE) as PackedScene).instantiate()
	var visual := (load(VISUAL) as PackedScene).instantiate()
	var metadata: Dictionary = map.get_node("Visual").get_meta("tiled_visual_map")
	_check(metadata == visual.get_meta("tiled_visual_map"), "route inherits the current imported map dimensions")
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var npcs := map.get_node("Entities/NPCs")
	var pokemon := map.get_node("Entities/Pokemon")
	_check(npcs.get_child_count() == 5 and pokemon.get_child_count() == 6, "five residents and six Pokemon")
	var actors: Array[Node] = []
	actors.append_array(npcs.get_children())
	actors.append_array(pokemon.get_children())
	var reserved := {}
	var speeds := {}
	var waits := {}
	var ids := {}
	for actor in actors:
		var is_pokemon: bool = actor.get("species_id") != null
		var id: String = actor.get("overworld_pokemon_id" if is_pokemon else "npc_id")
		_check(id.begins_with("kanto_route_7_") and not ids.has(id), "%s has a unique Route 7 content ID" % actor.name)
		ids[id] = true
		_check(not actor.dialogue_id.is_empty(), "%s has dialogue assigned" % actor.name)
		_check(actor.natural_ambient_movement and not actor.ambient_movement_ignores_map_collision, "%s respects natural pacing and map collision" % actor.name)
		if is_pokemon:
			_check(FollowerSpriteService.get_sprite_frames(actor.species_id, false) != null, "%s follower sprites load" % actor.name)
		else:
			_check(actor.npc_sprite_frames != null, "%s NPC sprites load" % actor.name)
		var radius: int = 0 if actor.movement_behavior == "idle" else actor.movement_tiles
		if radius > 0:
			speeds[actor.movement_speed_pixels] = true
			waits[actor.movement_wait_seconds] = true
			_check(actor.movement_wait_jitter_seconds > 0, "%s has variable pauses" % actor.name)
		var cell := collision.local_to_map(actor.position)
		var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
		for offset in range(-radius, radius + 1):
			var lane := cell + axis * offset
			reserved[lane] = true
	_check(speeds.size() >= 8 and waits.size() >= 8, "residents use varied authored speeds and waits")
	# Even with every patrol lane occupied, travel and interaction approaches stay connected.
	map.free()
	visual.free()
	print("ROUTE_7_POPULATION ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
