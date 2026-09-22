extends SceneTree
const Catalog = preload("res://scripts/battle/arenas/arena_catalog.gd")
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	assert(not ClassDB.class_exists("Terrain3D"))
	assert(not Catalog.prepare_forest("").is_empty())
	var fixture := "user://forest_art_pack_fixture.json"
	FileAccess.open(fixture, FileAccess.WRITE).store_string("not json")
	assert(not Catalog.prepare_forest(fixture).is_empty())
	assert(Catalog.Art.mounted_path.is_empty())
	var manifest := OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	assert(not manifest.is_empty())
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	# Native descriptor deliberately absent: art-only distribution is sufficient.
	FileAccess.open(fixture, FileAccess.WRITE).store_string(JSON.stringify({"schema": 1, "pack": source.pack}))
	assert(Catalog.prepare_forest(fixture).is_empty())
	var deadline := Time.get_ticks_msec() + 30000
	var progress := 0.0
	while not Catalog.forest_ready():
		assert(Catalog.forest_error.is_empty() and Time.get_ticks_msec() < deadline)
		var sample: float = Catalog.forest_progress()[1][0]
		assert(sample >= progress)
		progress = sample
		await process_frame
	assert(not ClassDB.class_exists("Terrain3D"))
	var count := Catalog.Art.resources.size()
	assert(count > 10)
	assert(Catalog.prepare_forest(fixture).is_empty())
	assert(Catalog.forest_ready() and Catalog.Art.resources.size() == count)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	print("FOREST_ART_PACK_OK: invalid manifest, descriptor-free load, progress, reuse, no native module")
	quit()
