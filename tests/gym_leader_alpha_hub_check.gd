extends SceneTree

const PEWTER_SCENE := "res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
const GYM_LEADER_SCENE := "res://scenes/npcs/gym_leader_npc.tscn"
const GYM_LEADER_SCRIPT := "res://scripts/world/npcs/gym_leader_npc.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ResourceLoader.exists(GYM_LEADER_SCENE), "reusable Gym Leader NPC scene exists")
	var leader_source := FileAccess.get_file_as_string(GYM_LEADER_SCRIPT)
	_check(leader_source.contains("extends TrainerNPC"), "Gym Leader reuses the trainer battle flow")
	_check(leader_source.contains("required_badge_ids"), "Gym Leader supports ordered badge trials")
	_check(leader_source.contains("dialogue_rematch"), "Gym Leader supports badge-aware rematch dialogue")

	var packed := load(PEWTER_SCENE) as PackedScene
	_check(packed != null, "Pewter City alpha hub scene loads")
	if packed == null:
		quit(1)
		return

	var map := packed.instantiate()
	root.add_child(map)
	await process_frame

	var expected := {
		"AlphaGymBrock": ["kanto_alpha_gym_brock", "boulder"],
		"AlphaGymMisty": ["kanto_alpha_gym_misty", "cascade"],
		"AlphaGymLtSurge": ["kanto_alpha_gym_lt_surge", "thunder"],
	}
	var leaders: Dictionary = {}
	var collision := map.get_node_or_null("Collision") as TileMapLayer
	_check(collision != null, "Pewter City collision layer is available")
	for node_name: String in expected:
		var leader := map.get_node_or_null("Entities/NPCs/%s" % node_name)
		_check(leader != null, "%s is placed in the alpha hub" % node_name)
		if leader == null:
			continue
		leaders[node_name] = leader
		var values: Array = expected[node_name]
		_check(str(leader.get("trainer_id")) == str(values[0]), "%s uses its server trainer id" % node_name)
		_check(str(leader.get("badge_id")) == str(values[1]), "%s advertises its canonical badge" % node_name)
		_check(int(leader.get("sight_range_tiles")) == 0, "%s starts only through deliberate interaction" % node_name)
		if collision != null:
			var cell := collision.local_to_map(collision.to_local(leader.global_position))
			_check(
				collision.get_cell_source_id(cell) == -1,
				"%s stands on a walkable tile" % node_name
			)

	var player_save := root.get_node_or_null("PlayerSave")
	_check(player_save != null, "PlayerSave is available for Gym trial gates")
	if player_save != null and leaders.has("AlphaGymMisty"):
		player_save.call("apply_gym_badge_state", {"badges": []})
		var misty: Node = leaders["AlphaGymMisty"] as Node
		_check(
			misty.call("_missing_required_badges") == ["boulder"],
			"Misty requires the Boulder Badge"
		)
		player_save.call("apply_gym_badge_state", {
			"badges": [{"region": "kanto", "badgeId": "boulder", "earned": true}],
		})
		_check(
			(misty.call("_missing_required_badges") as Array).is_empty(),
			"Misty unlocks after the Boulder Badge"
		)

	root.remove_child(map)
	map.free()
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
