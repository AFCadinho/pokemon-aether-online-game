extends SceneTree

const WildEncounterProvider := preload("res://scripts/world/map_encounter_provider.gd")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/overworld/kanto/interiors/power_plant.tscn") as PackedScene
	_check(packed != null, "Power Plant scene loads")
	if packed == null:
		quit(1)
		return
	var map := packed.instantiate()
	_check(str(map.call("get_wild_encounter_area_id")) == "kanto_power_plant", "Power Plant links to its wild encounter table")
	_check(str(map.call("get_step_encounter_type")) == "grass", "Power Plant checks encounters while walking")
	_check(str(map.call("get_battle_environment_id")) == "building", "Power Plant keeps the indoor battle environment")
	_check(is_equal_approx(float(map.get("grass_encounter_chance")), 0.21), "Power Plant has a fallback walking encounter chance")
	var encounter := WildEncounterProvider.resolve_wild_encounter(map, Vector2.ZERO, "grass")
	_check(bool(encounter.get("available", false)), "Power Plant walking encounters resolve")
	_check(str(encounter.get("area_id")) == "kanto_power_plant", "Walking encounters use the Power Plant species table")
	_check(bool(encounter.get("use_map_trigger", false)), "Power Plant walking encounters use the configured step chance")
	map.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failed = true
		push_error("FAIL %s" % label)
