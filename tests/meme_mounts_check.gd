extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
const DIRS := ["down", "left", "right", "up"]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for id: String in ["caterpie", "magikarp", "caterpie_shiny", "magikarp_shiny"]:
		var base_id := id.trim_suffix("_shiny")
		var mode := "land" if base_id == "caterpie" else "surf"
		var item := ("shiny-" if id.ends_with("_shiny") else "") + base_id + "-mount"
		_check(Mounts.get_mount_id_for_unlock_item(item) == id, id + " inventory item resolves")
		_check(Mounts.get_mount_movement_mode(id) == mode, id + " selects the correct movement mode")
		_check(not Mounts.is_mount_unlocked(id, []), id + " needs its grant")
		_check(Mounts.is_mount_unlocked(id, [item]) and Mounts.is_mount_unlocked(id, [item + "-bound"]), id + " normal and bound grants unlock")
		_check(Mounts.resolve_mount_id_for_mode(id, "surf" if mode == "land" else "land").is_empty(), id + " cannot enter the wrong slot")
		var icon := Icons.load_icon(item)
		_check(icon != null and icon.get_width() < 64 and icon.get_height() < 64, id + " cropped icon avoids tiny padded-sheet thumbnails")
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			var catalog: Dictionary = root.get_node("ItemLocalization").call("get_catalog", locale)
			_check(not str(catalog.get(item, {}).get("name", "")).is_empty(), id + " localized in " + locale)
		var reference_id := "cobalion" if mode == "land" else "lapras"
		var reference := Mounts._get_texture_image(Mounts.get_mount_frames(reference_id).get_frame_texture("idle_down", 0))
		var expected_bottom := reference.get_used_rect().end.y - reference.get_height() / 2
		var frames := Mounts.get_mount_frames(id)
		var foreground := Mounts.get_mount_foreground_frames(id)
		if id.ends_with("_shiny"):
			_check(Mounts._get_mask_image(id).get_data() == Mounts._get_mask_image(base_id).get_data(), id + " retains the approved rider mask")
			_check(Mounts._get_mask_image(id, true).get_data() == Mounts._get_mask_image(base_id, true).get_data(), id + " retains the approved idle mask")
		for row in range(4):
			var direction: String = DIRS[row]
			for moving: bool in [false, true]:
				var animation := StringName(("walk_" if moving else "idle_") + direction)
				_check(frames.get_frame_count(animation) == (4 if moving else 1), id + " idle/movement frame count")
				var mask := Mounts._get_mask_image(id, not moving)
				for phase in range(4 if moving else 1):
					var art := Mounts._get_texture_image(frames.get_frame_texture(animation, phase))
					var front := Mounts._get_texture_image(foreground.get_frame_texture(animation, phase))
					var actual_bottom := art.get_used_rect().end.y - art.get_height() / 2
					# Limb/tail motion is not identical to the rider bob. Idle must match
					# the reference exactly; native movement stays within two pixels.
					_check(actual_bottom == expected_bottom if phase == 0 else absf(actual_bottom - expected_bottom) <= 2, "%s %s %d reaches the established ground/waterline" % [id, animation, phase])
					var matching := true
					for y in range(art.get_height()):
						for x in range(art.get_width()):
							var pixel := front.get_pixel(x, y)
							if (pixel.a > 0) != (mask.get_pixel(phase*192+x, row*192+y).a > 0) or (pixel.a > 0 and pixel != art.get_pixel(x, y)):
								matching = false
					_check(matching, id + " foreground and mask follow the same pixels")
	print("Caterpie/Magikarp mount checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
