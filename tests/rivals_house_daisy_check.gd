extends SceneTree

const HOUSE_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/rivals_house.tscn"
const DAISY_PROFILE := "res://resources/npcs/story/daisy_oak.tres"
const DAISY_FRAMES := "res://assets/npcs/named/daisy_oak_frames.tres"
const GIFT_SCRIPT := "res://scripts/world/npcs/item_gift_npc.gd"

var failed := false


func _init() -> void:
	var scene := load(HOUSE_SCENE) as PackedScene
	var profile := load(DAISY_PROFILE)
	var frames := load(DAISY_FRAMES) as SpriteFrames
	_check(scene != null, "Rival's House scene loads with Daisy Oak")
	_check(profile != null, "Daisy has a reusable NPC profile")
	if profile != null:
		_check(profile.display_name == "Daisy Oak", "Daisy's profile owns her display name")
		_check(profile.npc_id == "kanto_rivals_house_daisy", "Daisy has a stable catalog identity")
		_check(profile.sprite_frames != null, "Daisy uses her official overworld sprite")
		_check(profile.mugshot != null, "Daisy uses her Showdown portrait")
	_check(frames != null, "Daisy's animation source loads")

	var scene_source := FileAccess.get_file_as_string(HOUSE_SCENE)
	_check(scene_source.contains('reward_id = "kanto_rivals_house_town_map"'), "Daisy grants the Town Map reward")
	_check(scene_source.contains("preload_quest_markers = true"), "Daisy's quest marker is preloaded")
	var gift_script := FileAccess.get_file_as_string(GIFT_SCRIPT)
	_check(gift_script.contains("is_story_requirement_met"), "Daisy's gift respects story requirements")
	_check(gift_script.contains("reward_resolved"), "Daisy's marker clears after receiving the Town Map")

	if scene != null:
		var house := scene.instantiate()
		var daisy := house.get_node_or_null("Entities/NPCs/DaisyOak") as Node2D
		_check(daisy != null, "Rival's House places Daisy downstairs")
		var collision := house.get_node_or_null("Collision") as TileMapLayer
		if daisy != null and collision != null:
			var tile := collision.local_to_map(collision.to_local(daisy.global_position))
			_check(collision.get_cell_source_id(tile) == -1, "Daisy stands on a walkable tile")
		house.free()

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
