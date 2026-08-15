extends SceneTree

const PEWTER_SCENE := "res://scenes/overworld/kanto/towns/pewter_city/pewter_gym.tscn"
const GYM_LEADER_SCENE := "res://scenes/npcs/gym_leader_npc.tscn"
const GYM_LEADER_SCRIPT := "res://scripts/world/npcs/gym_leader_npc.gd"
const GYM_LEADER_DEFINITION_SCRIPT := "res://scripts/world/npcs/gym_leader_definition.gd"
const GYM_LEADER_DEFINITIONS := [
	"res://resources/npcs/gym_leaders/alpha_brock.tres",
	"res://resources/npcs/gym_leaders/alpha_misty.tres",
	"res://resources/npcs/gym_leaders/alpha_lt_surge.tres",
]

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ResourceLoader.exists(GYM_LEADER_SCENE), "reusable Gym Leader NPC scene exists")
	_check(ResourceLoader.exists(GYM_LEADER_DEFINITION_SCRIPT), "typed Gym Leader definition exists")
	for definition_path: String in GYM_LEADER_DEFINITIONS:
		_check(ResourceLoader.exists(definition_path), "%s exists" % definition_path.get_file())
		var definition := load(definition_path)
		_check(definition != null, "%s loads" % definition_path.get_file())
	var leader_source := FileAccess.get_file_as_string(GYM_LEADER_SCRIPT)
	_check(leader_source.contains("extends TrainerNPC"), "Gym Leader reuses the trainer battle flow")
	_check(leader_source.contains("GymLeaderDefinition"), "Gym Leader consumes a typed definition")
	_check(leader_source.contains("required_badge_ids"), "Gym Leader supports ordered badge trials")
	_check(leader_source.contains("dialogue_rematch"), "Gym Leader supports badge-aware rematch dialogue")

	var packed := load(PEWTER_SCENE) as PackedScene
	_check(packed != null, "Pewter Gym scene loads")
	if packed == null:
		quit(1)
		return

	var map := packed.instantiate()
	root.add_child(map)
	await process_frame

	var expected := {
		"GymLeaderBrock": ["kanto_alpha_gym_brock", "boulder"],
	}
	var leaders: Dictionary = {}
	var collision := map.get_node_or_null("Collision") as TileMapLayer
	_check(collision != null, "Pewter City collision layer is available")
	for node_name: String in expected:
		var leader := map.get_node_or_null("Entities/NPCs/%s" % node_name)
		_check(leader != null, "%s is placed in Pewter Gym" % node_name)
		if leader == null:
			continue
		leaders[node_name] = leader
		var values: Array = expected[node_name]
		_check(leader.get("npc_profile") != null, "%s uses a bundled NPC profile" % node_name)
		_check(str(leader.get("trainer_id")) == str(values[0]), "%s uses its server trainer id" % node_name)
		_check(str(leader.get("badge_id")) == str(values[1]), "%s advertises its canonical badge" % node_name)
		_check(int(leader.get("sight_range_tiles")) == 0, "%s starts only through deliberate interaction" % node_name)
		if collision != null:
			var cell := collision.local_to_map(collision.to_local(leader.global_position))
			_check(
				collision.get_cell_source_id(cell) == -1,
				"%s stands on a walkable tile" % node_name
			)

	_check(
		map.get_node_or_null("Entities/NPCs/AlphaGymMisty") == null
		and map.get_node_or_null("Entities/NPCs/AlphaGymLtSurge") == null,
		"Pewter City only places its local Gym Leader"
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
