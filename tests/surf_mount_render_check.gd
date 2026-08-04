extends SceneTree

const CharacterAppearanceServiceScript := preload(
	"res://scripts/services/character_appearance_service.gd"
)
const MountServiceScript := preload("res://scripts/services/mount_service.gd")

var failed := false


func _init() -> void:
	_check_catalog_and_assets()
	_check_rider_mask_and_offsets()
	_check_player_scene_mount_layer()
	quit(1 if failed else 0)


func _check_catalog_and_assets() -> void:
	_expect(
		MountServiceScript.get_default_mount_id("surf") == "lapras",
		"Lapras is the default Surf mount"
	)
	var definition := MountServiceScript.get_mount_definition("lapras")
	_expect(str(definition.get("movementMode", "")) == "surf", "Lapras is a Surf mount")
	for asset_path: String in [
		"res://assets/mounts/lapras/mount.png",
		"res://assets/mounts/lapras/rider_mask.png",
	]:
		var texture := load(asset_path) as Texture2D
		_expect(texture != null and Vector2i(texture.get_size()) == Vector2i(256, 256), "%s uses a 4x4 64px grid" % asset_path)

	var mount_frames := MountServiceScript.get_mount_frames("lapras")
	_expect(mount_frames != null, "Lapras mount frames load")
	if mount_frames != null:
		_expect(mount_frames.get_frame_count(&"walk_left") == 4, "Lapras has four movement frames")
		_expect(mount_frames.get_frame_count(&"idle_down") == 1, "Lapras has a stable idle frame")


func _check_rider_mask_and_offsets() -> void:
	var base_frames := CharacterAppearanceServiceScript.get_body_frames(
		CharacterAppearanceServiceScript.DEFAULT_MALE_BODY_ID,
		"male",
		CharacterAppearanceServiceScript.BODY_MOVEMENT_RIDE
	)
	var mounted_frames := MountServiceScript.get_mounted_rider_frames(base_frames, "lapras")
	_expect(mounted_frames != null and mounted_frames != base_frames, "Lapras creates mount-specific rider frames")
	if mounted_frames == null:
		return

	var left_image := mounted_frames.get_frame_texture(&"walk_left", 0).get_image()
	var right_image := mounted_frames.get_frame_texture(&"walk_right", 0).get_image()
	var down_image := mounted_frames.get_frame_texture(&"walk_down", 0).get_image()
	_expect(_opaque_pixel_count(left_image) == 908, "left rider frame removes the 20 masked leg pixels")
	_expect(_opaque_pixel_count(right_image) == 908, "right rider frame removes the 20 masked leg pixels")
	_expect(_opaque_pixel_count(down_image) == 1064, "down rider frame keeps all unmasked pixels")
	_expect(left_image.get_used_rect().position.x == 36, "left rider uses the Lapras seat offset")
	_expect(right_image.get_used_rect().position.x == 0, "right rider uses the mirrored Lapras seat offset")
	_expect(
		MountServiceScript.get_rider_frame_delta("lapras", "left", 2) == Vector2i(-2, 2),
		"left rider follows Lapras animation bobbing as one layered unit"
	)
	_expect(
		MountServiceScript.get_rider_frame_delta("lapras", "right", 2) == Vector2i(2, 2),
		"right rider follows mirrored Lapras animation bobbing"
	)


func _check_player_scene_mount_layer() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scenes/player.tscn")
	_expect(
		scene_source.contains('[node name="MountSprite" type="AnimatedSprite2D" parent="Look"]'),
		"player scene owns a mount visual layer"
	)
	_expect(
		scene_source.contains('[node name="Rider" type="Node2D" parent="Look"]'),
		"all layered appearance sprites share a rider transform"
	)
	_expect(scene_source.contains("visible = false"), "mount is hidden while the player is not Surfing")
	_expect(scene_source.contains("z_index = -1"), "Lapras renders behind the masked rider")


func _opaque_pixel_count(image: Image) -> int:
	if image == null:
		return 0
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.001:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
