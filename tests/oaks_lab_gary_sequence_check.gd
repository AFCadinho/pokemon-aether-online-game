extends SceneTree

const LAB_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"
const GARY_SCENE := "res://scenes/npcs/oaks_lab_gary.tscn"
const GARY_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/oaks_lab_gary.gd"
const OAK_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/oak.gd"

var failed := false


func _init() -> void:
	var lab_resource := load(LAB_SCENE) as PackedScene
	_check_true(lab_resource != null, "Oak's Lab scene loads with starter balls")
	_check_true(load(GARY_SCENE) is PackedScene, "Oak's Lab Gary scene loads")
	var lab_text := _read_text(LAB_SCENE)
	_check_true(lab_text.contains('name="LeftBulbasaur"'), "left ball contains Bulbasaur")
	_check_true(lab_text.contains('name="MiddleSquirtle"'), "middle ball contains Squirtle")
	_check_true(lab_text.contains('name="RightCharmander"'), "right ball contains Charmander")
	var gary_text := _read_text(GARY_SCRIPT)
	_check_true(gary_text.contains("_walk_to_world_position"), "Gary walks to his selected ball")
	_check_true(gary_text.contains('selected_ball.call("set_claimed", true)'), "Gary removes his selected ball")
	_check_true(gary_text.contains('"start_trainer_battle"'), "Gary starts the server trainer battle")
	var oak_text := _read_text(OAK_SCRIPT)
	_check_true(oak_text.contains("_schedule_gary_starter_sequence(player, create_result)"), "Oak hands the new-starter flow to Gary")
	if lab_resource != null:
		_check_staging_tiles(lab_resource)
	quit(1 if failed else 0)


func _check_staging_tiles(lab_resource: PackedScene) -> void:
	var lab := lab_resource.instantiate()
	var collision := lab.get_node_or_null("Collision") as TileMapLayer
	_check_true(collision != null, "Oak's Lab exposes its collision layer")
	if collision != null:
		var staging_positions: Array[Vector2] = [Vector2(432, 720)]
		var stand_offsets := {
			"LeftBulbasaur": Vector2(0, 80),
			"MiddleSquirtle": Vector2(0, 80),
			"RightCharmander": Vector2(0, 80),
		}
		var oak := lab.get_node_or_null("Entities/NPCs/Oak") as Node2D
		var occupied_npc_tiles: Array[Vector2i] = []
		if oak != null:
			occupied_npc_tiles.append(collision.local_to_map(collision.to_local(oak.global_position)))
		for ball_name: String in ["LeftBulbasaur", "MiddleSquirtle", "RightCharmander"]:
			var ball := lab.get_node_or_null("Entities/Interactables/StarterBalls/%s" % ball_name) as Node2D
			_check_true(ball != null, "%s exists on Oak's table" % ball_name)
			if ball != null:
				staging_positions.append(ball.global_position + (stand_offsets[ball_name] as Vector2))
		for world_position: Vector2 in staging_positions:
			var tile := collision.local_to_map(collision.to_local(world_position))
			_check_true(collision.get_cell_source_id(tile) == -1, "Gary staging tile %s is walkable" % world_position)
			_check_true(tile not in occupied_npc_tiles, "Gary staging tile %s is not occupied by Oak" % world_position)
	lab.free()


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	return "" if file == null else file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
