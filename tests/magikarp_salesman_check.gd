extends SceneTree

const CENTER_PATH := "res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn"

var failed := false


func _init() -> void:
	var center_source := FileAccess.get_file_as_string(CENTER_PATH)
	_check(center_source.contains('instance=ExtResource("6_salesman")'), "Route 3 places the specialized Magikarp salesman")
	_check(center_source.contains('npc_id = "kanto_route_3_pokemon_center_magikarp_salesman"'), "salesman uses its content identity")
	var salesman_scene_source := FileAccess.get_file_as_string("res://scenes/npcs/magikarp_salesman_npc.tscn")
	_check(salesman_scene_source.contains('script = ExtResource("2_script")'), "salesman scene owns its purchase behavior")

	var service_source := FileAccess.get_file_as_string("res://scripts/services/npc_pokemon_sale_service.gd")
	_check(service_source.contains("/game/npc-pokemon-sales/%s/purchase"), "client calls the authoritative purchase endpoint")
	_check(service_source.contains("PlayerPartyStateService.refresh_party()"), "successful purchase refreshes the party")

	var npc_source := FileAccess.get_file_as_string("res://scripts/world/npcs/magikarp_salesman_npc.gd")
	_check(npc_source.contains('@export var sale_id := "kanto_route_3_magikarp"'), "salesman uses the one-time Route 3 sale")
	_check(npc_source.contains("AetherConfirmationDialog"), "salesman asks for confirmation before charging")
	_check(npc_source.contains('SfxManager.play("npc_shop_purchase")'), "salesman plays the NPC purchase sound after delivery")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failed = true
		printerr("FAIL %s" % label)
