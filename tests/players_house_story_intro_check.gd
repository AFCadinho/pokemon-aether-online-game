extends SceneTree

const HOUSE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"
const ROUTE_1_PATH := "res://scenes/overworld/kanto/routes/kanto_route_1.tscn"
const DAD_FRAMES_PATH := "res://assets/npcs/custom/adinho_dad_frames.tres"
const MOM_FRAMES_PATH := "res://assets/npcs/named/mom_frames.tres"
const MOM_SPRITE_PATH := "res://assets/npcs/Ultimate Gen 4 Overworlds Pack/All Official Overworlds/NPC_127_Mom.png"
const TRAINING_SCRIPT_PATH := "res://scripts/world/kanto/routes/dadinho_training_npc.gd"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var story_service := get_root().get_node("StoryService")
	story_service.reset_story()
	var house_scene := load(HOUSE_PATH) as PackedScene
	var route_scene := load(ROUTE_1_PATH) as PackedScene
	_expect(house_scene != null, "Player's House scene loads")
	_expect(route_scene != null, "Route 1 scene loads")
	if house_scene == null or route_scene == null:
		quit(1)
		return

	var house := house_scene.instantiate()
	get_root().add_child(house)
	await process_frame
	var father := house.get_node_or_null("Entities/NPCs/Father") as Node2D
	var mom := house.get_node_or_null("Entities/NPCs/Mom") as Node2D
	var intro_trigger := house.get_node_or_null("StoryTriggers/FatherIntro") as Area2D
	_expect(father != null and father.visible, "Dadinho is present for the opening")
	_expect(mom != null and not mom.visible, "Mom is hidden before the player receives a starter")
	_expect(intro_trigger != null and intro_trigger.monitoring, "Dadinho's opening trigger remains active")
	if father != null:
		_expect(father.position == Vector2(448, 896), "Dadinho starts beside the downstairs door")
		_expect(father.get("npc_sprite_frames") == load(DAD_FRAMES_PATH), "Dadinho keeps his custom sprite")
		_expect(
			father.get("sprite_offset") == Vector2(16, 0),
			"Player's House Dadinho aligns his sprite with the downstairs collision tile"
		)
		var father_nameplate := father.get("nameplate") as Control
		_expect(
			father_nameplate != null and father_nameplate.position.x == 16.0,
			"Dadinho's nameplate follows his opening sprite offset"
		)
		_expect(
			str(father.get("visibility_hidden_quest_id")) == "choose_starter"
			and str(father.get("visibility_hidden_quest_step_id")) == "choose_starter",
			"Dadinho leaves when the player receives a starter"
		)
	if mom != null:
		_expect(
			str(mom.get("visibility_required_quest_id")) == "choose_starter"
			and str(mom.get("visibility_required_quest_step_id")) == "choose_starter",
			"Mom arrives when the player receives a starter"
		)
		var mom_frames := load(MOM_FRAMES_PATH) as SpriteFrames
		_expect(mom.get("npc_sprite_frames") == mom_frames, "Mom uses her dedicated overworld sprite")
		var mom_default_frame := mom_frames.get_frame_texture("default", 0) as AtlasTexture
		_expect(
			mom_default_frame != null
			and mom_default_frame.atlas != null
			and mom_default_frame.atlas.resource_path == MOM_SPRITE_PATH,
			"Mom uses the requested NPC 127 overworld sheet"
		)
		_expect(str(mom.get("respawn_spawn_marker")) == "MomHeal", "Mom owns the house heal spawn")
		var mom_hook := mom.get_node_or_null("BeforeJourneyStoryHook")
		_expect(
			mom_hook != null
			and str(mom_hook.get("interaction_id")) == "players_house_mom_before_journey"
			and str(mom_hook.get("entity_id")) == "kanto_players_house_mom",
			"Mom completes the post-Pokedex family visit"
		)
	_expect(house.get_node_or_null("Spawns/MomHeal") != null, "Player's House exposes Mom's stable respawn marker")

	story_service.apply_story(_story_after_starter())
	await process_frame
	await process_frame
	_expect(father != null and not father.visible, "Dadinho leaves home after the player receives a starter")
	_expect(mom != null and mom.visible, "Mom appears after the player receives a starter")
	if father != null:
		_expect(not father.call("blocks_world_position", father.global_position), "Hidden Dadinho no longer blocks his old tile")

	story_service.apply_story(_story_after_parcel("available"))
	await process_frame
	await process_frame
	_expect(father != null and not father.visible, "Dadinho remains away after Oak returns the Parcel")
	_expect(mom != null and mom.visible, "Mom remains home after Oak returns the Parcel")
	if mom != null:
		mom.call("_apply_npc_metadata", {
			"questMarkers": [{
				"questId": "get_town_map",
				"stepId": "visit_father",
				"statuses": ["active"],
			}],
		})
		var marker := mom.get("quest_marker_label") as Label
		mom.call("_refresh_quest_marker")
		_expect(marker != null and marker.text == "!", "Mom shows the main-story visit marker")

	var route := route_scene.instantiate()
	get_root().add_child(route)
	await process_frame
	await process_frame
	var route_dad := route.get_node_or_null("Entities/NPCs/Dialogue/Dadinho") as Node2D
	_expect(route_dad != null and not route_dad.visible, "Dadinho does not offer the challenge before the family visit")
	story_service.apply_story(_story_after_parcel("available", "completed"))
	await process_frame
	await process_frame
	_expect(route_dad != null and route_dad.visible, "Dadinho waits near the start of Route 1 after the family visit")
	if route_dad != null:
		_expect(route_dad.position == Vector2(880, 2192), "Route Dadinho keeps his current Route 1 placement")
		_expect(str(route_dad.get("npc_id")) == "kanto_route_1_dadinho", "Route Dadinho has his own metadata identity")
		_expect(route_dad.get("npc_sprite_frames") == load(DAD_FRAMES_PATH), "Route Dadinho keeps the same appearance")
		_expect(route_dad.get_script() == load(TRAINING_SCRIPT_PATH), "Route Dadinho owns the training turn-in interaction")
		_expect(bool(route_dad.get("defer_story_hide_until_reload")), "Route Dadinho stays for the current map visit after turn-in")
		_expect(
			str(route_dad.get("visibility_hidden_quest_id")) == "train_starter_to_level_10",
			"Route Dadinho leaves when his side quest is completed"
		)

	story_service.apply_story(_story_after_parcel(
		"active",
		"completed",
		[{
			"stepId": "reach_level_10",
			"status": "completed",
		}, {
			"stepId": "return_to_dadinho",
			"status": "active",
		}]
	))
	await process_frame
	_expect(
		route_dad != null and bool(route_dad.call("_is_training_reward_available")),
		"Dadinho recognizes the ready-to-turn-in training step"
	)

	story_service.apply_story(_story_after_parcel("completed", "completed"))
	await process_frame
	await process_frame
	_expect(route_dad != null and route_dad.visible, "Dadinho remains until the player leaves Route 1")
	_expect(mom != null and mom.visible, "Mom remains at home after Dadinho's challenge")

	route.queue_free()
	await process_frame
	var reloaded_route := route_scene.instantiate()
	get_root().add_child(reloaded_route)
	await process_frame
	await process_frame
	var reloaded_dad := reloaded_route.get_node_or_null("Entities/NPCs/Dialogue/Dadinho") as Node2D
	_expect(reloaded_dad != null and not reloaded_dad.visible, "Dadinho is gone after Route 1 is reloaded")
	reloaded_route.queue_free()
	house.queue_free()
	story_service.reset_story()
	quit(1 if failed else 0)


func _story_after_starter() -> Dictionary:
	return {
		"revision": 4,
		"quests": [{
			"questId": "choose_starter",
			"questType": "main",
			"status": "completed",
			"steps": [{"stepId": "choose_starter", "status": "completed"}],
		}],
	}


func _story_after_parcel(
	training_status: String,
	family_visit_status := "active",
	training_steps: Array = []
) -> Dictionary:
	return {
		"revision": 5,
		"quests": [{
			"questId": "choose_starter",
			"questType": "main",
			"status": "completed",
			"steps": [{"stepId": "choose_starter", "status": "completed"}],
		}, {
			"questId": "oaks_parcel",
			"questType": "main",
			"status": "completed",
			"steps": [{"stepId": "return_to_oak", "status": "completed"}],
		}, {
			"questId": "get_town_map",
			"questType": "main",
			"status": "active",
			"steps": [{"stepId": "visit_father", "status": family_visit_status}],
		}, {
			"questId": "train_starter_to_level_10",
			"questType": "side",
			"status": training_status,
			"steps": training_steps,
		}],
	}


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
