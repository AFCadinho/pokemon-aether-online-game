extends SceneTree

const MAX_WEB_TEXTURE_SIZE := 4096
const MAX_WEB_VISUAL_TEXTURE_BYTES := 8 * 1024 * 1024
const WEB_VISUAL_DIRECTORIES := [
	"res://generated/tiled_visuals/pallet_town",
	"res://generated/tiled_visuals/route_1",
	"res://generated/tiled_visuals/viridian_city",
	"res://generated/tiled_visuals/players_house",
	"res://generated/tiled_visuals/rivals_house",
	"res://generated/tiled_visuals/pokemon_laboratory",
	"res://generated/tiled_visuals/pokemon_school",
	"res://generated/tiled_visuals/viridian_house_template",
	"res://generated/tiled_visuals/pokemon_center",
]
const WEB_MAP_MARKERS := {
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": ["FromPlayersHouse", "FromRoute1"],
	"res://scenes/overworld/kanto/routes/kanto_route_1.tscn": ["FromPalletTown", "FromViridianCity"],
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": ["FromRoute1", "FromPokecenter"],
	"res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn": ["FromPalletTown"],
	"res://scenes/overworld/kanto/towns/pallet_town/rivals_house.tscn": ["FromPalletTown"],
	"res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn": ["FromPalletTown"],
	"res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn": ["FromOutside"],
	"res://scenes/overworld/kanto/towns/viridian_city/trainer_school.tscn": ["FromViridianCity"],
	"res://scenes/overworld/kanto/towns/viridian_city/house1.tscn": ["FromViridianCity"],
}


func _initialize() -> void:
	var failures: Array[String] = []
	var texture_bytes := 0
	for directory: String in WEB_VISUAL_DIRECTORIES:
		texture_bytes += _check_directory(directory, failures)
	if texture_bytes > MAX_WEB_VISUAL_TEXTURE_BYTES:
		failures.append("Browser demo textures exceed the 8 MiB source budget: %.1f MiB" % (float(texture_bytes) / 1048576.0))
	for scene_path: String in WEB_MAP_MARKERS:
		_check_map_scene(scene_path, WEB_MAP_MARKERS[scene_path], failures)
	if failures.is_empty():
		print("web_map_texture_limits_check: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _check_directory(directory: String, failures: Array[String]) -> int:
	var texture_bytes := 0
	for file_name: String in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".texture.res"):
			continue
		var path := directory.path_join(file_name)
		texture_bytes += FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(path)).size()
		var texture := load(path) as Texture2D
		if texture == null:
			failures.append("Could not load %s" % path)
			continue
		if not texture is PortableCompressedTexture2D:
			failures.append("Web texture is not stored losslessly compressed: %s" % path)
		elif texture.get_compression_mode() != PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS:
			failures.append("Web texture does not use lossless compression: %s" % path)
		if texture.get_width() > MAX_WEB_TEXTURE_SIZE or texture.get_height() > MAX_WEB_TEXTURE_SIZE:
			failures.append("Web texture exceeds %dpx: %s (%dx%d)" % [
				MAX_WEB_TEXTURE_SIZE, path, texture.get_width(), texture.get_height(),
			])
	for child_directory: String in DirAccess.get_directories_at(directory):
		texture_bytes += _check_directory(directory.path_join(child_directory), failures)
	return texture_bytes


func _check_map_scene(scene_path: String, marker_names: Array, failures: Array[String]) -> void:
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		failures.append("Could not load browser demo map %s" % scene_path)
		return
	var map_instance := packed_scene.instantiate()
	for marker_name: String in marker_names:
		if map_instance.find_child(marker_name, true, false) == null:
			failures.append("Browser demo map %s misses marker %s" % [scene_path, marker_name])
	map_instance.free()
