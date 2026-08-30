extends SceneTree

const PARTY_HOVER_SCENE := preload("res://scenes/battle/party_hover_card.tscn")

var failures := 0


func _init() -> void:
	var card := PARTY_HOVER_SCENE.instantiate() as PartyHoverCard
	card.set_show_storage_details(true)
	root.add_child(card)
	await process_frame

	var iv_details := card.get_node_or_null(
		"MarginContainer/VBoxContainer/IVDetailsContainer"
	) as Control
	var ev_details := card.get_node_or_null(
		"MarginContainer/VBoxContainer/EVValueLabel"
	) as Control
	_check(iv_details != null and not iv_details.visible, "Storage hover cards hide IV details")
	_check(ev_details != null and not ev_details.visible, "Storage hover cards hide EV details")
	var stats := card.get_node("MarginContainer/VBoxContainer/StatsBoxContainer")
	for stat_row_name: String in ["AttackContainer", "DefContainer", "SpAContainer", "SpDContainer", "SpeContainer"]:
		var stat_row := stats.get_node(stat_row_name) as HBoxContainer
		_check(
			stat_row.get_theme_constant("separation") == PartyHoverCard.STORAGE_STAT_VALUE_SEPARATION,
			"Storage hover %s separates its stat label and value" % stat_row_name
		)

	card.show_for_pokemon({
		"species": "Blastoise",
		"level": 100,
		"types": ["water"],
		"hp": 299,
		"maxHp": 299,
		"ability": "Torrent",
		"nature": "Hardy",
		"stats": {"atk": 202, "def": 236, "spa": 206, "spd": 246, "spe": 192},
		"evs": {"hp": 4},
		"ivs": {"hp": 31, "atk": 31, "def": 31, "spa": 31, "spd": 31, "spe": 31},
		"moves": ["Mud-Slap", "Powder Snow", "Ice Shard", "Leech Seed"],
	})
	await process_frame
	card.size.y = 0.0
	card.reset_size()
	var populated_height := card.size.y
	var name_label := card.get_node("MarginContainer/VBoxContainer/NameLabel") as Label
	_check(name_label.text.contains("Blastoise"), "Storage hover cards show the Pokémon name")
	_check(name_label.text.contains("Lv. 100"), "Storage hover cards show the Pokémon level")
	_check(not iv_details.visible and not ev_details.visible, "Storage hover details stay hidden after data updates")
	_check(
		is_equal_approx(populated_height, PartyHoverCard.STORAGE_CARD_HEIGHT),
		"A fully populated Storage hover card stays at the fixed height"
	)
	var safe_bounds := Rect2(100, 100, 640, 320)
	card.position_beside_rect_within(Rect2(210, 210, 118, 80), safe_bounds)
	var positioned_rect := card.get_global_rect()
	_check(
		positioned_rect.position.x >= safe_bounds.position.x
			and positioned_rect.position.y >= safe_bounds.position.y
			and positioned_rect.end.x <= safe_bounds.end.x
			and positioned_rect.end.y <= safe_bounds.end.y,
		"Storage hover cards stay inside their navigation-safe bounds"
	)

	card.show_for_pokemon({
		"species": "Blastoise",
		"level": 50,
		"types": ["water"],
		"hp": 1,
		"maxHp": 1,
	})
	await process_frame
	card.size.y = 0.0
	card.reset_size()
	_check(
		is_equal_approx(card.size.y, populated_height),
		"Storage hover height stays fixed across different Pokémon details"
	)

	card.free()
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
