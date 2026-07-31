extends SceneTree

const PLAYERS_HOUSE_SCENE_PATH := "res://scenes/overworld/kanto/towns/pallet_town/players_house.tscn"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
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
	if father != null:
		_expect(
			str(father.get("npc_id")) == "kanto_players_house_father",
			"father uses the stable catalog NPC identity"
		)
		_expect(
			father.position.y > 608.0 and father.position.y < 1024.0,
			"father is placed on the ground floor"
		)
	if trigger != null:
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
	quit(1 if failed else 0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
