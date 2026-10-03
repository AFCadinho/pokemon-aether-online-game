extends SceneTree
var failed := false
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var world_script: Script = load("res://scripts/world/world.gd")
	_check(world_script != null and world_script.can_instantiate(), "World battle adapter compiles")
	var map: Node2D = load("res://scenes/overworld/kanto/interiors/power_plant.tscn").instantiate()
	var boss = map.get_node("Entities/Pokemon/ZapdosWeeklyBoss")
	_check(boss != null, "Zapdos is a static weekly boss")
	if boss == null:
		map.free()
		quit(1)
		return
	boss._apply_boss_definition()
	_check(boss.boss_definition.boss_id == "zapdos" and boss.species_id == "zapdos", "Zapdos definition is wired")
	_check(boss.movement_behavior == "idle", "Boss remains at its authoritative position")
	var backend_path := ProjectSettings.globalize_path("res://").path_join("../backend/account-service/data/weekly_bosses/catalog.json").simplify_path()
	if not FileAccess.file_exists(backend_path):
		backend_path = ProjectSettings.globalize_path("res://").path_join("../pokemon-aether-backend/account-service/data/weekly_bosses/catalog.json").simplify_path()
	var catalog_position := Vector2.INF
	if FileAccess.file_exists(backend_path):
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(backend_path))
		for entry: Dictionary in catalog.get("bosses", []):
			if entry.get("bossId") == boss.boss_definition.boss_id:
				catalog_position = Vector2(float(entry["position"]["x"]), float(entry["position"]["y"]))
	_check(boss.position == catalog_position, "Client and account catalog positions agree")
	_check(FollowerSpriteService.get_sprite_frames("zapdos", false) != null, "Zapdos has a follower sprite")
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var cell: Vector2i = collision.local_to_map(boss.position)
	_check(collision.get_cell_source_id(cell) == -1, "Boss stands on a walkable tile")
	for child: Node2D in map.get_node("Entities/Pokemon").get_children():
		if child != boss:
			_check(child.position.distance_to(boss.position) >= 32, "Boss avoids %s" % child.name)
	var visual := map.get_node("Visual")
	for layer: TileMapLayer in visual.find_children("*", "TileMapLayer", true, false):
		if layer.name not in ["Ground", "GroundDetail", "WallShadows"]:
			_check(layer.get_cell_source_id(layer.local_to_map(boss.position)) == -1, "Boss avoids decor in %s" % layer.name)
	map.free()
	quit(1 if failed else 0)
func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL " + label)
