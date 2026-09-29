extends RefCounted
## Only removes known optional battle assets under roots supplied by the launcher.

const LEGACY_SPRITE_FOLDERS: Array[String] = [
	"assets/sprites/pokemon/front",
	"assets/sprites/pokemon/back",
	"assets/sprites/pokemon/shiny_front",
	"assets/sprites/pokemon/shiny_back",
	"assets/sprites/pokemon/gen5/front",
	"assets/sprites/pokemon/gen5/back",
	"assets/sprites/pokemon/gen5/shiny_front",
	"assets/sprites/pokemon/gen5/shiny_back",
]


static func legacy_sprite_bytes() -> int:
	var root := _launcher_root("POKEAETHER_INSTALL_DIR")
	var total := 0
	for folder in LEGACY_SPRITE_FOLDERS:
		total += directory_bytes(root.path_join(folder)) if not root.is_empty() else 0
	return total


static func clear_legacy_sprites() -> bool:
	var root := _launcher_root("POKEAETHER_INSTALL_DIR")
	if root.is_empty():
		return true
	for folder in LEGACY_SPRITE_FOLDERS:
		if _has_link_in_relative_path(root, folder):
			return false
		if not remove_directory(root.path_join(folder)):
			return false
	return true


static func legacy_model_bytes() -> int:
	var root := _launcher_root("POKEAETHER_LAUNCHER_MODEL_DIR")
	return directory_bytes(root) if not root.is_empty() else 0


static func clear_legacy_models() -> bool:
	var root := _launcher_root("POKEAETHER_LAUNCHER_MODEL_DIR")
	return root.is_empty() or remove_directory(root)


static func _launcher_root(key: String) -> String:
	var path := OS.get_environment(key).strip_edges()
	if not path.is_absolute_path() or not DirAccess.dir_exists_absolute(path):
		return ""
	if key == "POKEAETHER_LAUNCHER_MODEL_DIR" and path.get_file() != "asset-bundles-v1":
		return ""
	var parent := DirAccess.open(path.get_base_dir())
	if parent == null or parent.is_link(path.get_file()):
		return ""
	return path.trim_suffix("/")


static func _has_link_in_relative_path(root: String, relative: String) -> bool:
	var current := root
	for part in relative.split("/"):
		var directory := DirAccess.open(current)
		if directory == null:
			return false
		if directory.is_link(part):
			return true
		current = current.path_join(part)
	return false


static func directory_bytes(path: String) -> int:
	var directory := DirAccess.open(path)
	if directory == null:
		return 0
	var total := 0
	for name in directory.get_files():
		if directory.is_link(name):
			continue
		var file := FileAccess.open(path.path_join(name), FileAccess.READ)
		if file != null:
			total += file.get_length()
	for name in directory.get_directories():
		if not directory.is_link(name):
			total += directory_bytes(path.path_join(name))
	return total


static func remove_directory(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return true
	for name in directory.get_files():
		if directory.is_link(name) or DirAccess.remove_absolute(path.path_join(name)) != OK:
			return false
	for name in directory.get_directories():
		if directory.is_link(name) or not remove_directory(path.path_join(name)):
			return false
	return DirAccess.remove_absolute(path) == OK
