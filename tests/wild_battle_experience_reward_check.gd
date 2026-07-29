extends SceneTree

var failures := 0


func _init() -> void:
	var world := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var wallet := FileAccess.get_file_as_string("res://scripts/services/player_wallet_service.gd")
	_check(world.contains("_notify_reward_experience_gains(reward)"), "wild reward announces applied experience")
	_check(world.contains('"ui.world.reward.exp"'), "system message localizes Pokémon and EXP amount")
	_check(world.contains('entry.get("pokemonId", 0)'), "experience message resolves the rewarded Pokemon")
	_check(world.contains('entry.get("progression", {})'), "experience message prefers authoritative progression species")
	_check(wallet.contains("PlayerSave.replace_party_from_state(party)"), "reward applies authoritative party experience")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
