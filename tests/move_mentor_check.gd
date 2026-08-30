extends SceneTree

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
		var mentor := center.get_node_or_null("Entities/NPCs/MoveMentor")
		_check(
			mentor != null
				and mentor.get_script() != null
				and str(mentor.get_script().resource_path) == "res://scripts/world/npcs/move_mentor_npc.gd",
			"%s inherits the Move Mentor" % path
		)
		_check(
			mentor != null
				and mentor.position == Vector2(368, 400)
				and mentor.get("facing_direction") == Vector2.DOWN
				and int(mentor.get("manual_interaction_reach_tiles")) == 2,
			"%s keeps the Move Mentor reachable across the desk" % path
		)
		center.free()


func _check_npc_scene() -> void:
	var packed := load(NPC_PATH) as PackedScene
	_check(packed != null, "Move Mentor NPC scene loads")
	if packed == null:
		return
	var npc := packed.instantiate()
	_check(npc != null, "Move Mentor NPC uses its dedicated behavior")
	if npc != null:
		_check(str(npc.get("npc_definition_id")) == "pokemon_center_move_mentor", "Move Mentor uses shared NPC metadata")
		var interaction_shape := npc.get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
		_check(
			interaction_shape != null
				and interaction_shape.shape is RectangleShape2D
				and (interaction_shape.shape as RectangleShape2D).size.y >= 96.0,
			"Move Mentor detects players across a two-tile-deep desk"
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
	var source_filter := popup.get("source_filter") as OptionButton
	var learn_button := popup.get("learn_button") as Button
	_check(source_filter != null and source_filter.item_count == REQUIRED_SOURCES.size() + 1, "Move Mentor lists every source filter")
	var popup_source := FileAccess.get_file_as_string("res://scripts/ui/move_mentor_popup.gd")
	for source: String in REQUIRED_SOURCES:
		_check(popup_source.contains('\t"%s",' % source), "Move Mentor includes %s moves" % source)
	_check(not popup_source.contains('\t"tm",'), "Move Mentor keeps TM moves in the machine flow")
	popup.visible = true
	_check(popup.visible, "Move Mentor popup opens")
	_check(learn_button != null and learn_button.disabled, "Move Mentor requires a Pokémon and move selection")
	popup.queue_free()
	await process_frame


func _check_service_contract() -> void:
	var service_source := FileAccess.get_file_as_string(PARTY_SERVICE_PATH)
	_check(
		service_source.contains('"/game/pokemon/%s/moves/mentor"')
			and service_source.contains('payload["learnSource"] = learn_source'),
		"party service loads the mentor catalog and submits the explicit mentor source"
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
			"ui.move_mentor.status.learned",
			"ui.move_mentor.source.relearn",
			"ui.move_mentor.npc.service_unavailable",
		]:
			_check(catalog.has(key), "%s contains %s" % [locale, key])


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
