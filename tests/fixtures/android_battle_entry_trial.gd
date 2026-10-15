extends RefCounted
## Offline request boundary; production host, BattleState, intro, UI and router.
const CASES := ["covered_wild", "early_wild", "preview_trainer"]
const MOVE_INDEX = preload("res://data/move_summary_index.json")
const MOVE_NAMES := ["Flamethrower", "Thunderbolt", "Rock Slide", "Draco Meteor"]
const MOVE_KEYS := ["flamethrower", "thunderbolt", "rockslide", "dracometeor"]
class OfflineBattle extends "res://scripts/battle/battle.gd":
	var lead_response := {}
	var selected_slot := 0
	func _submit_lead(_player_id: String, slot: int) -> Dictionary:
		selected_slot = slot
		_apply_api_response(lead_response, false)
		return lead_response
	func _submit_npc_lead() -> Dictionary:
		_apply_api_response(lead_response, false)
		opponent_party_reveal_policy.reveal_active(_get_display_team_data("p2"))
		return lead_response
	func _refresh_wild_opponent_owned_icon(_species: String, _shiny: bool, _id: int) -> void:
		pass # Account-only decoration is outside the offline entry fixture.
	func _schedule_damage_calc_prefetch() -> void:
		pass # No account/network damage-calculator requests in this fixture.
var host: Control
var battle: Control
var stage: Control
var errors: Array[String] = []
var entry := {}
var intro_done := false
var callback_done := false
var late_response := {}

static func moves() -> Array:
	var result := []
	for i in MOVE_NAMES.size():
		var data: Dictionary = MOVE_INDEX.data[["flamethrower", "thunderbolt", "rock-slide", "draco-meteor"][i]]
		result.append({"move": data.name, "id": MOVE_KEYS[i], "pp": data.pp, "maxpp": data.pp,
			"type": data.type, "target": "normal", "disabled": false})
	return result

static func active(side: String, species: String, shiny: bool, slot := 1, shown := true) -> Dictionary:
	return {"ident": side + "a: " + species, "details": species + ", L100" + (", shiny" if shiny else ""),
		"species": species, "shiny": shiny, "level": 100, "condition": "100/100", "hp": 100, "maxHp": 100,
		"active": shown, "metadataSlot": slot}

static func response(own: Array, enemy: Array, preview := false) -> Dictionary:
	return {"success": true, "battleId": "offline-entry-trial", "formatId": "gen9nationaldex",
		"players": {"p1": {"name": "Offline Player"}, "p2": {"name": "Offline Opponent"}},
		"ownTeam": own, "trainerTeam": enemy, "battleOptions": {"teamPreview": preview},
		"requests": {"p1": {"side": {"pokemon": own}, "active": [] if preview else [{"moves": moves()}], "teamPreview": preview},
			"p2": {"side": {"pokemon": enemy}, "teamPreview": preview}},
		"state": {"turn": 1, "ended": false}, "events": []}

func _entry_callback() -> void:
	host.request_reveal()
	await host.wait_until_revealed()
	callback_done = true

func _trainer(player: Pokemon, initial: Dictionary) -> void:
	await battle.setup_trainer_battle_from_response(player,
		{"name": "Offline Trainer", "_battle_sprite_frames": preload("res://assets/npcs/generic_npc_fallback_frames.tres")},
		initial, _entry_callback, &"grass")
	intro_done = true

func _wild(initial: Dictionary) -> void:
	await host.wait_until_revealed()
	if not host.released:
		if not late_response.is_empty(): battle._apply_api_response(late_response, false)
		await battle.play_wild_battle_intro(initial)
	intro_done = true

func mount(tree: SceneTree, kind: String, primary := "Charizard", other := "Dragonite", other_shiny := false) -> void:
	var player := Pokemon.new(primary, 100)
	var opponent := Pokemon.new(other, 100)
	opponent.shiny = other_shiny
	tree.root.get_node("PlayerSave").party.assign([player, opponent])
	host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	tree.root.add_child(host)
	battle = load("res://scenes/battle/battle.tscn").instantiate()
	battle.set_script(OfflineBattle)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(.12, .45, .22))
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE, false, ImageTexture.create_from_image(image))
	stage = battle.animation_router.model_presenter
	entry = {"case": kind, "warmup_enabled": stage.android_move_preparation_enabled(), "prepared": {},
		"previews_have_no_casts": true, "input_held_during_preparation": true, "samples_hidden": true}
	var p1 := active("p1", primary, false)
	var p2 := active("p2", other, other_shiny)
	if kind == "preview_trainer":
		var initial := response([active("p1", primary, false, 1, false), active("p1", other, other_shiny, 2, false)], [active("p2", primary, false, 1, false)], true)
		battle.lead_response = response([active("p1", primary, false, 1, false), active("p1", other, other_shiny, 2)], [active("p2", primary, false)])
		_trainer(player, initial)
	else:
		if kind == "early_wild":
			battle.prepare_pending_entry(&"grass")
			host.reveal_pending_entry()
			for i in 16: await tree.process_frame
			entry.early_visible_before_response = host.fade_progress > 0 and not host.preparation_ready
		var initial := response([p1], [p2])
		if kind == "late_moves_wild":
			late_response = initial.duplicate(true)
			initial.requests.p1.active = []
		if not battle.prepare_wild_battle_from_response(player, opponent, initial, &"grass"):
			errors.append("Normal battle response rejected")
		host.request_reveal()
		_wild(initial)

func finish(tree: SceneTree, timeout_ms := 30000) -> Dictionary:
	var started := Time.get_ticks_msec()
	var chosen := false
	while not intro_done and Time.get_ticks_msec() - started < timeout_ms and is_instance_valid(host) and not host.released:
		if battle.team_preview_lead_selection_active:
			entry.previews_have_no_casts = entry.previews_have_no_casts and stage.android_move_warmup.retained.is_empty()
			if callback_done and not battle.battle_input_locked and not chosen:
				chosen = true
				battle.player_party_grid.party_selected.emit(2) # Actual lead input signal.
		if stage.android_move_warmup.busy:
			var gate_closed: bool = not battle.battle_actions_ready and (host.preparation_ready or host.get_node("Cover").visible)
			entry.input_held_during_preparation = entry.input_held_during_preparation and gate_closed
			for effect in stage.android_move_warmup.retained.values():
				entry.samples_hidden = entry.samples_hidden and not effect.visible
		await tree.process_frame
	entry.ready = intro_done and host.preparation_ready and not host.get_node("Cover").visible and battle.battle_actions_ready and not battle.has_meta("battle_screen_preparing")
	entry.elapsed_ms = Time.get_ticks_msec() - host.mounted_at_msec
	entry.early_arena = host.early_arena_requested
	entry.selected_slot = battle.selected_slot
	entry.available_keys = battle.battle_state.get_available_moves(battle._get_local_state_player_id()).map(func(value): return value.id)
	entry.actors = stage.identities.duplicate()
	entry.warmup = stage.android_move_preparation_metrics.rounds.duplicate(true)
	for key in stage.android_move_warmup.retained:
		entry.prepared[key] = stage.android_move_warmup.retained[key].get_instance_id()
	if not entry.ready: errors.append("Normal intro did not reach first-turn readiness")
	return entry

func close() -> void:
	if is_instance_valid(host):
		host.release()
		host.free()
	host = null
	battle = null
	stage = null
