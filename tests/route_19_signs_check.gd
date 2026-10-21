extends SceneTree

const SCENE := "res://scenes/overworld/kanto/routes/kanto_route_19.tscn"
const PORTRAITS := preload("res://scripts/services/sign_portrait_catalog.gd")
const LOCALES := ["en", "nl", "pt-BR", "zh-CN"]
var failed := false

class DialogueProbe extends Node:
	signal dialogue_finished
	var lines: Array = []
	var speaker := ""
	var portrait: Texture2D
	var show_portrait := false
	func start_dialogue(new_lines: Array, new_speaker: String, image: Texture2D, show_image: bool) -> void:
		lines = new_lines
		speaker = new_speaker
		portrait = image
		show_portrait = show_image
		_finish.call_deferred()
	func _finish() -> void:
		dialogue_finished.emit()

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := (load(SCENE) as PackedScene).instantiate()
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var sandbox := Node2D.new()
	root.add_child(sandbox)
	current_scene = sandbox
	var dialogue := Node.new()
	dialogue.name = "DialogueBox"
	sandbox.add_child(dialogue)
	var box := DialogueProbe.new()
	box.name = "Box"
	dialogue.add_child(box)
	var state := root.get_node("GameState")
	var old_map: Node = state.get("current_map")
	state.set("current_map", map)
	var player := Node2D.new()
	sandbox.add_child(player)
	var count := 0
	for actor: Node in map.get_node("Entities/Interactables/Signs").get_children():
		if actor.get("sign_id") == null:
			continue
		count += 1
		var sign_id: String = actor.get("sign_id")
		_check(not sign_id.is_empty(), "%s has content assigned" % actor.name)
		_check(PORTRAITS.get_portrait(sign_id) != null, "%s portrait loads" % actor.name)
		_check(collision.get_cell_source_id(collision.local_to_map(actor.position)) == -1, "%s reading tile is walkable" % actor.name)
		actor.owner = null
		actor.get_parent().remove_child(actor)
		sandbox.add_child(actor)
		player.position = actor.position
		_check(actor.call("_is_player_on_interaction_tile", player), "%s reading tile is inside interaction area" % actor.name)
		_check(actor.get("required_facing_direction") == "up", "%s is read looking toward the sign" % actor.name)
		for index in range(LOCALES.size()):
			var locale: String = LOCALES[index]
			actor.set("locale", locale)
			await actor.call("show_sign_text")
			_check(not box.lines.is_empty() and not box.speaker.is_empty(), "%s opens localized dialogue in %s" % [actor.name, locale])
			_check(box.portrait != null and box.show_portrait, "%s displays its illustration in %s" % [actor.name, locale])
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_text/signs/%s/kanto/route_19.json" % locale))
			for entry: Dictionary in document.signs:
				if entry.id == sign_id:
					_check(box.lines == entry.lines and box.speaker == entry.title, "%s uses the exact localized content in %s" % [actor.name, locale])
	_check(count == 3, "all three Route 19 signs have text and illustrations")
	state.set("current_map", old_map)
	await process_frame
	map.free()
	sandbox.free()
	print("ROUTE19_SIGNS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
