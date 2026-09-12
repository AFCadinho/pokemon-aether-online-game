extends SceneTree

const LAB_SCENE := "res://scenes/overworld/kanto/towns/pallet_town/oaks_lab.tscn"
const GARY_SCENE := "res://scenes/npcs/oaks_lab_gary.tscn"
const GARY_FRAMES := "res://assets/npcs/gary_sprite_frames.tres"
const GARY_SHEET := "res://assets/npcs/Ultimate Gen 4 Overworlds Pack/All Official Overworlds/NPC_179_Champion_Blue_Oak.png"
const GARY_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/oaks_lab_gary.gd"
const OAK_SCRIPT := "res://scripts/world/kanto/towns/pallet_town/oak.gd"
const STARTER_BALL_SCRIPT := "res://scripts/world/interactables/starter_poke_ball.gd"
const WORLD_SCRIPT := "res://scripts/world/world.gd"
const BASE_NPC_SCRIPT := "res://scripts/world/npcs/base_npc.gd"
const GAME_STATE_SCRIPT := "res://scripts/core/game_state.gd"
const UI_OVERLAY_SCRIPT := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab_resource := load(LAB_SCENE) as PackedScene
	_check_true(lab_resource != null, "Oak's Lab scene loads with starter balls")
	_check_true(load(GARY_SCENE) is PackedScene, "Oak's Lab Gary scene loads")
	var gary_frames := load(GARY_FRAMES) as SpriteFrames
	_check_true(gary_frames != null, "Gary's shared SpriteFrames resource loads")
	if gary_frames != null:
		var idle_texture := gary_frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
		_check_true(
			idle_texture != null
			and idle_texture.atlas != null
			and idle_texture.atlas.resource_path == GARY_SHEET,
			"Gary's runtime SpriteFrames use the assigned Champion Blue Oak sheet"
		)
		for animation_name: StringName in [
			&"idle_down", &"idle_left", &"idle_right", &"idle_up",
			&"walk_down", &"walk_left", &"walk_right", &"walk_up",
		]:
			_check_true(
				gary_frames.has_animation(animation_name),
				"Gary provides the %s animation" % animation_name
			)
	var lab_text := _read_text(LAB_SCENE)
	_check_true(lab_text.contains('name="LeftBulbasaur"'), "left ball contains Bulbasaur")
	_check_true(lab_text.contains('name="MiddleSquirtle"'), "middle ball contains Squirtle")
	_check_true(lab_text.contains('name="RightCharmander"'), "right ball contains Charmander")
	var gary_text := _read_text(GARY_SCRIPT)
	_check_true(gary_text.contains("_walk_to_world_position"), "Gary walks to his selected ball")
	_check_true(
		gary_text.contains('var options: Dictionary = await PlayerPartyStateService.get_starter_options()'),
		"Gary recovers missing automatic starter handoff metadata"
	)
	_check_true(gary_text.contains('selected_ball.call("set_claimed", true)'), "Gary removes his selected ball")
	_check_true(
		gary_text.contains("var reached_player := await _walk_next_to_player(player)")
		and gary_text.contains("continuing the challenge from the starter table"),
		"A blocked player approach does not abort Gary's departure scene"
	)
	_check_true(
		gary_text.contains("STARTER_DEPARTURE_DIALOGUE_ID")
		and not gary_text.contains('"start_trainer_battle"'),
		"Gary dismisses the player instead of starting an immediate battle"
	)
	_check_true(
		gary_text.contains("play_parcel_return_departure")
		and gary_text.contains("ROUTE_22_DEPARTURE_DIALOGUE_ID")
		and gary_text.contains("parcel_departure_pending"),
		"Gary stays present through the parcel scene and then announces Route 22"
	)
	_check_true(
		gary_text.contains("_set_story_presence(false)"),
		"Gary leaves the lab after each departure scene"
	)
	_check_true(
		gary_text.contains("func blocks_world_position(world_position: Vector2) -> bool:")
		and gary_text.contains("if not visible:")
		and gary_text.contains("return super.blocks_world_position(world_position)"),
		"Gary releases his occupied tile whenever he is absent"
	)
	var oak_text := _read_text(OAK_SCRIPT)
	_check_true(
		oak_text.contains('StoryService.is_requirement_met("choose_starter", "talk_to_father", "completed")'),
		"Oak requires the player to complete Dadinho's introduction before offering a starter"
	)
	_check_true(
		oak_text.contains('var create_result: Dictionary = await give_starter_pokemon(selected_species_id)')
		and not oak_text.contains('complete_web_demo_oak_intro')
		and not oak_text.contains('Parcel delivery is outside the bounded browser demo')
		and oak_text.contains('return await super._run_story_or_legacy_interaction(body, trigger)'),
		"browser Oak uses the canonical story hook and starter claim"
	)
	_check_true(
		gary_text.contains("starter_sequence_pending")
		and gary_text.contains("func prepare_starter_sequence()")
		and oak_text.contains("_prepare_gary_starter_sequence()"),
		"Gary stays visible while the starter claim hands off to his turn"
	)
	_check_true(
		gary_text.contains("func is_starter_sequence_active() -> bool:")
		and gary_text.contains("return starter_sequence_pending or starter_sequence_running"),
		"Gary exposes the complete pending and running starter sequence window"
	)
	_check_true(
		gary_text.contains("GameState.acquire_overworld_input_lock(STARTER_SEQUENCE_INPUT_LOCK)")
		and gary_text.contains("GameState.release_overworld_input_lock(STARTER_SEQUENCE_INPUT_LOCK)")
		and gary_text.contains("GameState.acquire_ui_input_lock(STARTER_SEQUENCE_INPUT_LOCK)")
		and gary_text.contains("GameState.release_ui_input_lock(STARTER_SEQUENCE_INPUT_LOCK)"),
		"Gary owns the overworld and UI input locks throughout his starter walk and dialogue"
	)
	var game_state_text := _read_text(GAME_STATE_SCRIPT)
	_check_true(
		game_state_text.contains("func acquire_ui_input_lock(owner_id: StringName) -> void:")
		and game_state_text.contains("func release_ui_input_lock(owner_id: StringName) -> void:"),
		"UI input locks preserve independent owners during nested dialogue"
	)
	var ui_overlay_text := _read_text(UI_OVERLAY_SCRIPT)
	_check_true(
		ui_overlay_text.contains('ui_input_mouse_blocker.name = "UIInputMouseBlocker"')
		and ui_overlay_text.contains("ui_input_mouse_blocker.mouse_filter = Control.MOUSE_FILTER_STOP")
		and ui_overlay_text.contains("var should_block := GameState.is_ui_input_locked()"),
		"The HUD consumes mouse clicks while story UI input is locked"
	)
	_check_true(
		oak_text.contains("func _run_story_or_legacy_interaction(body: Node2D, trigger: String)")
		and oak_text.contains('"status": "gary_starter_sequence_active"')
		and oak_text.contains("return await super._run_story_or_legacy_interaction(body, trigger)"),
		"Oak blocks both parcel story hooks and normal dialogue until Gary has left"
	)
	_check_true(
		gary_text.contains('if parcel_status == "active":')
		and gary_text.contains('_set_story_presence(_is_parcel_return_active())'),
		"Active parcel progress keeps Gary hidden until the return step"
	)
	_check_true(oak_text.contains("_schedule_gary_starter_sequence(player, create_result)"), "Oak hands the new-starter flow to Gary")
	_check_true(
		oak_text.contains('gary.call("prepare_parcel_return_departure")')
		and oak_text.contains('gary.call("play_parcel_return_departure", player)'),
		"Oak keeps Gary staged throughout the completed parcel scene"
	)
	var starter_ball_text := _read_text(STARTER_BALL_SCRIPT)
	_check_true(
		starter_ball_text.contains("selection_stand_offset := Vector2(0, 32)"),
		"starter balls keep Gary on the table-facing row"
	)
	var gary_scene_text := _read_text(GARY_SCENE)
	_check_true(
		gary_scene_text.contains('region = Rect2(80, 0, 387, 387)')
		and gary_scene_text.contains('mugshot = SubResource("gary_mugshot_crop")'),
		"Gary's tall artwork is cropped around his head and shoulders for dialogue"
	)
	_check_true(
		gary_scene_text.contains("facing_direction = Vector2(0, 1)")
		and gary_scene_text.contains('animation = &"idle_down"'),
		"Gary initially faces down beside Oak"
	)
	var base_npc_text := _read_text(BASE_NPC_SCRIPT)
	_check_true(
		base_npc_text.contains("if not _is_player_facing_npc(nearby_player):")
		and base_npc_text.contains("manual_interaction_reach_tiles := 1")
		and base_npc_text.contains("player_tile + cardinal_direction * distance == npc_tile"),
		"NPC interaction remains cardinal with a one-tile default reach"
	)
	if lab_resource != null:
		_check_staging_tiles(lab_resource)
	quit(1 if failed else 0)


func _check_staging_tiles(lab_resource: PackedScene) -> void:
	var lab := lab_resource.instantiate()
	var collision := lab.get_node_or_null("Collision") as TileMapLayer
	_check_true(collision != null, "Oak's Lab exposes its collision layer")
	if collision != null:
		var gary := lab.get_node_or_null("Entities/NPCs/Gary") as Node2D
		_check_true(gary != null, "Gary exists beside Oak")
		_check_true(gary != null and gary.global_position == Vector2(432, 784), "Gary starts beside Oak")
		if gary != null:
			gary.visible = false
			_check_true(
				not bool(gary.call("blocks_world_position", gary.global_position)),
				"Gary's tile becomes walkable after he leaves"
			)
			gary.visible = true
		var staging_positions: Array[Vector2] = []
		if gary != null:
			staging_positions.append(gary.global_position)
		var oak := lab.get_node_or_null("Entities/NPCs/Oak") as Node2D
		var occupied_npc_tiles: Array[Vector2i] = []
		if oak != null:
			occupied_npc_tiles.append(collision.local_to_map(collision.to_local(oak.global_position)))
		for ball_name: String in ["LeftBulbasaur", "MiddleSquirtle", "RightCharmander"]:
			var ball := lab.get_node_or_null("Entities/Interactables/StarterBalls/%s" % ball_name) as Node2D
			_check_true(ball != null, "%s exists on Oak's table" % ball_name)
			if ball != null:
				var stand_position := ball.global_position + Vector2(0, 32)
				_check_true(stand_position.y == 720.0, "%s keeps Gary on the table-facing row" % ball_name)
				staging_positions.append(stand_position)
		for world_position: Vector2 in staging_positions:
			var tile := collision.local_to_map(collision.to_local(world_position))
			_check_true(collision.get_cell_source_id(tile) == -1, "Gary staging tile %s is walkable" % world_position)
			_check_true(tile not in occupied_npc_tiles, "Gary staging tile %s is not occupied by Oak" % world_position)
	lab.free()


func _read_text(path: String) -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	return "" if file == null else file.get_as_text()


func _check_true(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
