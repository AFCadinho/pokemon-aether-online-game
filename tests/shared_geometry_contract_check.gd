extends SceneTree
class Sink extends Logger:
	var tree: SceneTree
	func _log_error(_fn: String, _file: String, _line: int, _code: String, _why: String, _notify: bool, kind: int, _trace: Array[ScriptBacktrace]) -> void:
		if kind != Logger.ERROR_TYPE_WARNING: tree.call_deferred("quit", 2)
var sink := Sink.new()
const Pair = preload("res://scripts/services/model_pair_pack.gd")
func _init() -> void:
	sink.tree = self
	OS.add_logger(sink)
	var source: Dictionary = load("res://data/model_pair_pilot.json").data.assets[0]
	assert(Pair.metadata_error(source).is_empty())
	var candidate := source.duplicate(true)
	candidate.pair_manifest.schema = 2.0 # Trusted manifests originate in JSON.
	var leaf: Dictionary = candidate.pair_manifest.files[-1].duplicate()
	leaf.path = "meshes/" + "0".repeat(64) + ".res"
	candidate.pair_manifest.files.append(leaf)
	assert(Pair.metadata_error(candidate).is_empty())
	var legacy := candidate.duplicate(true)
	legacy.pair_manifest.schema = 1.0
	assert(not Pair.metadata_error(legacy).is_empty(), "Schema 1 must not accept geometry dependencies")
	for schema in [0, 3, 1.5, "2", null]:
		var invalid := candidate.duplicate(true)
		invalid.pair_manifest.schema = schema
		assert(not Pair.metadata_error(invalid).is_empty())
	for name in ["scripts/" + "0".repeat(64) + ".res", "meshes/../../outside.res", "meshes/not-a-hash.res"]:
		var invalid := candidate.duplicate(true)
		invalid.pair_manifest.files[-1].path = name
		assert(not Pair.metadata_error(invalid).is_empty())
	for folder in ["textures", "meshes", "skins", "libraries"]:
		var path: String = folder + "/" + "0".repeat(64) + ".res"
		assert(Pair.dependency_allowed(2, "models/normal.scn", path))
		assert(Pair.dependency_allowed(1, "models/normal.scn", path) == (folder == "textures"))
		assert(not Pair.dependency_allowed(2, path, path))
		assert(not Pair.dependency_allowed(2, path, "textures/" + "0".repeat(64) + ".res"))
	assert(not Pair.dependency_allowed(2, "models/normal.scn", "models/shiny.scn"))
	assert(not Pair.dependency_allowed(3, "models/normal.scn", "textures/a.res"))
	var minimum := Pair.budget(source, "normal")
	candidate.pair_manifest.files[-1].bytes = minimum + 1
	assert(Pair.budget(candidate, "normal") > minimum, "Cache budget includes shared geometry")
	assert(FileAccess.get_file_as_bytes("res://scripts/services/model_pair_pack.gd") == FileAccess.get_file_as_bytes("res://launcher/scripts/model_pair_pack.gd"))
	assert(FileAccess.get_file_as_bytes("res://scripts/services/model_pair_pilot.gd") == FileAccess.get_file_as_bytes("res://launcher/scripts/model_pair_pilot.gd"))
	print("SHARED_GEOMETRY_CONTRACT_OK schema_1_compatibility schema_2_paths flat_graph cache_budget launcher_parity")
	quit()
