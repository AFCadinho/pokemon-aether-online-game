extends SceneTree

const GuildEmblemTexture := preload("res://scripts/ui/guild_emblem_texture.gd")
const NameplateLayout := preload("res://scripts/ui/nameplate_layout.gd")

var failed := false


func _init() -> void:
	var player_scene_source := FileAccess.get_file_as_string("res://scenes/player.tscn")
	_check(
		player_scene_source.contains('[node name="GuildEmblem" type="TextureRect" parent="Nameplate"]'),
		"player nameplate contains a guild emblem"
	)
	_check(
		player_scene_source.contains("offset_right = 65.0")
		and player_scene_source.contains("offset_bottom = 60.0"),
		"guild emblem defaults to the name card's 24 pixel content height"
	)
	_check(
		player_scene_source.contains("texture_filter = 1"),
		"guild emblem keeps pixel art crisp"
	)
	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var remote_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	_check(
		_has_inline_guild_emblem(player_source)
		and _has_inline_guild_emblem(remote_source),
		"nameplate places the guild emblem inside the name card without changing its height"
	)

	var pixels: Array = []
	pixels.resize(32 * 32)
	pixels.fill(-1)
	pixels[0] = 0
	var texture := GuildEmblemTexture.create_texture({
		"size": 32,
		"palette": ["#60d3ff"],
		"pixels": pixels,
	})
	_check(texture != null, "valid guild emblem creates a texture")
	if texture != null:
		_check(texture.get_size() == Vector2(32.0, 32.0), "guild emblem preserves its 32 by 32 source")
		_check_inline_nameplate_geometry(texture)
	_check(
		GuildEmblemTexture.create_texture({
			"size": 32,
			"palette": ["#60d3ff"],
			"pixels": [-1],
		}) == null,
		"invalid guild emblem data stays hidden"
	)

	quit(1 if failed else 0)


func _check_inline_nameplate_geometry(_texture: Texture2D) -> void:
	var with_emblem := NameplateLayout.calculate_name_card(60.0, true)
	var without_emblem := NameplateLayout.calculate_name_card(60.0, false)
	var background: Rect2 = with_emblem.get("backgroundRect", Rect2())
	var label: Rect2 = with_emblem.get("labelRect", Rect2())
	var emblem: Rect2 = with_emblem.get("emblemRect", Rect2())
	var background_without_emblem: Rect2 = without_emblem.get("backgroundRect", Rect2())
	_check(is_equal_approx(background.size.y, 26.0), "guild emblem does not increase the name card height")
	_check(
		emblem.size == Vector2(24.0, 24.0),
		"guild emblem scales to 24 by 24 inside the name card"
	)
	_check(
		emblem.position.y >= background.position.y
		and emblem.end.y <= background.end.y,
		"guild emblem stays within the card's vertical bounds"
	)
	_check(emblem.end.x < label.position.x, "guild emblem appears left of the Trainer name")
	_check(
		is_equal_approx(background.get_center().x, 82.0),
		"guild emblem and Trainer name remain centered as one card"
	)
	_check(
		is_equal_approx(background_without_emblem.size.y, background.size.y),
		"name card height remains stable without a guild emblem"
	)
	_check(
		background_without_emblem.size.x < background.size.x,
		"name card only grows horizontally for a guild emblem"
	)


func _has_inline_guild_emblem(source: String) -> bool:
	return (
		source.contains('preload("res://scripts/ui/nameplate_layout.gd")')
		and source.contains("NameplateLayout.calculate_name_card")
		and source.contains("nameplate_background.offset_left = background_rect.position.x")
		and source.contains("guild_emblem.offset_left = emblem_rect.position.x")
		and source.contains("role_badge_panel.offset_bottom = next_layer_bottom")
		and not source.contains("guild_emblem.offset_bottom = next_layer_bottom")
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
