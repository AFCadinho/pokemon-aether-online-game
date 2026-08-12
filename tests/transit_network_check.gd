extends SceneTree

const MAP_CONTRACTS := {
	"res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn": [
		'position = Vector2(720, 560)',
		'local_destination_id = "kanto_pallet_town"',
	],
	"res://scenes/overworld/kanto/towns/viridian_city/viridian_city.tscn": [
		'position = Vector2(1200, 1488)',
		'local_destination_id = "kanto_viridian_city"',
	],
	"res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn": [
		'position = Vector2(1488, 1584)',
		'local_destination_id = "kanto_pewter_city"',
	],
}

var failures := 0


func _init() -> void:
	for scene_path: String in MAP_CONTRACTS:
		var source := FileAccess.get_file_as_string(scene_path)
		_check(source.contains('[node name="TransitArrival"'), "%s has TransitArrival" % scene_path)
		_check(source.contains('[node name="TransitKeeper"'), "%s has TransitKeeper" % scene_path)
		for expected: String in MAP_CONTRACTS[scene_path]:
			_check(source.contains(expected), "%s contains %s" % [scene_path, expected])

	var lobby_source := FileAccess.get_file_as_string(
		"res://scenes/overworld/aether_clash/aether_clash_lobby.tscn"
	)
	_check(lobby_source.contains('[node name="TransitKeeper"'), "Aether Clash Lobby has a Transit Keeper")

	var texture := load(
		"res://assets/npcs/gen5-g4-ow-sprites/OW PACK/trPsychic_M.png"
	) as Texture2D
	_check(texture != null and texture.get_size() == Vector2(256, 256), "Transit Keeper uses the selected 4x4 overworld sheet")
	var keeper_source := FileAccess.get_file_as_string(
		"res://scripts/world/npcs/transit_keeper_npc.gd"
	)
	_check(keeper_source.contains("TransitService.attune"), "Transit Keeper attunes through the server")
	_check(keeper_source.contains("begin_authorized_teleport"), "Transit Keeper uses the authorized teleport flow")
	_check(keeper_source.contains("PlayerWalletService.apply_wallet_result"), "Transit travel updates the local wallet projection")

	if failures == 0:
		print("Transit network checks passed.")
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures += 1
	push_error("FAIL: %s" % label)
