extends SceneTree

const GuildEmblemTexture := preload("res://scripts/ui/guild_emblem_texture.gd")
const NameplateLayout := preload("res://scripts/ui/nameplate_layout.gd")
const RoleBadgeTexture := preload("res://scripts/ui/role_badge_texture.gd")

var failed := false


func _init() -> void:
	var player_scene_source := FileAccess.get_file_as_string("res://scenes/player.tscn")
	_check(
		player_scene_source.contains('[node name="GuildEmblemBackground" type="Panel" parent="Nameplate"]'),
		"player nameplate gives the guild emblem its own badge background"
	)
	_check(
		player_scene_source.contains('[node name="GuildEmblem" type="TextureRect" parent="Nameplate"]'),
		"player nameplate contains a guild emblem"
	)
	_check(
		player_scene_source.contains('[node name="RoleBadgeIcon" type="TextureRect" parent="Nameplate"]')
		and not player_scene_source.contains('path="res://assets/ui/gamemaster_emblem_readable.png"')
		and not player_scene_source.contains('path="res://assets/ui/developer_emblem_teal.png"')
		and not player_scene_source.contains('path="res://assets/ui/moderator_emblem_purple.png"'),
		"player scene opens without depending on role badge PNG import metadata"
	)
	var role_badge_texture_source := FileAccess.get_file_as_string("res://scripts/ui/role_badge_texture.gd")
	_check(
		role_badge_texture_source.contains('"gamemaster": "res://assets/ui/gamemaster_emblem_readable.png"')
		and role_badge_texture_source.contains('"developer": "res://assets/ui/developer_emblem_teal.png"')
		and role_badge_texture_source.contains('"moderator": "res://assets/ui/moderator_emblem_purple.png"')
		and role_badge_texture_source.contains("ResourceLoader.exists")
		and role_badge_texture_source.contains("Image.load_from_file"),
		"role emblems support imported textures and fresh-checkout PNG loading"
	)
	var gm_badge_image := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/ui/gamemaster_emblem_readable.png")
	)
	_check(
		gm_badge_image != null
		and gm_badge_image.get_size() == Vector2i(28, 28)
		and gm_badge_image.detect_alpha() != Image.ALPHA_NONE,
		"Game Master shield emblem has readable dimensions and transparent pixels"
	)
	var developer_badge_image := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/ui/developer_emblem_teal.png")
	)
	_check(
		developer_badge_image != null
		and developer_badge_image.get_size() == Vector2i(28, 28)
		and developer_badge_image.detect_alpha() != Image.ALPHA_NONE
		and RoleBadgeTexture.get_role_badge_texture("developer") != null,
		"Developer shield emblem has readable dimensions and transparent pixels"
	)
	var moderator_badge_image := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/ui/moderator_emblem_purple.png")
	)
	_check(
		moderator_badge_image != null
		and moderator_badge_image.get_size() == Vector2i(28, 28)
		and moderator_badge_image.detect_alpha() != Image.ALPHA_NONE
		and RoleBadgeTexture.get_role_badge_texture("moderator") != null,
		"Moderator shield emblem has readable dimensions and transparent pixels"
	)
	_check(
		player_scene_source.contains("offset_left = 9.0")
		and player_scene_source.contains("offset_right = 33.0")
		and player_scene_source.contains("offset_bottom = 65.0"),
		"guild emblem defaults to its larger 24 pixel display size"
	)
	_check(
		player_scene_source.contains("texture_filter = 1"),
		"guild emblem keeps pixel art crisp"
	)
	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var remote_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	var npc_source := FileAccess.get_file_as_string("res://scripts/world/npcs/base_npc.gd")
	_check(
		player_source.contains("RoleBadgeTexture.get_role_badge_texture(normalized_role_id)")
		and remote_source.contains("RoleBadgeTexture.get_role_badge_texture(normalized_role_id)"),
		"local and remote players assign the selected resilient role texture"
	)
	_check(
		_has_adjacent_guild_emblem(player_source)
		and _has_adjacent_guild_emblem(remote_source),
		"nameplate places the guild emblem in a separate badge beside the name card"
	)
	_check(
		_uses_pixel_role_badge(player_source)
		and _uses_pixel_role_badge(remote_source),
		"local and remote Game Masters, Developers, and Moderators use pixel badges without replacing guild emblems"
	)
	_check(
		_uses_content_sized_name_card(player_source)
		and _uses_content_sized_name_card(remote_source)
		and npc_source.contains("_get_nameplate_label_text_size")
		and npc_source.contains("var card_height := name_size.y")
		and not npc_source.contains("NAMEPLATE_MIN_NAME_WIDTH"),
		"player and NPC name cards follow their rendered text size"
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
	var thumbnail_pixels: Array = []
	thumbnail_pixels.resize(32 * 32)
	thumbnail_pixels.fill(-1)
	thumbnail_pixels[8 + (8 * 32)] = 0
	thumbnail_pixels[23 + (19 * 32)] = 0
	var nameplate_texture := GuildEmblemTexture.create_nameplate_texture({
		"size": 32,
		"palette": ["#60d3ff"],
		"pixels": thumbnail_pixels,
	})
	_check(
		nameplate_texture != null and nameplate_texture.get_size() == Vector2(16.0, 16.0),
		"nameplate emblem trims transparent margins into a square texture"
	)
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
	var name_size := Vector2(60.0, 14.0)
	var with_emblem := NameplateLayout.calculate_name_card(name_size, true)
	var without_emblem := NameplateLayout.calculate_name_card(name_size, false)
	var short_name := NameplateLayout.calculate_name_card(Vector2(8.0, 14.0), false)
	var background: Rect2 = with_emblem.get("backgroundRect", Rect2())
	var label: Rect2 = with_emblem.get("labelRect", Rect2())
	var emblem: Rect2 = with_emblem.get("emblemRect", Rect2())
	var emblem_background: Rect2 = with_emblem.get("emblemBackgroundRect", Rect2())
	var background_without_emblem: Rect2 = without_emblem.get("backgroundRect", Rect2())
	_check(
		background == background_without_emblem,
		"guild emblem does not resize or move the centered name card"
	)
	_check(
		emblem.size == Vector2(24.0, 24.0),
		"guild emblem uses a clear 24 by 24 display size"
	)
	_check(
		emblem_background.size == Vector2(28.0, 28.0),
		"guild emblem has a compact 28 by 28 badge background"
	)
	_check(
		is_equal_approx(background.position.x - emblem_background.end.x, 2.0),
		"guild emblem badge keeps a two pixel gap before the name card"
	)
	_check(
		is_equal_approx(emblem_background.get_center().y, background.get_center().y),
		"guild emblem badge is vertically centered beside the name card"
	)
	_check(
		emblem.position == emblem_background.position + Vector2(2.0, 2.0),
		"guild emblem is centered inside its badge"
	)
	_check(
		is_equal_approx(background.get_center().x, 82.0),
		"Trainer name card remains centered independently of the guild emblem"
	)
	_check(
		is_equal_approx(background_without_emblem.size.y, name_size.y + 4.0),
		"name card height follows the rendered name without a guild emblem"
	)
	_check(
		is_equal_approx(background_without_emblem.size.x, name_size.x + 10.0),
		"name card width follows the rendered name plus compact padding"
	)
	_check(
		is_equal_approx((short_name.get("backgroundRect", Rect2()) as Rect2).size.x, 18.0),
		"short names are not expanded to a minimum card width"
	)
	_check(label == without_emblem.get("labelRect", Rect2()), "guild emblem does not shift the Trainer name")


func _has_adjacent_guild_emblem(source: String) -> bool:
	return (
		source.contains('preload("res://scripts/ui/nameplate_layout.gd")')
		and source.contains("NameplateLayout.calculate_name_card")
		and source.contains("create_nameplate_texture")
		and source.contains("nameplate_background.offset_left = background_rect.position.x")
		and source.contains("guild_emblem_background.offset_left = emblem_background_rect.position.x")
		and source.contains("guild_emblem.offset_left = emblem_rect.position.x")
		and source.contains("role_badge_panel.offset_bottom = next_layer_bottom")
		and not source.contains("guild_emblem.offset_bottom = next_layer_bottom")
	)


func _uses_content_sized_name_card(source: String) -> bool:
	return (
		source.contains("_get_label_text_size")
		and source.contains("NameplateLayout.calculate_name_card(name_size")
		and source.contains("label.label_settings.font_size")
		and not source.contains("NAMEPLATE_MIN_NAME_WIDTH")
	)


func _uses_pixel_role_badge(source: String) -> bool:
	return (
		source.contains("RoleBadgeTexture.has_role_badge(normalized_role_id)")
		and source.contains("role_badge_icon.visible = use_role_icon")
		and source.contains("if uses_role_icon:")
		and source.contains("ROLE_BADGE_ICON_SIZE")
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
