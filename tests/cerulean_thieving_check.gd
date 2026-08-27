extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const TARGETS := {
	"Entities/NPCs/OfficerJenny": {
		"npc_id": "kanto_cerulean_city_patrol_officer",
		"behind": Vector2(1008, 1008),
	},
	"Entities/NPCs/WaterwayVisitorMaya": {
		"npc_id": "kanto_cerulean_city_waterway_visitor_maya",
		"behind": Vector2(1424, 752),
	},
	"Entities/NPCs/BikeEnthusiastTheo": {
		"npc_id": "kanto_cerulean_city_bike_enthusiast_theo",
		"behind": Vector2(752, 1712),
	},
	"Entities/NPCs/AceTrainerLila": {
		"npc_id": "kanto_cerulean_city_ace_trainer_lila",
		"behind": Vector2(592, 1200),
	},
}
const LOCALIZATION_KEYS := [
	"ui.skills.thieving.target.cerulean_theo",
	"ui.skills.thieving.target.maya",
	"ui.skills.thieving.target.lila",
	"ui.skills.thieving.target.officer_jenny",
	"ui.skills.thieving.location.cerulean_city",
	"ui.skills.thieving.target_type.law_enforcement",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(CITY_SCENE) as PackedScene
	_check(packed_scene != null, "Cerulean City loads for Thieving checks")
	if packed_scene == null:
		quit(1)
		return

	var city := packed_scene.instantiate()
	root.add_child(city)
	var collision := city.get_node_or_null("Tiles/Collision") as TileMapLayer
	var water := city.get_node_or_null("Tiles/Water") as TileMapLayer
	_check(collision != null and water != null, "Cerulean resolves Thieving approach masks")

	for node_path: String in TARGETS:
		var target := city.get_node_or_null(node_path)
		var contract: Dictionary = TARGETS[node_path]
		_check(target != null, "Cerulean places %s" % node_path.get_file())
		if target == null:
			continue
		_check(str(target.get("npc_id")) == contract["npc_id"], "%s uses its authoritative NPC id" % node_path.get_file())
		var behind: Vector2 = contract["behind"]
		if collision != null and water != null:
			var collision_cell := collision.local_to_map(collision.to_local(behind))
			var water_cell := water.local_to_map(water.to_local(behind))
			_check(collision.get_cell_source_id(collision_cell) == -1, "%s has a walkable tile behind it" % node_path.get_file())
			_check(water.get_cell_source_id(water_cell) == -1, "%s has a dry tile behind it" % node_path.get_file())

	var officer := city.get_node_or_null("Entities/NPCs/OfficerJenny")
	_check(officer != null and str(officer.get("npc_definition_id")) == "trainer_class_policeman", "Officer Jenny keeps her police identity")
	var scene_source := FileAccess.get_file_as_string(CITY_SCENE)
	_check("pickpocket_enabled = true" not in scene_source, "Cerulean Thieving eligibility remains catalog-driven")

	for locale: String in "en,nl,pt_BR,zh_CN".split(","):
		var source := FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		for key: String in LOCALIZATION_KEYS:
			_check(('"%s"' % key) in source, "%s localizes %s" % [locale, key])

	city.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error(label)
