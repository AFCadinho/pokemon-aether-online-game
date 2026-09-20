extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
func _init() -> void:
	assert(Arenas.validate("bogus")=="classic")
	assert(Arenas.validate_selection("bogus")=="auto")
	for pair in [["grass","forest"],["water","sea"],["cave","cave"],["pvp_stadium","stadium"],["unknown","forest"]]:
		assert(Arenas.resolve("auto",StringName(pair[0]))==pair[1])
		assert(Arenas.resolve("cave",StringName(pair[0]))=="cave")
	var resolver = preload("res://scripts/battle/battle_environment_resolver.gd")
	for context in [{"battle_kind":"pvp"},{"battle_kind":"wild","map_id":"aether_clash_lobby"},{"battle_kind":"trainer","explicit_environment_id":"pvp_stadium"}]:
		assert(Arenas.resolve("auto",resolver.resolve(context))=="stadium")
	for id in Arenas.IDS:
		assert(Arenas.validate(id)==id)
		assert(Arenas.camera_home(id).y>0)
	assert(Arenas.spawn(0)!=Arenas.spawn(1))
	assert(not Arenas.prepare_forest("").is_empty())
	assert(not ClassDB.class_exists("Terrain3D"),"Ordinary client startup must not load the native forest addon")
	print("BATTLE_ARENA_CONTRACT_OK")
	quit()
