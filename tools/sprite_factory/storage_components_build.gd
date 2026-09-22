extends SceneTree
const Components = preload("res://tools/sprite_factory/storage_components.gd")
const Reviewed = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const SPECIES := ["articuno", "dragonite", "lucario", "pikachu", "roaring-moon", "snorlax"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := OS.get_environment("STORAGE_COMPONENT_SOURCE")
	var output := OS.get_environment("STORAGE_COMPONENT_OUTPUT")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output), "Fresh output required")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var store := Components.new()
	store.directory = output
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	var entries: Array = raw if raw is Array else raw.entries
	var result := []
	var species_base := {}
	var species_content := {}
	for entry in entries:
		var species: String = str(entry.species).trim_suffix("@shiny")
		if species not in SPECIES:
			continue
		var identity := Reviewed.entry_key(entry)
		var path: String = entry.runtime_path
		if not path.is_absolute_path():
			path = source.get_base_dir().path_join(path)
		assert(FileAccess.get_sha256(path) == entry.runtime_sha256)
		assert(not Reviewed.resolve(identity, entry.runtime_sha256).is_empty(), "Unapproved source")
		var original: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var node := original.instantiate()
		var before := Components.actor_content(node)
		store.used = {}
		var appearance := Resource.new()
		appearance.set_meta("appearance", store.prepare(node))
		var stripped := Components.actor_content(node)
		if species_content.has(species) and species_content[species] != stripped:
			for node_path in stripped:
				var fields: Dictionary = stripped[node_path][1]
				var old_fields: Dictionary = species_content[species].get(node_path, ["", {}])[1]
				for field in fields:
					if fields[field] != old_fields.get(field):
						print("STRUCTURE_DIFFERENCE ", node_path, " ", field, " ", str(fields[field]).left(150), " vs ", str(old_fields.get(field)).left(150))
		if species_content.has(species):
			assert(species_content[species] == stripped, "Variant scene semantics differ")
		species_content[species] = stripped
		var packed := PackedScene.new()
		assert(packed.pack(node) == OK)
		# PackedScene internal variant-table ordering is not a semantic identity.
		# Reuse only after all normalized node properties compare exactly.
		var shared: PackedScene = store.resources[species_base[species]] if species_base.has(species) else store.external(packed)
		var base_id := shared.resource_path.get_file().get_basename()
		species_base[species] = base_id
		store.mark(base_id)
		var variant := store.external(appearance)
		var restored := Components.instantiate(shared, variant)
		assert(before == Components.actor_content(restored), "Actor semantics changed: " + identity)
		restored.free()
		node.free()
		result.append({"identity": identity, "species": species, "source_path": path,
			"source_sha256": entry.runtime_sha256, "old_bytes": FileAccess.get_file_as_bytes(path).size(),
			"shared": base_id, "appearance": variant.resource_path.get_file().get_basename(),
			"components": store.used.keys()})
		assert(FileAccess.get_sha256(path) == entry.runtime_sha256)
		print("COMPONENT_BUILD ", identity, " unique_resources=", store.records.size())
		await process_frame
	assert(result.size() == 12, "Expected six complete approved pairs")
	var manifest := {"schema": 1, "prototype_only": true, "godot": Engine.get_version_info().string,
		"source_catalog_sha256": FileAccess.get_sha256(source), "entries": result, "components": store.records}
	var file := FileAccess.open(output.path_join("prototype.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("COMPONENT_BUILD_OK ", result.size())
	quit()
