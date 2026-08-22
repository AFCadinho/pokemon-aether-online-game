extends SceneTree

const BASE_NPC_SCRIPT := "res://scripts/world/npcs/base_npc.gd"
const TRAINER_NPC_SCRIPT := "res://scripts/world/npcs/trainer_npc.gd"
const TRANSIT_KEEPER_SCRIPT := "res://scripts/world/npcs/transit_keeper_npc.gd"

var failed := false


func _init() -> void:
	var base_npc := FileAccess.get_file_as_string(BASE_NPC_SCRIPT)
	var trainer_npc := FileAccess.get_file_as_string(TRAINER_NPC_SCRIPT)
	var transit_keeper := FileAccess.get_file_as_string(TRANSIT_KEEPER_SCRIPT)

	_check(
		base_npc.contains("func _loads_pickpocket_profile_from_npc_metadata() -> bool:")
		and base_npc.contains("not _loads_pickpocket_profile_from_npc_metadata()"),
		"ordinary dialogue NPCs can load server-owned pickpocket profiles"
	)
	_check(
		_has_pickpocket_metadata_opt_out(trainer_npc),
		"trainers do not request unrelated generic NPC metadata"
	)
	_check(
		_has_pickpocket_metadata_opt_out(transit_keeper),
		"Transit Keepers do not request unused generic NPC metadata"
	)

	quit(1 if failed else 0)


func _has_pickpocket_metadata_opt_out(source: String) -> bool:
	var marker := "func _loads_pickpocket_profile_from_npc_metadata() -> bool:"
	var start := source.find(marker)
	if start < 0:
		return false
	var next_function := source.find("\nfunc ", start + marker.length())
	var block := source.substr(start) if next_function < 0 else source.substr(start, next_function - start)
	return block.contains("return false")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		push_error("FAIL %s" % label)
