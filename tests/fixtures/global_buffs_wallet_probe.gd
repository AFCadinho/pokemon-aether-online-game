extends "res://scripts/services/player_wallet_service.gd"

signal reply
signal base_reply
var requests: Array[String] = []
var responses: Array = []
var delayed := false
var delayed_base := false

func _ready() -> void:
	pass

func _global_buffs_base_url() -> String:
	if delayed_base:
		await base_reply
	return "https://fixture.invalid"

func _request_json(url: String, _method: HTTPClient.Method, _headers: PackedStringArray, _body: String) -> Dictionary:
	requests.append(url)
	if delayed:
		await reply
	return responses.pop_front()
