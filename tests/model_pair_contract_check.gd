extends SceneTree
const Contract = preload("res://tools/sprite_factory/model_pair_bundle_contract.gd")
var directory := "user://model-pair-contract-fixture"

func write_manifest(manifest: Dictionary) -> void:
	var file := FileAccess.open(directory.path_join("bundle.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	# Match the fixture protocol: both trusted pins and installed manifests
	# are parsed JSON (Godot represents their JSON numbers as floats).
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(manifest))
	manifest.clear()
	manifest.merge(normalized)

func scene(extra: Resource = null) -> PackedScene:
	var node := Node3D.new()
	if extra != null:
		node.set_meta("fixture_dependency", extra)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	node.free()
	return packed

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(directory.path_join("models"))
	var original := {"schema": 1, "kind": "pokeaether-model-pair-experiment", "prototype_only": true,
		"species": "fixture", "variant": "baseline", "models": [{"path": "models/normal.scn"}, {"path": "models/shiny.scn"}], "files": []}
	for variant in ["normal", "shiny"]:
		var name: String = "models/" + variant + ".scn"
		var path := directory.path_join(name)
		assert(ResourceSaver.save(scene(), path, ResourceSaver.FLAG_COMPRESS) == OK)
		original.files.append({"path": name, "bytes": FileAccess.get_file_as_bytes(path).size(), "sha256": FileAccess.get_sha256(path)})
	write_manifest(original)
	assert(Contract.validate(directory, original).is_empty())
	var invalid: Dictionary = original.duplicate(true)
	invalid.files[0].path = "../outside.scn"
	write_manifest(invalid)
	assert(Contract.validate(directory, invalid) == "Invalid/duplicate file path")
	invalid = original.duplicate(true)
	invalid.files.append(invalid.files[0].duplicate())
	write_manifest(invalid)
	assert(Contract.validate(directory, invalid) == "Invalid/duplicate file path")
	invalid = original.duplicate(true)
	invalid.files.append({"path": "textures/" + "0".repeat(64) + ".res", "bytes": 123, "sha256": "0".repeat(64)})
	write_manifest(invalid)
	assert(Contract.validate(directory, invalid).begins_with("File hash/size mismatch"))
	write_manifest(original)
	var path := directory.path_join("models/normal.scn")
	var bytes := FileAccess.get_file_as_bytes(path)
	var corrupted := bytes.duplicate()
	corrupted[-1] = (corrupted[-1] + 1) % 256
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(corrupted)
	file.close()
	assert(Contract.validate(directory, original).begins_with("File hash/size mismatch"))
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	assert(Contract.validate(directory, original).is_empty())
	invalid = original.duplicate(true)
	invalid.species = "changed"
	assert(Contract.validate(directory, invalid) == "Manifest differs from trusted fixture")
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	var external := ImageTexture.create_from_image(image)
	external.resource_path = "user://outside-model-pair-contract.res"
	assert(ResourceSaver.save(scene(external), path, ResourceSaver.FLAG_COMPRESS) == OK)
	invalid = original.duplicate(true)
	invalid.files[0].bytes = FileAccess.get_file_as_bytes(path).size()
	invalid.files[0].sha256 = FileAccess.get_sha256(path)
	write_manifest(invalid)
	assert(Contract.validate(directory, invalid).begins_with("Dependency escaped bundle"))
	print("MODEL_PAIR_CONTRACT_CHECK_OK traversal/duplicate/missing/corruption/manifest/dependency")
	quit()
