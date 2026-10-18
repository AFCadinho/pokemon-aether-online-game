extends SceneTree

const GYM := "res://scenes/overworld/kanto/towns/celadon_city/celadon_gym.tscn"
const PortraitCatalog := preload("res://scripts/services/trainer_portrait_catalog.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Keep detached: content placement checks do not require live account services.
	var gym: Node = load(GYM).instantiate()
	var collision: TileMapLayer = gym.get_node("Tiles/Collision")
	var actors: Array[Node] = gym.get_node("Entities/NPCs").get_children()
	_check(actors.size() == 5, "Four Gym trainers and Erika are present")
	var occupied: Dictionary = {}
	var ids: Dictionary = {}
	var catalog := PortraitCatalog.new()
	for actor: Node in actors:
		var tile := Vector2i(actor.position / 32.0)
		_check(not occupied.has(tile), "Trainer positions are distinct")
		occupied[tile] = true
		_check(collision.get_cell_source_id(tile) == -1, "Trainer stands on open floor")
		_check(actor.trainer_id == actor.npc_id and not ids.has(actor.trainer_id), "Stable unique trainer identity")
		ids[actor.trainer_id] = true
		_check(actor.battle_environment_id == "celadon_gym", "Dedicated garden battle environment")
		_check(actor.npc_sprite_frames != null and (actor.npc_sprite_frames.has_animation("default") or actor.npc_sprite_frames.has_animation("idle_down")), "Overworld sprite is available")
		var profile: Resource = actor.npc_profile
		var portrait := catalog.resolve_portrait_id(profile.portrait_id if profile != null else "", actor.npc_id, actor.npc_definition_id)
		_check(catalog.get_texture(portrait) != null, "Dialogue and battle portrait resolve")
	var reached := _reachable(collision, occupied)
	_check(reached.has(Vector2i(20, 10)) and reached.has(Vector2i(20, 64)), "Erika's approach and exit remain reachable with all trainers standing still")
	for actor: Node in actors:
		var tile := Vector2i(actor.position / 32.0)
		var facing := Vector2i(actor.facing_direction)
		_check(reached.has(tile + facing), "Every trainer can be approached from the front")
		for distance in range(1, int(actor.sight_range_tiles) + 1):
			_check(reached.has(tile + facing * distance), "Trainer sight stays in a clear walkable corridor")
	var erika: Node = gym.get_node("Entities/NPCs/GymLeaderErika")
	erika._apply_npc_profile()
	_check(erika.badge_id == "rainbow" and erika.badge_region == "kanto" and erika.badge_icon_texture != null, "Erika awards the matching Rainbow Badge")
	_check(not erika.supports_trainer_rematches() and erika.sight_range_tiles == 0, "Erika waits for interaction and has no standard rematches")
	_check(erika.npc_profile.portrait_id == "showdown_erika_lgpe", "Erika has her own trainer portrait")
	gym.free()
	catalog.free()
	if not failed:
		print("Celadon Gym trainers check passed")
	quit(1 if failed else 0)


func _reachable(collision: TileMapLayer, occupied: Dictionary) -> Dictionary:
	var queue: Array[Vector2i] = [Vector2i(20, 62)]
	var seen := {Vector2i(20, 62): true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := tile + direction
			if not Rect2i(0, 0, 42, 68).has_point(next) or seen.has(next) or occupied.has(next) or collision.get_cell_source_id(next) != -1:
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
