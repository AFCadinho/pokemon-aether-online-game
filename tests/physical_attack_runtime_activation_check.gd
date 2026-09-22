extends SceneTree

const Registry = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")

func _init() -> void:
	var catalog_path := OS.get_environment("POKEAETHER_PHYSICAL_ATTACK_CATALOG")
	assert(catalog_path.is_absolute_path())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	assert(parsed is Array and parsed.size() == 75)
	var alternate_count := 0
	for raw: Variant in parsed:
		assert(raw is Dictionary)
		var entry: Dictionary = raw
		var digest := FileAccess.get_sha256(entry.runtime_path)
		assert(digest == entry.runtime_sha256)
		var profile := Registry.resolve(str(entry.species), digest)
		assert(not profile.is_empty())
		var packed := ResourceLoader.load(entry.runtime_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		assert(packed != null)
		var actor := packed.instantiate()
		var player := _animation_player(actor)
		assert(player != null)
		var has_alternate := player.has_animation("physical_attack_2")
		assert(profile.action_timing.has("physical_attack_2") == has_alternate)
		for family: Variant in profile.get("attack_family_actions", {}):
			assert(player.has_animation(str(profile.attack_family_actions[family])))
		if has_alternate:
			alternate_count += 1
		actor.free()
	assert(alternate_count == 74)
	print("PHYSICAL_ATTACK_RUNTIME_ACTIVATION_CHECK_PASS")
	quit()

func _animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _animation_player(child)
		if found != null:
			return found
	return null
