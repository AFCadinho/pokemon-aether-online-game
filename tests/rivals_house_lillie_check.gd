extends SceneTree

const RIVALS_HOUSE := "res://scenes/overworld/kanto/towns/pallet_town/rivals_house.tscn"
const LILLIE_PROFILE := "res://resources/npcs/story/lillie.tres"
const LILLIE_FRAMES := "res://assets/npcs/custom/lillie_aether_blossom_frames.tres"

var failed := false


func _init() -> void:
	var scene := load(RIVALS_HOUSE) as PackedScene
	_check(scene != null, "Rival's House scene loads with Lillie")
	var profile := load(LILLIE_PROFILE) as NpcDefinition
	_check(profile != null, "Lillie has a reusable NPC profile")
	if profile != null:
		_check(profile.display_name == "Lillie", "Lillie's profile owns her display name")
		_check(profile.npc_id == "kanto_rivals_house_lillie", "Lillie has a stable catalog identity")
		_check(profile.sprite_frames != null, "Lillie uses the Aether Blossom sprite frames")
		_check(profile.mugshot != null, "Lillie has an Aether Blossom dialogue portrait")
	var frames := load(LILLIE_FRAMES) as SpriteFrames
	_check(frames != null, "Lillie's Aether Blossom animation resource loads")
	if frames != null:
		for animation_name: StringName in [&"idle_down", &"idle_left", &"idle_right", &"idle_up", &"walk_down", &"walk_left", &"walk_right", &"walk_up"]:
			_check(frames.has_animation(animation_name), "Lillie provides %s" % animation_name)
	var scene_source := FileAccess.get_file_as_string(RIVALS_HOUSE)
	_check(scene_source.contains('reward_id = "kanto_rivals_house_town_map"'), "Lillie grants the Town Map reward")
	if scene != null:
		var house := scene.instantiate()
		var collision := house.get_node_or_null("Collision") as TileMapLayer
		var lillie := house.get_node_or_null("Entities/NPCs/Lillie") as Node2D
		_check(lillie != null, "Rival's House places Lillie downstairs")
		if collision != null and lillie != null:
			var tile := collision.local_to_map(collision.to_local(lillie.position))
			_check(collision.get_cell_source_id(tile) == -1, "Lillie's feet and collision occupy a walkable tile")
		house.free()
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
