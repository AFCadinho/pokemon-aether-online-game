extends SceneTree

const Assets := preload("res://scripts/battle/battle_ui/rendered_sprite_assets.gd")
const Packs := preload("res://scripts/services/content_pack_runtime.gd")
const LEGACY_POINTER := "res://.pokeaether/rendered-preview-catalog"
const FIXTURE_ROOT := "user://explicit_sprite_preview_check"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var old_preview := OS.get_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG")
	var old_approved := OS.get_environment("POKEAETHER_RENDERED_CATALOG")
	var had_pointer := FileAccess.file_exists(LEGACY_POINTER)
	var old_pointer := FileAccess.get_file_as_bytes(LEGACY_POINTER) if had_pointer else PackedByteArray()
	var had_directory := DirAccess.dir_exists_absolute("res://.pokeaether")
	DirAccess.make_dir_recursive_absolute(FIXTURE_ROOT)
	DirAccess.make_dir_recursive_absolute("res://.pokeaether")
	var manifest_path := FIXTURE_ROOT.path_join("manifest.json")
	var catalog_path := FIXTURE_ROOT.path_join("preview.json")
	_write(manifest_path, JSON.stringify({
		"schema": 1, "species": "meowth", "variant": "normal",
		"status": "needs_review", "cell_size": 512, "fps": 60,
	}))
	_write(catalog_path, JSON.stringify({
		"schema": 1, "mode": "preview", "entries": {"meowth:normal": {
			"path": manifest_path, "sha256": FileAccess.get_sha256(manifest_path),
		}},
	}))
	_write(LEGACY_POINTER, catalog_path)
	OS.set_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG", "")
	OS.set_environment("POKEAETHER_RENDERED_CATALOG", "")
	_check(Assets._preview_catalog_path().is_empty(), "stale local pointer does not enable a review")
	_check(Assets._resolve_asset("meowth", false).is_empty(), "normal Meowth bypasses the old preview catalog")

	# A downloaded sprite already in memory must be selected on the ordinary
	# battle path, even with the legacy review pointer present.
	Packs._loaded = true
	Packs._entries.clear()
	Packs._cache.clear()
	Packs._sprite_collection_styles.clear()
	var service := root.get_node("WebPokemonSpriteService")
	var style: String = root.get_node("SettingsManager").get_active_sprite_style()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	frames.add_frame("idle", texture)
	var identity: Dictionary = service._sprite_identity("meowth", "front", false, style)
	service._cache[identity.cache_key] = {
		"frames": frames, "style": style, "render_scale": 1.0,
		"frame_size": Vector2(64, 64), "visual_bounds": Rect2(0, 0, 64, 64),
	}
	var box: Node = load("res://scripts/battle/battle_ui/sprite_box.gd").new()
	_check(box._load_sprite_frames("Meowth", "front", false) == frames,
		"ordinary 2D battle uses its downloaded sprite cache")
	box.free()

	OS.set_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG", "  " + catalog_path + "  ")
	_check(Assets._preview_catalog_path() == catalog_path, "explicit preview launch still selects its catalog")
	var resolved := Assets._resolve_asset("meowth", false)
	_check(not resolved.is_empty() and bool(resolved.get("preview", false)),
		"explicit sprite review still resolves the requested asset")
	OS.set_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG", "")
	OS.set_environment("POKEAETHER_RENDERED_CATALOG", catalog_path)
	_check(Assets._resolve_asset("meowth", false).is_empty(), "preview data cannot enter the approved catalog path")

	OS.set_environment("POKEAETHER_RENDERED_PREVIEW_CATALOG", old_preview)
	OS.set_environment("POKEAETHER_RENDERED_CATALOG", old_approved)
	if had_pointer:
		var file := FileAccess.open(LEGACY_POINTER, FileAccess.WRITE)
		file.store_buffer(old_pointer)
		file.close()
	else:
		DirAccess.remove_absolute(LEGACY_POINTER)
	if not had_directory:
		DirAccess.remove_absolute("res://.pokeaether")
	DirAccess.remove_absolute(manifest_path)
	DirAccess.remove_absolute(catalog_path)
	DirAccess.remove_absolute(FIXTURE_ROOT)
	if failures == 0:
		print("explicit_sprite_preview_check: PASS")
	quit(1 if failures else 0)


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
