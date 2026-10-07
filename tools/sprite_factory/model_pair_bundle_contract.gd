extends RefCounted
## Diagnostic contract. Production v11 remains self-contained and unchanged.
static func validate(directory: String, expected: Dictionary) -> String:
	if expected.get("kind") != "pokeaether-model-pair-experiment" or not expected.get("prototype_only", false):
		return "Not an experiment bundle"
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("bundle.json")))
	if not manifest is Dictionary or manifest != expected:
		return "Manifest differs from trusted fixture"
	var allowed := {}
	var total := 0
	var name_pattern := RegEx.create_from_string("^(models/(normal|shiny)\\.scn|textures/[0-9a-f]{64}\\.res)$")
	for row: Dictionary in expected.files:
		var name := str(row.get("path", ""))
		if name_pattern.search(name) == null or allowed.has(name):
			return "Invalid/duplicate file path"
		var path := directory.path_join(name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != int(row.bytes) or FileAccess.get_sha256(path) != row.sha256:
			return "File hash/size mismatch: " + name
		total += int(row.bytes)
		allowed[name] = true
	if total > 134217728 or expected.models.size() != 2:
		return "Experiment limit exceeded"
	var referenced := {}
	var base := ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/") + "/"
	for name: String in allowed:
		var path := directory.path_join(name)
		for dependency: String in ResourceLoader.get_dependencies(ProjectSettings.localize_path(path)):
			var target := dependency.get_slice("::", 2) if dependency.contains("::") else dependency
			if not target.is_absolute_path():
				target = path.get_base_dir().path_join(target)
			var absolute := ProjectSettings.globalize_path(target).simplify_path()
			if not absolute.begins_with(base):
				return "Dependency escaped bundle: " + dependency
			var relative := absolute.trim_prefix(base)
			if not relative.begins_with("textures/") or not allowed.has(relative) or not name.begins_with("models/"):
				return "Unexpected dependency"
			referenced[relative] = true
	if expected.variant == "shared":
		for name: String in allowed:
			if name.begins_with("textures/") and not referenced.has(name):
				return "Unreferenced dependency file"
	elif expected.variant != "baseline" or not referenced.is_empty():
		return "Invalid baseline"
	return ""

static func textures(value: Variant, seen: Dictionary = {}, result: Dictionary = {}) -> Dictionary:
	if value is Resource:
		var id: int = value.get_instance_id()
		if seen.has(id):
			return result
		seen[id] = true
		if value is Texture2D:
			result[id] = value
			return result
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				textures(value.get(property.name), seen, result)
	elif value is Array:
		for item in value:
			textures(item, seen, result)
	elif value is Dictionary:
		for item in value.values():
			textures(item, seen, result)
	return result
