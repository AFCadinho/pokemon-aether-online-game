extends SceneTree
const Store := preload("res://launcher/scripts/content_pack_store.gd")
const Runtime := preload("res://scripts/services/content_pack_runtime.gd")
const Followers := preload("res://scripts/services/follower_sprite_service.gd")
var failed := false
var test_root := "user://content-pack-check-" + str(Time.get_ticks_usec())

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func manifest(pack_id: String) -> Dictionary:
	return {"format_version": 1, "id": pack_id, "name": "Test", "version": "1", "author": "Test",
		"assets": {"battle_sprites": {"pikachu:front:normal": {"file": "sheet.png", "columns": 2, "frames": 2, "fps": 12}},
		"followers": {"pikachu:normal": {"file": "follower.png"}},
		"sprite_collections": {"gen5": {"directory": "sprites", "style": "gen5"}},
		"cries": {"pikachu": {"file": "cry.ogg"}}}}

func archive(path: String, data: Dictionary, assets: Dictionary) -> void:
	var writer := ZIPPacker.new()
	check(writer.open(path) == OK, "create fixture zip")
	writer.start_file("mod.json")
	writer.write_file(JSON.stringify(data).to_utf8_buffer())
	writer.close_file()
	for name: String in assets:
		writer.start_file(name)
		writer.write_file(assets[name])
		writer.close_file()
	writer.close()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(test_root)
	var store := Store.new(test_root.path_join("mods"))
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var cry_bytes := FileAccess.get_file_as_bytes("res://assets/audio/sfx/pokemon_cries/PIKACHU.ogg")
	check(not cry_bytes.is_empty(), "cry fixture exists")
	var assets := {"sheet.png": img.save_png_to_buffer(), "follower.png": img.save_png_to_buffer(), "cry.ogg": cry_bytes,
		"sprites/gen5/front/pikachu/sheet.png": img.save_png_to_buffer(),
		"sprites/gen5/front/pikachu/animation.json": "{\"frame_width\": 4, \"frame_height\": 4, \"frames\": []}".to_utf8_buffer(),
		"ignored.gd": "extends Node".to_utf8_buffer()}
	var path := test_root.path_join("valid.zip")
	archive(path, manifest("valid"), assets)
	check(store.import_zip(path).is_empty(), "valid zip imports")
	check(store.installed().size() == 1, "installed pack discovered")
	check(not FileAccess.file_exists(store.root.path_join("valid/ignored.gd")), "scripts are not extracted")
	check(not store.import_zip(path).is_empty(), "existing pack is not overwritten")
	var update := manifest("valid")
	update.version = "2"
	archive(path, update, assets)
	check(store.import_zip(path, true).is_empty(), "official pack update atomically replaces an installed pack")
	check(str(store.installed()[0].version) == "2", "updated manifest becomes active")
	check(store.enabled_ids().is_empty(), "import does not implicitly enable")
	check(store.save_enabled(["valid"]) == OK, "enable pack")
	check(store.save_enabled(["valid"]) == OK, "selection can be replaced")
	check(store.candidates("cries", "pikachu").size() == 1, "enabled asset resolves")
	check(store.sprite_collection_directories().size() == 1, "enabled Gen 5 collection resolves")
	check(FileAccess.file_exists(store.root.path_join("valid/sprites/gen5/front/pikachu/animation.json")), "declared sprite collection is extracted")

	var broken := manifest("broken")
	assets["sheet.png"] = "bad image".to_utf8_buffer()
	assets["cry.ogg"] = PackedByteArray([0, 1, 2])
	archive(path, broken, assets)
	check(store.import_zip(path).is_empty(), "data-only import permits runtime decoding checks")
	check(store.save_enabled(["broken", "valid"]) == OK, "priorities saved")
	Runtime._loaded = false
	Runtime._entries.clear()
	Runtime._cache.clear()
	Runtime._pokemon_sprite_roots.clear()
	Runtime._sprite_collection_styles.clear()
	OS.set_environment("POKEAETHER_MODS_DIR", store.root)
	var frames := Runtime.battle_frames("Pikachu", "front", false)
	check(frames != null and frames.get_frame_count("idle") == 2, "broken higher priority sprite falls back to next pack")
	if frames != null:
		check(frames.get_animation_speed("idle") == 12, "sprite animation timing loaded")
		check(frames.get_frame_texture("idle", 1).get_width() == 4, "sprite grid sliced")
	check(Runtime.has_sprite_collection_style("gen5"), "enabled Gen 5 pack selects its sprite style")
	var sprite_scene := load("res://scenes/battle/sprite_box.tscn") as PackedScene
	check(sprite_scene != null, "battle sprite scene compiles")
	if sprite_scene != null:
		var box := sprite_scene.instantiate()
		check(box._get_sprite_asset_roots("front", false)[0] == "gen5/front", "battle widget prioritizes enabled Gen 5 collections")
		check(box._load_sprite_frames("Pikachu", "front", false) == frames, "battle widget uses pack frames")
		check(box._load_sprite_frames("pikachu", "back", false, false) != null, "battle widget retains standard back sprite fallback")
		box.free()
	check(Runtime.battle_frames("Pikachu", "back", false) == null, "missing back preserves game fallback")
	check(Runtime.battle_frames("Pikachu", "front", true) == null, "normal pack does not replace shiny")
	check(Runtime.battle_frames("Pikachu-Alola", "front", false) == null, "form identity stays distinct")
	check(Runtime.cry("Pikachu") != null, "external Ogg loaded with corrupt priority fallback")
	check(Runtime.cry("Pikachu-Mega") != null, "cry pack falls back through the base cry key")
	check(Runtime.cry("missing") == null, "missing cry preserves game fallback")
	check(Runtime.get_pokemon_sprite_roots().size() == 2, "both enabled collection roots load in priority order")
	check(Followers.get_sprite_frames("Pikachu", false) != null, "follower service consumes pack texture")
	check(store.save_enabled([]) == OK, "disable all")
	check(Runtime.battle_frames("Pikachu", "front", false) == frames, "selection frozen during game session")
	Runtime._loaded = false
	Runtime._entries.clear()
	Runtime._cache.clear()
	Runtime._pokemon_sprite_roots.clear()
	Runtime._sprite_collection_styles.clear()
	check(Runtime.battle_frames("Pikachu", "front", false) == null, "next session respects disabled pack")

	var unsafe := manifest("unsafe")
	unsafe.assets.cries.pikachu.file = "../outside.ogg"
	archive(path, unsafe, assets)
	check(not store.import_zip(path).is_empty(), "traversal rejected")
	check(not DirAccess.dir_exists_absolute(store.root.path_join("unsafe")), "failed import leaves no installed pack")
	unsafe = manifest("unsafe")
	unsafe.format_version = 999
	check(not Store.validate(unsafe).is_empty(), "unknown format rejected")
	unsafe = manifest("unsafe")
	unsafe.assets.battle_sprites["pikachu:front:normal"].frames = 999
	check(not Store.validate(unsafe).is_empty(), "invalid frame count rejected")
	assets["../outside.png"] = img.save_png_to_buffer()
	archive(path, manifest("unsafe"), assets)
	check(not store.import_zip(path).is_empty(), "unsafe undeclared zip entry rejected before extraction")
	# Declared uncompressed size is checked before decompression.
	assets.erase("../outside.png")
	archive(path, manifest("oversized"), assets)
	var zip_data := FileAccess.get_file_as_bytes(path)
	for index in range(zip_data.size() - 46):
		if zip_data.decode_u32(index) == 0x02014b50:
			zip_data.encode_u32(index + 24, Store.MAX_FILE_BYTES + 1)
			break
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(zip_data)
	file.close()
	check(not store.import_zip(path).is_empty(), "oversized declared decompression rejected")
	OS.unset_environment("POKEAETHER_MODS_DIR")
	remove_tree(ProjectSettings.globalize_path(test_root))
	print("Content pack checks: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories():
		remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
