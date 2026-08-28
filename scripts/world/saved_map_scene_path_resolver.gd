extends RefCounted

const LEGACY_MAP_SCENE_PATHS := {
	"res://scenes/overworld/kanto/routes/kanto_route_2.tscn":
		"res://scenes/overworld/kanto/routes/route2/kanto_route_2.tscn",
	"res://scenes/overworld/kanto/routes/route_2_house.tscn":
		"res://scenes/overworld/kanto/routes/route2/route_2_house.tscn",
	"res://scenes/overworld/kanto/routes/kanto_route_25.tscn":
		"res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn",
	"res://scenes/overworld/kanto/routes/bills_house.tscn":
		"res://scenes/overworld/kanto/routes/route25/bills_house.tscn",
}


static func resolve(scene_path: String) -> String:
	var normalized_path := scene_path.strip_edges()
	return str(LEGACY_MAP_SCENE_PATHS.get(normalized_path, normalized_path))
