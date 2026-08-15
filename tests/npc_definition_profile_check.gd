extends SceneTree

const NPC_DEFINITION_SCRIPT := "res://scripts/world/npcs/npc_definition.gd"
const TRAINER_DEFINITION_SCRIPT := "res://scripts/world/npcs/trainer_definition.gd"
const BASE_NPC_SCRIPT := "res://scripts/world/npcs/base_npc.gd"
const FALLBACK_FRAMES := "res://assets/npcs/generic_npc_fallback_frames.tres"
const TRAINER_RED_PROFILE := "res://resources/npcs/trainers/trainer_red_boss.tres"
const BOSS_BATTLE_SCENE := "res://scenes/npcs/boss_battle_npc.tscn"
const PALLET_TOWN_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const VIRIDIAN_CITY_SCENE := "res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn"
const PEWTER_GYM_SCENE := "res://scenes/overworld/kanto/towns/pewter_city/pewter_gym.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ResourceLoader.exists(NPC_DEFINITION_SCRIPT), "base NPC definition exists")
	_check(ResourceLoader.exists(TRAINER_DEFINITION_SCRIPT), "typed trainer definition exists")
	_check(ResourceLoader.exists(TRAINER_RED_PROFILE), "reused Trainer Red profile exists")

	var base_source := FileAccess.get_file_as_string(BASE_NPC_SCRIPT)
	_check(base_source.contains("@export var npc_profile:"), "BaseNPC exports one shared profile")
	_check(base_source.contains("func _apply_npc_profile()"), "BaseNPC centrally applies profiles")
	_check(base_source.contains("func _refresh_npc_profile_preview()"), "profiles support editor preview")

	var fallback_source := FileAccess.get_file_as_string(FALLBACK_FRAMES)
	_check(
		not fallback_source.contains("resource_local_to_scene = true"),
		"generic fallback frames stay shared between scene instances"
	)

	var trainer_red_profile := load(TRAINER_RED_PROFILE)
	_check(trainer_red_profile != null, "Trainer Red profile loads")
	if trainer_red_profile != null:
		_check(
			str(trainer_red_profile.get("npc_id")) == "kanto_route_1_trainer_red_boss",
			"Trainer Red profile owns stable NPC identity"
		)
		_check(
			str(trainer_red_profile.get("display_name")) == "Trainer Red",
			"Trainer Red profile owns client presentation name"
		)
		_check(trainer_red_profile.get("sprite_frames") != null, "Trainer Red profile owns sprite frames")
		_check(trainer_red_profile.get("mugshot") != null, "Trainer Red profile owns mugshot")

	await _check_runtime_profile_application(trainer_red_profile)
	_check_test_bosses_are_not_placed()
	_check_gym_scene_has_no_fallback_copies()

	quit(1 if failed else 0)


func _check_runtime_profile_application(profile: Resource) -> void:
	if profile == null:
		return

	var packed := load(BOSS_BATTLE_SCENE) as PackedScene
	_check(packed != null, "Boss battle base scene loads")
	if packed == null:
		return

	var npc := packed.instantiate()
	npc.set("npc_profile", profile)
	root.add_child(npc)
	await process_frame

	_check(
		str(npc.get("npc_id")) == "kanto_route_1_trainer_red_boss",
		"profile identity is applied before gameplay"
	)
	_check(str(npc.get("display_name")) == "Trainer Red", "profile name overrides base-scene fallback")
	_check(npc.get("mugshot") == profile.get("mugshot"), "profile mugshot is applied")
	var sprite := npc.get_node_or_null("Look/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite != null and sprite.sprite_frames.has_animation("idle_right"), "profile sprite is directional")

	root.remove_child(npc)
	npc.free()


func _check_test_bosses_are_not_placed() -> void:
	for scene_path: String in [PALLET_TOWN_SCENE, VIRIDIAN_CITY_SCENE]:
		var source := FileAccess.get_file_as_string(scene_path)
		_check(
			not source.contains('path="res://resources/npcs/trainers/trainer_red_boss.tres"')
			and not source.contains('[node name="AshKetchum"'),
			"%s does not place the Trainer Red test boss" % scene_path.get_file()
		)


func _check_gym_scene_has_no_fallback_copies() -> void:
	var source := FileAccess.get_file_as_string(PEWTER_GYM_SCENE)
	_check(source.count("npc_profile = ExtResource") >= 1, "Pewter's Gym Leader uses a shared NPC profile")
	_check(
		not source.contains("AtlasTexture_fallback"),
		"Pewter City no longer serializes Gym Leader fallback sprites"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
