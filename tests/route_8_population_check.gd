extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_8.tscn"


func _initialize() -> void:
	var packed := load(ROUTE) as PackedScene
	_check(packed != null, "Route 8 scene loads")
	if packed == null:
		quit(1)
		return
	var route := packed.instantiate()
	_check(route.get("encounter_area_id") == "kanto_route_8", "Route uses its wild encounter area")
	_check(is_equal_approx(float(route.get("grass_encounter_chance")), 0.21), "Route has grass encounters")
	_check(route.has_node("Tiles/TallGrass"), "Artist tall grass mask remains available to gameplay")
	_check(route.has_node("Tiles/Collision"), "Existing player collision layer is preserved")
	_check(route.get_node("Entities/NPCs").get_child_count() == 12, "FRLG route trainers are present")
	_check(route.get_node("Entities/Pokemon").get_child_count() == 6, "Route wildlife has visible overworld Pokemon")
	_check(route.get_node("Entities/Interactables/Items").get_child_count() == 4, "Route pickups are present")
	route.free()
	quit(0 if failures == 0 else 1)


var failures := 0


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Route 8 population: " + description)
	print("FAIL: " + description)
