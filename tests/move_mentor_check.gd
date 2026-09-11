extends SceneTree

class NotificationOverlay extends Node:
	var system_messages: Array[String] = []
	var move_notifications: Array[Dictionary] = []
	var removed_items: Array[Dictionary] = []

	func add_system_message(message: String) -> void:
		system_messages.append(message)

	func add_pokemon_move_reward_notification(pokemon_context: Dictionary, move_value: Variant) -> void:
		move_notifications.append({
			"pokemon": pokemon_context.duplicate(true),
			"move": (move_value as Dictionary).duplicate(true) if move_value is Dictionary else {},
		})

	func add_removed_item_system_message(item_id: String, quantity: int) -> void:
		removed_items.append({"itemId": item_id, "quantity": quantity})

const CENTER_PATHS: Array[String] = [
	"res://scenes/overworld/kanto/towns/viridian_city/pokemon_center.tscn",
	"res://scenes/overworld/kanto/towns/pewter_city/pokemon_center.tscn",
	"res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn",
	"res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn",
]
const POPUP_PATH := "res://scenes/interface/move_mentor_popup.tscn"
const NPC_PATH := "res://scenes/npcs/move_mentor_npc.tscn"
const PARTY_SERVICE_PATH := "res://scripts/services/player_party_state_service.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const REQUIRED_SOURCES: Array[String] = [
	"relearn",
	"evolution",
	"egg",
	"tutor",
	"special",
	"event",
	"legacy",
	"legacyEvent",
	"preEvolution",
]

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
		var mentor := center.get_node_or_null("Entities/NPCs/MoveManiac")
		_check(
			mentor != null
				and mentor.get_script() != null
				and str(mentor.get_script().resource_path) == "res://scripts/world/npcs/move_mentor_npc.gd",
			"%s inherits the Move Maniac" % path
		)
		_check(
			mentor != null
				and mentor.position == Vector2(368, 400)
				and mentor.get("facing_direction") == Vector2.DOWN
				and int(mentor.get("manual_interaction_reach_tiles")) == 2,
			"%s keeps the Move Maniac reachable across the desk" % path
		)
		center.free()


func _check_npc_scene() -> void:
	var scene_source := FileAccess.get_file_as_string(NPC_PATH)
	_check(scene_source.contains("NPC_084_Poke_Maniac.png"), "Move Maniac uses the official Poké Maniac overworld look")
	var packed := load(NPC_PATH) as PackedScene
	_check(packed != null, "Move Maniac NPC scene loads")
	if packed == null:
		return
	var npc := packed.instantiate()
	_check(npc != null, "Move Maniac NPC uses its dedicated behavior")
	if npc != null:
		_check(str(npc.get("npc_definition_id")) == "pokemon_center_move_mentor", "Move Maniac uses shared NPC metadata")
		var interaction_shape := npc.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
		_check(
			interaction_shape != null
				and interaction_shape.shape is RectangleShape2D
				and (interaction_shape.shape as RectangleShape2D).size.y >= 96.0,
			"Move Maniac detects players across a two-tile-deep desk"
		)
		npc.free()


func _check_popup_scene() -> void:
	var packed := load(POPUP_PATH) as PackedScene
	_check(packed != null, "Move Mentor popup scene loads")
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
	preview_pokemon.moves = [{"id": "water-shuriken", "name": "Water Shuriken", "pp": 20, "maxPp": 20}]
	var preview_party := player_save.get("party") as Array
	preview_party.clear()
	preview_party.append(preview_pokemon)
	popup.set("selected_party_index", 0)
	popup.call("_refresh_party_list")
	popup.call("_refresh_current_moves")
	await process_frame
	var source_filter := popup.get("source_filter") as OptionButton
	var learn_button := popup.get("learn_button") as Button
	var party_list := popup.get("party_list") as VBoxContainer
	var current_moves_list := popup.get("current_moves_list") as VBoxContainer
	_check(
		party_list != null and _count_texture_rects(party_list) >= 3,
		"Move Mentor party cards show Pokémon portraits and type icons"
	)
	_check(
		current_moves_list != null and _count_texture_rects(current_moves_list) >= 2,
		"Move Mentor current-move cards show type and damage-category icons"
	)
	_check(source_filter != null and source_filter.item_count == REQUIRED_SOURCES.size() + 1, "Move Mentor lists every source filter")
	_check(
		source_filter != null
			and source_filter.get_theme_icon("arrow") != null
			and source_filter.get_popup().get_theme_stylebox("panel") is StyleBoxFlat,
		"Move Mentor source filter uses the themed dropdown and popup"
	)
	var preview_candidates: Array = popup.get("candidates") as Array
	preview_candidates.append({
		"moveId": "water-pulse",
		"name": "Water Pulse",
		"source": "tutor",
		"cost": {"itemId": "resonite-ore", "quantity": 1, "ownedQuantity": 1},
	})
	popup.call("_refresh_move_list")
	await process_frame
	var move_list := popup.get("move_list") as VBoxContainer
	_check(
		move_list != null and _count_texture_rects(move_list) >= 2,
		"Move Mentor move cards show type and damage-category icons"
	)
	var catalog_stats := move_list.find_child("MoveStats_water-pulse", true, false) as Label
	_check(
		catalog_stats != null
			and catalog_stats.text.contains("PP 20")
			and catalog_stats.text.contains("BP 60")
			and catalog_stats.text.contains("ACC 100")
			and catalog_stats.custom_minimum_size.x >= 140.0,
		"Move Mentor catalog keeps PP, base power, and accuracy visibly readable"
	)
	var catalog_cost := move_list.find_child("MoveCost_water-pulse", true, false) as PanelContainer
	var catalog_price := (
		catalog_cost.find_child("MoveCostPrice", true, false) as Label
		if catalog_cost != null
		else null
	)
	_check(
		catalog_cost != null
			and catalog_cost.custom_minimum_size.x >= 58.0
			and catalog_price != null
			and catalog_price.text == "×1"
			and catalog_cost.tooltip_text.contains("Resonite Ore"),
		"Move Mentor catalog shows a compact price beside every move"
	)
	preview_pokemon.moves = [
		{"id": "water-shuriken", "name": "Water Shuriken", "pp": 20, "maxPp": 20},
		{"id": "hydro-pump", "name": "Hydro Pump", "pp": 5, "maxPp": 5},
		{"id": "ice-beam", "name": "Ice Beam", "pp": 10, "maxPp": 10},
		{"id": "dark-pulse", "name": "Dark Pulse", "pp": 15, "maxPp": 15},
	]
	popup.call("_refresh_current_moves")
	popup.call("_on_move_selected", "water-pulse")
	await process_frame
	_check(not learn_button.disabled, "Move Mentor enables Teach move before choosing a replacement")
	_check(
		learn_button.text.contains("1")
			and learn_button.icon == null
			and learn_button.text.contains("1"),
		"Move Mentor Teach button shows the selected resource cost"
	)
	var first_current_move := current_moves_list.get_child(0) as Button
	_check(
		first_current_move != null
			and first_current_move.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and first_current_move.pressed.get_connections().is_empty(),
		"Current moves remain informational until Teach move is pressed"
	)
	popup.call("_on_learn_pressed")
	await process_frame
	var replacement_dialog := popup.get_node_or_null("MoveMentorReplacementDialog") as AetherConfirmationDialog
	_check(replacement_dialog != null and replacement_dialog.visible, "A full moveset opens the replacement dialog")
	if replacement_dialog != null:
		var new_move_preview := replacement_dialog.find_child("NewMovePreview", true, false) as VBoxContainer
		var new_move_card := replacement_dialog.find_child("NewMoveHoverCard", true, false) as Button
		_check(
			new_move_preview != null
				and new_move_card != null
				and _count_texture_rects(new_move_preview) >= 2,
			"Replacement dialog previews the new move with type and category icons"
		)
		_check(
			new_move_card != null
				and new_move_card.tooltip_text.contains("Water Pulse")
				and new_move_card.tooltip_text.contains("Type:")
				and new_move_card.tooltip_text.contains("Category:")
				and new_move_card.tooltip_text.contains("Source:")
				and new_move_card.tooltip_text.contains("PP "),
			"Hovering the new move exposes its complete move details"
		)
		var replacement_grid := replacement_dialog.find_child("ReplacementMoveGrid", true, false) as GridContainer
		_check(
			replacement_grid != null and replacement_grid.get_child_count() == 4,
			"Replacement dialog offers all four current moves"
		)
		_check(replacement_dialog.confirm_button.disabled, "Replacement confirmation starts disabled")
		if replacement_grid != null and replacement_grid.get_child_count() > 0:
			(replacement_grid.get_child(0) as Button).pressed.emit()
			_check(not replacement_dialog.confirm_button.disabled, "Choosing a current move enables confirmation")
		replacement_dialog.canceled.emit()
		await process_frame
	var notification_overlay := NotificationOverlay.new()
	notification_overlay.add_to_group("ui_overlay")
	root.add_child(notification_overlay)
	popup.call(
		"_announce_learned_move",
		{"pokemonId": 42, "species": "Greninja", "nickname": "Ninja", "shiny": false},
		{"moveId": "water-pulse", "name": "Water Pulse", "type": "water"},
		{"id": "water-shuriken", "name": "Water Shuriken"},
		"Ninja",
		"Water Pulse"
	)
	_check(
		notification_overlay.system_messages.size() == 1
			and notification_overlay.system_messages[0].contains("Ninja")
			and notification_overlay.system_messages[0].contains("Water Pulse")
			and notification_overlay.system_messages[0].contains("Water Shuriken"),
		"Move Mentor replacement adds a system message"
	)
	_check(
		notification_overlay.move_notifications.size() == 1
			and int(notification_overlay.move_notifications[0].pokemon.get("pokemonId", 0)) == 42
			and str(notification_overlay.move_notifications[0].move.get("moveId", "")) == "water-pulse"
			and str(notification_overlay.move_notifications[0].move.get("type", "")) == "water",
		"Move Mentor lesson adds a top-right learned-move card"
	)
	popup.call("_announce_consumed_items", [{"itemId": "heart-scale", "quantity": 1}])
	_check(
		notification_overlay.removed_items == [{"itemId": "heart-scale", "quantity": 1}],
		"Move Mentor reports its server-confirmed item payment"
	)
	notification_overlay.queue_free()
	var popup_source := FileAccess.get_file_as_string("res://scripts/ui/move_mentor_popup.gd")
	for source: String in REQUIRED_SOURCES:
		_check(popup_source.contains('\t"%s",' % source), "Move Mentor includes %s moves" % source)
	_check(not popup_source.contains('\t"tm",'), "Move Mentor keeps TM moves in the machine flow")
	popup.visible = true
	_check(popup.visible, "Move Mentor popup opens")
	popup.set("selected_move_id", "")
	popup.call("_refresh_action_state")
	_check(learn_button != null and learn_button.disabled, "Move Mentor requires a move selection")
	preview_party.clear()
	preview_party.append_array(original_party)
	if created_player_save:
		player_save.queue_free()
	popup.queue_free()
	await process_frame


func _count_texture_rects(node: Node) -> int:
	var count := 1 if node is TextureRect else 0
	for child: Node in node.get_children():
		count += _count_texture_rects(child)
	return count


func _check_service_contract() -> void:
	var service_source := FileAccess.get_file_as_string(PARTY_SERVICE_PATH)
	_check(
		service_source.contains('"/game/pokemon/%s/moves/mentor"')
			and service_source.contains('payload["learnSource"] = learn_source')
			and service_source.contains('"consumedItems": _array_from_value(body.get("consumedItems", []))'),
		"party service submits the explicit mentor source and preserves confirmed item costs"
	)
	var error_service_source := FileAccess.get_file_as_string(
		"res://scripts/services/backend_error_localization_service.gd"
	)
	_check(
		error_service_source.contains(
			'"move_mentor_resource_required": "backend.error.move_mentor_resource_required"'
		),
		"Move Mentor resource errors use the localized backend error path"
	)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check(load(UI_OVERLAY_PATH) != null, "UI overlay parses with the Move Mentor integration")
	_check(
		overlay_source.contains("func open_move_mentor()")
			and overlay_source.contains("_activate_ui_panel(move_mentor_popup)"),
		"UI overlay opens the Move Mentor as a movement-blocking window"
	)


func _check_localization() -> void:
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var path := "res://localization/%s.json" % locale
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary, "%s Move Mentor localization parses" % locale)
		if not parsed is Dictionary:
			continue
		var catalog := parsed as Dictionary
		for key: String in [
			"ui.move_mentor.title",
			"ui.move_mentor.replace_dialog.title",
			"ui.move_mentor.replace_dialog.message",
			"ui.move_mentor.replace_dialog.new_move",
			"ui.move_mentor.replace_dialog.confirm",
			"ui.move_mentor.tooltip.source",
			"ui.move_mentor.status.learned",
			"ui.move_mentor.status.cost",
			"ui.move_mentor.status.resource_required",
			"ui.move_mentor.cost.tooltip",
			"ui.npc.cost.item_removed",
			"ui.move_mentor.source.relearn",
			"ui.move_mentor.npc.service_unavailable",
		]:
			_check(catalog.has(key), "%s contains %s" % [locale, key])


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
