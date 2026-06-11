extends RefCounted

class_name BattleHoverState

var pokemon_info_request: HTTPRequest
var pokemon_stats_request: HTTPRequest
var current_sprite_hover_player_id := ""
var current_hover_pokemon_ident := ""
var is_hud_slot_hover_active := false
var request_token := 0


func setup(info_request: HTTPRequest, stats_request: HTTPRequest) -> void:
	pokemon_info_request = info_request
	pokemon_stats_request = stats_request


func set_sprite_hover_player(player_id: String) -> void:
	current_sprite_hover_player_id = player_id


func get_sprite_hover_player() -> String:
	return current_sprite_hover_player_id


func begin_hud_hover(ident: String) -> void:
	is_hud_slot_hover_active = true
	current_sprite_hover_player_id = ""
	current_hover_pokemon_ident = ident


func end_hud_hover() -> void:
	is_hud_slot_hover_active = false
	current_hover_pokemon_ident = ""


func should_poll_sprite_hover() -> bool:
	return not is_hud_slot_hover_active


func begin_hover_request() -> int:
	request_token += 1
	cancel_requests()
	return request_token


func invalidate_hover() -> void:
	current_sprite_hover_player_id = ""
	current_hover_pokemon_ident = ""
	request_token += 1
	cancel_requests()


func is_hover_request_current(token: int, hover_ident: String, owner_player_id: String) -> bool:
	if token != request_token:
		return false
	if is_hud_slot_hover_active:
		return current_hover_pokemon_ident == hover_ident

	return current_sprite_hover_player_id == owner_player_id


func cancel_requests() -> void:
	if pokemon_info_request != null:
		pokemon_info_request.cancel_request()
	if pokemon_stats_request != null:
		pokemon_stats_request.cancel_request()
