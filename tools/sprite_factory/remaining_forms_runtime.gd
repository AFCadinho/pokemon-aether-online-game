extends "alternate_forms_runtime.gd"
const LayeredPack = preload("remaining_forms_layered_pack.gd")

func _convert(entry: Dictionary, output: String) -> Dictionary:
	var prepared := super._convert(entry, output)
	if prepared.is_empty() or not entry.has("independent_layer_sampling"): return prepared
	var scene := ResourceLoader.load(prepared.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var actor := scene.instantiate()
	var changed := LayeredPack.apply(actor, entry.independent_layer_sampling)
	var packed := PackedScene.new()
	assert(packed.pack(actor) == OK)
	assert(ResourceSaver.save(packed,prepared.runtime_path,ResourceSaver.FLAG_COMPRESS)==OK)
	actor.free()
	prepared.runtime_sha256=FileAccess.get_sha256(prepared.runtime_path)
	prepared["independent_layer_materials"]=changed
	return prepared
