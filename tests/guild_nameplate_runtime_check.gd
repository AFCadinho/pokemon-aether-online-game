extends SceneTree

const GuildEmblemTexture := preload("res://scripts/ui/guild_emblem_texture.gd")

var failed := false


func _init() -> void:
	var player_scene_source := FileAccess.get_file_as_string("res://scenes/player.tscn")
	_check(
		player_scene_source.contains('[node name="GuildEmblem" type="TextureRect" parent="Nameplate"]'),
		"player nameplate contains a guild emblem"
	)
	_check(
		player_scene_source.contains("offset_right = 65.0")
		and player_scene_source.contains("offset_bottom = 34.0"),
		"guild emblem renders at 24 by 24"
	)
	_check(
		player_scene_source.contains("texture_filter = 1"),
		"guild emblem keeps pixel art crisp"
	)
	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	var remote_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	_check(
		_has_ordered_nameplate_stack(player_source)
		and _has_ordered_nameplate_stack(remote_source),
		"nameplate stacks emblem, staff badge, and anchored name in order"
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
	_check(
		GuildEmblemTexture.create_texture({
			"size": 32,
			"palette": ["#60d3ff"],
			"pixels": [-1],
		}) == null,
		"invalid guild emblem data stays hidden"
	)

	quit(1 if failed else 0)


func _has_ordered_nameplate_stack(source: String) -> bool:
	return (
		source.contains("nameplate_label.offset_bottom = NAMEPLATE_STACK_BOTTOM")
		and source.contains("role_badge_panel.offset_bottom = next_layer_bottom")
		and source.contains("next_layer_bottom = role_badge_panel.offset_top - NAMEPLATE_LAYER_GAP")
		and source.contains("guild_emblem.offset_bottom = next_layer_bottom")
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
