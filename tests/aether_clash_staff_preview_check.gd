extends SceneTree

const PREVIEWS := {
	"res://scenes/overworld/aether_clash/aether_clash_battle_royale_preview.tscn": {
		"map_id": "aether_clash_battle_royale_preview",
		"source_suffix": "/Clan Wars Map.tmx",
	},
	"res://scenes/overworld/aether_clash/aether_clash_duel_preview.tscn": {
		"map_id": "aether_clash_duel_preview",
		"source_suffix": "/Clan Wars Map x1 Jail.tmx",
		"requires_collision": true,
		"jail_spawn": Vector2(2192, 2320),
	},
	"res://scenes/overworld/aether_clash/waiting_area_preview.tscn": {
		"map_id": "aether_clash_waiting_area_preview",
		"source_suffix": "/Waiting Area.tmx",
		"requires_collision": false,
	},
}

const EXPECTED_VISUAL_LAYERS := ["Ground", "Grass", "GroundDetail", "Objects", "ObjectsTop"]

var failed := false


func _init() -> void:
	for scene_path: String in PREVIEWS:
		_check_preview(scene_path, PREVIEWS[scene_path] as Dictionary)
	quit(1 if failed else 0)


func _check_preview(scene_path: String, expected: Dictionary) -> void:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	if packed == null:
		return
	var preview := packed.instantiate()
	root.add_child(preview)
	_check(
		preview.call("get_map_id") == str(expected.get("map_id", "")),
		"%s has an isolated preview map id" % scene_path.get_file()
	)
	var preview_map := preview.get_node_or_null("PreviewMap")
	var visual := preview_map.get_child(0) if preview_map != null and preview_map.get_child_count() > 0 else null
	_check(
		visual != null
		and str(visual.get_meta("tiled_source_path", "")).ends_with(
			str(expected.get("source_suffix", ""))
		),
		"%s uses the intended Aether Clash visual" % scene_path.get_file()
	)
	var layer_names: Array[String] = []
	if visual != null:
		for child: Node in visual.get_children():
			layer_names.append(str(child.name))
	layer_names.sort()
	var expected_layer_names := EXPECTED_VISUAL_LAYERS.duplicate()
	expected_layer_names.sort()
	_check(
		layer_names == expected_layer_names,
		"%s uses the updated visual layer names" % scene_path.get_file()
	)
	var objects_top: TileMapLayer = null
	if visual != null:
		objects_top = visual.get_node_or_null("ObjectsTop") as TileMapLayer
	_check(
		objects_top != null and objects_top.z_index >= 2048,
		"%s renders ObjectsTop as a foreground depth layer" % scene_path.get_file()
	)
	var spawn := preview.get_node_or_null("Spawns/PreviewSpawn") as Marker2D
	var collision := preview.find_child("Collision", true, false) as TileMapLayer
	var spawn_tile := Vector2i(
		floori(spawn.position.x / 32.0),
		floori(spawn.position.y / 32.0)
	) if spawn != null else Vector2i(-1, -1)
	_check(
		spawn != null
		and (
			not bool(expected.get("requires_collision", true))
			or (collision != null and collision.get_cell_source_id(spawn_tile) == -1)
		),
		"%s has a walkable staff preview spawn" % scene_path.get_file()
	)
	if expected.has("jail_spawn"):
		var jail_position := expected.get("jail_spawn", Vector2.ZERO) as Vector2
		var preview_jail_spawn := preview.get_node_or_null("Spawns/JailSpawn") as Marker2D
		var match_jail_spawn := preview.get_node_or_null("PreviewMap/Spawns/JailSpawn") as Marker2D
		var jail_tile := Vector2i(
			floori(jail_position.x / 32.0),
			floori(jail_position.y / 32.0)
		)
		_check(
			preview_jail_spawn != null
			and preview_jail_spawn.position == jail_position
			and match_jail_spawn != null
			and match_jail_spawn.position == jail_position,
			"%s exposes the jail spawn to matches and staff previews" % scene_path.get_file()
		)
		_check(
			collision != null and collision.get_cell_source_id(jail_tile) == -1,
			"%s places its jail spawn on a walkable tile" % scene_path.get_file()
		)
	preview.queue_free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
