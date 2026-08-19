extends SceneTree

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pokemon := Pokemon.new("Pikachu", 18)
	pokemon.nickname = "Sparky"
	pokemon.current_hp = 35
	pokemon.max_hp = 50

	var party_scene := load("res://scenes/battle/party_slot.tscn") as PackedScene
	var party_slot := party_scene.instantiate()
	root.add_child(party_slot)
	await process_frame
	party_slot.call("set_pokemon", pokemon)
	var party_name := party_slot.get("name_label") as Label
	_check(party_name != null and party_name.text == "Sparky", "Battle party rail shows nickname")
	_check(str(party_slot.get("current_pokemon_data").get("species", "")) == "Pikachu", "Battle party rail retains canonical species")

	var hud_scene := load("res://scenes/battle/pokemon_hud_panel.tscn") as PackedScene
	var hud := hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("set_pokemon_data", "Pikachu", 18, 35, 50, "", "", false, {}, "Sparky")
	var rows: Array = hud.get("active_info_rows")
	var hud_name := rows[0].get_node_or_null("MarginContainer/VBoxContainer/TopRow/NameContainer/NameLabel") as Label
	_check(hud_name != null and hud_name.text == "Sparky", "Active battle HUD shows nickname")
	var metadata := rows[0].get_meta("battle_hud_data", {}) as Dictionary
	_check(str(metadata.get("species", "")) == "Pikachu", "Active battle HUD metadata retains canonical species")

	party_slot.queue_free()
	hud.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
