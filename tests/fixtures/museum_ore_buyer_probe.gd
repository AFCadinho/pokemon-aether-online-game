extends "res://scripts/world/npcs/museum_ore_buyer_npc.gd"

class SaleStub:
	extends Node
	var calls := 0
	var last_request := ""
	func get_quote() -> Dictionary:
		return {"success": true, "body": {"quoteId": "test-quote", "totalMoney": 10000,
			"items": [{"itemId": "emberite-ore", "name": "Emberite Ore", "quantity": 1, "totalMoney": 10000}]}}
	func sell_all(_quote_id: String, request_id: String) -> Dictionary:
		calls += 1
		last_request = request_id
		return {"success": true, "body": {"sold": true, "totalMoney": 10000}}

var stub := SaleStub.new()
var accepted := false
var offered := false
var last_dialogue := ""

func _init() -> void:
	var look := Node2D.new()
	look.name = "Look"
	add_child(look)
	var sprite_node := AnimatedSprite2D.new()
	sprite_node.name = "AnimatedSprite2D"
	look.add_child(sprite_node)
	var feet := Marker2D.new()
	feet.name = "FeetMarker"
	add_child(feet)
	var area := Area2D.new()
	area.name = "InteractionArea"
	add_child(area)

func _ready() -> void:
	_bind_services()
	set_process(false)
	add_child(stub)

func _ore_service() -> Node:
	return stub

func _sync_position() -> Dictionary:
	return {"success": true}

func _confirm_sale(_quote: Dictionary) -> bool:
	offered = true
	return accepted

func show_dialogue(lines: Array[String] = [], _speaker := "") -> bool:
	last_dialogue = " ".join(lines)
	return true
