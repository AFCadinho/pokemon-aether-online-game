extends SceneTree

const PLAYERS_HOUSE_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
const DAD_PROFILE_PATH := "res://resources/npcs/story/dadinho.tres"
const DAD_SPRITE_PATH := "res://assets/npcs/custom/adinho_dad.png"
const DAD_FRAMES_PATH := "res://assets/npcs/custom/adinho_dad_frames.tres"
const DAD_ANIMATIONS: Array[StringName] = [
	&"idle_down",
	&"idle_left",
	&"idle_right",
	&"idle_up",
	&"walk_down",
	&"walk_left",
	&"walk_right",
	&"walk_up",
]

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var story_service := get_root().get_node("StoryService")
	story_service.reset_story()
	var packed := load(PLAYERS_HOUSE_SCENE_PATH) as PackedScene
	_expect(packed != null, "Player's House story scene loads")
	if packed == null:
		quit(1)
		return

	var house := packed.instantiate()
	get_root().add_child(house)
	await process_frame

	var father := house.get_node_or_null("Entities/NPCs/Father") as Node2D
	var trigger := house.get_node_or_null("StoryTriggers/FatherIntro") as Area2D
	var hook := house.get_node_or_null("StoryTriggers/FatherIntro/StoryHook")
	var trigger_shape := house.get_node_or_null(
		"StoryTriggers/FatherIntro/CollisionShape2D"
	) as CollisionShape2D

	_expect(father != null, "father NPC exists downstairs")
	_expect(trigger != null, "father intro has an automatic area trigger")
	_expect(hook != null, "father intro trigger has a story hook")
	var dad_texture := load(DAD_SPRITE_PATH) as Texture2D
	var dad_frames := load(DAD_FRAMES_PATH) as SpriteFrames
	var dad_profile := load(DAD_PROFILE_PATH) as Resource
	_expect(dad_profile != null, "father has a reusable NPC definition profile")
	if dad_profile != null:
		_expect(
			str(dad_profile.get("npc_id")) == "kanto_players_house_father"
			and str(dad_profile.get("npc_definition_id")) == "kanto_players_house_father",
			"father profile owns its stable NPC and metadata identities"
		)
		_expect(
			str(dad_profile.get("display_name")) == "Dadinho",
			"father profile owns the Dadinho cameo name"
		)
		_expect(
			dad_profile.get("sprite_frames") == dad_frames,
			"father profile owns the dedicated Adinho dad appearance"
		)
	_expect(
		dad_texture != null and dad_texture.get_size() == Vector2(256, 256),
		"father uses a complete 4x4 Adinho overworld spritesheet"
	)
	_expect(dad_frames != null, "father animation resource loads")
	if dad_frames != null:
		for animation_name: StringName in DAD_ANIMATIONS:
			_expect(
				dad_frames.has_animation(animation_name),
				"father provides %s animation" % animation_name
			)
		_expect(dad_frames.get_frame_count(&"idle_up") == 1, "father has a stable upward idle pose")
		_expect(dad_frames.get_frame_count(&"walk_down") == 4, "father retains the full walk cycle")
	if father != null:
		_expect(father.get("npc_profile") == dad_profile, "Player's House uses Dadinho's reusable NPC profile")
		_expect(
			str(father.get("npc_id")) == "kanto_players_house_father",
			"father uses the stable catalog NPC identity"
		)
		_expect(str(father.get("display_name")) == "Dadinho", "father uses the Dadinho cameo name")
		_expect(
			father.position == Vector2(432, 944),
			"first visit keeps Dadinho at his downstairs intro position"
		)
		_expect(
			father.get("npc_sprite_frames") == dad_frames,
			"Dadinho profile applies the dedicated Adinho dad appearance"
		)
	if trigger != null:
		_expect(trigger.monitoring, "first visit keeps the one-time automatic trigger active")
		_expect(
			trigger.position.y < father.position.y,
			"the intro catches a player approaching father from upstairs"
		)
		_expect(
			trigger.get_node_or_null(trigger.get("story_host_path")) == father,
			"the story sequence resolves father as its actor"
		)
	if trigger_shape != null and trigger_shape.shape is RectangleShape2D:
		var rectangle := trigger_shape.shape as RectangleShape2D
		_expect(
			rectangle.size.x >= 160.0,
			"the trigger spans the downstairs approach corridor"
		)
	else:
		_expect(false, "father intro has a rectangular collision shape")
	if hook != null:
		_expect(
			str(hook.get("interaction_id")) == "players_house_father_intro",
			"scene interaction id matches the storyline catalog"
		)
		_expect(
			str(hook.get("entity_id")) == "kanto_players_house_father",
			"scene entity id matches the storyline catalog"
		)

	house.queue_free()
	await process_frame

	story_service.apply_story({
		"revision": 2,
		"quests": [{
			"questId": "choose_starter",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "main",
			"status": "active",
			"steps": [{
				"stepId": "talk_to_father",
				"status": "completed",
				"currentValue": 1,
				"targetValue": 1,
			}, {
				"stepId": "choose_starter",
				"status": "active",
				"currentValue": 0,
				"targetValue": 1,
			}],
		}],
	})
	var revisited_house := packed.instantiate()
	get_root().add_child(revisited_house)
	await process_frame
	await process_frame
	var revisited_father := revisited_house.get_node_or_null("Entities/NPCs/Father") as Node2D
	var revisited_trigger := revisited_house.get_node_or_null("StoryTriggers/FatherIntro") as Area2D
	var watching_tv_marker := revisited_house.get_node_or_null(
		"StoryPositions/DadinhoWatchingTV"
	) as Marker2D
	var television_marker := revisited_house.get_node_or_null(
		"StoryPositions/LivingRoomTV"
	) as Marker2D
	_expect(watching_tv_marker != null, "Player's House defines Dadinho's blue-cushion position")
	_expect(television_marker != null, "Player's House defines the living-room television position")
	if revisited_father != null and watching_tv_marker != null:
		_expect(
			revisited_father.global_position == watching_tv_marker.global_position
			and revisited_father.position == Vector2(336, 880),
			"completed father intro places Dadinho on the blue cushion"
		)
		_expect(
			revisited_father.get("facing_direction") == Vector2.UP,
			"Dadinho faces the television after the intro"
		)
		var revisited_sprite := revisited_father.get_node_or_null(
			"Look/AnimatedSprite2D"
		) as AnimatedSprite2D
		_expect(
			revisited_sprite != null and revisited_sprite.animation == &"idle_up",
			"Dadinho renders his upward idle frame while watching television"
		)
		revisited_father.call("_apply_npc_metadata", {
			"dialogueId": "kanto_players_house_father_after_intro",
			"dialogueVariants": [{
				"dialogueId": "kanto_players_house_father_after_starter",
				"requiredQuestId": "choose_starter",
				"requiredQuestStepId": "choose_starter",
				"requiredQuestStatus": "completed",
			}],
		})
		_expect(
			str(revisited_father.call("_resolve_story_dialogue_id"))
			== "kanto_players_house_father_after_intro",
			"Dadinho still reminds the player about Oak before choosing a starter"
		)
	if revisited_trigger != null:
		_expect(
			not revisited_trigger.monitoring and not revisited_trigger.monitorable,
			"completed father intro disables the one-time automatic trigger"
		)
	var story_state_source := FileAccess.get_file_as_string(
		"res://scripts/world/story/story_step_scene_variant.gd"
	)
	_expect(
		story_state_source.contains("_apply_story_state.call_deferred()")
		and not story_state_source.contains("story_changed.connect"),
		"Dadinho changes position on scene entry instead of teleporting after the conversation"
	)
	_expect(
		story_state_source.contains("class_name StoryStepSceneVariant")
		and story_state_source.contains("@export var quest_id")
		and story_state_source.contains("@export var step_id"),
		"Dadinho uses the reusable story-step scene variant layer"
	)

	story_service.apply_story({
		"revision": 3,
		"quests": [{
			"questId": "choose_starter",
			"storylineId": "kanto_main",
			"definitionVersion": 1,
			"questType": "main",
			"status": "completed",
			"steps": [{
				"stepId": "talk_to_father",
				"status": "completed",
			}, {
				"stepId": "choose_starter",
				"status": "completed",
			}],
		}],
	})
	if revisited_father != null:
		_expect(
			str(revisited_father.call("_resolve_story_dialogue_id"))
			== "kanto_players_house_father_after_starter",
			"Dadinho stops saying Oak is waiting after the starter step completes"
		)

	revisited_house.queue_free()
	story_service.reset_story()
	quit(1 if failed else 0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
