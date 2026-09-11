extends SceneTree

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BASE_NPC_SCRIPT_PATH := "res://scripts/world/npcs/base_npc.gd"
const TRAINER_NPC_SCRIPT_PATH := "res://scripts/world/npcs/trainer_npc.gd"
const BOSS_NPC_SCRIPT_PATH := "res://scripts/world/npcs/boss_battle_npc.gd"
const BATTLE_ANIMATION_ROUTER_PATH := "res://scripts/battle/battle_animation_router.gd"
const BattleTrainerScene := preload("res://scenes/battle/battle_trainer_sprite.tscn")
const BattleRenderLayers := preload("res://scripts/battle/battle_render_layers.gd")
const NPC_FRAMES := preload("res://assets/npcs/generic_npc_fallback_frames.tres")
const PortraitCatalogScript := preload("res://scripts/services/trainer_portrait_catalog.gd")

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_check_scene_staging()
	_check_battle_setup_contract()
	_check_npc_metadata_contract()
	await _check_runtime_renderer()
	quit(1 if failed else 0)


func _check_scene_staging() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var player_start := source.find('[node name="PlayerTrainerSprite"')
	var enemy_start := source.find('[node name="EnemyTrainerSprite"')
	var platform_start := source.find('[node name="BattlePlatform"')
	_check(player_start >= 0, "player overworld trainer marker exists")
	_check(enemy_start >= 0, "opponent overworld trainer marker exists")
	_check(player_start < platform_start and enemy_start < platform_start, "trainers render behind both platforms")
	_check(source.contains("position = Vector2(124, 474)"), "player trainer stands slightly above the player platform baseline")
	_check(source.contains("position = Vector2(1028, 316)"), "opponent trainer mirrors the raised staging")
	_check(source.contains('[node name="EnemySpriteBox"') and source.contains("z_index = 2"), "active Pokemon render above trainer art")
	_check(source.contains("position = Vector2(300, 412)"), "player team preview remains in its original position")
	_check(source.contains("position = Vector2(850, 268)"), "opponent team preview remains in its original position")


func _check_battle_setup_contract() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(source.contains("show_player(PlayerSave.to_appearance_state(), Vector2.RIGHT)"), "local trainer faces right toward the opponent")
	_check(source.contains('players.get("p1", {}), Vector2.RIGHT)'), "spectator near-side trainer also faces right")
	var wild_prepare_start := source.find("func prepare_wild_battle_from_response(")
	var wild_prepare_end := source.find("\nfunc ", wild_prepare_start + 1)
	var wild_prepare_source := source.substr(wild_prepare_start, wild_prepare_end - wild_prepare_start)
	var wild_intro_start := source.find("func play_wild_battle_intro(")
	var wild_intro_end := source.find("\nfunc ", wild_intro_start + 1)
	var wild_intro_source := source.substr(wild_intro_start, wild_intro_end - wild_intro_start)
	var wild_event_index := wild_intro_source.find("await _render_initial_battle_events(api_response)")
	var wild_controls_index := wild_intro_source.find("_show_battle_controls_after_initial_events()")
	var wild_ready_index := wild_intro_source.find("_set_battle_actions_ready(true)")
	_check(
		wild_prepare_start >= 0
		and not wild_prepare_source.contains("_show_local_player_trainer()")
		and wild_prepare_source.contains("player_sprite_box.visible = true"),
		"wild battles stage the lead directly without showing the player trainer"
	)
	_check(
		wild_intro_start >= 0
		and not wild_intro_source.contains("_play_lead_summon(")
		and wild_event_index >= 0
		and wild_controls_index > wild_event_index
		and wild_ready_index > wild_controls_index,
		"wild battles unlock controls immediately after required start events without an opening summon"
	)
	var trainer_setup_start := source.find("func setup_trainer_battle_from_response(")
	var pvp_setup_start := source.find("func setup_pvp_battle_from_response(")
	var trainer_show_index := source.find("_show_local_player_trainer()", trainer_setup_start)
	var pvp_show_index := source.find("_show_pvp_trainers(display_response)", pvp_setup_start)
	_check(
		trainer_show_index > trainer_setup_start and trainer_show_index < pvp_setup_start,
		"NPC and story trainer battles keep the local trainer visible"
	)
	_check(
		pvp_show_index > pvp_setup_start,
		"PvP battles keep both trainers visible"
	)
	_check(source.contains("_show_npc_opponent_trainer(trainer_data)"), "trainer battles render the placed NPC")
	_check(source.contains('npc_trainer_display_name = setup_flow.get_trainer_name(trainer_data, "")'), "trainer setup retains the NPC display name for later battle events")
	_check(source.contains('player_id == "p2" and battle_type == BattleType.TRAINER and npc_trainer_display_name != ""'), "NPC switch events prefer the retained trainer name over the generic opponent fallback")
	_check(source.contains("npc_trainer_display_name = \"\""), "every battle setup clears the prior NPC trainer name")
	_check(source.contains("_show_pvp_trainers(display_response)"), "PvP consumes appearances only from its projected response")
	_check(
		source.contains('_vs_panel_call("set_trainer_portraits_visible", [_vs_panel_uses_player_portraits()])'),
		"VS panel hides player heads when full trainer art is staged"
	)
	_check(
		source.contains("return _is_pvp_battle() and not _is_training_room_battle()"),
		"VS portraits remain exclusive to real PvP rather than NPC or AI battles"
	)
	_check(source.contains("_show_pvp_trainers(mapped_snapshot)"), "spectator side swaps rebuild side-owned trainer visuals")
	_check(source.contains("# their attached command callouts cannot remain tied to the old side."), "spectator side swaps document callout reset ownership")
	_check(source.contains("if appearance_state.is_empty():\n\t\treturn"), "missing opponent appearances stay hidden instead of using a false identity")
	var switch_command_index := source.find("_show_switch_trainer_command(event_data, switch_player_id)")
	var switch_recall_index := source.find("await _play_switch_recall_for_event(event_data, switch_player_id)", switch_command_index)
	_check(switch_command_index >= 0, "switch events present a trainer command")
	_check(switch_recall_index > switch_command_index, "switch commands appear immediately before recall animation")
	_check(source.contains("if battle_type != BattleType.TRAINER:"), "wild battles do not show trainer command callouts")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/battle/battle_ui/battle_trainer_sprite.gd")
	_check(renderer_source.contains("REMOTE_PLAYER_AVATAR_SCRIPT_PATH"), "player staging reuses the overworld avatar renderer lazily")
	_check(renderer_source.contains('"facingDirection": _direction_name(facing_direction)'), "player staging selects an inward-facing overworld pose")
	_check(renderer_source.contains("Node.PROCESS_MODE_DISABLED"), "player staging disables overworld processing")
	var router_source := FileAccess.get_file_as_string(BATTLE_ANIMATION_ROUTER_PATH)
	_check(
		router_source.contains("BattleRenderLayers.MOVE_FOREGROUND"),
		"move overlays use the shared foreground render band"
	)


func _check_npc_metadata_contract() -> void:
	var base_source := FileAccess.get_file_as_string(BASE_NPC_SCRIPT_PATH)
	var trainer_source := FileAccess.get_file_as_string(TRAINER_NPC_SCRIPT_PATH)
	var boss_source := FileAccess.get_file_as_string(BOSS_NPC_SCRIPT_PATH)
	_check(base_source.contains("func build_battle_trainer_metadata"), "BaseNPC owns visual-only battle metadata")
	_check(base_source.contains('battle_metadata["_battle_sprite_frames"] = _get_directional_sprite_frames(npc_sprite_frames)'), "NPC battle metadata reuses directional overworld frames")
	_check(base_source.contains('battle_metadata["_battle_sprite_id"] = resolved_battle_sprite_id'), "NPC metadata includes a resolved catalog battle sprite")
	_check(base_source.contains("func _resolve_battle_sprite_id()"), "NPCs resolve battle art independently from overworld frames")
	_check(base_source.contains('battle_metadata["_battle_mugshot"] = mugshot'), "NPC battle metadata preserves its local portrait for battle outros")
	_check(trainer_source.contains("build_battle_trainer_metadata(trainer_metadata)"), "regular trainers pass their placed overworld sprite")
	_check(boss_source.contains("build_battle_trainer_metadata(trainer_metadata)"), "boss trainers pass their placed overworld sprite")


func _check_runtime_renderer() -> void:
	var catalog := PortraitCatalogScript.new()
	root.add_child(catalog)
	var npc := _create_base_npc_harness()
	npc.set("npc_sprite_frames", NPC_FRAMES)
	npc.set("npc_id", "kanto_alpha_gym_brock")
	root.add_child(npc)
	await process_frame
	var battle_metadata: Dictionary = npc.call("build_battle_trainer_metadata", {})
	var battle_frames := battle_metadata.get("_battle_sprite_frames") as SpriteFrames
	var battle_sprite_id := catalog.resolve_battle_sprite_id(
		"",
		"",
		"kanto_alpha_gym_brock",
		""
	)

	var renderer := BattleTrainerScene.instantiate() as BattleTrainerSprite
	root.add_child(renderer)
	_check(
		renderer.z_index > BattleRenderLayers.FIELD
			and renderer.z_index < BattleRenderLayers.POKEMON,
		"trainer figures render above arena platforms but behind active Pokemon"
	)
	_check(
		renderer.command_callout.z_index == BattleRenderLayers.TRAINER_CALLOUTS
			and renderer.command_callout.z_index > BattleRenderLayers.SIDE_CONDITION_INDICATORS,
		"trainer command callouts remain above all battle-stage overlays"
	)
	renderer.show_npc(battle_frames, Vector2.LEFT)
	_check(renderer.visible, "NPC renderer becomes visible with valid frames")
	_check(renderer.npc_sprite.visible, "NPC renderer exposes its still overworld pose")
	_check(renderer.npc_sprite.animation == &"idle_left", "NPC battle trainers idle facing left")
	renderer.show_command("Spearow, use Peck!")
	var command_callout := renderer.command_callout as Control
	var command_label := command_callout.get_node("Panel/MarginContainer/MessageLabel") as Label
	_check(command_callout.visible, "trainer command callout becomes visible")
	_check(command_label.text == "Spearow, use Peck!", "trainer command callout renders the requested command")
	_check(command_callout.position.x < 0.0, "opponent command callout opens toward the battlefield")
	_check(command_callout.size.x <= 214.0, "trainer command callout stays compact")
	_check(command_callout.position.y <= -150.0, "trainer command callout stays above the trainer sprite")
	_check(renderer.npc_sprite.z_as_relative, "NPC trainer art inherits the protected trainer render band")
	_check(battle_sprite_id == "showdown_brock_lgpe", "NPC uses its existing Showdown assignment for battle art")
	_check(
		str(battle_metadata.get("_battle_sprite_id", "")) == battle_sprite_id,
		"NPC battle metadata resolves the assigned Showdown art locally"
	)
	var catalog_texture := catalog.get_texture(battle_sprite_id)
	renderer.show_catalog_sprite(catalog_texture, Vector2.LEFT)
	_check(renderer.visible, "catalog trainer renderer becomes visible with a valid texture")
	_check(renderer.catalog_sprite.visible, "catalog trainer art is visible")
	_check(not renderer.npc_sprite.visible, "catalog trainer art replaces the overworld-frame renderer")
	_check(renderer.catalog_sprite.texture == catalog_texture, "catalog trainer art keeps the assigned Showdown texture")
	_check(
		renderer.catalog_sprite.position == Vector2(-24.0, -32.0),
		"catalog trainer art aligns its feet and clears the opponent party rail"
	)

	renderer.show_player({
		"gender": "male",
		"body": "Gen4_Base_v1",
		"hair": "Adinho_Hair",
		"facial_hair": "Adinho_Beard",
	}, Vector2.RIGHT)
	_check(renderer.player_avatar != null, "player trainer avatar is composed for battle")
	var body := renderer.player_avatar.find_child("BodySprite", true, false) as AnimatedSprite2D
	_check(body != null and body.animation == &"idle_right", "hidden trainer initialization applies the actual right-facing animation before processing stops")
	_check(
		renderer.player_avatar != null and renderer.player_avatar.z_as_relative,
		"layered player trainer art inherits the protected trainer render band"
	)

	renderer.clear()
	_check(not renderer.visible, "clearing a trainer removes its battle visual")
	_check(not command_callout.visible, "clearing a trainer also clears its command callout")
	renderer.free()
	npc.free()
	catalog.free()

	var default_image := _render_player_trainer_skin("#f8d0b8")
	var deep_image := _render_player_trainer_skin("#3f271f")
	var changed_skin_pixels := _count_changed_opaque_pixels(default_image, deep_image)
	_check(
		changed_skin_pixels > 12,
		"inward-facing battle trainers render their selected skin tone"
	)


func _create_base_npc_harness() -> Node2D:
	var npc := (load(BASE_NPC_SCRIPT_PATH) as Script).new() as Node2D
	var look := Node2D.new()
	look.name = "Look"
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	look.add_child(sprite)
	npc.add_child(look)
	var feet_marker := Marker2D.new()
	feet_marker.name = "FeetMarker"
	npc.add_child(feet_marker)
	var interaction_area := Area2D.new()
	interaction_area.name = "InteractionArea"
	npc.add_child(interaction_area)
	return npc


func _render_player_trainer_skin(skin_tone: String) -> Image:
	var renderer := BattleTrainerScene.instantiate() as BattleTrainerSprite
	root.add_child(renderer)
	renderer.show_player({
		"gender": "male",
		"body": "Gen4_Base_v1",
		"hair": "Adinho_Hair",
		"facial_hair": "Adinho_Beard",
		"skin_tone": skin_tone,
	}, Vector2.RIGHT)
	var body_sprite := renderer.player_avatar.find_child("BodySprite", true, false) as AnimatedSprite2D
	var image: Image
	if body_sprite != null and body_sprite.sprite_frames != null:
		var texture := body_sprite.sprite_frames.get_frame_texture(body_sprite.animation, body_sprite.frame)
		if texture != null:
			image = texture.get_image()
	renderer.free()
	return image


func _count_changed_opaque_pixels(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return 0
	var changed := 0
	for y: int in range(first.get_height()):
		for x: int in range(first.get_width()):
			var first_pixel := first.get_pixel(x, y)
			var second_pixel := second.get_pixel(x, y)
			if first_pixel.a <= 0.01 and second_pixel.a <= 0.01:
				continue
			var difference := Vector4(
				first_pixel.r - second_pixel.r,
				first_pixel.g - second_pixel.g,
				first_pixel.b - second_pixel.b,
				first_pixel.a - second_pixel.a
			).length()
			if difference > 0.02:
				changed += 1
	return changed


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
