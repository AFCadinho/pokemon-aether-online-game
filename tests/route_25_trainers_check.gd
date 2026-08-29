extends SceneTree

const ROUTE_25_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"
const EXPECTED_TRAINERS := {
	"HikerFranklin": "kanto_route_25_hiker_franklin",
	"YoungsterJoey": "kanto_route_25_youngster_joey",
	"HikerWayne": "kanto_route_25_hiker_wayne",
	"YoungsterDan": "kanto_route_25_youngster_dan",
	"PicnickerKelsey": "kanto_route_25_picnicker_kelsey",
	"HikerNob": "kanto_route_25_hiker_nob",
	"CamperFlint": "kanto_route_25_camper_flint",
	"YoungsterChad": "kanto_route_25_youngster_chad",
	"LassHaley": "kanto_route_25_lass_haley",
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(ROUTE_25_SCENE) as PackedScene
	_check(packed != null, "Route 25 scene loads with trainer content")
	if packed == null:
		quit(1)
		return

	var route := packed.instantiate()
	root.add_child(route)
	await process_frame
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(collision != null, "Route 25 exposes its gameplay collision")

	for node_name: String in EXPECTED_TRAINERS:
		var trainer := route.get_node_or_null("Entities/NPCs/%s" % node_name)
		_check(trainer != null, "Route 25 places %s" % node_name)
		if trainer == null:
			continue
		var trainer_id := str(EXPECTED_TRAINERS[node_name])
		_check(str(trainer.get("trainer_id")) == trainer_id, "%s uses its registered battle" % node_name)
		_check(str(trainer.get("npc_id")) == trainer_id, "%s keeps a stable NPC identity" % node_name)
		if collision != null:
			var trainer_cell := collision.local_to_map(trainer.position)
			_check(collision.get_cell_source_id(trainer_cell) < 0, "%s stands on a walkable tile" % node_name)

	var trainer_count := 0
	for npc: Node in route.get_node("Entities/NPCs").get_children():
		if EXPECTED_TRAINERS.has(npc.name):
			trainer_count += 1
	_check(trainer_count == EXPECTED_TRAINERS.size(), "Route 25 retains all nine canonical battle Trainers")
	route.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
