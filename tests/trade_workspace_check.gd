extends SceneTree

const Workspace := preload("res://scripts/ui/trade_workspace.gd")

var failed := false


func _init() -> void:
	var candidates := Workspace.collect_candidates(
		[{"ownedPokemonId":11,"speciesId":"pidgey","level":12}],
		[{"boxIndex":2,"slots":[{"slotIndex":4,"pokemon":{"id":22,"pokemon":{"speciesId":"rattata","level":8}}}]}]
	)
	_check(candidates.size() == 2, "party and box candidates collected")
	_check(candidates[0].get("pokemonId", 0) == 11, "party identity preserved")
	_check(candidates[0].get("location", {}).get("type", "") == "party", "party location")
	_check(candidates[1].get("location", {}).get("boxIndex", -1) == 2, "box location")
	var workspace := Workspace.new()
	_check(workspace._pokemon_label({"nickname":null, "speciesName":null, "speciesId":"rattata", "level":4}) == "rattata  Lv. 4", "null nickname falls back to species id")
	workspace.trade = {"tradeId":"trade-1"}
	workspace.offer_draft_dirty = true
	_check(not workspace._should_sync_selected_from_offer("trade-1", "active"), "active polling preserves an unsaved offer draft")
	_check(workspace._should_sync_selected_from_offer("trade-2", "active"), "new trade synchronizes offer selection")
	workspace.free()
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_workspace.gd")
	_check(not source.contains("Leave Trade"), "workspace has no separate leave button")
	_check(source.contains("close_requested.connect(_on_close_requested)"), "window close owns authoritative trade leave")
	_check(source.contains("str(trade.get(\"status\", \"\")) in [\"active\", \"locked\"]"), "only open trades are cancelled by window close")
	_check(source.contains("func _ready() -> void:\n\thide()"), "workspace starts hidden without an active trade")
	_check(source.contains("replace_offer"), "workspace uses complete replacement")
	_check(source.contains("Send Offer"), "workspace distinguishes draft selection from server offer submission")
	_check(source.contains("Both players must send at least one Pokemon"), "workspace explains disabled Ready state")
	_check(source.contains("PlayerPartyStateService"), "workspace reuses party service")
	_check(source.contains("PokemonStorageService"), "workspace reuses storage service")
	_check(source.contains("Ready"), "readiness control")
	_check(source.contains("Edit Offer"), "explicit edit control")
	_check(source.contains("lockedReview"), "server locked review rendering")
	_check(source.contains("You give") and source.contains("You receive"), "immutable exchange labels")
	_check(source.contains("Confirm Trade"), "locked review confirmation control")
	_check(source.contains("lockedRevision") and source.contains("snapshotHash"), "confirmation references immutable review")
	_check(not source.contains("or not realtime.connected"), "websocket status does not block authoritative trade commands")
	_check(not source.contains("owner_user_id"), "client does not perform ownership settlement")
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
