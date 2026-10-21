extends SceneTree

var failed := false

func _init() -> void:
    _run.call_deferred()

func _run() -> void:
    var map := (load("res://scenes/overworld/kanto/routes/kanto_route_19.tscn") as PackedScene).instantiate()
    root.add_child(map)
    var collision: TileMapLayer = map.find_map_tilemap_layer("Collision")
    _check(map.encounter_area_id == "kanto_route_19" and is_equal_approx(map.surf_encounter_chance, .02), "Surf encounters are registered")
    var actors: Array = map.get_node("Entities/NPCs").get_children()
    actors.append_array(map.get_node("Entities/Pokemon").get_children())
    _check(map.get_node("Entities/NPCs").get_child_count() == 19, "twelve swimmers and seven friendly NPCs")
    _check(map.get_node("Entities/Pokemon").get_child_count() == 8, "eight ambient Pokemon")
    var occupied := {}
    for actor in actors:
        var cell := Vector2i(actor.position / 32.0)
        _check(not occupied.has(cell), "actors have unique positions")
        occupied[cell] = true
    var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
    player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
    map.get_node("Entities/Players").add_child(player)
    player.position = map.get_node("Spawns/FromFuchsiaGate").position
    player.refresh_map_layers()
    var sea := Vector2(25*32+16,60*32+16)
    _check(not player.can_move_to(sea), "walking cannot enter the sea")
    player.surf_activity_active = true
    _check(player.can_move_to(sea), "Surf can enter the sea")
    var start := Vector2i(map.get_node("Spawns/FromFuchsiaGate").position / 32.0)
    var reached := {start:true}
    var pending: Array[Vector2i] = [start]
    var cursor := 0
    while cursor < pending.size():
        var cell := pending[cursor]
        cursor += 1
        for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
            var next: Vector2i = cell + direction
            if not Rect2i(0,0,48,72).has_point(next) or reached.has(next) or occupied.has(next): continue
            if player.can_move_to(Vector2(next)*32+Vector2(16,16)):
                reached[next] = true
                pending.append(next)
    var trainers := 0
    for actor in actors:
        var cell := Vector2i(actor.position / 32.0)
        _check(collision.get_cell_source_id(cell) == -1, "actor stands on unblocked ground: " + actor.name)
        var accessible := false
        for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
            if reached.has(cell+direction): accessible = true
        _check(accessible, "actor can be approached with Surf: " + actor.name)
        for exit_node in map.get_node("Exits").get_children():
            _check(not exit_node.contains_world_position(actor.position), "actor avoids exit trigger")
        if actor.name.begins_with("swimmer_") or actor.name.begins_with("sis_and_bro_"):
            trainers += 1
            _check(map.is_water_tile_for_actor(actor.position,actor), "swimmer trainer stays in the sea: " + actor.name)
            _check(actor.npc_sprite_frames != null and actor.mugshot != null, "trainer has swimmer art")
            _check(actor.trainer_id == actor.npc_id and actor.battle_environment_id == "water", "trainer battle registration")
            for step in range(1,actor.sight_range_tiles+1):
                var target: Vector2i = cell + Vector2i(actor.facing_direction)*step
                _check(collision.get_cell_source_id(target) == -1 and not occupied.has(target), "clear trainer approach: " + actor.name)
        if actor.name in ["beach_attendant","sandcastle_builder","beachgoer","coast_watcher","resting_sailor"]:
            _check(not map.is_water_tile_for_actor(actor.position,actor), "beach visitor stands on dry land: " + actor.name)
            _check(actor.npc_sprite_frames != null and actor.dialogue_id.ends_with("_talk"), "beach visitor has ordinary art and dialogue")
            _check(reached.has(cell+Vector2i(actor.facing_direction)), "beach visitor faces an accessible interaction tile: " + actor.name)
        if actor.get_parent().name == "Pokemon":
            var on_water: bool = map.is_water_tile_for_actor(actor.position, actor)
            for offset in [-1,0,1]:
                var target := cell + Vector2i(offset,0)
                _check(collision.get_cell_source_id(target) == -1 and (offset == 0 or not occupied.has(target)), "ambient patrol is free: " + actor.name)
                _check(map.is_water_tile_for_actor(Vector2(target)*32+Vector2(16,16),actor) == on_water, "ambient patrol preserves land/water habitat: " + actor.name)
    _check(trainers == 12, "all twelve trainers use the real trainer script")
    map.free()
    print("ROUTE_19_POPULATION ", "FAIL" if failed else "PASS")
    quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
    if not ok:
        failed = true
        push_error(label)
