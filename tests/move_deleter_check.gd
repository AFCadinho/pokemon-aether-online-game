extends SceneTree

const CENTER_PATHS: Array[String] = [
	"res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn",
	"res://scenes/overworld/kanto/towns/pewter_city/pokemon_center.tscn",
	"res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn",
]
const NPC_PATH := "res://scenes/npcs/move_deleter_npc.tscn"
const POPUP_PATH := "res://scenes/interface/move_deleter_popup.tscn"
const PARTY_SERVICE_PATH := "res://scripts/services/player_party_state_service.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_center_instances()
	_check_npc_scene()
	await _check_popup_scene()
	_check_service_contract()
	_check_localization()
	quit(1 if failed else 0)


func _check_center_instances() -> void:
	for path: String in CENTER_PATHS:
		var packed := load(path) as PackedScene
		_check(packed != null, "%s loads" % path)
		if packed == null:
			continue
		var center := packed.instantiate()
		var deleter := center.get_node_or_null("Entities/NPCs/MoveDeleter")
		_check(
			deleter != null
				and deleter.position == Vector2(656, 464)
				and deleter.get("facing_direction") == Vector2.LEFT,
			"%s keeps the editor-positioned Move Deleter separately approachable" % path
		)
		center.free()


func _check_npc_scene() -> void:
	var scene_source := FileAccess.get_file_as_string(NPC_PATH)
	_check(scene_source.contains("NPC_036_Gentleman.png"), "Move Deleter uses a distinct calm Gentleman look")
	var packed := load(NPC_PATH) as PackedScene
	_check(packed != null, "Move Deleter NPC scene loads")
	if packed == null:
		return
	var npc := packed.instantiate()
	_check(
		npc != null
			and str(npc.get("npc_definition_id")) == "pokemon_center_move_deleter"
			and str(npc.get("display_name")) == "Move Deleter",
		"Move Deleter uses its shared specialist metadata"
	)
	if npc != null:
		var interaction := npc.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
		_check(
			interaction != null
				and interaction.shape is RectangleShape2D
				and (interaction.shape as RectangleShape2D).size == Vector2(48, 48),
			"Move Deleter uses a normal direct interaction area"
		)
		npc.free()


func _check_popup_scene() -> void:
	var packed := load(POPUP_PATH) as PackedScene
	_check(packed != null, "Move Deleter popup scene loads")
	if packed == null:
		return
	var popup := packed.instantiate()
	root.add_child(popup)
	await process_frame
	var player_save := root.get_node_or_null("PlayerSave")
	var created_player_save := false
	if player_save == null:
		player_save = load("res://scripts/data/player_data.gd").new()
		player_save.name = "PlayerSave"
		root.add_child(player_save)
		created_player_save = true
	var original_party: Array = (player_save.get("party") as Array).duplicate()
	var preview_pokemon := Pokemon.new("Greninja", 26)
	preview_pokemon.types = ["water", "dark"]
	preview_pokemon.moves = [
		{"id": "water-shuriken", "name": "Water Shuriken", "pp": 20, "maxPp": 20},
		{"id": "dark-pulse", "name": "Dark Pulse", "pp": 15, "maxPp": 15},
	]
	var preview_party := player_save.get("party") as Array
	preview_party.clear()
	preview_party.append(preview_pokemon)
	popup.call("open_deleter")
	await process_frame
	var party_list := popup.get("party_list") as VBoxContainer
	var move_list := popup.get("move_list") as GridContainer
	var delete_button := popup.get("delete_button") as Button
	_check(party_list != null and _count_texture_rects(party_list) >= 3, "Move Deleter shows Pokémon portrait and types")
	_check(move_list != null and move_list.get_child_count() == 2 and _count_texture_rects(move_list) >= 4, "Move Deleter shows all current moves with icons")
	_check(delete_button != null and delete_button.disabled, "Move deletion requires a move selection")
	popup.call("_on_move_selected", 0)
	await process_frame
	_check(not delete_button.disabled, "Selecting a move enables the destructive action")
	popup.call("_on_delete_pressed")
	await process_frame
	var confirmation := popup.get_node_or_null("MoveDeleterConfirmation") as AetherConfirmationDialog
	_check(confirmation != null and confirmation.visible, "Move deletion always opens a confirmation dialog")
	if confirmation != null:
		_check(confirmation.message_label.text.contains("Water Shuriken"), "Confirmation names the move being forgotten")
		_check(confirmation.message_label.text.contains("cannot be undone"), "Confirmation warns that forgetting cannot be undone")
		confirmation.canceled.emit()
		await process_frame
	preview_pokemon.moves = [{"id": "dark-pulse", "name": "Dark Pulse", "pp": 15, "maxPp": 15}]
	popup.set("selected_move_slot", -1)
	popup.call("_refresh_moves")
	await process_frame
	_check(delete_button.disabled, "Move Deleter never enables removal of the final move")
	preview_party.clear()
	preview_party.append_array(original_party)
	if created_player_save:
		player_save.queue_free()
	popup.queue_free()
	await process_frame


func _check_service_contract() -> void:
	var service_source := FileAccess.get_file_as_string(PARTY_SERVICE_PATH)
	_check(
		service_source.contains('"/game/pokemon/%s/moves/delete"')
			and service_source.contains('JSON.stringify({"moveSlot": move_slot, "moveId": move_id})')
			and service_source.contains('"deletedMove"'),
		"Party service submits and applies the authoritative move deletion"
	)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(load(UI_OVERLAY_PATH) != null, "UI overlay parses with Move Deleter integration")
	_check(
		overlay_source.contains("func open_move_deleter()")
			and overlay_source.contains("_activate_ui_panel(move_deleter_popup)"),
		"UI overlay opens Move Deleter as a movement-blocking window"
	)


func _check_localization() -> void:
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var path := "res://localization/%s.json" % locale
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "%s Move Deleter localization parses" % locale)
		if not parsed is Dictionary:
			continue
		var catalog := parsed as Dictionary
		for key: String in [
			"ui.move_deleter.title",
			"ui.move_deleter.status.last_move",
			"ui.move_deleter.confirm.message",
			"ui.move_deleter.result.deleted",
			"ui.move_deleter.npc.service_unavailable",
		]:
			_check(catalog.has(key), "%s contains %s" % [locale, key])


func _count_texture_rects(node: Node) -> int:
	var count := 1 if node is TextureRect else 0
	for child: Node in node.get_children():
		count += _count_texture_rects(child)
	return count


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
