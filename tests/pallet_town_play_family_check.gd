extends SceneTree

const PALLET_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn"
const PLAYMATE_SCRIPT := "res://scripts/world/npcs/synchronized_playmate_npc.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(PALLET_SCENE) as PackedScene
	_check(packed != null, "Pallet Town scene loads")
	if packed == null:
		quit(1)
		return

	var map := packed.instantiate()
	var father := map.get_node_or_null("Entities/NPCs/PlayFamilyFather") as Node2D
	var mother := map.get_node_or_null("Entities/NPCs/PlayFamilyMother") as Node2D
	var child := map.get_node_or_null("Entities/NPCs/PlayFamilyChild") as Node2D
	var pikachu := map.get_node_or_null("Entities/Pokemon/Pikachu") as Node2D

	_check(father != null and father.position == Vector2(272, 240), "Father replaces the former market position")
	_check(mother != null and mother.position == Vector2(368, 240), "Mother replaces the former Nurse Joy position")
	_check(child != null and pikachu != null, "Child and Pikachu are both placed")
	if child != null and pikachu != null:
		var child_script := child.get_script() as Script
		_check(child_script != null and child_script.resource_path == PLAYMATE_SCRIPT, "Child uses synchronized playmate movement")
		_check(child.get("movement_target_path") == NodePath("../../Pokemon/Pikachu"), "Child follows Pikachu")
		_check(child.get("movement_offset") == Vector2(0, -64), "Child stays two tiles behind Pikachu")
		_check(child.position == pikachu.position + Vector2(0, -64), "Initial play formation is aligned")
		_check(pikachu.get("movement_behavior") == "pace_vertical", "Pikachu keeps its vertical play route")

		child.set("is_interacting", true)
		child.call("_resolve_movement_target")
		pikachu.position += Vector2(0, 32)
		child.call("_sync_to_movement_target")
		_check(child.position == pikachu.position + Vector2(0, -64), "Child remains synchronized when Pikachu moves")

	map.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
