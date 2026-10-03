extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
var mount_id := "mega_absol_z"
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for id: String in ["mega_absol", "mega_absol_z"]:
		mount_id = id
		await _check_mount()
	print("Unimported mount assets: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check_mount() -> void:
	# user:// is never imported by the editor. Copy bytes, not import metadata or
	# caches, to reproduce a freshly merged mount in an already open checkout.
	var directory := "user://mount-unimported-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var files: Array[String] = []
	var definition := Mounts.get_mount_definition(mount_id)
	var original := definition.duplicate(true)
	var keys := {"iconTexture": "icon.png", "spriteSheet": "mount.png", "foregroundSheet": "foreground.png", "riderMaskSheet": "rider_mask.png"}
	for key: String in keys:
		var path := directory + "/" + str(keys[key])
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(str(definition[key])))
		file.close()
		files.append(path)
		_check(FileAccess.file_exists(path) and not ResourceLoader.exists(path), "fixture is a PNG without an import")
		definition[key] = path
	Mounts._catalog["mounts"][mount_id] = definition
	var frames := Mounts.get_mount_frames(mount_id)
	var foreground := Mounts.get_mount_foreground_frames(mount_id)
	var mask := Mounts._get_mask_image(mount_id)
	var icon := Icons.load_icon(mount_id.replace("_", "-") + "-mount")
	_check(icon != null and icon.get_size() == Vector2(64, 64), "Bag icon loads before editor import")
	_check(frames != null and foreground != null and mask != null, "all mount layers load before editor import")
	if frames != null and foreground != null and mask != null:
		_check(frames == Mounts.get_mount_frames(mount_id), "loaded animation frames are cached")
		for direction: String in ["down", "left", "right", "up"]:
			var anim := StringName("walk_" + direction)
			_check(frames.get_frame_count(anim) == 4 and foreground.get_frame_count(anim) == 4, "unimported sheets produce all animation frames")
			var image := Mounts._get_texture_image(frames.get_frame_texture(anim, 0))
			_check(image.get_size() == Vector2i(128, 128) and image.get_used_rect().has_area(), "unimported creature is visible")
		var avatar: Node2D = load("res://scripts/ui/mount_rider_preview.gd").new()
		root.add_child(avatar)
		avatar.call("configure", mount_id, {"gender": "female"}, "down", false)
		_check(avatar.get_node("Look/MountSprite").visible, "actual avatar displays the unimported mount")
		_check(avatar.get_node("Look/MountForegroundSprite").visible, "actual avatar displays the foreground")
		avatar.queue_free()
		await process_frame
	Mounts._catalog["mounts"][mount_id] = original
	for path: String in files:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
