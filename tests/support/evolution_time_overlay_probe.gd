extends "res://scripts/ui/ui_overlay.gd"

var transport: Node
var fixture_pokemon := Pokemon.new("Rockruff", 25)
var rendered_prompt: Dictionary = {}
var messages: Array[String] = []


func _request_developer_evolution_candidates(pokemon_id: int) -> Dictionary:
	return await transport.get_evolution_candidates(pokemon_id)


func _find_party_pokemon_by_owned_id(_pokemon_id: int) -> Pokemon:
	return fixture_pokemon


func _render_evolution_prompt(prompt: Dictionary) -> void:
	rendered_prompt = prompt.duplicate(true)
	evolution_prompt_popup.visible = true


func _refresh_utc_time_label(_delta: float, _force := false) -> void:
	pass


func _refresh_dev_world_time_selector() -> void:
	pass


func _add_chat_message(text: String, _use_bbcode: bool = false, _category: String = CHAT_CATEGORY_SYSTEM) -> void:
	messages.append(text)
