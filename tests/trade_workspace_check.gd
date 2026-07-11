extends SceneTree

const Workspace := preload("res://scripts/ui/trade_workspace.gd")

var failed := false


func _init() -> void:
	var candidates := Workspace.collect_candidates(
		[{"ownedPokemonId":11,"speciesId":"pidgey","level":12}]
	)
	_check(candidates.size() == 1, "only party candidates are collected")
	_check(candidates[0].get("pokemonId", 0) == 11, "party identity preserved")
	_check(candidates[0].get("location", {}).get("type", "") == "party", "party location")
	var workspace := Workspace.new()
	_check(workspace._pokemon_label({"nickname":null, "speciesName":null, "speciesId":"rattata", "level":4}) == "rattata  Lv. 4", "null nickname falls back to species id")
	var rendered_slot := workspace._create_offer_slot()
	workspace.selected_ids.assign([11])
	workspace._render_offer_slot(rendered_slot, {"pokemonId":11,"speciesId":"pidgey","speciesName":"Pidgey","level":12}, true, 0)
	_check(rendered_slot.get_child_count() == 1, "filled offer slot builds its styled content")
	rendered_slot.free()
	_check(Workspace.build_drop_replacement([11], 12, -1, 2) == [11, 12], "drop appends within capacity")
	_check(Workspace.build_drop_replacement([11], 12, 0, 1) == [12], "drop onto occupied slot replaces it")
	_check(Workspace.build_drop_replacement([11], 12, -1, 1) == [11], "drop cannot exceed recipient capacity")
	_check(Workspace.build_drop_replacement([11], 11, 0, 5) == [11], "duplicate drop is harmless")
	_check(Workspace.normalize_summary_payload({"pokemonId":11,"speciesId":"pidgey"}).get("species", "") == "pidgey", "public offer identity opens readonly summary")
	workspace.trade = {"tradeId":"trade-1", "revision":3, "lastEventSeq":4}
	_check(not workspace._trade_snapshot_changed({"tradeId":"trade-1", "revision":3, "lastEventSeq":4}), "identical active snapshot does not refresh candidates")
	_check(workspace._trade_snapshot_changed({"tradeId":"trade-1", "revision":4, "lastEventSeq":5}), "changed active snapshot refreshes candidates")
	workspace.free()
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_workspace.gd")
	_check(not source.contains("Leave Trade"), "workspace has no separate leave button")
	_check(source.contains("close_requested.connect(_on_close_requested)"), "window close owns authoritative trade leave")
	_check(source.contains("borderless = true") and source.contains("close_button.pressed.connect(_on_close_requested)"), "workspace uses custom chrome without changing close semantics")
	_check(source.contains("str(trade.get(\"status\", \"\")) in [\"active\", \"locked\"]"), "only open trades are cancelled by window close")
	_check(source.contains("func _ready() -> void:\n\thide()"), "workspace starts hidden without an active trade")
	_check(source.contains("replace_offer"), "workspace uses complete replacement")
	_check(not source.contains("CheckButton"), "workspace no longer renders toggle candidates")
	_check(not source.contains("Send Offer"), "valid drops immediately replace the authoritative offer")
	_check(source.contains("try_offer_party_drop"), "workspace accepts party-slot drops")
	_check(source.contains("_main_to_workspace_position"), "drop hit testing converts main viewport coordinates into the trade window")
	_check(source.contains("begin_party_offer_drag") and source.contains("update_party_offer_drag"), "trade window renders its own drag preview")
	_check(source.contains("local_offer_slots") and source.contains("opponent_offer_slots"), "workspace renders two stable offer boxes")
	_check(source.contains("open_trade_pokemon_summary"), "offered Pokemon open the shared readonly summary")
	_check(source.contains("hide_for_pokemon_summary") and source.contains("restore_after_pokemon_summary"), "trade window yields to the shared summary and restores afterward")
	_check(source.contains("_local_offer_nonempty"), "Ready depends only on the local participant offer")
	_check(source.contains("opponent_ready_indicator") and source.contains("_opponent_participant_ready"), "workspace shows authoritative opponent readiness")
	_check(source.contains("Offer at least one Pokemon before becoming Ready"), "workspace explains local Ready requirement")
	_check(source.contains("func _trade_snapshot_changed"), "candidate refresh is gated by authoritative snapshot changes")
	_check(source.contains("PlayerPartyStateService"), "workspace reuses party service")
	_check(not source.contains("PokemonStorageService"), "PC storage is excluded from trade selection and settlement refresh")
	_check(source.contains("partyCount"), "workspace limits offers by opponent free party slots")
	_check(source.contains("Ready"), "readiness control")
	_check(source.contains("Edit Offer"), "explicit edit control")
	_check(source.contains("lockedReview"), "server locked review rendering")
	_check(source.contains("You give") and source.contains("You receive"), "immutable exchange labels")
	_check(source.contains("Confirm Trade"), "locked review confirmation control")
	_check(source.contains("lockedRevision") and source.contains("snapshotHash"), "confirmation references immutable review")
	_check(not source.contains("or not realtime.connected"), "websocket status does not block authoritative trade commands")
	_check(not source.contains("owner_user_id"), "client does not perform ownership settlement")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(overlay_source.contains("_try_offer_party_drag_to_trade"), "party drag delegates offer drops before party reordering")
	_check(overlay_source.contains("party_drag_workspace_preview"), "party drag preview is hosted above the trade window")
	_check(overlay_source.contains("trade_summary_card_keys") and overlay_source.contains("_restore_trade_workspace_after_summary"), "closing a trade summary restores the trade window")
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
