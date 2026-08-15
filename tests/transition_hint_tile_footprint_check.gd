extends SceneTree

const ROUTE_HINT_SCENE := "res://scenes/world/transition_hints/route_transition_hint.tscn"
const DOOR_HINT_SCENE := "res://scenes/world/transition_hints/door_transition_hint.tscn"
const ROUTE_HINT_SCRIPT := "res://scripts/world/route_transition_hint.gd"
const DOOR_HINT_SCRIPT := "res://scripts/world/transition_hint.gd"
const MAP_SCENES: Array[String] = [
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn",
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn",
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_2.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_3.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_22.tscn",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_hint := (load(ROUTE_HINT_SCENE) as PackedScene).instantiate()
	var door_hint := (load(DOOR_HINT_SCENE) as PackedScene).instantiate()
	root.add_child(route_hint)
	root.add_child(door_hint)
	await process_frame

	_check(route_hint.get("tile_footprint") == Vector2i(4, 2), "route hints default to a 4x2 tile footprint")
	_check(route_hint.call("get_footprint_size") == Vector2(128, 64), "route footprint converts tiles to world size")
	_check(route_hint.call("get_flow_vector") == Vector2.UP, "route hints expose an upward default flow")
	route_hint.set("tile_footprint", Vector2i(6, 2))
	_check(route_hint.call("get_footprint_size") == Vector2(192, 64), "route footprints scale without pixel dimensions")
	route_hint.set("flow_direction", "right")
	_check(route_hint.call("get_flow_vector") == Vector2.RIGHT, "route hint arrows can flow right")
	_check(door_hint.get("tile_footprint") == Vector2i.ONE, "door hints default to one tile")
	_check(door_hint.call("get_footprint_size") == Vector2(32, 32), "door footprint converts to one world tile")
	door_hint.set("flow_direction", "down")
	_check(door_hint.call("get_flow_vector") == Vector2.DOWN, "door hint arrows have a configurable direction")
	await process_frame

	var route_source := FileAccess.get_file_as_string(ROUTE_HINT_SCRIPT)
	var door_source := FileAccess.get_file_as_string(DOOR_HINT_SCRIPT)
	_check(route_source.contains("draw_polyline") and route_source.contains("radius * 2.6"), "route hints use bright directional chevrons and particle halos")
	_check(door_source.contains("draw_polyline") and door_source.contains("radius * 2.8") and door_source.contains("draw_arc"), "door hints use bright directional chevrons, open arcs, and particle halos")
	_check(not route_source.contains("draw_rect(") and not door_source.contains("draw_rect("), "transition hints blend into the world without hard rectangular frames")
	_check(not route_source.contains("@export_range(16.0, 512.0") and not door_source.contains("@export_range(8.0, 256.0"), "transition hint sizing no longer exposes pixel width fields")

	for scene_path: String in MAP_SCENES:
		_check_scene_uses_tile_footprints(scene_path)

	route_hint.queue_free()
	door_hint.queue_free()
	quit(1 if failed else 0)


func _check_scene_uses_tile_footprints(scene_path: String) -> void:
	var source := FileAccess.get_file_as_string(scene_path)
	for hint_name: String in ["RouteTransitionHint", "DoorTransitionHint"]:
		var search_from := 0
		while true:
			var marker := '[node name="%s"' % hint_name
			var start := source.find(marker, search_from)
			if start < 0:
				break
			var end := source.find("\n[node ", start + marker.length())
			if end < 0:
				end = source.length()
			var block := source.substr(start, end - start)
			_check(not block.contains("\nwidth =") and not block.contains("\nheight ="), "%s %s avoids pixel dimensions" % [scene_path.get_file(), hint_name])
			search_from = end


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		printerr("FAIL %s" % label)
