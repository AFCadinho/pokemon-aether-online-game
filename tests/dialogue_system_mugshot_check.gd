extends SceneTree

const DIALOGUE_BOX_SCENE_PATH := "res://scripts/ui/dialogue_box.tscn"
const SYSTEM_MUGSHOT_PATH := "res://assets/sprites/mugshots/aether_system_core.png"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var dialogue_scene := load(DIALOGUE_BOX_SCENE_PATH) as PackedScene
	var dialogue_layer := dialogue_scene.instantiate()
	root.add_child(dialogue_layer)
	await process_frame
	var dialogue_box := dialogue_layer.get_node("Box")
	var npc_sprite := dialogue_box.get_node(
		"PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/PortraitPanel/PortraitMargin/NPCSprite"
	) as TextureRect
	var default_mugshot: Texture2D = npc_sprite.texture
	var system_mugshot := load(SYSTEM_MUGSHOT_PATH) as Texture2D

	dialogue_box.start_dialogue(["System notice"], "System")
	_check(npc_sprite.texture == system_mugshot, "System dialogue uses the Aether Core mugshot")
	_check(
		npc_sprite.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"System mugshot remains fully visible in the portrait frame"
	)
	dialogue_box.hide_dialogue()

	dialogue_box.start_dialogue(["Ordinary dialogue"], "Professor Oak")
	_check(npc_sprite.texture == default_mugshot, "Ordinary dialogue retains its default mugshot")
	dialogue_box.hide_dialogue()

	dialogue_box.start_dialogue(["Explicit override"], "System", default_mugshot)
	_check(npc_sprite.texture == default_mugshot, "An explicit mugshot overrides the System default")
	dialogue_box.hide_dialogue()

	dialogue_layer.queue_free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
