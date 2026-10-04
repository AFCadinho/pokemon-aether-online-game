extends SceneTree

var failed := false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var route := (load("res://scenes/overworld/kanto/routes/kanto_route_12.tscn") as PackedScene).instantiate()
	var house := (load("res://scenes/overworld/kanto/routes/route_12_fishing_brother_house.tscn") as PackedScene).instantiate()
	check(route.get_node("Exits/ToFishingBrotherHouse").target_scene_path == house.scene_file_path, "Route 12 entrance targets the Fishing Brother house")
	check(route.get_node("Exits/ToFishingBrotherHouse").target_spawn_name == "FromRoute12", "Route 12 entrance selects the interior arrival spawn")
	check(route.get_node("Spawns/FromFishingBrotherHouse").position == Vector2(1040, 2544), "Exterior spawn matches Tiled arrival tile 32,79")
	check(house.get_node("Exits/ToRoute12").target_scene_path == route.scene_file_path, "House exit returns to Route 12")
	check(house.get_node("Exits/ToRoute12").target_spawn_name == "FromFishingBrotherHouse", "House exit selects the exterior arrival spawn")
	check(house.get_node("Spawns/FromRoute12").position == Vector2(304, 464), "Interior spawn matches Tiled arrival tile 9,14")
	check(house.get_node("Visual").scene_file_path == "res://generated/tiled_visuals/route_12_fishing_brother_house/route_12_fishing_brother_house.visual.tscn", "House uses the imported Tiled visual")
	var fishing_brother := house.get_node("Entities/NPCs/FishingGuruYoungerBrother")
	check(fishing_brother.npc_id == "kanto_route_12_fishing_guru", "House contains the registered Fishing Guru's younger brother")
	check(fishing_brother.reward_id == "kanto_route_12_super_rod", "Fishing brother grants the existing one-time Super Rod reward")
	check(fishing_brother.npc_sprite_frames != null, "Fishing brother uses the fishing guru overworld sprite")
	route.free()
	house.free()
	if not failed:
		print("PASS Route 12 Fishing Brother house entrance, exit, spawns and visual")
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
