extends "res://scripts/world/kanto/towns/shiny_mount_collector.gd"

var accept_trade := true
var choice_count := 0
var shown_dialogue: Array[String] = []

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func show_dialogue(lines: Array[String] = [], _speaker_name_override := "") -> bool:
	shown_dialogue.append_array(lines)
	return true

func _choose_offer(offers: Array, _page: int, _credit: int) -> String:
	choice_count += 1
	return str(offers[0]["itemId"]) if choice_count == 1 else ""

func _confirm_exchange(_offer: Dictionary, _credit: int) -> bool:
	return accept_trade
