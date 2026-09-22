extends SceneTree
## Canonical content comparison excludes resource identifiers, not track data.
func _initialize() -> void:
	_run.call_deferred()

func content(resource: Resource) -> Dictionary:
	var result := {}
	for property in resource.get_property_list():
		var name: String = property.name
		if int(property.usage) & PROPERTY_USAGE_STORAGE and not name.begins_with("resource_"):
			var value: Variant = resource.get(name)
			if value is Resource:
				assert(false,"Unexpected nested resource in animation/skin comparison")
			result[name] = value
	return result

func _run() -> void:
	var fixture := Animation.new()
	fixture.length = 1.0
	var renamed: Animation = fixture.duplicate()
	renamed.resource_name = "different_resource_identifier"
	assert(content(fixture) == content(renamed))
	renamed.length = 2.0
	assert(content(fixture) != content(renamed), "semantic comparison must detect real animation changes")
	var path := OS.get_environment("STORAGE_AUDIT_SHINY_CATALOG")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var entries: Array = raw if raw is Array else raw.entries
	var pairs := {}
	for entry in entries:
		var model_path: String = entry.runtime_path
		if not model_path.is_absolute_path():
			model_path = path.get_base_dir().path_join(model_path)
		if FileAccess.get_sha256(model_path) != entry.runtime_sha256:
			continue
		var scene: PackedScene = ResourceLoader.load(model_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		var node := scene.instantiate()
		var data := {"animations":{},"skins":[],"skeletons":[],"source_sha256":entry.runtime_sha256}
		for player in node.find_children("*","AnimationPlayer",true,false):
			for clip in player.get_animation_list():
				data.animations[clip] = content(player.get_animation(clip))
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			if mesh.skin != null:
				var bindings := content(mesh.skin)
				if bindings not in data.skins:
					data.skins.append(bindings)
		for skeleton in node.find_children("*","Skeleton3D",true,false):
			var bones := {}
			for i in skeleton.get_bone_count():
				bones[str(i)] = [skeleton.get_bone_name(i),skeleton.get_bone_parent(i),skeleton.get_bone_rest(i)]
			data.skeletons.append(bones)
		var species: String = str(entry.species).trim_suffix("@shiny")
		var variant: String = "shiny" if str(entry.species).ends_with("@shiny") else str(entry.get("variant","normal"))
		if not pairs.has(species): pairs[species] = {}
		pairs[species][variant] = data
		node.free()
	var results := []
	for species in pairs:
		var pair: Dictionary = pairs[species]
		if not pair.has("normal") or not pair.has("shiny"): continue
		var clips := []
		for clip in pair.normal.animations:
			var a: Dictionary = pair.normal.animations[clip]
			var b: Dictionary = pair.shiny.animations.get(clip,{})
			var differences := []
			for key in a:
				if not b.has(key) or a[key] != b[key]: differences.append(key)
			clips.append({"clip":clip,"identical":a==b,"different_properties":differences})
		results.append({"species":species,"clips":clips,"skins_identical":pair.normal.skins==pair.shiny.skins,"skeletons_identical":pair.normal.skeletons==pair.shiny.skeletons,
			"source_sha256":{"normal":pair.normal.source_sha256,"shiny":pair.shiny.source_sha256}})
	var file := FileAccess.open(OS.get_environment("STORAGE_VARIANT_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	print("VARIANT_AUDIT ",JSON.stringify(results))
	quit()
