extends SceneTree

const TREE_SCENE := "res://scenes/world/interactables/cuttable_tree.tscn"
const TREE_MUGSHOT := "res://assets/sprites/mugshots/cuttable_tree.png"


func _init() -> void:
	var mugshot := load(TREE_MUGSHOT) as Texture2D
	_check(mugshot != null, "Cuttable Tree mugshot imports as a Texture2D")
	_check(mugshot != null and mugshot.get_width() > 0 and mugshot.get_height() > 0, "Cuttable Tree mugshot has image data")
	var tree_scene := load(TREE_SCENE) as PackedScene
	_check(tree_scene != null, "Cuttable Tree scene loads with its mugshot resource")
	quit(0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		push_error("FAIL: %s" % label)
		quit(1)
