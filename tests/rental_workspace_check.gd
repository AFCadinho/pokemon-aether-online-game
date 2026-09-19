extends SceneTree

const WORKSPACE := preload("res://scripts/ui/rental_workspace.gd")

class FakeRentalService extends Node:
	func request(_path: String, _payload: Dictionary = {}, _mutate := false) -> Dictionary:
		return {"success": true, "body": {"displayName": "Scizor", "buyoutTotal": 1000, "pokemon": [{"speciesId": "scizor", "nature": "Adamant", "ability": "technician", "item": "", "moves": ["bullet-punch"], "ivs": {"atk": 31}}]}}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var workspace := WORKSPACE.new()
	root.add_child(workspace)
	workspace.catalog = {"offers": [{"offerId": "test", "displayName": "Test Team", "pokemon": []}], "rentals": []}
	workspace._filter()
	workspace._render_active()
	assert(workspace.listing.item_count == 1)
	workspace.service.queue_free()
	workspace.service = FakeRentalService.new()
	workspace.add_child(workspace.service)
	workspace.kind = "pokemon"
	await workspace._select(0)
	assert(not workspace.rent_button.disabled)
	assert(workspace.description.text.contains("No item"))
	assert(workspace.description.text.contains("bullet-punch"))
	assert(workspace.description.text.contains("1000 Aetherite"))
	workspace.search.text = "missing"
	workspace._filter()
	assert(workspace.listing.item_count == 0)
	assert(workspace.rent_button.disabled)
	workspace.queue_free()
	var npc: PackedScene = load("res://scenes/npcs/rental_npc.tscn")
	assert(npc != null)
	print("PASS rental workspace builds, filters and locks unselected purchases")
	quit(0)
