extends SceneTree

const PARTY_HOVER_SCENE := preload("res://scenes/battle/party_hover_card.tscn")

var failures := 0


func _init() -> void:
	var card := PARTY_HOVER_SCENE.instantiate() as PartyHoverCard
	card.set_show_storage_details(true)
	root.add_child(card)
	await process_frame

	_check(
		is_equal_approx(card.custom_minimum_size.y, PartyHoverCard.STORAGE_CARD_HEIGHT),
		"Storage hover cards reserve one stable height"
	)
	var iv_grid := card.get_node_or_null(
		"MarginContainer/VBoxContainer/IVDetailsContainer/IVGrid"
	) as GridContainer
	_check(iv_grid != null, "Storage hover details present IVs as a compact grid")
	if iv_grid != null:
		_check(iv_grid.columns == 6, "The IV grid keeps all six stats aligned")

	card.show_for_pokemon({
		"species": "Blastoise",
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
	_check(
		is_equal_approx(populated_height, PartyHoverCard.STORAGE_CARD_HEIGHT),
		"A fully populated Storage hover card stays at the fixed height"
	)
	if iv_grid != null:
		var hp_value := iv_grid.get_node_or_null("HpValue") as Label
		var speed_value := iv_grid.get_node_or_null("SpeValue") as Label
		_check(
			hp_value != null and hp_value.text == "31"
			and speed_value != null and speed_value.text == "31",
			"The IV grid displays the supplied values"
		)

	card.show_for_pokemon({
		"species": "Blastoise",
		"types": ["water"],
		"hp": 1,
		"maxHp": 1,
		"ivs": {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
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
