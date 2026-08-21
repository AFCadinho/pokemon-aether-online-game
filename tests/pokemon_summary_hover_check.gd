extends SceneTree

const OVERLAY_SCENE_PATH := "res://scenes/interface/ui_overlay.tscn"
var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(OVERLAY_SCENE_PATH) as PackedScene
	_check(packed != null, "Pokémon Summary scene loads")
	if packed == null:
		quit(1)
		return

	var overlay := packed.instantiate()
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	overlay.set("root_control", host)
	overlay.call("_setup_pokemon_summary_popup", "normal-hover-check")
	var popup := overlay.get("pokemon_summary_popup") as PanelContainer
	var nodes := popup.get_meta("summary_hover_nodes", {}) as Dictionary
	var detail_hover := nodes.get("detail_hover_panel") as PanelContainer
	var move_hover := nodes.get("move_hover_panel") as PanelContainer
	_check(not nodes.is_empty(), "normal Summary owns the shared hover layer")
	_check(detail_hover != null and detail_hover.mouse_filter == Control.MOUSE_FILTER_IGNORE, "detail hover does not block Summary controls")
	_check(move_hover != null and move_hover.mouse_filter == Control.MOUSE_FILTER_IGNORE, "move hover does not block move interactions")

	var ability_card := overlay.call(
		"_create_summary_field_card",
		"Ability",
		"Volt Absorb",
		Color("#ffb15f"),
		false,
		148.0,
		Color(0, 0, 0, 0),
		Color(0, 0, 0, 0),
		"Absorbs Electric moves, healing for 1/4 max HP."
	) as Control
	(overlay.get("pokemon_summary_content_stack") as VBoxContainer).add_child(ability_card)
	_check(ability_card.tooltip_text == "", "normal Summary ability no longer opens a native tooltip")
	_check(ability_card.mouse_entered.has_connections(), "normal Summary ability opens the shared hover card")
	_check(_descendants_ignore_mouse(ability_card), "ability value controls leave hover handling to the complete card")
	overlay.call("_show_readonly_summary_detail_hover", ability_card, nodes)
	_check(detail_hover.visible, "normal Summary ability hover is visible")
	_check((detail_hover.find_children("*", "Label", true, false)[0] as Label).text == "Volt Absorb", "normal Summary ability hover shows the selected value")
	overlay.call("_hide_readonly_summary_detail_hover", nodes)

	var pokemon := Pokemon.new(
		"Zeraora", 100, "", "volt-absorb", "Jolly", {}, {},
		{"hp": 186, "atk": 180, "def": 140, "spa": 160, "spd": 140, "spe": 220},
		[], "life-orb", 7, false, false, ["electric"], ["volt-absorb"], "Route 1", {}
	)
	var happiness_card := overlay.call(
		"_create_summary_metric_card",
		"Happiness",
		"Happiness: 180 / 255",
		180,
		255,
		Color("#f2cf78"),
		148.0
	) as Control
	(overlay.get("pokemon_summary_content_stack") as VBoxContainer).add_child(happiness_card)
	_check(happiness_card.tooltip_text == "" and happiness_card.mouse_entered.has_connections(), "Happiness uses the compact hover card")
	_check(_descendants_ignore_mouse(happiness_card), "the complete Happiness metric is hoverable")
	overlay.call("_show_readonly_summary_detail_hover", happiness_card, nodes)
	_check((detail_hover.find_children("*", "Label", true, false)[0] as Label).text == "Happiness", "Happiness hover has a clear title")
	overlay.call("_hide_readonly_summary_detail_hover", nodes)

	var experience_card := overlay.call("_create_summary_experience_metric_card", pokemon, Color("#62d7ff"), 148.0) as Control
	(overlay.get("pokemon_summary_content_stack") as VBoxContainer).add_child(experience_card)
	_check(experience_card.tooltip_text == "" and experience_card.mouse_entered.has_connections(), "EXP uses the compact hover card")
	_check(_descendants_ignore_mouse(experience_card), "the complete EXP metric is hoverable")
	overlay.call("_show_readonly_summary_detail_hover", experience_card, nodes)
	_check((detail_hover.find_children("*", "Label", true, false)[0] as Label).text == "EXP", "EXP hover has a clear title")
	overlay.call("_hide_readonly_summary_detail_hover", nodes)

	var move_value := {
		"id": "plasma-fists",
		"name": "Plasma Fists",
		"type": "electric",
		"category": "physical",
		"power": 100,
		"accuracy": 100,
		"pp": 15,
		"maxPp": 15,
		"description": "The user attacks with electrically charged fists."
	}
	var move_card := PanelContainer.new()
	move_card.custom_minimum_size = Vector2(300, 50)
	(overlay.get("pokemon_summary_content_stack") as VBoxContainer).add_child(move_card)
	overlay.call(
		"_set_pokemon_summary_move_hover",
		move_card,
		move_value,
		"The user attacks with electrically charged fists."
	)
	_check(move_card.tooltip_text == "", "normal Summary move no longer opens a native tooltip")
	_check(move_card.mouse_entered.has_connections(), "normal Summary move opens the shared hover card")
	overlay.call("_show_readonly_summary_move_hover", move_card, nodes)
	_check(move_hover.visible, "normal Summary move hover is visible")
	_check((move_hover.find_children("*", "Label", true, false)[0] as Label).text == "Plasma Fists", "normal Summary move hover shows the selected move")
	_check(not move_card.has_meta("readonly_base_style"), "normal Summary moves do not require read-only style metadata")
	overlay.call("_hide_readonly_summary_move_hover", move_card, nodes)
	_check(not move_hover.visible, "normal Summary move hover closes without read-only style metadata")

	overlay.call("_set_pokemon_summary_ball_button", pokemon)
	overlay.call("_set_pokemon_summary_held_item_slot", pokemon)
	var ball_button := overlay.get("pokemon_summary_ball_button") as Button
	var item_button := overlay.get("pokemon_summary_held_item_slot_button") as Button
	_check(ball_button.tooltip_text == "" and ball_button.mouse_entered.has_connections(), "normal Summary Poké Ball uses the shared hover card")
	_check(item_button.tooltip_text == "" and item_button.mouse_entered.has_connections(), "normal Summary held item uses the shared hover card")

	overlay.set("pokemon_summary_active_tab", "general")
	overlay.call("_render_pokemon_summary_content", pokemon)
	_check(not move_hover.visible, "changing Summary content closes an open move hover")

	for loader_property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader := overlay.get(loader_property) as Node
		if loader != null:
			loader.free()
	overlay.free()
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _descendants_ignore_mouse(source: Control) -> bool:
	for child: Node in source.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return false
		if child is Control and not _descendants_ignore_mouse(child as Control):
			return false
	return true
