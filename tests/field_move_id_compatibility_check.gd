extends SceneTree

const MoveIdResolverScript := preload("res://scripts/data/move_id_resolver.gd")

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := root.get_node("FieldMoveService")
	var player_save := root.get_node("PlayerSave")
	var localization_manager := root.get_node("LocalizationManager")
	var content_localization := root.get_node("ContentLocalization")
	var party: Array = player_save.get("party") as Array
	var original_party := party.duplicate()
	var original_hms: Dictionary = service.get("owned_hm_item_ids").duplicate(true)
	var original_charms: Dictionary = service.get("owned_charm_moves").duplicate(true)

	_check(
		MoveIdResolverScript.equivalent("rocksmash", "rock-smash"),
		"compact Showdown and canonical Rock Smash IDs are equivalent"
	)
	_check(
		MoveIdResolverScript.equivalent("Ancient Power", "ancient-power"),
		"display names and canonical IDs are equivalent for general moves"
	)
	_check(
		MoveIdResolverScript.value_matches({"moveId": "vcreate"}, "v-create"),
		"alternate move ID fields use the same resolver"
	)

	party.clear()
	party.append(Pokemon.new(
		"Trumbeak",
		5,
		"",
		"",
		"Hardy",
		{},
		{},
		{},
		[{"id": "rocksmash", "name": "Rock Smash"}]
	))
	service.set("owned_hm_item_ids", {"hm-rock-smash": true})
	service.set("owned_charm_moves", {})

	var available: Dictionary = service.call("can_use_field_move", "rock-smash")
	_check(bool(available.get("success", false)), "legacy compact move IDs work as field moves")
	_check(available.get("source", "") == "pokemon", "the matching Pokémon remains the move source")

	party.clear()
	var unavailable: Dictionary = service.call("can_use_field_move", "rock-smash")
	var expected_message: String = localization_manager.call(
		"text",
		"ui.field_move.error.unavailable",
		{
			"move": content_localization.call(
				"display_name",
				"moves",
				"rock-smash",
				"Rock Smash"
			)
		}
	)
	_check(unavailable.get("errorCode", "") == "field_move_not_known", "missing moves return a stable error code")
	_check(unavailable.get("error", "") == expected_message, "missing move messages use localization")

	party.append_array(original_party)
	service.set("owned_hm_item_ids", original_hms)
	service.set("owned_charm_moves", original_charms)
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
