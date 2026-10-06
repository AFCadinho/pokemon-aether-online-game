extends SceneTree

const Mounts := preload("res://scripts/services/mount_service.gd")
const Icons := preload("res://scripts/services/item_icon_resolver.gd")
const IDS := ["giratina_origin", "ho_oh", "yveltal", "miraidon", "reshiram", "metagross", "salamence"]
const DIRECTIONS := ["down", "left", "right", "up"]
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var all_ids: Array = IDS.duplicate()
	for base: String in IDS:
		all_ids.append(base + "_shiny")
	all_ids.append("metagross_black_gold")
	for id: String in all_ids:
		var item := ("shiny-" if id.ends_with("_shiny") else "") + id.trim_suffix("_shiny").replace("_", "-") + "-mount"
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
		if id.ends_with("_shiny") or id == "metagross_black_gold":
			var base_id := "metagross" if id == "metagross_black_gold" else id.trim_suffix("_shiny")
			_check(mask.get_data() == Mounts._get_mask_image(base_id).get_data(), id + " preserves rider mask")
			_check(idle_mask.get_data() == Mounts._get_mask_image(base_id, true).get_data(), id + " preserves idle rider mask")
			_check(Mounts.get_mount_definition(id).riderOffsets == Mounts.get_mount_definition(base_id).riderOffsets, id + " preserves seats")
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
	_check_repaired_anatomy()
	print("Land mount collection checks: ", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func _check_repaired_anatomy() -> void:
	var source := Image.load_from_file("res://assets/mounts/miraidon/source.png")
	var frames := Mounts.get_mount_frames("miraidon")
	# Original arm tips and tail pixels must stay in place while only the
	# anatomical head/neck is lowered. These caught the old full-width cut.
	var protected := [
		[Rect2i(28, 78, 16, 22), Rect2i(84, 78, 18, 22)],
		[Rect2i(90, 94, 36, 32)],
		[Rect2i(2, 94, 36, 32)],
		[Rect2i(28, 80, 16, 24), Rect2i(84, 80, 18, 24)]
	]
	for row in range(4):
		var origin := Vector2i(32, 112 - source.get_region(Rect2i(0, row*128, 128, 128)).get_used_rect().end.y)
		for phase in range(4):
			var art := Mounts._get_texture_image(frames.get_frame_texture("walk_" + DIRECTIONS[row], phase))
			var intact := true
			var colored := 0
			for region: Rect2i in protected[row]:
				for y in range(region.position.y, region.end.y):
					for x in range(region.position.x, region.end.x):
						var pixel := source.get_pixel(phase*128 + x, row*128 + y)
						if pixel.a > 0:
							colored += 1
							if pixel != art.get_pixel(origin.x + x, origin.y + y):
								intact = false
			_check(colored > 20 and intact, "Miraidon retains source limbs/tail %s phase %d" % [DIRECTIONS[row], phase])
	for id: String in ["miraidon", "yveltal"]:
		var art_frames := Mounts.get_mount_frames(id)
		var front_frames := Mounts.get_mount_foreground_frames(id)
		var tail_source := Image.load_from_file("res://assets/mounts/%s/source.png" % id)
		var base_y := 112 - tail_source.get_region(Rect2i(0, 384, 128, 128)).get_used_rect().end.y
		var shifts := [0, -2, -2, -4] if id == "miraidon" else [0, 2, -4, -2]
		for phase in range(4):
			var art := Mounts._get_texture_image(art_frames.get_frame_texture("walk_up", phase))
			var front := Mounts._get_texture_image(front_frames.get_frame_texture("walk_up", phase))
			var covered := 0
			var intact := true
			for y in range(104 + shifts[phase], 114 + shifts[phase]):
				for x in range(59, 70):
					var point := Vector2i(x + 32, y + base_y)
					var pixel := art.get_pixelv(point)
					if pixel.a > 0:
						covered += 1
						if front.get_pixelv(point) != pixel:
							intact = false
			_check(covered > 20 and intact, "%s rear tail stays in front of rider phase %d" % [id, phase])
