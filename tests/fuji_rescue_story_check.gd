extends SceneTree

const TOWER := "res://scenes/overworld/kanto/towns/lavender_town/pokemon_tower.tscn"
const HOUSE := "res://scenes/overworld/kanto/towns/lavender_town/mr_fuji_house.tscn"
const Base := preload("res://scripts/world/npcs/base_npc.gd")

class FakeBox extends Node:
	signal dialogue_finished
	func start_dialogue(_lines: Array[String], _speaker: String, _portrait: Texture2D = null, _show := false) -> void:
		dialogue_finished.emit.call_deferred()
class FakeHost extends Node2D:
	var seen: Array[String] = []
	func show_dialogue(lines: Array[String], _speaker := "") -> bool:
		seen.assign(lines)
		return true

var failures := 0
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var story := root.get_node("StoryService")
	var state := root.get_node("GameState")
	var old_story: Dictionary = story.get_story()
	var old_map: Node = state.current_map
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var tower := (load(TOWER) as PackedScene).instantiate()
	var house := (load(HOUSE) as PackedScene).instantiate()
	# Keep real actor nodes/feet but disable HTTP-backed population behavior.
	for map: Node in [tower, house]:
		map.set_script(null)
		for container: String in ["Entities/Pokemon", "StoryTriggers"]:
			var node := map.get_node_or_null(container)
			if node != null:
				node.free()
		for actor: Node in map.get_node("Entities/NPCs").get_children():
			if actor.name in ["MrFuji", "PilgrimRen", "RocketGrunt1", "RocketGrunt2", "RocketGrunt3"]:
				var properties: Dictionary = {}
				for field: String in ["npc_id", "npc_sprite_frames", "mugshot", "visibility_required_quest_id", "visibility_required_quest_step_id", "visibility_required_quest_status", "visibility_hidden_quest_id", "visibility_hidden_quest_step_id", "visibility_hidden_quest_status"]:
					properties[field] = actor.get(field)
				actor.set_script(Base)
				for field: String in properties:
					actor.set(field, properties[field])
			else:
				actor.free()
		world.add_child(map)
	var fuji := tower.get_node("Entities/NPCs/MrFuji") as BaseNPC
	var home := house.get_node("Entities/NPCs/MrFuji") as BaseNPC
	var ren := tower.get_node("Entities/NPCs/PilgrimRen") as BaseNPC
	var actors: Array[BaseNPC] = [fuji,home,ren]
	for index: int in range(1,4):
		actors.append(tower.get_node("Entities/NPCs/RocketGrunt%d" % index) as BaseNPC)
	story.apply_story(_story(false))
	for actor: BaseNPC in actors:
		actor._apply_story_visibility()
	_check(fuji.visible and not home.visible and not ren.visible, "Fuji is held in the tower; Ren and home Fuji are absent before rescue")
	for index: int in range(3,6):
		_check(actors[index].visible and actors[index].blocks_world_position(actors[index].get_feet_position()), "Each Rocket is a real collidable overworld NPC")
	for actor: BaseNPC in actors:
		var map := house if actor == home else tower
		var collision := map.get_node("Tiles/Collision") as TileMapLayer
		_check(collision.get_cell_source_id(collision.local_to_map(actor.position)) == -1, actor.name + " stands on a walkable tile")
	_check(fuji.get_node("StoryHook").interaction_id == "kanto_pokemon_tower_fuji_rescued", "Tower Fuji has the rescue hook")
	_check(home.get_node("StoryHook").interaction_id == "kanto_lavender_fuji_flute_gift", "Home Fuji has the one-time gift hook")
	_check(fuji.npc_sprite_frames == home.npc_sprite_frames and fuji.mugshot != null, "Both Fuji placements use his existing artwork and matching portrait")
	story.apply_story(_story(true))
	for actor: BaseNPC in actors:
		actor._apply_story_visibility()
	_check(not fuji.visible and home.visible and ren.visible, "Rescue completion moves Fuji home and lets Ren return")
	_check(not fuji.blocks_world_position(fuji.get_feet_position()), "Departed Fuji no longer blocks the tower")
	for index: int in range(3,6):
		_check(not actors[index].visible and not actors[index].blocks_world_position(actors[index].get_feet_position()), "Every Rocket leaves the tower and releases collision")
	# Reconnecting/revisiting uses the same projected visibility, and rewinds
	# reconstitute the original rescue rather than retaining local hide flags.
	for actor: BaseNPC in actors:
		actor._apply_story_visibility()
	_check(not fuji.visible and home.visible, "Reapplying the saved projection preserves Fuji's relocation")
	story.apply_story(_story(false))
	for actor: BaseNPC in actors:
		actor._apply_story_visibility()
	_check(fuji.visible and not home.visible and not ren.visible, "A developer rewind restores the rescue stage")
	var vision_probe: Node = load("res://scripts/world/npcs/pokemon_tower_rocket.gd").new()
	vision_probe.trainer_progress_loaded = true
	vision_probe.trainer_progress_state = "first_encounter"
	_check(vision_probe._can_auto_challenge(), "A live rescue Rocket can challenge from its sight lane")
	vision_probe.visible = false
	_check(not vision_probe._can_auto_challenge(), "A hidden Rocket cannot issue an invisible challenge")
	vision_probe.visible = true
	story.apply_story(_story(true))
	_check(not vision_probe._can_auto_challenge(), "Completed rescue disables vision even with stale trainer metadata")
	vision_probe.free()
	# The response carries a name independently of the cached dialogue template.
	var dialogue := root.get_node("DialogueMetadataService")
	var locale: String = dialogue.call("_get_http_locale")
	var id := "kanto_lavender_fuji_potential"
	var key: String = dialogue.call("_get_cache_key",locale,id)
	var had_cache: bool = dialogue.dialogue_metadata_cache.has(key)
	var previous: Variant = dialogue.dialogue_metadata_cache.get(key)
	dialogue.dialogue_metadata_cache[key] = {"success":true,"metadata":{"id":id,"dialogueId":id,"speakerName":"Mr. Fuji","lines":["You and {starterSpeciesName} have great potential."]}}
	var holder := Node.new()
	holder.name = "DialogueBox"
	world.add_child(holder)
	var box := FakeBox.new()
	box.name = "Box"
	holder.add_child(box)
	var host := FakeHost.new()
	world.add_child(host)
	var runner := root.get_node("StorySequenceRunner")
	for name: String in ["Gible","Gabite","Garchomp"]:
		var result: Dictionary = await runner.run_sequence([{"type":"dialogue","dialogueId":id}],host,null,{"starterSpeciesName":name})
		_check(result.success and host.seen == ["You and %s have great potential." % name], "Fuji presents the server-resolved starter stage " + name)
	_check(dialogue.dialogue_metadata_cache[key].metadata.lines == ["You and {starterSpeciesName} have great potential."], "Personalization never changes shared cached dialogue")
	var api := root.get_node("PlayerGameStateService")
	var body := {"handled":true,"interactionId":"kanto_lavender_fuji_flute_gift","revision":1,"actions":[],"completionRequired":true,"dialogueParameters":{"starterSpeciesName":"Garchomp"}}
	_check(api._is_valid_story_resolve_body(body), "Story API accepts the authoritative starter parameter")
	body.dialogueParameters = {"starterSpeciesName":12}
	_check(not api._is_valid_story_resolve_body(body), "Malformed personalization fails the response contract")
	if had_cache:
		dialogue.dialogue_metadata_cache[key] = previous
	else:
		dialogue.dialogue_metadata_cache.erase(key)
	story.apply_story(old_story)
	state.current_map = old_map
	world.queue_free()
	await process_frame
	print("fuji_rescue_story_check: ", "FAIL" if failures else "PASS")
	quit(1 if failures else 0)
func _story(rescued: bool) -> Dictionary:
	return {"revision":2 if rescued else 1,"quests":[{"questId":"rescue_mr_fuji","status":"completed" if rescued else "active","steps":[{"stepId":"rescue_fuji","status":"completed" if rescued else "active"},{"stepId":"speak_to_fuji","status":"completed" if rescued else "inactive"}]}]}
func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)
