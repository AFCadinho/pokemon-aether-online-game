extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const NPC_ID := "kanto_vermilion_city_guild_registrar"
const DIALOGUE_ID := "kanto_vermilion_city_guild_registrar_closed"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	var guard: Variant = city.get_node("Entities/NPCs/GuildRegistrarNPC")
	var collision := city.get_node("Tiles/Collision") as TileMapLayer
	_check(guard != null, "Vermilion places its Guild Registrar")
	_check(guard.npc_id == NPC_ID, "registrar uses its own metadata identity")
	_check(guard.npc_sprite_frames != null, "registrar has overworld sprites")
	_check(not guard.is_gate_open(), "registration passage starts closed even without party requirements")
	_check(not guard.requires_party_pokemon and not guard.requires_staff_role, "guild passage has no unrelated party or staff requirement")

	# Metadata for a normal attendant must never unlock a closed passage.
	var metadata_service := root.get_node("NpcMetadataService")
	var locale := str(metadata_service.call("_get_http_locale"))
	var cache_key := str(metadata_service.call("_get_cache_key", locale, NPC_ID))
	metadata_service.npc_metadata_cache[cache_key] = {
		"success": true,
		"metadata": {
			"id": NPC_ID,
			"name": "Guild Registrar",
			"requiresPartyPokemon": false,
			"requiresStaffRole": false,
			"blockedDialogueId": DIALOGUE_ID,
		},
	}
	root.add_child(city)
	for y in range(18, 21):
		var gate_tile := Vector2(37 * 32 + 16, y * 32 + 16)
		_check(city.get_closed_route_gate_npc(gate_tile) == guard, "registrar blocks entrance row %d" % y)
		_check(city.get_closed_route_gate_npc(gate_tile - Vector2(64, 0)) == null, "public approach row %d remains outside the passage" % y)
	_check(city.get_closed_route_gate_npc(Vector2(1200, 560)) == null, "passage does not extend north of the entrance")
	_check(city.get_closed_route_gate_npc(Vector2(1200, 688)) == null, "passage does not extend south of the entrance")
	_check(not _garden_reachable(collision, guard), "map fences and the full passage prevent walking around the registrar")
	var registrar_position: Vector2 = guard.position
	guard.position += Vector2(-64, 32)
	for y in range(18, 21):
		_check(city.get_closed_route_gate_npc(Vector2(1200, y * 32 + 16)) == guard, "moving the registrar keeps entrance row %d closed" % y)
	_check(not _garden_reachable(collision, guard), "moving the registrar cannot open a route into the garden")
	guard.position = registrar_position
	var response: Dictionary = await guard._load_gate_metadata()
	_check(bool(response.get("success", false)), "registrar metadata loads")
	_check(guard.display_name == "Guild Registrar" and guard.blocked_dialogue_id == DIALOGUE_ID, "registrar adopts its metadata name and dialogue")
	_check(not guard.is_gate_open(), "loading metadata keeps the passage closed")
	guard.transition_access_resolved = true
	guard.transition_access = {"allowed": true}
	guard._sync_guard_presence()
	_check(guard.visible and guard.guard_present, "closed passage retains its visible registrar even with allowed transition metadata")
	_check(not guard.is_gate_open(), "transition metadata cannot open the unfinished registration passage")

	# The explicit closure leaves the existing gate-opening behavior reusable.
	guard.passage_closed = false
	_check(guard.is_gate_open(), "removing the explicit closure restores ordinary gate access")
	_check(city.get_closed_route_gate_npc(Vector2(1200, 592)) == null, "open passage releases its side tiles")
	_check(_garden_reachable(collision, guard), "garden can be reached when the passage opens")
	city.free()
	metadata_service.clear_cache()
	print("VERMILION_GUILD_GARDEN_GATE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _garden_reachable(collision: TileMapLayer, guard: Node2D) -> bool:
	var bounds := collision.get_used_rect()
	var start := Vector2i(35, 19)
	var target := Vector2i(48, 18)
	var visited := {start: true}
	var pending: Array[Vector2i] = [start]
	var cursor := 0
	var npc_cell := collision.local_to_map(collision.to_local(guard.global_position))
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		if cell == target:
			return true
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := cell + direction
			if not bounds.has_point(next) or visited.has(next) or next == npc_cell:
				continue
			if collision.get_cell_source_id(next) != -1:
				continue
			var feet := Vector2(next * 32 + Vector2i(16, 16))
			if bool(guard.call("guards_world_position", feet)):
				continue
			visited[next] = true
			pending.append(next)
	return false


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + label)
