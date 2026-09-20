extends SceneTree
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")
func _init() -> void:
	assert(Arenas.validate("bogus")=="classic")
	for id in Arenas.IDS:
		assert(Arenas.validate(id)==id)
		assert(Arenas.camera_home(id).y>0)
	assert(Arenas.spawn(0)!=Arenas.spawn(1))
	assert(not Arenas.prepare_forest("").is_empty())
	assert(not ClassDB.class_exists("Terrain3D"),"Ordinary client startup must not load the native forest addon")
	print("BATTLE_ARENA_CONTRACT_OK")
	quit()
