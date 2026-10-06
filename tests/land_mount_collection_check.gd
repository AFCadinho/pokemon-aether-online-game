extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
const IDS := ["giratina_origin", "ho_oh", "yveltal", "miraidon", "reshiram"]
const DIRECTIONS := ["down", "left", "right", "up"]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for id: String in IDS:
		var item := id.replace("_", "-") + "-mount"
		_check(Mounts.get_mount_id_for_unlock_item(item) == id, id + " item resolves")
		_check(Mounts.get_unlocked_mount_ids_for_mode("land", [item]) == [id], id + " grant unlocks only this mount")
		_check(Mounts.is_mount_unlocked(id, [item + "-bound"]), id + " bound grant works")
		_check(not Mounts.is_mount_unlocked(id, []), id + " requires ownership")
		_check(Mounts.resolve_mount_id_for_mode(id, "surf").is_empty(), id + " cannot enter the Surf slot")
		var icon := Icons.load_icon(item)
		_check(icon != null and icon.get_width() <= 128 and icon.get_height() <= 128, id + " cropped inventory icon loads")
		for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
			var catalog: Dictionary = root.get_node("ItemLocalization").call("get_catalog", locale)
			var localized: Dictionary = catalog.get(item, {})
			_check(not str(localized.get("name", "")).is_empty() and not str(localized.get("shortDesc", "")).is_empty(), id + " localization " + locale)
		var frames := Mounts.get_mount_frames(id)
		var foreground := Mounts.get_mount_foreground_frames(id)
		var mask := Mounts._get_mask_image(id)
		var idle_mask := Mounts._get_mask_image(id, true)
		_check(frames != null and foreground != null and mask != null and idle_mask != null, id + " layers load")
		if frames == null or foreground == null or mask == null or idle_mask == null:
			continue
		_check(mask.get_size() == Vector2i(768, 768) and idle_mask.get_size() == Vector2i(192, 768), id + " walking and standing mask dimensions")
		for row in range(4):
			for moving: bool in [false, true]:
				var animation := StringName(("walk_" if moving else "idle_") + DIRECTIONS[row])
				_check(frames.get_frame_count(animation) == (4 if moving else 1), id + " animation frames")
				if moving:
					_check(frames.get_animation_speed(animation) == 4.0 and foreground.get_animation_speed(animation) == 4.0, id + " layer timing matches")
				for phase in range(frames.get_frame_count(animation)):
					var art := Mounts._get_texture_image(frames.get_frame_texture(animation, phase))
					var front := Mounts._get_texture_image(foreground.get_frame_texture(animation, phase))
					_check(art.get_size() == Vector2i(192,192), id + " original sprite scale in padded frame")
					var selected_mask := mask if moving else idle_mask
					var layers_match := true
					for y in range(192):
						for x in range(192):
							var pixel := front.get_pixel(x,y)
							var hidden := selected_mask.get_pixel(phase*192+x,row*192+y).a > 0
							if hidden != (pixel.a > 0) or (pixel.a > 0 and pixel != art.get_pixel(x,y)):
								layers_match = false
					_check(layers_match, "%s %s %d foreground and rider mask follow the same artwork" % [id,animation,phase])
					if not moving:
						var first := Mounts._get_texture_image(frames.get_frame_texture(StringName("walk_"+DIRECTIONS[row]),0))
						_check(art.get_data() == first.get_data(), id + " idle starts at the reviewed pose")
	print("Land mount collection checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
