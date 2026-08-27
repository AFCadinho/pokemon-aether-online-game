extends SceneTree

const GYM_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string(GYM_SCENE)
	_check(
		source.contains("generated/tiled_visuals/cerulean_gym/cerulean_gym.visual.tscn"),
		"Cerulean Gym references its imported visual"
	)
	var gym: Node = load(GYM_SCENE).instantiate()
	root.add_child(gym)
	await process_frame
	var visual := gym.get_node_or_null("CeruleanGymVisual")
	var visual_map: Dictionary = {}
	if visual != null:
		visual_map = visual.get_meta("tiled_visual_map", {}) as Dictionary
	_check(visual_map.get("width") == 30, "Cerulean Gym preserves the 30-tile visual width")
	_check(visual_map.get("height") == 45, "Cerulean Gym preserves the 45-tile visual height")
	_check(gym.get_node_or_null("PewterGymTemplate/Visuals") == null, "Cerulean Gym removes the Pewter visual")
	_check(gym.get_node_or_null("PewterGymTemplate/FloorVisibilityMask") == null, "Cerulean Gym removes the Pewter floor mask")
	var collision := gym.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(collision != null, "Cerulean Gym retains gameplay collision")
	var spawn := gym.get_node_or_null("Spawns/FromCeruleanCity") as Marker2D
	_check(spawn != null and spawn.position == Vector2(496, 1232), "Cerulean Gym aligns its arrival with the foyer")
	if collision != null and spawn != null:
		_check(collision.get_cell_source_id(collision.local_to_map(spawn.position)) < 0, "Cerulean Gym arrival remains walkable")
	var exit := gym.get_node_or_null("Exits/ToCeruleanCity") as Area2D
	_check(exit != null and exit.position == Vector2(496, 1264), "Cerulean Gym aligns its exit with the foyer")
	var guide := gym.get_node_or_null("Entities/NPCs/GymGuide") as Node2D
	_check(guide != null and guide.position == Vector2(624, 1168), "Cerulean Gym Guide stands in the new foyer")
	gym.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
